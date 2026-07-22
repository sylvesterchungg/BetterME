import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/ai_insight_service.dart';
import '../theme.dart';
import '../utils/stats.dart';
import '../widgets/app_page_header.dart';

class TrendsInsightsScreen extends StatefulWidget {
  const TrendsInsightsScreen({super.key});

  @override
  State<TrendsInsightsScreen> createState() => _TrendsInsightsScreenState();
}

class _TrendsInsightsScreenState extends State<TrendsInsightsScreen> {
  // AI insight state
  AIInsight? _aiInsight;
  bool _loadingAI = false;
  bool _aiError = false;
  // Data signature we've already resolved (shown from cache or attempted to
  // generate) — prevents re-triggering on every rebuild and error loops.
  String? _handledSignature;

  // Coping-suggestions state (mirrors the insight flow above).
  AICopingTips? _coping;
  bool _loadingCoping = false;
  String? _copingHandledSig;

  /// How long a cached insight stays fresh before we regenerate it.
  static const Duration _cacheTtl = Duration(hours: 24);

  Future<void> _generateInsight(AppProvider provider, List<LogEntry> logs,
      List<ProductivityRecord> records) async {
    if (_loadingAI) return;
    setState(() {
      _loadingAI = true;
      _aiError = false;
    });
    final result = await AIInsightService.generateInsights(
      logs: logs,
      productivityRecords: records,
      currentStreak: provider.currentUser?.streak,
    );
    if (!mounted) return;
    setState(() {
      _loadingAI = false;
      if (result == null) {
        _aiError = true;
      } else {
        _aiInsight = result;
        _handledSignature = result.dataSignature;
      }
    });
    if (result != null) {
      // Cache it so the next open is instant and skips the Gemini call.
      provider.persistInsight(result);
    }
  }

