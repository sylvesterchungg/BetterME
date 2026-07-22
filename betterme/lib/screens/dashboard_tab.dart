import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'notifications_screen.dart';
import 'profile_tab.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, provider),
                const _MorningNudgeCard(),
                const SizedBox(height: 24),
                _buildSummaryGrid(context, provider),
                const SizedBox(height: 20),
                _buildWeekStrip(provider),
                const SizedBox(height: 20),
                _buildQuickAdd(context, provider),
                const SizedBox(height: 20),
                _buildUpcomingReminder(context, provider),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, AppProvider provider) {
    final user = provider.currentUser;
    final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => ProfileScreen.open(context),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.outlineVariant, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: user?.avatarUrl != null && user!.avatarUrl.isNotEmpty
                      ? Image.network(user.avatarUrl, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.person, color: AppTheme.outline, size: 28))
                      : const Icon(Icons.person, color: AppTheme.outline, size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, ${user?.username ?? ''}',
                      style: const TextStyle(
                          fontSize: 16, color: AppTheme.onSurfaceVariant)),
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary)),
                ],
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          child: Stack(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderDefault),
                ),
                child: const Icon(Icons.notifications_outlined,
                    color: AppTheme.onSurfaceVariant, size: 24),
              ),
              if (provider.unreadNotificationCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                        color: AppTheme.error, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      provider.unreadNotificationCount > 9
                          ? '9+'
                          : '${provider.unreadNotificationCount}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 2×2 Summary Grid ─────────────────────────────────────────────────────

  Widget _buildSummaryGrid(BuildContext context, AppProvider provider) {
    final today = DateTime.now();
    final todayLogs = provider.logs
        .where((l) =>
            l.date.day == today.day &&
            l.date.month == today.month &&
            l.date.year == today.year)
        .toList();

    final todayMood =
        todayLogs.isNotEmpty && todayLogs.first.moodScore > 0
            ? todayLogs.first.moodScore
            : null;
    final todaySleep =
        todayLogs.isNotEmpty && todayLogs.first.sleepHours > 0
            ? todayLogs.first.sleepHours
            : null;

    final water = provider.currentUser?.waterIntake ?? 0;
    final waterGoal = provider.currentUser?.waterGoal ?? 2500;
    final streak = provider.currentUser?.streak ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Today's Overview",
            style:
                TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _statTile(
                icon: Icons.mood,
                color: AppTheme.primary,
                label: 'Mood',
                value: todayMood != null
                    ? todayMood.toStringAsFixed(1)
                    : '—',
                sub: todayMood != null ? '/ 10' : 'not logged',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statTile(
                icon: Icons.bedtime,
                color: AppTheme.tertiary,
                label: 'Sleep',
                value: todaySleep != null
                    ? '${todaySleep.toStringAsFixed(1)}h'
                    : '—',
                sub: todaySleep != null ? 'last night' : 'not logged',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statTile(
                icon: Icons.water_drop,
                color: const Color(0xFF0288D1),
                label: 'Water',
                value: '$water',
                sub: '/ $waterGoal ml',
                progress: (water / waterGoal).clamp(0.0, 1.0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statTile(
                icon: Icons.local_fire_department,
                color: const Color(0xFFE65100),
                label: 'Streak',
                value: '$streak',
                sub: streak == 1 ? 'day' : 'days',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String sub,
    double? progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700)),
          Text(sub,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.onSurfaceVariant)),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppTheme.surfaceContainer,
                color: const Color(0xFF0288D1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Week Strip ────────────────────────────────────────────────────────────

  Widget _buildWeekStrip(AppProvider provider) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Monday of the current week (weekday: Mon=1 … Sun=7).
    final monday = today.subtract(Duration(days: today.weekday - 1));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('This Week',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderDefault),
          ),
          child: Row(
            children: List.generate(7, (i) {
              final date = monday.add(Duration(days: i));
              final isToday = sameDay(date, today);
              final isFuture = date.isAfter(today);

              // The day's log, preferring one that actually carries a mood.
              // (Compare by calendar day so time-of-day never hides a log.)
              LogEntry? dayLog;
              for (final l in provider.logs) {
                if (!sameDay(l.date, date)) continue;
                dayLog = l;
                if (l.moodScore > 0) break;
              }
              final hasLog = dayLog != null;
              final mood = (dayLog != null && dayLog.moodScore > 0)
                  ? dayLog.moodScore
                  : null;

              // Circle fill + inner icon: the mood face when a mood was logged,
              // a check for a mood-less log, an add prompt on today, else empty.
              final Color circleColor;
              final Widget? inner;
              if (mood != null) {
                final c = _moodColor(mood);
                circleColor = c.withValues(alpha: 0.18);
                inner = Icon(_moodIcon(mood), size: 20, color: c);
              } else if (hasLog) {
                circleColor = AppTheme.primaryFixed;
                inner = Icon(Icons.check, size: 18, color: AppTheme.primary);
              } else if (isToday) {
                circleColor = AppTheme.outlineVariant.withValues(alpha: 0.15);
                inner =
                    const Icon(Icons.add, size: 18, color: AppTheme.outline);
              } else {
                circleColor = (isFuture
                        ? AppTheme.surfaceContainer
                        : AppTheme.surfaceContainerHigh)
                    .withValues(alpha: 0.15);
                inner = null;
              }

              return Expanded(
                child: Column(
                  children: [
                    Text(labels[i],
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isToday
                                ? AppTheme.onSurface
                                : AppTheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: circleColor,
                        shape: BoxShape.circle,
                        border: isToday && !hasLog
                            ? Border.all(
                                color: AppTheme.outlineVariant, width: 1.5)
                            : null,
                      ),
                      child: inner,
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // Maps a 1–10 mood score to the same five faces used in the daily-log tab.
  IconData _moodIcon(double score) {
    if (score <= 2.0) return Icons.sentiment_very_dissatisfied;
    if (score <= 4.0) return Icons.sentiment_dissatisfied;
    if (score <= 6.0) return Icons.sentiment_neutral;
    if (score <= 8.5) return Icons.sentiment_satisfied;
    return Icons.sentiment_very_satisfied;
  }

  // Colour scale for those faces: red → green, with the neutral tone matching
  // the amber used for mood elsewhere (trends chart).
  Color _moodColor(double score) {
    if (score <= 2.0) return const Color(0xFFE53935); // awful — red
    if (score <= 4.0) return const Color(0xFFFB8C00); // bad — orange
    if (score <= 6.0) return const Color(0xFFF59E0B); // meh — amber
    if (score <= 8.5) return const Color(0xFF7CB342); // good — light green
    return const Color(0xFF43A047); // great — green
  }

  // ── Quick Add ─────────────────────────────────────────────────────────────

  Widget _buildQuickAdd(BuildContext context, AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Add',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _quickChip(context, provider, 'Meds',
                  Icons.medication, AppTheme.primaryFixed, AppTheme.primary,
                  category: 'Medicines',
                  categoryIconKey: 'medication',
                  example: 'take vitamin'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _quickChip(context, provider, 'Caffeine',
                  Icons.coffee, AppTheme.tertiaryFixed, AppTheme.tertiary,
                  category: 'Nutrition',
                  categoryIconKey: 'restaurant',
                  example: 'morning coffee'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _quickChip(context, provider, 'Exercise',
                  Icons.fitness_center, AppTheme.secondaryFixed,
                  AppTheme.secondary,
                  category: 'Exercise',
                  categoryIconKey: 'fitness_center',
                  example: '30 min run'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickChip(
    BuildContext context,
    AppProvider provider,
    String label,
    IconData icon,
    Color bg,
    Color fg, {
    required String category,
    required String categoryIconKey,
    required String example,
  }) {
    return GestureDetector(
      onTap: () => _showAddTaskDialog(
          context, provider, label, example, category, categoryIconKey),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderDefault),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: fg, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, AppProvider provider,
      String label, String example, String category, String categoryIconKey) {
    final controller = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool reminderEnabled = false;
    TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Add $label Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                    labelText: 'Task title', hintText: 'e.g. $example'),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => selectedDate = d);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 18, color: AppTheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      const Text('Due date',
                          style: TextStyle(fontSize: 14)),
                      const Spacer(),
                      Text(DateFormat('MMM d, yyyy').format(selectedDate),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.notifications_outlined,
                      size: 18, color: AppTheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  const Text('Reminder', style: TextStyle(fontSize: 14)),
                  const Spacer(),
                  Switch(
                    value: reminderEnabled,
                    onChanged: (v) => setState(() => reminderEnabled = v),
                    activeThumbColor: AppTheme.primary,
                  ),
                ],
              ),
              if (reminderEnabled)
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(
                        context: ctx, initialTime: reminderTime);
                    if (t != null) setState(() => reminderTime = t);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const SizedBox(width: 28),
                        const Text('Time', style: TextStyle(fontSize: 14)),
                        const Spacer(),
                        Text(reminderTime.format(ctx),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final title = controller.text.trim();
                if (title.isEmpty) return;
                final rStr = reminderEnabled
                    ? '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}'
                    : null;
                provider.addTask(title,
                    category: category,
                    categoryIconKey: categoryIconKey,
                    dueDate: selectedDate,
                    reminderTime: rStr);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added: $title')));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Upcoming Reminder ─────────────────────────────────────────────────────

  Widget _buildUpcomingReminder(BuildContext context, AppProvider provider) {
    final reminder = _nextUpcomingTask(provider.tasks);
    if (reminder == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: Colors.white, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Up next: ${reminder.task.title}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(_formatReminderTime(reminder.when),
                    style: const TextStyle(
                        fontSize: 14, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  DateTime? _reminderDateTime(Task task, DateTime now) {
    final date = task.dueDate;
    final reminder = task.reminderTime;
    if (date == null && reminder == null) return null;
    final base = date ?? now;
    if (reminder != null) {
      final parts = reminder.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          return DateTime(base.year, base.month, base.day, h, m);
        }
      }
    }
    return DateTime(base.year, base.month, base.day, 23, 59);
  }

  String _formatReminderTime(DateTime when) {
    final now = DateTime.now();
    final diff =
        DateTime(when.year, when.month, when.day)
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;
    final t = DateFormat('h:mm a').format(when);
    if (diff == 0) return 'Today at $t';
    if (diff == 1) return 'Tomorrow at $t';
    return '${DateFormat('MMM d').format(when)} at $t';
  }
}

class _UpcomingReminder {
  final Task task;
  final DateTime when;
  _UpcomingReminder(this.task, this.when);
}

/// A warm, one-line personalized morning nudge banner. Triggers generation via
/// the provider (guarded internally, so calling it every rebuild is cheap) and
/// hides itself entirely until there's something to show.
class _MorningNudgeCard extends StatelessWidget {
  const _MorningNudgeCard();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.ensureMorningNudge();
    });

    final nudge = provider.morningNudge;
    final loading = provider.morningNudgeLoading;
    if (!loading && (nudge == null || nudge.text.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3F1FB), Color(0xFFF6F1FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8B7CC8).withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('☀️', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: loading
                ? Row(
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF8B7CC8)),
                      ),
                      SizedBox(width: 12),
                      Text('Thinking about your morning…',
                          style: TextStyle(
                              fontSize: 15, color: Color(0xFF4B4463))),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('GOOD MORNING',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: Color(0xFF6D5DB0))),
                      const SizedBox(height: 5),
                      Text(nudge!.text,
                          style: const TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              color: Color(0xFF3B3560),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
