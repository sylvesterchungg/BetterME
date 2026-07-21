import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/app_page_header.dart';

class TrendsInsightsScreen extends StatelessWidget {
  const TrendsInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final logs = appProvider.logs;
    final productivityRecords = appProvider.productivityRecords;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(title: 'Trends & Insights', user: appProvider.currentUser),
            const SizedBox(height: 24),
            _buildWeeklyTrends(logs, productivityRecords),
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
    if (validLogs.length < 3) return const SizedBox();

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
    if (productivityRecords.isEmpty) return const SizedBox();

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
