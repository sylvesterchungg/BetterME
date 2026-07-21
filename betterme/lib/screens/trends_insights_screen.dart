import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/ai_insight_service.dart';
import '../theme.dart';
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
            _buildWeeklyTrends(logs, productivityRecords),
            const SizedBox(height: 24),
            _buildProductivityTrend(logs, productivityRecords),
            const SizedBox(height: 24),
            _buildCorrelations(logs, productivityRecords),
            const SizedBox(height: 24),
            _buildDeepInsights(logs, productivityRecords),
            const SizedBox(height: 24),
            _buildTopEmotions(logs),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
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
          'Log $remaining more $dayWord of sleep and mood data to unlock your '
          '7-day correlation insight!',
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

    final sleepNonZero = sleepVals.where((v) => v > 0);
    final moodNonZero = moodVals.where((v) => v > 0);
    final prodNonZero = prodVals.where((v) => v > 0);

    final avgSleep = sleepNonZero.isEmpty ? 0.0 : sleepNonZero.reduce((a, b) => a + b) / sleepNonZero.length;
    final avgMood = moodNonZero.isEmpty ? 0.0 : moodNonZero.reduce((a, b) => a + b) / moodNonZero.length;
    final avgProd = prodNonZero.isEmpty ? 0.0 : prodNonZero.reduce((a, b) => a + b) / prodNonZero.length;

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

  /// A visible placeholder card used when a section has too little data yet,
  /// so features like FR_405 always appear on the page instead of silently
  /// collapsing to nothing.
  Widget _buildEmptyPlaceholder({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderDefault),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 34,
                  color: AppTheme.outlineVariant.withValues(alpha: 0.7)),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.onSurfaceVariant,
                    height: 1.4),
              ),
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
        'Log a few more days to unlock the mood → productivity correlation.',
        style: TextStyle(
            fontSize: 12,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.75),
            height: 1.4),
      );
    }

    final mag = c.abs();
    final direction = c >= 0 ? 'rises with' : 'drops with';
    final strength =
        mag >= 0.6 ? 'strongly' : (mag >= 0.3 ? 'moderately' : 'slightly');
    final icon = c >= 0 ? Icons.trending_up : Icons.trending_down;
    final color = c >= 0 ? AppTheme.tertiary : AppTheme.secondary;

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
              'Your productivity $strength $direction your mood  (r = ${_fmt(c)})',
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

  String _fmt(double c) => '${c >= 0 ? '+' : ''}${c.toStringAsFixed(2)}';

  String _strengthLabel(double c) {
    final mag = c.abs();
    final dir = c >= 0 ? 'positive' : 'negative';
    if (mag >= 0.6) return 'Strong $dir';
    if (mag >= 0.3) return 'Moderate $dir';
    if (mag >= 0.1) return 'Weak $dir';
    return 'No clear link';
  }

  Widget _buildCorrelations(
      List<LogEntry> logs, List<ProductivityRecord> productivityRecords) {
    final recordMap = {for (var r in productivityRecords) r.date: r};

    final sleepMoodX = <double>[], sleepMoodY = <double>[];
    final sleepProdX = <double>[], sleepProdY = <double>[];
    final moodProdX = <double>[], moodProdY = <double>[];

    for (final log in logs) {
      final hasSleep = log.sleepHours > 0;
      final hasMood = log.moodScore > 0;
      final rec = recordMap[_dayKey(log.date)];
      final hasProd = rec != null;

      if (hasSleep && hasMood) {
        sleepMoodX.add(log.sleepHours);
        sleepMoodY.add(log.moodScore);
      }
      if (hasSleep && hasProd) {
        sleepProdX.add(log.sleepHours);
        sleepProdY.add(rec.completionRate);
      }
      if (hasMood && hasProd) {
        moodProdX.add(log.moodScore);
        moodProdY.add(rec.completionRate);
      }
    }

    final pairs = <({String a, String b, double? c})>[
      (a: 'Sleep', b: 'Mood', c: _pearson(sleepMoodX, sleepMoodY)),
      (a: 'Sleep', b: 'Productivity', c: _pearson(sleepProdX, sleepProdY)),
      (a: 'Mood', b: 'Productivity', c: _pearson(moodProdX, moodProdY)),
    ];

    final hasAny = pairs.any((p) => p.c != null);
    final sampleDays = sleepMoodX.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How They Interact',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
          child: hasAny
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < pairs.length; i++) ...[
                      _buildCorrelationRow(pairs[i]),
                      if (i < pairs.length - 1) const SizedBox(height: 18),
                    ],
                    const SizedBox(height: 20),
                    Container(height: 1, color: AppTheme.borderDefault),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _correlationParagraph(pairs, sampleDays),
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.onSurfaceVariant,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : const Text(
                  'Keep logging sleep, mood, and completing tasks for a few days to reveal how they interact.',
                  style: TextStyle(color: AppTheme.outline),
                ),
        ),
      ],
    );
  }

  Widget _buildCorrelationRow(({String a, String b, double? c}) pair) {
    final c = pair.c;
    final label = c == null ? 'Not enough data' : _strengthLabel(c);
    final valueColor = c == null
        ? AppTheme.outline
        : (c >= 0 ? AppTheme.primary : AppTheme.error);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${pair.a} ↔ ${pair.b}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            Text(c == null ? '—' : _fmt(c),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: valueColor)),
          ],
        ),
        const SizedBox(height: 6),
        _buildDivergingBar(c),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.outline)),
      ],
    );
  }

  /// Center-anchored bar: negative fills left (red), positive fills right (primary).
  Widget _buildDivergingBar(double? c) {
    final v = (c ?? 0.0).clamp(-1.0, 1.0);
    return SizedBox(
      height: 10,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: v < 0 ? v.abs() : 0.0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.error,
                    borderRadius:
                        BorderRadius.horizontal(left: Radius.circular(5)),
                  ),
                ),
              ),
            ),
          ),
          Container(width: 2, color: AppTheme.borderDefault),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: v > 0 ? v : 0.0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius:
                        BorderRadius.horizontal(right: Radius.circular(5)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Deterministic, rule-based summary of the correlations — no AI model.
  String _correlationParagraph(
      List<({String a, String b, double? c})> pairs, int sampleDays) {
    final valid = pairs.where((p) => p.c != null).toList()
      ..sort((x, y) => y.c!.abs().compareTo(x.c!.abs()));

    if (valid.isEmpty) {
      return 'Keep logging to reveal how your sleep, mood, and productivity move together.';
    }

    String clause(({String a, String b, double? c}) p) {
      final c = p.c!;
      final mag = c.abs();
      final adverb =
          mag >= 0.6 ? 'strongly' : (mag >= 0.3 ? 'moderately' : 'only weakly');
      final a = p.a.toLowerCase();
      final b = p.b.toLowerCase();
      return c >= 0
          ? '$a and $b $adverb rise and fall together (${_fmt(c)})'
          : '$a and $b $adverb move in opposite directions (${_fmt(c)})';
    }

    final clauses = valid.map(clause).toList();
    final String body;
    if (clauses.length == 1) {
      body = clauses[0];
    } else {
      body =
          '${clauses.sublist(0, clauses.length - 1).join('; ')}; and ${clauses.last}';
    }

    // Actionable tip from the strongest relationship.
    final top = valid.first;
    final tc = top.c!;
    String tip;
    if (tc.abs() < 0.3) {
      tip =
          'None of these links are strong yet — a few more days of logging will sharpen the picture.';
    } else if (top.a == 'Sleep' && top.b == 'Mood') {
      tip = tc >= 0
          ? 'Protecting your sleep looks like your clearest lever for a better mood.'
          : 'Longer nights are lining up with lower moods — worth watching for oversleeping on rough days.';
    } else if (top.b == 'Productivity') {
      tip = tc >= 0
          ? 'On days your ${top.a.toLowerCase()} is higher, you tend to finish more of your tasks.'
          : 'Higher ${top.a.toLowerCase()} is coinciding with fewer tasks done — an interesting pattern to reflect on.';
    } else {
      tip = 'This is the pattern worth paying the most attention to.';
    }

    final dayWord = sampleDays == 1 ? 'day' : 'days';
    final lead = sampleDays >= 3
        ? 'Across your $sampleDays logged $dayWord, '
        : 'From your recent logs, ';
    return '$lead$body. $tip';
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

  // ══════════════════════════════ DEEP INSIGHTS ══════════════════════════════

  Widget _buildDeepInsights(List<LogEntry> logs, List<ProductivityRecord> productivityRecords) {
    final validLogs = logs.where((l) => l.sleepHours > 0 && l.moodScore > 0).toList();
    if (validLogs.length < 3) {
      return _buildEmptyPlaceholder(
        icon: Icons.insights_outlined,
        title: 'Deep Insights',
        message: 'Log sleep and mood for 3+ days to unlock deep insights.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Deep Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        _buildSleepMoodCard(validLogs),
        const SizedBox(height: 16),
        _buildMoodProductivityCard(logs, productivityRecords),
      ],
    );
  }

  Widget _buildSleepMoodCard(List<LogEntry> logs) {
    final n = logs.length.toDouble();
    final avgSleep = logs.map((l) => l.sleepHours).reduce((a, b) => a + b) / n;
    final avgMood = logs.map((l) => l.moodScore).reduce((a, b) => a + b) / n;

    // Pearson correlation
    double num = 0, denX = 0, denY = 0;
    for (final l in logs) {
      num += (l.sleepHours - avgSleep) * (l.moodScore - avgMood);
      denX += (l.sleepHours - avgSleep) * (l.sleepHours - avgSleep);
      denY += (l.moodScore - avgMood) * (l.moodScore - avgMood);
    }
    final corr = (denX > 0 && denY > 0)
        ? (num / math.sqrt(denX * denY)).clamp(-1.0, 1.0)
        : 0.0;

    final goodSleepLogs = logs.where((l) => l.sleepHours >= 7).toList();
    final moodLiftPct = goodSleepLogs.isNotEmpty
        ? ((goodSleepLogs.map((l) => l.moodScore).reduce((a, b) => a + b) / goodSleepLogs.length - avgMood) / avgMood * 100).abs()
        : 0.0;

    final corrLabel = corr >= 0.5
        ? 'Positive Correlation (${corr.toStringAsFixed(2)})'
        : corr <= -0.5
            ? 'Negative Correlation (${corr.toStringAsFixed(2)})'
            : 'Weak Correlation (${corr.toStringAsFixed(2)})';

    final insightText = goodSleepLogs.isNotEmpty && moodLiftPct > 5
        ? 'On days following 7+ hours of quality sleep, your self-reported mood improves by an average of ${moodLiftPct.toInt()}%.'
        : 'Keep logging daily to uncover how your sleep affects your mood.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDefault),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sleep Quality vs. Mood',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  const SizedBox(height: 2),
                  Text(corrLabel, style: const TextStyle(fontSize: 12, color: AppTheme.outline)),
                ],
              ),
              const Icon(Icons.insights, color: AppTheme.primary),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: _ScatterPlotPainter(logs: logs, color: AppTheme.primary),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Poor Sleep', style: TextStyle(fontSize: 10, color: AppTheme.outline)),
              Text('Great Sleep', style: TextStyle(fontSize: 10, color: AppTheme.outline)),
            ],
          ),
          const SizedBox(height: 12),
          Text(insightText,
              style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildMoodProductivityCard(List<LogEntry> logs, List<ProductivityRecord> productivityRecords) {
    if (productivityRecords.isEmpty) {
      return _buildEmptyPlaceholder(
        icon: Icons.link_outlined,
        title: 'Mood ↔ Productivity',
        message:
            'Complete some tasks across a few days to see how your mood relates to what you get done.',
      );
    }

    final recordMap = {for (var r in productivityRecords) r.date: r};
    final lowRates = <double>[], stableRates = <double>[], highRates = <double>[];

    for (final log in logs) {
      if (log.moodScore == 0) continue;
      final key = '${log.date.year}-${log.date.month.toString().padLeft(2, '0')}-${log.date.day.toString().padLeft(2, '0')}';
      final rec = recordMap[key];
      if (rec == null) continue;
      if (log.moodScore < 5) {
        lowRates.add(rec.completionRate);
      } else if (log.moodScore <= 7) {
        stableRates.add(rec.completionRate);
      } else {
        highRates.add(rec.completionRate);
      }
    }

    final lowAvg = lowRates.isEmpty ? 0.0 : lowRates.reduce((a, b) => a + b) / lowRates.length;
    final stableAvg = stableRates.isEmpty ? 0.0 : stableRates.reduce((a, b) => a + b) / stableRates.length;
    final highAvg = highRates.isEmpty ? 0.0 : highRates.reduce((a, b) => a + b) / highRates.length;

    final lowPct = (lowAvg * 100).toInt();
    final stablePct = (stableAvg * 100).toInt();
    final highPct = (highAvg * 100).toInt();

    final basePct = lowPct > 0 ? lowPct : stablePct;
    final insightText = highPct > 0 && basePct >= 0
        ? 'A "Positive" mood state is the strongest predictor for completing your daily goals. Task completion jumps from $basePct% to $highPct% when mood is elevated.'
        : 'Keep logging mood and completing tasks to uncover this pattern.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDefault),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mood vs. Productivity',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.tertiary)),
                  const SizedBox(height: 2),
                  const Text('High Impact Coupling', style: TextStyle(fontSize: 12, color: AppTheme.outline)),
                ],
              ),
              const Icon(Icons.trending_up, color: AppTheme.tertiary),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMoodProdBar('Low Mood', lowAvg, AppTheme.secondary.withValues(alpha: 0.3)),
              const SizedBox(width: 8),
              _buildMoodProdBar('Stable', stableAvg, AppTheme.secondary.withValues(alpha: 0.55)),
              const SizedBox(width: 8),
              _buildMoodProdBar('High Mood', highAvg, AppTheme.tertiaryContainer),
            ],
          ),
          const SizedBox(height: 12),
          Text(insightText,
              style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildMoodProdBar(String label, double completionRate, Color color) {
    const maxBarHeight = 80.0;
    final barHeight = math.max(4.0, maxBarHeight * completionRate.clamp(0.0, 1.0));
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            height: maxBarHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppTheme.outline)),
        ],
      ),
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

