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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(title: 'Trends & Insights', user: appProvider.currentUser),
            const SizedBox(height: 24),
            _buildMoodFluctuations(context, logs),
            const SizedBox(height: 32),
            _buildCorrelations(context, logs),
            const SizedBox(height: 32),
            _buildTopSymptoms(context, logs),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodFluctuations(BuildContext context, List<LogEntry> logs) {
    // Sort logs by date ascending for the chart
    final sortedLogs = List<LogEntry>.from(logs)..sort((a, b) => a.date.compareTo(b.date));

    // Take the last 8 entries
    final recentLogs = sortedLogs.length > 8 ? sortedLogs.sublist(sortedLogs.length - 8) : sortedLogs;

    double maxMood = 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Mood Fluctuations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text('Recent', style: TextStyle(fontSize: 12, color: AppTheme.outline)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderDefault),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
            ],
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primary.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
          child: recentLogs.isEmpty
              ? const Center(child: Text("Not enough data to show trends.", style: TextStyle(color: AppTheme.outline)))
              : Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: recentLogs.map((log) {
                          double heightFactor = (log.moodScore / maxMood).clamp(0.1, 1.0);
                          bool isHighlight = log.moodScore >= 8.0;
                          return _buildChartBar(heightFactor, isHighlight, context);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (recentLogs.isNotEmpty)
                          Text(DateFormat('MMM dd').format(recentLogs.first.date), style: const TextStyle(fontSize: 12, color: AppTheme.outline)),
                        if (recentLogs.length > 2)
                          Text(DateFormat('MMM dd').format(recentLogs[recentLogs.length ~/ 2].date), style: const TextStyle(fontSize: 12, color: AppTheme.outline)),
                        if (recentLogs.length > 1)
                          Text(DateFormat('MMM dd').format(recentLogs.last.date), style: const TextStyle(fontSize: 12, color: AppTheme.outline)),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildChartBar(double heightFactor, bool isHighlight, BuildContext context) {
    return Container(
      width: 8,
      height: 140 * heightFactor,
      decoration: BoxDecoration(
        color: isHighlight ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildCorrelations(BuildContext context, List<LogEntry> logs) {
    if (logs.length < 2) {
       return const SizedBox(); // Need more data for correlations
    }

    // Correlation 1: Sleep vs Mood
    double moodWithGoodSleep = 0;
    int countGoodSleep = 0;
    double moodWithBadSleep = 0;
    int countBadSleep = 0;

    for (var log in logs) {
      if (log.sleepHours >= 7) {
        moodWithGoodSleep += log.moodScore;
        countGoodSleep++;
      } else {
        moodWithBadSleep += log.moodScore;
        countBadSleep++;
      }
    }

    double avgMoodGoodSleep = countGoodSleep > 0 ? moodWithGoodSleep / countGoodSleep : 0;
    double avgMoodBadSleep = countBadSleep > 0 ? moodWithBadSleep / countBadSleep : 0;

    String sleepImpactDesc = "More data needed.";
    String sleepImpactLabel = "Neutral";
    Color sleepColor = AppTheme.primary;

    if (countGoodSleep > 0 && countBadSleep > 0) {
       if (avgMoodGoodSleep > avgMoodBadSleep + 1) {
          sleepImpactDesc = "Getting 7+ hours of sleep correlates with a noticeably higher mood.";
          sleepImpactLabel = "Positive Shift";
          sleepColor = AppTheme.tertiary;
       } else if (avgMoodBadSleep > avgMoodGoodSleep + 1) {
          sleepImpactDesc = "Surprisingly, less sleep correlates with a higher mood for you.";
          sleepImpactLabel = "Unusual Trend";
          sleepColor = AppTheme.secondary;
       } else {
          sleepImpactDesc = "Sleep duration hasn't significantly impacted your mood recently.";
          sleepImpactLabel = "Low Impact";
          sleepColor = AppTheme.outline;
       }
    }

    // Correlation 2: Triggers
    Map<String, List<double>> triggerMoods = {};
    for (var log in logs) {
      if (log.trigger.isNotEmpty) {
        if (!triggerMoods.containsKey(log.trigger)) {
          triggerMoods[log.trigger] = [];
        }
        triggerMoods[log.trigger]!.add(log.moodScore);
      }
    }

    String topTrigger = "";
    double avgTriggerMood = 0;
    if (triggerMoods.isNotEmpty) {
       var mostFrequent = triggerMoods.entries.reduce((a, b) => a.value.length > b.value.length ? a : b);
       topTrigger = mostFrequent.key;
       avgTriggerMood = mostFrequent.value.reduce((a, b) => a + b) / mostFrequent.value.length;
    }

    String triggerDesc = "Not enough triggers logged to find a correlation.";
    String triggerLabel = "Influence";
    Color triggerColor = AppTheme.secondary;

    if (topTrigger.isNotEmpty) {
      if (avgTriggerMood < 5) {
         triggerDesc = "The trigger '$topTrigger' correlates with a lower mood score.";
         triggerLabel = "High Impact";
         triggerColor = AppTheme.secondary;
      } else {
         triggerDesc = "The trigger '$topTrigger' correlates with a positive mood.";
         triggerLabel = "Positive Shift";
         triggerColor = AppTheme.tertiary;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Correlations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (countGoodSleep > 0 && countBadSleep > 0)
                _buildCorrelationCard(
                  'Influence',
                  sleepImpactLabel,
                  Icons.bedtime,
                  sleepColor,
                  'Sleep vs Mood',
                  sleepImpactDesc,
                  Icons.bedtime,
                  Icons.sentiment_satisfied,
                  AppTheme.secondaryFixed,
                  AppTheme.primaryFixed,
                  const Color(0xFF85145A),
                  const Color(0xFF2F2EBE),
                ),
              if (countGoodSleep > 0 && countBadSleep > 0)
                const SizedBox(width: 16),
              if (topTrigger.isNotEmpty)
                _buildCorrelationCard(
                  'Influence',
                  triggerLabel,
                  Icons.warning_amber,
                  triggerColor,
                  'Trigger: $topTrigger',
                  triggerDesc,
                  Icons.bolt,
                  Icons.mood,
                  AppTheme.tertiaryFixed,
                  AppTheme.secondaryFixed,
                  const Color(0xFF703700),
                  const Color(0xFF85145A),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCorrelationCard(
    String label1,
    String label2,
    IconData topIcon,
    Color topIconColor,
    String title,
    String description,
    IconData icon1,
    IconData icon2,
    Color bg1,
    Color bg2,
    Color fg1,
    Color fg2,
  ) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDefault),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
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
                  Text(label1, style: const TextStyle(fontSize: 12, color: AppTheme.outline)),
                  Text(label2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: topIconColor)),
                ],
              ),
              Icon(topIcon, color: topIconColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: bg1, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: Icon(icon1, color: fg1, size: 16),
              ),
              Transform.translate(
                offset: const Offset(-8, 0),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: bg2, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  child: Icon(icon2, color: fg2, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopSymptoms(BuildContext context, List<LogEntry> logs) {
    // Calculate occurrences of emotions
    Map<String, int> emotionCounts = {};
    int totalEmotions = 0;

    for (var log in logs) {
      for (var emotion in log.emotions) {
        emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
        totalEmotions++;
      }
    }

    if (emotionCounts.isEmpty) {
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
              child: const Text('Not enough data to display top emotions.', style: TextStyle(color: AppTheme.outline)),
            ),
          ],
        );
    }

    var sortedEmotions = emotionCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    var top3 = sortedEmotions.take(3).toList();

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
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: top3.asMap().entries.map((entry) {
              int index = entry.key;
              var data = entry.value;
              double percent = data.value / totalEmotions;
              String label = '${(percent * 100).toInt()}%';

              Color color;
              Color bgColor;
              IconData icon;

              if (index == 0) {
                 color = AppTheme.error;
                 bgColor = const Color(0xFFFFDAD6);
                 icon = Icons.bolt;
              } else if (index == 1) {
                 color = AppTheme.tertiary;
                 bgColor = AppTheme.tertiaryContainer.withValues(alpha: 0.2);
                 icon = Icons.psychology;
              } else {
                 color = AppTheme.primary;
                 bgColor = AppTheme.primaryContainer.withValues(alpha: 0.2);
                 icon = Icons.heart_broken;
              }

              return Column(
                children: [
                  _buildSymptomRow(data.key, icon, percent, label, color, bgColor),
                  if (index < top3.length - 1)
                    const Divider(height: 1, color: AppTheme.borderDefault),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSymptomRow(String name, IconData icon, double value, String label, Color color, Color bgColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor: AppTheme.surfaceContainer,
                      color: color,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
