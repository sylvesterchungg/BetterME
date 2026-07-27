import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/api_keys.dart';
import '../models/models.dart';

// AIInsight lives in models.dart so the DB layer and provider can share it.

class AIInsightService {
  static const _placeholderKey = 'YOUR_GEMINI_API_KEY_HERE';

  /// Minimum distinct logged days (within the window) needed before we ask
  /// Gemini for a correlation — mirrors FR_406's graceful missing-data rule.
  static const int minDaysForInsight = 3;

  /// The model used for every call. Chosen on measured free-tier quota, which
  /// is the binding constraint for a live demo — not on model quality:
  ///   gemini-2.5-flash      20 RPD  — unusable; one debug session exhausts it
  ///   gemini-3(.5)-flash    20 RPD  — same wall
  ///   gemini-3.5-flash-lite 500 RPD — quota fine, but measured 40-120s latency
  ///   gemma-4-31b-it     14.4K RPD  — 5-7s latency, 30 RPM
  ///
  /// Gemma is an open model and honours `responseSchema` less reliably than the
  /// Gemini models: roughly 1 call in 8 appends a second JSON object after the
  /// first (hence [firstJsonObject]), and it can echo schema field names into
  /// the prose (hence the "never name a field" rule in each prompt).
  ///
  /// Use the 31B, not gemma-4-26b-a4b-it: the 26B misread 80% task completion
  /// as "0% task completion ... room for improvement" in testing, which is
  /// exactly the kind of error this app must never show a user.
  ///
  /// Gemma on the Gemini API does not accept `systemInstruction`; every call
  /// here inlines the system prompt into the user turn, so that is a non-issue.
  static const String _modelName = 'gemma-4-31b-it';

  /// Hard ceiling on any single generation. Without it a slow draw is an
  /// indefinite spinner in the UI; with it, a stall lands in the existing
  /// catch block and degrades to the same null path as any other failure.
  static const Duration _callTimeout = Duration(seconds: 20);