class _ScatterPlotPainter extends CustomPainter {
  final List<LogEntry> logs;
  final Color color;

  const _ScatterPlotPainter({required this.logs, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (logs.isEmpty) return;

    const pad = 14.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    final minSleep = logs.map((l) => l.sleepHours).reduce(math.min);
    final maxSleep = logs.map((l) => l.sleepHours).reduce(math.max);
    final sleepRange = (maxSleep - minSleep).clamp(1.0, double.infinity);

    // Regression line
    final n = logs.length.toDouble();
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (final l in logs) {
      final x = (l.sleepHours - minSleep) / sleepRange;
      final y = 1.0 - (l.moodScore / 10.0);
      sumX += x; sumY += y; sumXY += x * y; sumX2 += x * x;
    }
    final denom = (n * sumX2 - sumX * sumX);
    if (denom.abs() > 0.0001) {
      final slope = (n * sumXY - sumX * sumY) / denom;
      final intercept = (sumY - slope * sumX) / n;

      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      final x0 = pad;
      final y0 = (pad + intercept * h).clamp(pad, pad + h);
      final x1 = pad + w;
      final y1 = (pad + (slope + intercept) * h).clamp(pad, pad + h);

      _drawDashedLine(canvas, Offset(x0, y0), Offset(x1, y1), linePaint);
    }

    // Dots — sort by date so recent logs are drawn on top
    final sorted = List<LogEntry>.from(logs)..sort((a, b) => a.date.compareTo(b.date));
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < sorted.length; i++) {
      final l = sorted[i];
      final x = pad + ((l.sleepHours - minSleep) / sleepRange) * w;
      final y = pad + (1.0 - l.moodScore / 10.0) * h;
      final opacity = 0.3 + (i / sorted.length) * 0.7;
      canvas.drawCircle(Offset(x, y), 4, dotPaint..color = color.withValues(alpha: opacity));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 6.0, gapLen = 4.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final ux = dx / len, uy = dy / len;
    double dist = 0;
    bool drawing = true;
    while (dist < len) {
      final seg = math.min(drawing ? dashLen : gapLen, len - dist);
      final end = dist + seg;
      if (drawing) {
        canvas.drawLine(
          Offset(p1.dx + ux * dist, p1.dy + uy * dist),
          Offset(p1.dx + ux * end, p1.dy + uy * end),
          paint,
        );
      }
      dist += seg;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(_ScatterPlotPainter old) => old.logs != logs || old.color != color;
}