  Future<void> _generateCoping(
      AppProvider provider, List<LogEntry> logs) async {
    if (_loadingCoping) return;
    setState(() => _loadingCoping = true);
    final result = await AIInsightService.generateCoping(logs: logs);
    if (!mounted) return;
    setState(() {
      _loadingCoping = false;
      if (result != null) _coping = result;
    });
    if (result != null) provider.persistCoping(result);
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final logs = appProvider.logs;
    final productivityRecords = appProvider.productivityRecords;

    // Decide once per data-signature whether to reuse the cache or regenerate.
    // A changed signature (new data) re-enters even after a prior error, so
    // fresh logs auto-retry; the sync guard below stops same-data error loops.
    final loggedDays = AIInsightService.loggedDaysInWindow(logs);
    if (loggedDays >= AIInsightService.minDaysForInsight && !_loadingAI) {
      final currentSig =
          AIInsightService.signatureFor(logs, productivityRecords);
      if (_handledSignature != currentSig) {
        // Guard synchronously so a rebuild before the callback can't double-fire.
        _handledSignature = currentSig;
        final cached = appProvider.cachedInsight;
        final cacheFresh = cached != null &&
            cached.dataSignature == currentSig &&
            DateTime.now().difference(cached.generatedAt) < _cacheTtl;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (cacheFresh) {
            setState(() {
              _aiInsight = cached;
              _aiError = false;
            });
          } else {
            _generateInsight(appProvider, logs, productivityRecords);
          }
        });
      }
    }

    // Coping suggestions: only when rough days (nightmares/symptoms/low mood)
    // cluster in the recent logs. Same cache-or-generate approach as insights.
    final showCoping = AIInsightService.hasRoughCluster(logs);
    if (showCoping && !_loadingCoping) {
      final copingSig = AIInsightService.copingSignatureFor(logs);
      if (_copingHandledSig != copingSig) {
        _copingHandledSig = copingSig;
        final cachedCoping = appProvider.cachedCoping;
        final copingFresh = cachedCoping != null &&
            cachedCoping.signature == copingSig &&
            DateTime.now().difference(cachedCoping.generatedAt) < _cacheTtl;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (copingFresh) {
            setState(() => _coping = cachedCoping);
          } else {
            _generateCoping(appProvider, logs);
          }
        });
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(title: 'Trends & Insights', user: appProvider.currentUser),
            const SizedBox(height: 24),
            _buildAIInsightCard(appProvider, logs, productivityRecords),
            const SizedBox(height: 24),
            _buildInsightVisual(logs, productivityRecords),
            ..._buildCopingSection(showCoping),
            _buildWeeklyTrends(logs, productivityRecords),
            const SizedBox(height: 24),
            _buildProductivityTrend(logs, productivityRecords),
            const SizedBox(height: 24),
            _buildTopEmotions(logs),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Coping card + trailing spacing, only when a rough cluster exists and we
  /// have tips (or are loading them). Returns [] otherwise (no vertical space).
  List<Widget> _buildCopingSection(bool showCoping) {
    if (!showCoping) return const [];
    if (_loadingCoping && _coping == null) {
      return [_buildCopingLoading(), const SizedBox(height: 24)];
    }
    if (_coping == null || _coping!.isEmpty) return const [];
    return [_buildCopingCard(_coping!), const SizedBox(height: 24)];
  }

  // ══════════════════════════════ AI INSIGHT CARD ════════════════════════════

  // Calm-technology palette for the AI card (cool teal → soft blue).
  static const Color _aiTeal = Color(0xFF0D9488); // accent
  static const Color _aiInk = Color(0xFF10403B); // headline slate
  static const Color _aiBody = Color(0xFF334155); // body slate

  Widget _buildAIInsightCard(AppProvider provider, List<LogEntry> logs,
      List<ProductivityRecord> records) {
    final loggedDays = AIInsightService.loggedDaysInWindow(logs);
    final hasEnoughData = loggedDays >= AIInsightService.minDaysForInsight;
    final remaining = AIInsightService.minDaysForInsight - loggedDays;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE0F2F1), Color(0xFFE3EEF9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _aiTeal.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: _aiTeal.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _aiTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 13, color: _aiTeal),
                      SizedBox(width: 5),
                      Text('7-Day AI Insight',
                          style: TextStyle(
                              fontSize: 11,
                              color: _aiTeal,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const Spacer(),
                if (hasEnoughData && !_loadingAI)
                  GestureDetector(
                    onTap: () => _generateInsight(provider, logs, records),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _aiTeal.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.refresh, size: 16, color: _aiTeal),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasEnoughData)
              _buildAINotEnough(remaining)
            else if (_loadingAI)
              _buildAILoading()
            else if (_aiError)
              _buildAIErrorState(provider, logs, records)
            else if (_aiInsight != null)
              _buildInsightBody(_aiInsight!)
            else
              _buildAILoading(),
          ],
        ),
      ),
    );
  }

  Widget _buildAINotEnough(int remaining) {
    final dayWord = remaining == 1 ? 'day' : 'days';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your BetterME Assistant',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: _aiInk)),
        const SizedBox(height: 8),
        Text(
          'Log $remaining more $dayWord of sleep and mood, and I\'ll show you '
          'how your rest, mood and focus connect over the week!',
          style: const TextStyle(fontSize: 14, color: _aiBody, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildAILoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reading your last 7 days…',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: _aiInk)),
        const SizedBox(height: 14),
        LinearProgressIndicator(
          backgroundColor: _aiTeal.withValues(alpha: 0.15),
          valueColor: const AlwaysStoppedAnimation<Color>(_aiTeal),
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Text('Looking for the connection between sleep, mood and focus…',
            style: TextStyle(
                fontSize: 12, color: _aiBody.withValues(alpha: 0.7))),
      ],
    );
  }

  Widget _buildAIErrorState(AppProvider provider, List<LogEntry> logs,
      List<ProductivityRecord> records) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Insight unavailable',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: _aiInk)),
        const SizedBox(height: 8),
        const Text(
          'We couldn’t reach the AI just now. Check your connection or API key '
          'and try again.',
          style: TextStyle(fontSize: 13, color: _aiBody, height: 1.5),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => _generateInsight(provider, logs, records),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: _aiTeal,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Try again',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }

  /// Renders the structured insight: label → headline → breakdown → gentle tip.
  Widget _buildInsightBody(AIInsight insight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (insight.correlationType.isNotEmpty) ...[
          Text(
            insight.correlationType.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: _aiTeal.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 8),
        ],
        if (insight.headline.isNotEmpty)
          Text(
            insight.headline,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _aiInk,
                height: 1.35),
          ),
        if (insight.breakdown.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            insight.breakdown,
            style: const TextStyle(fontSize: 14, color: _aiBody, height: 1.55),
          ),
        ],
        if (insight.nudge.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _aiTeal.withValues(alpha: 0.20)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insight.nudge,
                    style: const TextStyle(
                        fontSize: 13.5,
                        color: _aiInk,
                        height: 1.5,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════ AI INSIGHT VISUAL (the story in a chart) ══════════════

  /// A 7-day overlay of sleep, mood and tasks-done — the picture behind the AI
  /// insight, so the user can SEE the sleep → mood → progress story it describes.
  Widget _buildInsightVisual(
      List<LogEntry> logs, List<ProductivityRecord> records) {
    // Only shown alongside a real insight (needs enough recent days).
    if (AIInsightService.loggedDaysInWindow(logs) <
        AIInsightService.minDaysForInsight) {
      return const SizedBox.shrink();
    }

    const sleepColor = Color(0xFF0D9488);
    const moodColor = Color(0xFFF59E0B);
    const prodColor = Color(0xFF10B981);

    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final logByDay = {for (final l in logs) _dayKey(l.date): l};
    final recMap = {for (final r in records) r.date: r};

    final sleep = <double?>[];
    final mood = <double?>[];
    final prod = <double?>[];
    var hasSleep = false, hasMood = false, hasProd = false;
    for (final d in days) {
      final key = _dayKey(d);
      final l = logByDay[key];
      final r = recMap[key];
      // Normalize each to 0..1 so they overlay comparably.
      final s = (l != null && l.sleepHours > 0)
          ? (l.sleepHours / 10).clamp(0.0, 1.0)
          : null;
      final m = (l != null && l.moodScore > 0)
          ? (l.moodScore / 10).clamp(0.0, 1.0)
          : null;
      final p = r?.completionRate.clamp(0.0, 1.0);
      if (s != null) hasSleep = true;
      if (m != null) hasMood = true;
      if (p != null) hasProd = true;
      sleep.add(s);
      mood.add(m);
      prod.add(p);
    }

    final series = <List<double?>>[];
    final colors = <Color>[];
    final legend = <({String label, Color color})>[];
    if (hasSleep) {
      series.add(sleep);
      colors.add(sleepColor);
      legend.add((label: 'Sleep', color: sleepColor));
    }
    if (hasMood) {
      series.add(mood);
      colors.add(moodColor);
      legend.add((label: 'Mood', color: moodColor));
    }
    if (hasProd) {
      series.add(prod);
      colors.add(prodColor);
      legend.add((label: 'Tasks done', color: prodColor));
    }
    if (series.isEmpty) return const SizedBox.shrink();

    final dayLabels = days.map((d) => DateFormat('E').format(d)).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderDefault),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The story behind your insight',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface)),
              const SizedBox(height: 4),
              const Text(
                  'How your sleep, mood and tasks moved together this week',
                  style: TextStyle(fontSize: 12, color: AppTheme.outline)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  for (final e in legend)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: e.color, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(e.label,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.onSurfaceVariant)),
                    ]),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 120,
                width: double.infinity,
                child: CustomPaint(
                    painter: _TriLinePainter(series: series, colors: colors)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final lbl in dayLabels)
                    Expanded(
                        child: Text(lbl,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 9, color: AppTheme.outline))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ═════════════════════════ COPING SUGGESTIONS (AI) ═════════════════════════

  Widget _buildCopingLoading() {
    const accent = Color(0xFF8B7CC8);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.spa_outlined, size: 16, color: accent),
            SizedBox(width: 8),
            Text('A little support',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3B3560))),
          ]),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            backgroundColor: accent.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(accent),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          const Text('Putting together a few calming ideas for you…',
              style: TextStyle(fontSize: 12, color: Color(0xFF4B4463))),
        ],
      ),
    );
  }

  Widget _buildCopingCard(AICopingTips coping) {
    const accent = Color(0xFF8B7CC8);
    const ink = Color(0xFF3B3560);
    const body = Color(0xFF4B4463);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3F1FB), Color(0xFFF7F1F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.spa_outlined, size: 13, color: accent),
                SizedBox(width: 5),
                Text('A little support',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent)),
              ]),
            ),
            if (coping.intro.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(coping.intro,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ink,
                      height: 1.4)),
            ],
            const SizedBox(height: 16),
            for (int i = 0; i < coping.tips.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _buildCopingTip(coping.tips[i], accent, ink, body),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCopingTip(AICopingTip tip, Color accent, Color ink, Color body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration:
              BoxDecoration(color: accent.withValues(alpha: 0.14), shape: BoxShape.circle),
          child: Icon(Icons.favorite, size: 12, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tip.title.isNotEmpty)
                Text(tip.title,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: ink)),
              if (tip.detail.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(tip.detail,
                    style: TextStyle(fontSize: 13, color: body, height: 1.45)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════ WEEKLY TRENDS ══════════════════════════════

  Widget _buildWeeklyTrends(List<LogEntry> logs, List<ProductivityRecord> productivityRecords) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final dayKeys = days
        .map((d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}')
        .toList();

    final logByDay = <String, LogEntry>{};
    for (final log in logs) {
      final key = '${log.date.year}-${log.date.month.toString().padLeft(2, '0')}-${log.date.day.toString().padLeft(2, '0')}';
      logByDay[key] = log;
    }
    final recordMap = {for (var r in productivityRecords) r.date: r};

    final sleepVals = dayKeys.map((k) => logByDay[k]?.sleepHours ?? 0.0).toList();
    final moodVals = dayKeys.map((k) => logByDay[k]?.moodScore ?? 0.0).toList();
    final prodVals = dayKeys.map((k) => recordMap[k]?.completionRate ?? 0.0).toList();

    // Same rule as the Profile stats: average only the days that carry real
    // data (see meanIgnoringZero in utils/stats.dart).
    final avgSleep = meanIgnoringZero(sleepVals);
    final avgMood = meanIgnoringZero(moodVals);
    final avgProd = meanIgnoringZero(prodVals);

    String moodStatus;
    if (avgMood == 0) {
      moodStatus = 'No data';
    } else if (avgMood >= 7) {
      moodStatus = 'Status: Positive';
    } else if (avgMood >= 5) {
      moodStatus = 'Status: Stable';
    } else {
      moodStatus = 'Status: Low';
    }

    final dayLabels = days.map((d) => DateFormat('E').format(d).substring(0, 3)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: const [
            Text('Weekly Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text('Last 7 days', style: TextStyle(fontSize: 12, color: AppTheme.outline)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderDefault),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              _buildMiniBarSection(
                icon: Icons.bedtime_outlined,
                label: 'Sleep',
                stat: avgSleep > 0 ? 'Avg: ${avgSleep.toStringAsFixed(1)}h' : 'No data',
                statColor: AppTheme.primary,
                values: sleepVals,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 20),
              _buildMiniBarSection(
                icon: Icons.mood,
                label: 'Mood',
                stat: moodStatus,
                statColor: AppTheme.secondary,
                values: moodVals,
                color: AppTheme.secondary,
              ),
              const SizedBox(height: 20),
              _buildMiniBarSection(
                icon: Icons.check_circle_outline,
                label: 'Productivity',
                stat: avgProd > 0 ? 'Done: ${(avgProd * 100).toInt()}%' : 'No data',
                statColor: AppTheme.tertiary,
                values: prodVals,
                color: AppTheme.tertiary,
              ),
              const SizedBox(height: 8),
              Row(
                children: dayLabels
                    .map((d) => Expanded(
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, color: AppTheme.outline, fontWeight: FontWeight.w500),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════ PRODUCTIVITY TREND (FR_403) ══════════════════

  Widget _buildProductivityTrend(
      List<LogEntry> logs, List<ProductivityRecord> records) {
    final now = DateTime.now();
    final days = List.generate(14, (i) => now.subtract(Duration(days: 13 - i)));
    final dayKeys = days.map(_dayKey).toList();
    final dayLabels =
        days.map((d) => DateFormat('d/M').format(d)).toList();

    final recordMap = {for (final r in records) r.date: r};
    final prodVals =
        dayKeys.map((k) => recordMap[k]?.completionRate ?? -1.0).toList();

    final hasAnyData = prodVals.any((v) => v >= 0);
    final validVals = prodVals.where((v) => v >= 0);
    final avgProd = validVals.isEmpty
        ? 0.0
        : validVals.reduce((a, b) => a + b) / validVals.length;

    // Mood by day for inline mood-productivity correlation hint
    final logMap = <String, LogEntry>{};
    for (final l in logs) {
      logMap.putIfAbsent(_dayKey(l.date), () => l);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: const [
            Text('Productivity Trend',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text('Last 14 days',
                style: TextStyle(fontSize: 12, color: AppTheme.outline)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderDefault),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stat row
              Row(
                children: [
                  _statPill(
                    Icons.check_circle_outline,
                    hasAnyData
                        ? 'Avg: ${(avgProd * 100).toInt()}%'
                        : 'No data yet',
                    AppTheme.tertiary,
                  ),
                  const SizedBox(width: 10),
                  if (hasAnyData)
                    _statPill(
                      Icons.calendar_today_outlined,
                      '${validVals.length} day${validVals.length == 1 ? "" : "s"} tracked',
                      AppTheme.outline,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (!hasAnyData)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.task_alt,
                            size: 36,
                            color:
                                AppTheme.outlineVariant.withValues(alpha: 0.6)),
                        const SizedBox(height: 10),
                        const Text(
                          'Add tasks and complete them to see your productivity trend.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // 14-day bar chart
                SizedBox(
                  height: 100,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(14, (i) {
                      final val = prodVals[i];
                      final isEmpty = val < 0;
                      final pct = isEmpty ? 0.0 : val.clamp(0.0, 1.0);
                      final isToday = i == 13;
                      final color = isToday ? AppTheme.tertiary : AppTheme.tertiary.withValues(alpha: 0.55);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!isEmpty)
                                Container(
                                  height: math.max(4.0, 88 * pct),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(3)),
                                  ),
                                )
                              else
                                Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 6),
                // Day labels — show only first, middle, and last to avoid clutter
                Row(
                  children: List.generate(14, (i) {
                    final show = i == 0 || i == 6 || i == 13;
                    return Expanded(
                      child: Text(
                        show ? dayLabels[i] : '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 9, color: AppTheme.outline),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                // Mood-productivity mini correlation (FR_405 inline hint)
                _buildMoodProdCorrelationRow(logs, records),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _statPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Inline Mood → Productivity direction hint shown inside the productivity card.
  Widget _buildMoodProdCorrelationRow(
      List<LogEntry> logs, List<ProductivityRecord> records) {
    final recordMap = {for (final r in records) r.date: r};
    final moodProdX = <double>[], moodProdY = <double>[];
    for (final log in logs) {
      if (log.moodScore == 0) continue;
      final rec = recordMap[_dayKey(log.date)];
      if (rec == null) continue;
      moodProdX.add(log.moodScore);
      moodProdY.add(rec.completionRate);
    }
    final c = _pearson(moodProdX, moodProdY);
    if (c == null) {
      return Text(
        'Log a few more days to see how your mood and getting things done go together.',
        style: TextStyle(
            fontSize: 12,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.75),
            height: 1.4),
      );
    }

    final mag = c.abs();
    final howMuch =
        mag >= 0.6 ? 'a lot' : (mag >= 0.3 ? 'a bit' : 'a little');
    final positive = c >= 0;
    final sentence = positive
        ? 'On your brighter-mood days, you tend to get $howMuch more done.'
        : 'Interestingly, your brighter-mood days line up with getting $howMuch less done.';
    final icon = positive ? Icons.trending_up : Icons.trending_down;
    final color = positive ? AppTheme.tertiary : AppTheme.secondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sentence,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.onSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════ CORRELATIONS ══════════════════════════════

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Pearson correlation over two aligned lists; null if fewer than 3 pairs or
  /// a series has no variance.
  double? _pearson(List<double> xs, List<double> ys) {
    final n = xs.length;
    if (n < 3) return null;
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    double num = 0, dx = 0, dy = 0;
    for (int i = 0; i < n; i++) {
      num += (xs[i] - mx) * (ys[i] - my);
      dx += (xs[i] - mx) * (xs[i] - mx);
      dy += (ys[i] - my) * (ys[i] - my);
    }
    if (dx == 0 || dy == 0) return null;
    return (num / math.sqrt(dx * dy)).clamp(-1.0, 1.0);
  }

  Widget _buildMiniBarSection({
    required IconData icon,
    required String label,
    required String stat,
    required Color statColor,
    required List<double> values,
    required Color color,
  }) {
    final nonZero = values.where((v) => v > 0);
    final dynamicMax = nonZero.isEmpty ? 1.0 : nonZero.reduce(math.max);
    final avg = nonZero.isEmpty ? 0.0 : nonZero.reduce((a, b) => a + b) / nonZero.length;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: statColor),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            Text(stat, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statColor)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final val = values[i];
              final isEmpty = val == 0;
              final heightFactor = isEmpty ? 0.0 : (val / dynamicMax).clamp(0.0, 1.0);
              final isHighlighted = !isEmpty && val >= avg;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: isEmpty ? 4 : math.max(4.0, 76 * heightFactor),
                      decoration: BoxDecoration(
                        color: isEmpty
                            ? color.withValues(alpha: 0.08)
                            : isHighlighted
                                ? color
                                : color.withValues(alpha: 0.25),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════ TOP EMOTIONS ══════════════════════════════

  Widget _buildTopEmotions(List<LogEntry> logs) {
    final counts = <String, int>{};
    int total = 0;
    for (final log in logs) {
      for (final emotion in log.emotions) {
        counts[emotion] = (counts[emotion] ?? 0) + 1;
        total++;
      }
    }

    if (counts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Emotions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderDefault),
            ),
            child: const Text('Log your emotions to see trends here.', style: TextStyle(color: AppTheme.outline)),
          ),
        ],
      );
    }

    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).toList();

    const configs = [
      (color: AppTheme.error, bg: Color(0xFFFFDAD6), icon: Icons.bolt),
      (color: AppTheme.tertiary, bg: AppTheme.tertiaryContainer, icon: Icons.psychology),
      (color: AppTheme.primary, bg: AppTheme.primaryFixed, icon: Icons.self_improvement),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Top Emotions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderDefault),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: top3.asMap().entries.map((entry) {
              final i = entry.key;
              final data = entry.value;
              final pct = data.value / total;
              final cfg = configs[i];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: cfg.bg, shape: BoxShape.circle),
                              child: Icon(cfg.icon, color: cfg.color, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data.key,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 120,
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    backgroundColor: AppTheme.surfaceContainer,
                                    color: cfg.color,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '${(pct * 100).toInt()}%',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cfg.color),
                        ),
                      ],
                    ),
                  ),
                  if (i < top3.length - 1)
                    const Divider(height: 1, color: AppTheme.borderDefault),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════ CUSTOM PAINTERS ══════════════════════════════

/// Overlays several 0..1 series as gap-aware polylines with dots. Points sit at
/// slot centres so they line up with the centred day labels beneath the chart.
class _TriLinePainter extends CustomPainter {
  final List<List<double?>> series;
  final List<Color> colors;

  _TriLinePainter({required this.series, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final n = series.isEmpty ? 0 : series.first.length;
    if (n == 0) return;
    final slot = size.width / n;
    double xFor(int i) => (i + 0.5) * slot;
    double yFor(double v) => size.height * (1 - v.clamp(0.0, 1.0));

    final grid = Paint()
      ..color = const Color(0x0F000000)
      ..strokeWidth = 1;
    for (int g = 0; g <= 4; g++) {
      final y = size.height * g / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (int s = 0; s < series.length; s++) {
      final vals = series[s];
      final line = Paint()
        ..color = colors[s]
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final dot = Paint()
        ..color = colors[s]
        ..style = PaintingStyle.fill;

      var run = <Offset>[];
      void flush() {
        if (run.length >= 2) {
          final p = Path()..moveTo(run.first.dx, run.first.dy);
          for (int k = 1; k < run.length; k++) {
            p.lineTo(run[k].dx, run[k].dy);
          }
          canvas.drawPath(p, line);
        }
        run = [];
      }

      for (int i = 0; i < n; i++) {
        final v = vals[i];
        if (v == null) {
          flush();
          continue;
        }
        final o = Offset(xFor(i), yFor(v));
        run.add(o);
        canvas.drawCircle(o, 3, dot);
      }
      flush();
    }
  }

  @override
  bool shouldRepaint(_TriLinePainter old) =>
      old.series != series || old.colors != colors;
}
