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
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => Scaffold(
                  backgroundColor: AppTheme.surfaceContainerLow,
                  appBar: AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: AppTheme.onSurface),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    title: const Text('Profile',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.white,
                    elevation: 0,
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(1),
                      child: Container(
                          height: 1, color: AppTheme.borderDefault),
                    ),
                  ),
                  body: const ProfileTab(),
                ),
              )),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.outlineVariant, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: user?.avatarUrl != null && user!.avatarUrl.isNotEmpty
                      ? Image.network(user.avatarUrl, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.person, color: AppTheme.outline))
                      : const Icon(Icons.person, color: AppTheme.outline),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, ${user?.username ?? ''}',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.onSurfaceVariant)),
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 14,
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderDefault),
                ),
                child: const Icon(Icons.notifications_outlined,
                    color: AppTheme.onSurfaceVariant, size: 20),
              ),
              if (provider.unreadNotificationCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: const BoxDecoration(
                        color: AppTheme.error, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      provider.unreadNotificationCount > 9
                          ? '9+'
                          : '${provider.unreadNotificationCount}',
                      style: const TextStyle(
                          fontSize: 8,
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
                TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
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
            const SizedBox(width: 10),
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
        const SizedBox(height: 10),
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
            const SizedBox(width: 10),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700)),
          Text(sub,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.onSurfaceVariant)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
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
    final today = DateTime.now();
    final monday =
        today.subtract(Duration(days: today.weekday - 1));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S'];

    final logsThisWeek = provider.logs.where((l) =>
        !l.date.isBefore(monday.subtract(const Duration(hours: 1))) &&
        l.date.isBefore(monday.add(const Duration(days: 7)))).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('This Week',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderDefault),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final date = monday.add(Duration(days: i));
              final isToday = date.day == today.day &&
                  date.month == today.month &&
                  date.year == today.year;
              final isFuture =
                  date.isAfter(today) && !isToday;
              final hasLog = logsThisWeek.any((l) =>
                  l.date.day == date.day &&
                  l.date.month == date.month &&
                  l.date.year == date.year);

              Color dotColor;
              if (hasLog) {
                dotColor = AppTheme.primary;
              } else if (isToday) {
                dotColor = AppTheme.outlineVariant;
              } else if (isFuture) {
                dotColor = AppTheme.surfaceContainer;
              } else {
                dotColor = AppTheme.surfaceContainerHigh;
              }

              return Column(
                children: [
                  Text(labels[i],
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isToday
                              ? AppTheme.onSurface
                              : AppTheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: hasLog
                          ? AppTheme.primaryFixed
                          : dotColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: isToday && !hasLog
                          ? Border.all(
                              color: AppTheme.outlineVariant, width: 1.5)
                          : null,
                    ),
                    child: hasLog
                        ? Icon(Icons.check,
                            size: 14, color: AppTheme.primary)
                        : isToday
                            ? const Icon(Icons.add,
                                size: 14, color: AppTheme.outline)
                            : null,
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // ── Quick Add ─────────────────────────────────────────────────────────────

  Widget _buildQuickAdd(BuildContext context, AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Add',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderDefault),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: fg, size: 18),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500)),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Up next: ${reminder.task.title}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(_formatReminderTime(reminder.when),
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white70)),
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