  static final _model = GenerativeModel(
    model: _modelName,
    apiKey: ApiKeys.geminiApiKey,
    generationConfig: GenerationConfig(
      temperature: 0.6,
      // Gemma is not a thinking model, so the JSON (4 short fields) is all this
      // budget has to cover. Kept generous anyway: a truncated response is an
      // unterminated string, and [firstJsonObject] discards those outright
      // rather than surfacing half an insight. Ceiling is 32768 for this model.
      maxOutputTokens: 8192,
      // Force a strict, parseable JSON shape so the UI never has to guess.
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'correlation_type': Schema.string(
            description:
                'Very short label for the single clearest relationship, '
                'e.g. "Positive Sleep-Productivity Link". Max 5 words.',
          ),
          'headline_insight': Schema.string(
            description:
                'One warm, encouraging sentence summarising the finding. '
                'Max 12 words. No numbers, no jargon.',
          ),
          'detailed_breakdown': Schema.string(
            description:
                '1-2 plain sentences explaining the pattern using the '
                "user's own numbers (e.g. sleep hours, mood, completion %).",
          ),
          'actionable_nudge': Schema.string(
            description:
                'One gentle, specific, non-judgmental suggestion for the '
                'next day or two. Supportive tone, no pressure. Max 20 words.',
          ),
        },
        requiredProperties: [
          'correlation_type',
          'headline_insight',
          'detailed_breakdown',
          'actionable_nudge',
        ],
      ),
    ),
  );

  /// Separate model for coping suggestions — same Gemini model, different
  /// output shape (an intro line + a short list of coping actions).
  static final _copingModel = GenerativeModel(
    model: _modelName,
    apiKey: ApiKeys.geminiApiKey,
    generationConfig: GenerationConfig(
      temperature: 0.7,
      maxOutputTokens: 8192,
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'intro': Schema.string(
            description:
                'One warm, validating sentence acknowledging the rough patch. '
                'No diagnosis, no alarm. Max 20 words.',
          ),
          'tips': Schema.array(
            description: '2 to 3 gentle, specific coping actions.',
            items: Schema.object(
              properties: {
                'title': Schema.string(
                  description: 'A short action label, e.g. "Wind-down ritual". '
                      'Max 4 words.',
                ),
                'detail': Schema.string(
                  description:
                      'One friendly sentence on how to do it, tailored to what '
                      'the user logged. Max 22 words.',
                ),
              },
              requiredProperties: ['title', 'detail'],
            ),
          ),
        },
        requiredProperties: ['intro', 'tips'],
      ),
    ),
  );

  /// A deterministic fingerprint of the last [window] days of data. If this
  /// string is unchanged, the cached insight is still valid and no new Gemini
  /// call is needed. Any change to sleep/mood/quality/completion flips it.
  static String signatureFor(
    List<LogEntry> logs,
    List<ProductivityRecord> records, {
    int window = 7,
  }) {
    final now = DateTime.now();
    final recordMap = {for (final r in records) r.date: r};
    final logByDay = <String, LogEntry>{};
    for (final l in logs) {
      logByDay.putIfAbsent(_key(l.date), () => l);
    }
    final parts = <String>[];
    for (var i = window - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = _key(d);
      final log = logByDay[key];
      final rec = recordMap[key];
      parts.add('$key:'
          '${log?.moodScore ?? 0}:'
          '${log?.sleepHours ?? 0}:'
          '${log?.sleepQuality ?? 0}:'
          '${rec != null ? (rec.completionRate * 100).round() : -1}');
    }
    return parts.join('|');
  }

  /// Distinct days in the last [window] days that carry a mood or sleep log.
  /// Used to gate insight generation and to build the "log N more days" state.
  static int loggedDaysInWindow(List<LogEntry> logs, {int window = 7}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.subtract(Duration(days: window - 1));
    final seen = <String>{};
    for (final l in logs) {
      final d = DateTime(l.date.year, l.date.month, l.date.day);
      if (d.isBefore(cutoff) || d.isAfter(today)) continue;
      if (l.moodScore <= 0 && l.sleepHours <= 0) continue;
      seen.add(_key(d));
    }
    return seen.length;
  }

  /// Returns a structured [AIInsight], or null on failure / not enough data.
  /// Analyses a rolling [window]-day window of the user's real logs.
  static Future<AIInsight?> generateInsights({
    required List<LogEntry> logs,
    required List<ProductivityRecord> productivityRecords,
    int? currentStreak,
    int window = 7,
  }) async {
    if (ApiKeys.geminiApiKey == _placeholderKey) return null;
    if (loggedDaysInWindow(logs, window: window) < minDaysForInsight) {
      return null;
    }

    final now = DateTime.now();
    final days = List.generate(
      window,
      (i) => now.subtract(Duration(days: window - 1 - i)),
    );

    final recordMap = {for (final r in productivityRecords) r.date: r};
    final logByDay = <String, LogEntry>{};
    for (final l in logs) {
      logByDay.putIfAbsent(_key(l.date), () => l);
    }

    // Build the compact JSON payload described in the proposal. Days with no
    // data are simply omitted (FR_406) rather than sent as zeros.
    final dataPoints = <Map<String, dynamic>>[];
    for (final d in days) {
      final key = _key(d);
      final log = logByDay[key];
      final rec = recordMap[key];
      if (log == null && rec == null) continue;
      dataPoints.add({
        'day': DateFormat('E').format(d),
        if (log != null && log.sleepHours > 0)
          'sleep_hrs': double.parse(log.sleepHours.toStringAsFixed(1)),
        if (log != null && log.sleepQuality > 0)
          'sleep_quality': log.sleepQuality,
        if (log != null && log.moodScore > 0)
          'mood': double.parse(log.moodScore.toStringAsFixed(1)),
        // Symptoms / activities / nightmares let the AI tie a bad-sleep or
        // low-mood day to how the user actually felt that day, in plain words.
        if (log != null && log.emotions.isNotEmpty) 'symptoms': log.emotions,
        if (log != null && log.hadNightmare) 'nightmare': true,
        if (log != null && log.trigger.isNotEmpty) 'activities': log.trigger,
        if (rec != null)
          'task_completion_pct': (rec.completionRate * 100).round(),
      });
    }

    final payload = jsonEncode({
      'period': '${window}_days',
      // The user's live progression hook — used only to make the nudge more
      // motivating ("keep your 5-day streak alive"). Deliberately NOT part of
      // signatureFor(): a streak ticking over must not force a fresh Gemini
      // call when sleep/mood/completion are unchanged.
      if (currentStreak != null && currentStreak > 0)
        'current_streak_days': currentStreak,
      'data_points': dataPoints,
    });

    const systemPrompt =
        '''You are a warm, plain-speaking wellness buddy inside the BetterME app. You talk like a caring friend, NOT a scientist or doctor.

Your job: look at the user's rolling 7-day logs and give them ONE encouraging, motivating insight about how their SLEEP is shaping their MOOD and their PROGRESS (tasks finished + their daily streak). Pick a single clear story — do not list several.

HOW SLEEP, MOOD AND PROGRESS USUALLY CONNECT (this is well-established — use it as your background knowledge, but ALWAYS ground the story in THEIR own numbers):
- Sleep sits upstream. A good, longer night tends to lift the NEXT day's mood much more than mood changes sleep — so sleep is the lever they can pull.
- More and better-quality sleep -> a brighter, calmer mood the next day: more positive feelings, less irritability, stress and anxiety.
- That steadier mood plus a rested brain -> more willpower and focus, less procrastination -> more tasks finished and streaks kept alive.
- So the chain reads: sleep well -> feel better -> get more done -> your streak and progress grow. Short or poor sleep quietly runs the same chain in reverse.

Your goal is to MOTIVATE them to protect and extend their sleep by showing them this positive payoff playing out in their own life.

How to write (this matters a lot):
- Use everyday words. NEVER use stats jargon: no "correlation", "coefficient", "r =", "predictor", "data", "metric". Say it like you'd tell a friend.
- Lead with the POSITIVE. Celebrate their good-sleep days and the payoff they got, rather than scolding the rough ones.
- Be concrete. Name a real threshold from THEIR numbers, e.g. "on the nights you got past 7.5 hours, your mood lifted and you finished more of your list".
- When good-sleep days line up with brighter mood and more done (or their streak), SAY it plainly and connect the dots in simple cause-and-effect words.
- If bad-sleep or low-mood days line up with logged symptoms (headache, tired, a nightmare), you may note it gently — but still steer toward the hopeful "more sleep helps" message.
- If the week is short or noisy, you can still lean on the general truth that better sleep usually helps mood and getting things done — but NEVER invent numbers they don't have.
- Be kind and encouraging. Never guilt-trip. No medical claims or diagnoses.
- Every field holds ordinary prose the user will read as-is. NEVER write a field name ("correlation_type", "headline_insight", "detailed_breakdown", "actionable_nudge") inside the text itself, and never prefix a value with its own label.
- Only state numbers that appear in the data below. Never restate one of their figures as a different number.

Scales: "mood" and "sleep_quality" are 0-10, "sleep_hrs" is hours, "task_completion_pct" is 0-100. "current_streak_days" is how many days their logging streak is at right now. "symptoms" is how they felt, "activities" is what they did.

Fill the fields like this:
- correlation_type: a short, friendly plain-word label about the positive link, e.g. "Sleep is fuelling your progress". No jargon.
- headline_insight: one warm, motivating sentence — the main takeaway.
- detailed_breakdown: 2-3 short sentences that NAME a concrete sleep threshold from their data and connect it to their mood AND what they got done, in simple cause-and-effect words.
- actionable_nudge: one gentle, specific, encouraging tip aimed at getting a bit MORE sleep, with a real number, and tie it to the payoff — e.g. "try to be in bed by 11pm to hit 7+ hours; your mood and your streak will thank you".

Data:''';

    try {
      final response = await _model.generateContent([
        Content.text('$systemPrompt\n$payload'),
      ]).timeout(_callTimeout);
      final decoded = _decodeJson(response.text, 'AIInsight');
      if (decoded == null) return null;
      final insight = AIInsight.fromJson(decoded);
      if (insight.isEmpty) return null;
      // Stamp with the data fingerprint + time so it can be cached and reused.
      return insight.copyWith(
        dataSignature: signatureFor(logs, productivityRecords, window: window),
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[AIInsight] error: $e');
      return null;
    }
  }

  // ─────────────────────────── COPING SUGGESTIONS ───────────────────────────

  /// Minimum "rough" days in the window before we surface coping support.
  static const int minRoughDaysForCoping = 2;

  /// A day is "rough" if it carries a nightmare, a logged symptom, or a clearly
  /// low mood. (All of the app's symptoms — Anxiety/Fatigue/Headache/Nausea/
  /// Pain — are negative, so any logged symptom counts.)
  static bool _isRoughDay(LogEntry l) =>
      l.hadNightmare ||
      l.emotions.isNotEmpty ||
      (l.moodScore > 0 && l.moodScore <= 4);

  /// Rough days within the last [window] days.
  static int roughDaysInWindow(List<LogEntry> logs, {int window = 7}) =>
      _recentRoughLogs(logs, window: window).length;

  /// Whether there's enough of a rough cluster to offer coping support.
  static bool hasRoughCluster(List<LogEntry> logs, {int window = 7}) =>
      roughDaysInWindow(logs, window: window) >= minRoughDaysForCoping;

  static List<LogEntry> _recentRoughLogs(List<LogEntry> logs, {int window = 7}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.subtract(Duration(days: window - 1));
    final byDay = <String, LogEntry>{};
    for (final l in logs) {
      final d = DateTime(l.date.year, l.date.month, l.date.day);
      if (d.isBefore(cutoff) || d.isAfter(today)) continue;
      if (_isRoughDay(l)) byDay[_key(d)] = l;
    }
    final list = byDay.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  /// Fingerprint of the rough-day content — flips when the symptoms/nightmares/
  /// low-mood days change, so cached coping tips regenerate only when needed.
  static String copingSignatureFor(List<LogEntry> logs, {int window = 7}) {
    final rough = _recentRoughLogs(logs, window: window);
    return rough
        .map((l) => '${_key(l.date)}:'
            '${l.hadNightmare ? 1 : 0}:'
            '${(l.emotions.toList()..sort()).join(",")}:'
            '${l.moodScore <= 4 ? l.moodScore : 0}')
        .join('|');
  }

  /// Returns tailored coping suggestions, or null when there's no cluster / on
  /// failure. Looks at the recent rough days (nightmares, symptoms, low mood).
  static Future<AICopingTips?> generateCoping({
    required List<LogEntry> logs,
    int window = 7,
  }) async {
    if (ApiKeys.geminiApiKey == _placeholderKey) return null;
    final rough = _recentRoughLogs(logs, window: window);
    if (rough.length < minRoughDaysForCoping) return null;

    // Compact, plain summary of what made recent days rough.
    final lines = <String>[];
    for (final l in rough) {
      final bits = <String>[];
      if (l.hadNightmare) bits.add('nightmare');
      if (l.emotions.isNotEmpty) bits.add('symptoms=${l.emotions.join(",")}');
      if (l.moodScore > 0 && l.moodScore <= 4) {
        bits.add('low_mood=${l.moodScore.toStringAsFixed(0)}/10');
      }
      if (l.trigger.isNotEmpty) bits.add('activities=${l.trigger}');
      lines.add('${DateFormat('E').format(l.date)}: ${bits.join(" ")}');
    }
    final payload = jsonEncode({'rough_days': lines});

    const systemPrompt =
        '''You are a warm, caring wellness buddy in the BetterME app — like a supportive friend, NOT a doctor.

The user has had a few rough days recently (some mix of nightmares, physical/mental symptoms, or low mood). Look at what they logged and offer gentle, practical self-care they can actually try. Be validating first, then helpful.

Rules:
- Warm, everyday language. No clinical or scary wording. No diagnosis. No medical claims.
- Tailor the tips to what they actually logged. If nightmares show up, suggest calming pre-sleep ideas. If it's anxiety, suggest grounding/breathing. Headache/fatigue -> rest, hydration, screen breaks. Match the tips to their signals.
- Keep each tip short, specific and doable today. 2-3 tips only.
- If things sound genuinely heavy, you may gently suggest talking to someone they trust — but keep it light and optional, never alarming.
- Every field holds ordinary prose the user will read as-is. NEVER write a field name ("intro", "tips", "title", "detail") inside the text itself, and never prefix a value with its own label. A title is a short plain phrase like "Wind-down ritual".

Fill the fields:
- intro: one warm sentence letting them know it's okay and you've noticed.
- tips: 2-3 items, each with a short "title" and a one-sentence "detail".

What they logged recently:''';

    try {
      final response = await _copingModel.generateContent([
        Content.text('$systemPrompt\n$payload'),
      ]).timeout(_callTimeout);
      final decoded = _decodeJson(response.text, 'AICoping');
      if (decoded == null) return null;
      final coping = AICopingTips.fromJson(decoded);
      if (coping.isEmpty) return null;
      return coping.copyWith(
        signature: copingSignatureFor(logs, window: window),
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[AICoping] error: $e');
      return null;
    }
  }

  // ─────────────────────────── MORNING NUDGE ───────────────────────────

  /// One-line good-morning tip. Same Gemini model, minimal single-field shape.
  static final _nudgeModel = GenerativeModel(
    model: _modelName,
    apiKey: ApiKeys.geminiApiKey,
    generationConfig: GenerationConfig(
      temperature: 0.7,
      // Headroom against truncation; matches the coping/insight budget.
      maxOutputTokens: 8192,
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'nudge': Schema.string(
            description: 'One warm good-morning sentence with a single '
                'practical tip for today. Max 25 words. Everyday words only, '
                'no numbers or jargon.',
          ),
        },
        requiredProperties: ['nudge'],
      ),
    ),
  );

  /// Fingerprint for the morning nudge: today's date + last night's log +
  /// streak. Flips when a new day starts or last night's log changes, so a
  /// cached nudge is reused until something meaningful is different.
  ///
  /// Deliberately EXCLUDES the pending-task count. The count is still sent to
  /// the model for colour, but ticking a checkbox must not invalidate the
  /// cache: it is a *morning* greeting, and regenerating it mid-afternoon on
  /// every completion is both odd behaviour and the app's largest source of
  /// API calls (a user with 8 tasks burned ~8 extra calls a day).
  static String nudgeSignatureFor(LogEntry? latest, {int? streak}) {
    final today = _key(DateTime.now());
    if (latest == null) return '$today|nolog|${streak ?? 0}';
    return '$today|${_key(latest.date)}|${latest.sleepHours}'
        '|${latest.sleepQuality}|${latest.moodScore}|${latest.hadNightmare}'
        '|${(latest.emotions.toList()..sort()).join(",")}'
        '|${streak ?? 0}';
  }

  /// One-line personalized morning nudge, or null on failure / no recent data.
  static Future<MorningNudge?> generateMorningNudge({
    required LogEntry? latest,
    required int pendingTasks,
    int? streak,
  }) async {
    if (ApiKeys.geminiApiKey == _placeholderKey) return null;
    if (latest == null) return null;

    final ctx = StringBuffer();
    if (latest.sleepHours > 0) {
      ctx.write('slept ${latest.sleepHours.toStringAsFixed(1)}h ');
    }
    if (latest.sleepQuality > 0) {
      ctx.write('sleep quality ${latest.sleepQuality}/10 ');
    }
    if (latest.hadNightmare) ctx.write('had a nightmare ');
    if (latest.moodScore > 0) {
      ctx.write('mood ${latest.moodScore.toStringAsFixed(1)}/10 ');
    }
    if (latest.emotions.isNotEmpty) {
      ctx.write('felt ${latest.emotions.join(", ")} ');
    }
    ctx.write('| $pendingTasks task(s) left today');
    if (streak != null && streak > 0) ctx.write(' | $streak-day streak');

    final prompt =
        '''You are a warm morning wellness buddy in the BetterME app.
Greet the user briefly and give ONE short, friendly, practical tip for TODAY based on how they slept and felt last night and how many tasks they have.
Rules: exactly one sentence, max 25 words. Everyday words, no stats or jargon. Kind and encouraging, never guilt. If they slept little or had a nightmare, be gentle and suggest easing in. If they slept well, be upbeat. Mention water, rest, or pacing when it fits.
The "nudge" field holds ordinary prose the user reads as-is — never write the word "nudge" in it, and never prefix it with a label.
Their morning so far: ${ctx.toString()}''';

    try {
      final response = await _nudgeModel
          .generateContent([Content.text(prompt)]).timeout(_callTimeout);
      final decoded = _decodeJson(response.text, 'MorningNudge');
      if (decoded == null) return null;
      final nudge = MorningNudge.fromJson(decoded);
      if (nudge.isEmpty) return null;
      return nudge.copyWith(
        signature: nudgeSignatureFor(latest, streak: streak),
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[MorningNudge] error: $e');
      return null;
    }
  }

  // ─────────────────────────── RESPONSE PARSING ───────────────────────────

  /// Returns the first complete JSON object in [raw], or null if there isn't
  /// one. Gemma sometimes emits a valid object followed by a second object or
  /// stray prose, which makes a plain [jsonDecode] throw "Extra data".
  ///
  /// Note this deliberately does NOT use the common `indexOf('{')` ..
  /// `lastIndexOf('}')` slice: when the trailing junk is itself a JSON object,
  /// `lastIndexOf` reaches into it and the slice spans both objects, throwing
  /// the very same "Extra data" error. Scanning forward on brace depth (while
  /// skipping braces inside string literals) takes only the first value.
  ///
  /// A response truncated mid-object returns null rather than a partial slice —
  /// half an insight is worse than none.
  @visibleForTesting
  static String? firstJsonObject(String raw) {
    final start = raw.indexOf('{');
    if (start == -1) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < raw.length; i++) {
      final c = raw[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') {
        inString = true;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) return raw.substring(start, i + 1);
      }
    }
    return null;
  }

  /// Shared decode path for all three call sites. Returns null (never throws)
  /// so every failure mode collapses into the same graceful empty state.
  static Map<String, dynamic>? _decodeJson(String? text, String tag) {
    if (text == null || text.trim().isEmpty) return null;
    final slice = firstJsonObject(text);
    if (slice == null) {
      debugPrint('[$tag] no complete JSON object in response');
      return null;
    }
    try {
      final decoded = jsonDecode(slice);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded;
    } on FormatException catch (e) {
      debugPrint('[$tag] JSON parse failed: $e');
      return null;
    }
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
