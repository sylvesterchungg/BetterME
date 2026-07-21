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
  /// Gemini for a correlation — mirrors FR_407's graceful missing-data rule.
  static const int minDaysForInsight = 3;

  static final _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: ApiKeys.geminiApiKey,
    generationConfig: GenerationConfig(
      temperature: 0.6,
      // gemini-2.5-flash is a *thinking* model: it spends output tokens on
      // internal reasoning before the answer. The budget must cover thinking
      // (~400-800 tokens here) PLUS the JSON, or the response truncates to
      // invalid JSON. 2048 leaves comfortable headroom. (The 0.4.7 package
      // can't set thinkingBudget:0, which would otherwise disable thinking.)
      maxOutputTokens: 2048,
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
    // data are simply omitted (FR_407) rather than sent as zeros.
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
        if (rec != null)
          'task_completion_pct': (rec.completionRate * 100).round(),
      });
    }

    final payload = jsonEncode({
      'period': '${window}_days',
      'data_points': dataPoints,
    });

    const systemPrompt =
        '''You are an empathetic, non-judgmental wellness analyst for the BetterME app.

Analyse the user's rolling 7-day logs and surface the SINGLE clearest connection between Sleep, Mood, and Task Completion (for example: sleep -> mood, or mood -> productivity). Pick the strongest relationship — do not list several.

Scales: "mood" and "sleep_quality" are 0-10, "sleep_hrs" is hours, "task_completion_pct" is 0-100.

Write in warm, plain, "calm technology" language: supportive, never clinical, never guilt-inducing, no medical claims. Ground the breakdown in the user's own numbers. Keep every field short and easy to read.

Data:''';

    try {
      final response = await _model.generateContent([
        Content.text('$systemPrompt\n$payload'),
      ]);
      final text = response.text;
      if (text == null || text.trim().isEmpty) return null;
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return null;
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

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
