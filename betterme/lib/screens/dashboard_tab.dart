import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'notifications_screen.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, provider),
                const SizedBox(height: 24),
                _buildWeeklyStreak(context, provider),
                const SizedBox(height: 24),
                _buildTodaysSummary(context, provider),
                const SizedBox(height: 24),
                _buildQuickAdd(context, provider),
                const SizedBox(height: 24),
                _buildUpcomingReminder(context, provider),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
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
            // Avatar
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
                Text(
                  'Hello, ${user?.username ?? ''}',
                  style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primary),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderDefault),
            ),
            child: const Icon(Icons.notifications_outlined, color: AppTheme.onSurfaceVariant, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyStreak(BuildContext context, AppProvider provider) {
    // Calculate current week
    final today = DateTime.now();
    final int daysSinceMonday = today.weekday - 1;
    final monday = today.subtract(Duration(days: daysSinceMonday));

    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    // Extract logs for this week
    final logsThisWeek = provider.logs.where((l) =>
      l.date.isAfter(monday.subtract(const Duration(days: 1))) &&
      l.date.isBefore(monday.add(const Duration(days: 7)))
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weekly Streak',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderDefault),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final date = monday.add(Duration(days: index));
              final dayName = weekDays[index];
              final isToday = date.day == today.day && date.month == today.month && date.year == today.year;
              final isFuture = date.isAfter(today) && !isToday;

              // Check if there is a log on this date
              final hasLog = logsThisWeek.any((l) => l.date.day == date.day && l.date.month == date.month && l.date.year == date.year);

              if (isFuture) {
                return _buildStreakDayFuture(dayName);
              } else if (isToday) {
                return hasLog
                    ? _buildStreakDay(dayName, Icons.sentiment_very_satisfied, AppTheme.secondaryFixed, AppTheme.secondary)
                    : _buildStreakDayCurrent(dayName);
              } else {
                return hasLog
                    ? _buildStreakDay(dayName, Icons.sentiment_satisfied, AppTheme.primaryFixed, const Color(0xFF2F2EBE))
                    : _buildStreakDayFuture(dayName);
              }
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakDay(String day, IconData icon, Color bgColor, Color iconColor) {
    return Column(
      children: [
        Text(day, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ],
    );
  }

  Widget _buildStreakDayCurrent(String day) {
    return Column(
      children: [
        Text(day, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.outlineVariant, width: 2),
          ),
          child: const Icon(Icons.add, color: AppTheme.outline, size: 20),
        ),
      ],
    );
  }

  Widget _buildStreakDayFuture(String day) {
    return Column(
      children: [
        Text(day, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppTheme.surfaceContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.circle, color: AppTheme.outline, size: 10),
        ),
      ],
    );
  }

  Widget _buildTodaysSummary(BuildContext context, AppProvider provider) {
    final water = provider.currentUser?.waterIntake ?? 0;
    final waterGoal = provider.currentUser?.waterGoal ?? 2500;
    final waterProgress = (water / waterGoal).clamp(0.0, 1.0);

    // Calculate today's sleep if available
    final today = DateTime.now();
    final todayLogs = provider.logs.where((l) => l.date.day == today.day && l.date.month == today.month && l.date.year == today.year).toList();
    double todaySleep = 0.0;
    if (todayLogs.isNotEmpty) {
      todaySleep = todayLogs.first.sleepHours;
    }

    final todayMood = todayLogs.isNotEmpty ? todayLogs.first.moodScore : null;

    final steps = provider.currentSteps;
    final sleepHours = todaySleep.floor();
    final sleepMins = ((todaySleep - sleepHours) * 60).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Summary",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderDefault),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Water Intake', style: TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('$water', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                            Text(' / $waterGoal ml', style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            value: waterProgress,
                            strokeWidth: 6,
                            backgroundColor: AppTheme.surfaceContainer,
                            color: AppTheme.primary,
                          ),
                        ),
                        const Icon(Icons.water_drop, color: AppTheme.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildSummaryCard(Icons.directions_walk, AppTheme.secondary, 'Steps', '$steps')),
            const SizedBox(width: 16),
            Expanded(child: _buildSummaryCard(Icons.bedtime, AppTheme.tertiary, 'Sleep', '${sleepHours}h ${sleepMins}m')),
            const SizedBox(width: 16),
            Expanded(child: _buildSummaryCard(
              Icons.mood,
              AppTheme.primary,
              'Mood',
              todayMood != null ? todayMood.toStringAsFixed(1) : '—',
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(IconData icon, Color iconColor, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildQuickAdd(BuildContext context, AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Add',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildQuickAddButton(context, provider, 'Meds', Icons.medication, AppTheme.primaryFixed, AppTheme.primary,
                category: 'Medicines', categoryIconKey: 'medication', example: 'take vitamin')),
            const SizedBox(width: 16),
            Expanded(child: _buildQuickAddButton(context, provider, 'Caffeine', Icons.coffee, AppTheme.tertiaryFixed, AppTheme.tertiary,
                category: 'Nutrition', categoryIconKey: 'restaurant', example: 'morning coffee')),
            const SizedBox(width: 16),
            Expanded(child: _buildQuickAddButton(context, provider, 'Exercise', Icons.fitness_center, AppTheme.secondaryFixed, AppTheme.secondary,
                category: 'Exercise', categoryIconKey: 'fitness_center', example: '30 min run')),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAddButton(BuildContext context, AppProvider provider, String label, IconData icon, Color bgColor, Color iconColor,
      {required String category, required String categoryIconKey, required String example}) {
    return GestureDetector(
      onTap: () {
        final controller = TextEditingController();
        DateTime selectedDate = DateTime.now();
        bool reminderEnabled = false;
        TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0);

        showDialog(
          context: context,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setState) {
                return AlertDialog(
                  title: Text('Quick Add Task: $label'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Task title',
                          hintText: 'e.g. $example',
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 16),
                      // Due date
                      InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(now.year, now.month, now.day),
                            lastDate: now.add(const Duration(days: 365)),
                          );
                          if (date != null) setState(() => selectedDate = date);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 20, color: AppTheme.onSurfaceVariant),
                              const SizedBox(width: 12),
                              const Text('Due date', style: TextStyle(fontSize: 14)),
                              const Spacer(),
                              Text(
                                DateFormat('MMM d, yyyy').format(selectedDate),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      // Reminder toggle
                      Row(
                        children: [
                          const Icon(Icons.notifications_outlined, size: 20, color: AppTheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          const Text('Reminder', style: TextStyle(fontSize: 14)),
                          const Spacer(),
                          Switch(
                            value: reminderEnabled,
                            onChanged: (val) => setState(() => reminderEnabled = val),
                          ),
                        ],
                      ),
                      if (reminderEnabled)
                        InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: ctx,
                              initialTime: reminderTime,
                            );
                            if (time != null) setState(() => reminderTime = time);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const SizedBox(width: 32),
                                const Text('Time', style: TextStyle(fontSize: 14)),
                                const Spacer(),
                                Text(
                                  reminderTime.format(ctx),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final title = controller.text.trim();
                        if (title.isEmpty) return;
                        final reminderStr = reminderEnabled
                            ? '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}'
                            : null;
                        provider.addTask(
                          title,
                          category: category,
                          categoryIconKey: categoryIconKey,
                          dueDate: selectedDate,
                          reminderTime: reminderStr,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added task: $title')),
                        );
                      },
                      child: const Text('Add Task'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderDefault),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingReminder(BuildContext context, AppProvider provider) {
    final reminder = _nextUpcomingTask(provider.tasks);

    if (reminder == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderDefault),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications_off_outlined, color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No upcoming reminders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('You\'re all caught up', style: TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final task = reminder.task;
    final when = reminder.when;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.notifications_active, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upcoming: ${task.title}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 4),
                Text(_formatReminderTime(when),
                    style: const TextStyle(fontSize: 14, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Finds the not-yet-completed task with the soonest reminder/due time that
  /// is still in the future. Returns null if there are no upcoming reminders.
  _UpcomingReminder? _nextUpcomingTask(List<Task> tasks) {
    final now = DateTime.now();
    _UpcomingReminder? next;

    for (final task in tasks) {
      if (task.isCompleted) continue;

      final when = _reminderDateTime(task, now);
      if (when == null || when.isBefore(now)) continue;

      if (next == null || when.isBefore(next.when)) {
        next = _UpcomingReminder(task, when);
      }
    }

    return next;
  }

  /// Combines a task's due date and reminder time ("HH:mm") into a single
  /// DateTime. Falls back to today when only a reminder time is set.
  DateTime? _reminderDateTime(Task task, DateTime now) {
    final date = task.dueDate;
    final reminder = task.reminderTime;

    if (date == null && reminder == null) return null;

    final baseDate = date ?? now;
    if (reminder != null) {
      final parts = reminder.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
        }
      }
    }

    // No (valid) reminder time: due at end of the due date.
    return DateTime(baseDate.year, baseDate.month, baseDate.day, 23, 59);
  }

  String _formatReminderTime(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(when.year, when.month, when.day);
    final dayDiff = target.difference(today).inDays;

    final timeStr = DateFormat('h:mm a').format(when);
    if (dayDiff == 0) return 'Today at $timeStr';
    if (dayDiff == 1) return 'Tomorrow at $timeStr';
    return '${DateFormat('MMM d').format(when)} at $timeStr';
  }
}

class _UpcomingReminder {
  final Task task;
  final DateTime when;

  _UpcomingReminder(this.task, this.when);
}
