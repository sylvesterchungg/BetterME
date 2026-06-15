import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'notifications_screen.dart';

class PersonalDiaryScreen extends StatelessWidget {
  const PersonalDiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final logs = List<LogEntry>.from(appProvider.logs)
      ..sort((a, b) => b.date.compareTo(a.date)); // descending
    final user = appProvider.currentUser;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, appProvider),
              const SizedBox(height: 16),
              const Text('Review your journey and celebrate your progress.', style: TextStyle(fontSize: 14, color: AppTheme.outline)),
              const SizedBox(height: 24),
              _buildStatsOverview(context, user?.streak ?? 0, logs.length),
              const SizedBox(height: 24),
              _buildSearchAndFilter(context),
              const SizedBox(height: 24),
              _buildEntriesList(context, logs),
              const SizedBox(height: 80),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppProvider provider) {
    final user = provider.currentUser;
    final now = DateTime.now();
    final dateStr = DateFormat('MMMM d, yyyy').format(now);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.outlineVariant, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: user?.avatarUrl != null && user!.avatarUrl.isNotEmpty
                    ? Image.network(user.avatarUrl, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.person, color: AppTheme.outline))
                    : const Icon(Icons.person, color: AppTheme.outline),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Journal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text(dateStr, style: const TextStyle(fontSize: 12, color: AppTheme.outline)),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.notifications_outlined, color: AppTheme.onSurfaceVariant, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsOverview(BuildContext context, int streak, int totalEntries) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryFixed.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Weekly Streak', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                    const SizedBox(height: 4),
                    Text('$streak Days of Reflection', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2F2EBE))),
                  ],
                ),
                const Icon(Icons.local_fire_department, color: AppTheme.primary, size: 36),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Text('Total Entries', style: TextStyle(fontSize: 12, color: AppTheme.outline)),
                const SizedBox(height: 4),
                Text('$totalEntries', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: AppTheme.outline),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search reflections...',
                      hintStyle: TextStyle(color: AppTheme.outline, fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.filter_list, color: AppTheme.primary),
        ),
      ],
    );
  }

  Widget _buildEntriesList(BuildContext context, List<LogEntry> logs) {
    if (logs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No journal entries yet. Tap + to add one!', style: TextStyle(color: AppTheme.outline)),
        ),
      );
    }

    return Column(
      children: logs.map((log) {
        // Map mood score to icon and colors
        IconData icon = Icons.sentiment_neutral;
        Color bgIconColor = AppTheme.surfaceContainerHighest;
        Color fgIconColor = AppTheme.onSurfaceVariant;

        if (log.moodScore >= 8) {
          icon = Icons.sentiment_very_satisfied;
          bgIconColor = AppTheme.primaryFixed;
          fgIconColor = AppTheme.primaryContainer;
        } else if (log.moodScore >= 6) {
          icon = Icons.sentiment_satisfied;
          bgIconColor = AppTheme.secondaryFixed;
          fgIconColor = AppTheme.secondary;
        } else if (log.moodScore <= 3) {
          icon = Icons.sentiment_very_dissatisfied;
          bgIconColor = const Color(0xFFFFDAD6);
          fgIconColor = AppTheme.error;
        }

        // Format Date and Time
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final logDay = DateTime(log.date.year, log.date.month, log.date.day);

        String dateStr;
        if (logDay == today) {
          dateStr = 'Today, ${DateFormat('MMM dd').format(log.date)}';
        } else if (logDay == today.subtract(const Duration(days: 1))) {
          dateStr = 'Yesterday, ${DateFormat('MMM dd').format(log.date)}';
        } else {
          dateStr = DateFormat('MMM dd, yyyy').format(log.date);
        }

        String timeStr = DateFormat('hh:mm a').format(log.date);

        // Generate title from notes if available, otherwise just say Log Entry
        String title = log.notes.isNotEmpty ? log.notes.split('\n').first : 'Log Entry for ${DateFormat('MMM dd').format(log.date)}';
        if (title.length > 30) {
            title = '${title.substring(0, 30)}...';
        }
        String desc = log.notes.isNotEmpty ? log.notes : 'No additional notes provided for this reflection.';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildEntryCard(
            context,
            log,
            dateStr,
            timeStr,
            icon,
            bgIconColor,
            fgIconColor,
            title,
            desc,
            hasImage: false,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    LogEntry log,
    String date,
    String time,
    IconData icon,
    Color bgIconColor,
    Color fgIconColor,
    String title,
    String description, {
    bool hasImage = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: bgIconColor, shape: BoxShape.circle),
                    child: Icon(icon, color: fgIconColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(time, style: const TextStyle(fontSize: 12, color: AppTheme.outline)),
                    ],
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.outlineVariant),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditMoodDialog(context, log);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Edit Mood'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasImage) ...[
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.landscape, size: 48, color: AppTheme.outlineVariant),
            ),
            const SizedBox(height: 12),
          ],
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showEditMoodDialog(BuildContext context, LogEntry log) {
    double currentScore = log.moodScore;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Mood'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Mood Score: ${currentScore.toStringAsFixed(1)}'),
                  Slider(
                    value: currentScore,
                    min: 1.0,
                    max: 10.0,
                    divisions: 9,
                    onChanged: (value) {
                      setState(() {
                        currentScore = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    log.moodScore = currentScore;
                    context.read<AppProvider>().updateLog(log);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
