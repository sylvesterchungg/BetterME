import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/models.dart';

// Handles OS-level local notifications for task reminders (FR_901) and
// streak milestone banners (FR_902). In-app Firestore notifications are
// written directly from AppProvider.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    // Initialize timezone data. We intentionally leave tz.local as UTC and
    // instead convert local DateTimes to UTC before creating TZDateTimes —
    // see scheduleTaskReminder. This avoids requiring flutter_timezone.
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );
    _initialized = true;
  }

  // Request OS notification permission (Android 13+ / iOS).
  // Returns true if granted.
  static Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true, badge: true, sound: true) ??
            false;
      }
    } catch (e) {
      debugPrint('[Notifications] permission request error: $e');
    }
    return false;
  }

  // Schedule an OS alarm for a task's reminder time on its due date (FR_901).
  static Future<void> scheduleTaskReminder(Task task) async {
    if (!_initialized) return;
    if (task.reminderTime == null || task.dueDate == null || task.id.isEmpty) {
      return;
    }

    final parts = task.reminderTime!.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    // Recurrence: map the task's repeatInterval to the OS repeat rule so the
    // reminder actually recurs (Daily/Weekly/Monthly). Anything else ('None')
    // fires exactly once.
    final match = _matchComponentsFor(task.repeatInterval);

    // Build the local DateTime the user intended, convert to UTC, then wrap in
    // a TZDateTime(UTC) so flutter_local_notifications fires at the right wall-
    // clock time without needing flutter_timezone to set tz.local.
    var localDt = DateTime(
      task.dueDate!.year,
      task.dueDate!.month,
      task.dueDate!.day,
      hour,
      minute,
    );

    final now = DateTime.now();
    if (localDt.isBefore(now)) {
      // A one-off reminder in the past is pointless; a recurring one just needs
      // to roll forward to its next occurrence so the OS can start repeating.
      if (match == null) return;
      localDt = _rollForward(localDt, task.repeatInterval, now);
    }

    final scheduledDate = tz.TZDateTime.from(localDt.toUtc(), tz.UTC);
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.UTC))) return;

    try {
      await _plugin.zonedSchedule(
        _taskNotifId(task.id),
        'Task Reminder',
        task.title,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Task Reminders',
            channelDescription: 'Reminders for your scheduled tasks',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: match,
      );
    } catch (e) {
      debugPrint('[Notifications] scheduleTaskReminder error: $e');
    }
  }

  // Maps a task's repeat interval to the recurrence rule the OS applies.
  // null = fire once (no repeat).
  static DateTimeComponents? _matchComponentsFor(String repeatInterval) {
    switch (repeatInterval) {
      case 'Daily':
        return DateTimeComponents.time;
      case 'Weekly':
        return DateTimeComponents.dayOfWeekAndTime;
      case 'Monthly':
        return DateTimeComponents.dayOfMonthAndTime;
      default:
        return null;
    }
  }

  // Advances [dt] by whole intervals until it is in the future, so a recurring
  // reminder whose first occurrence already passed still schedules correctly.
  static DateTime _rollForward(DateTime dt, String interval, DateTime now) {
    var d = dt;
    var guard = 0; // safety cap so a bad interval can't loop forever
    while (d.isBefore(now) && guard < 1000) {
      switch (interval) {
        case 'Weekly':
          d = d.add(const Duration(days: 7));
          break;
        case 'Monthly':
          d = DateTime(d.year, d.month + 1, d.day, d.hour, d.minute);
          break;
        case 'Daily':
        default:
          d = d.add(const Duration(days: 1));
          break;
      }
      guard++;
    }
    return d;
  }

  // Cancel a previously scheduled task reminder.
  static Future<void> cancelTaskReminder(String taskId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_taskNotifId(taskId));
    } catch (e) {
      debugPrint('[Notifications] cancelTaskReminder error: $e');
    }
  }

  // Show an immediate OS banner for a streak milestone (FR_902).
  static Future<void> showStreakMilestone(int streak) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        _streakNotifId(streak),
        'Streak Milestone!',
        "You've hit a $streak-day streak — amazing consistency!",
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'streak_alerts',
            'Streak Milestones',
            channelDescription: 'Celebrate your wellness streak milestones',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true),
        ),
      );
    } catch (e) {
      debugPrint('[Notifications] showStreakMilestone error: $e');
    }
  }

  // Schedule (or reschedule) a repeating hydration reminder that fires every
  // [intervalMinutes] minutes. Passing 0 or a negative value simply cancels
  // any existing reminder. Uses periodicallyShowWithDuration so any interval
  // (30 min, 1h, 2h, …) is supported, not just the fixed RepeatInterval values.
  static Future<void> scheduleHydrationReminder(int intervalMinutes) async {
    if (!_initialized) return;
    // Always clear the previous schedule first so changing the interval doesn't
    // leave a stale reminder running alongside the new one.
    await cancelHydrationReminder();
    if (intervalMinutes <= 0) return;

    try {
      await _plugin.periodicallyShowWithDuration(
        _hydrationNotifId,
        'Time to hydrate 💧',
        'Take a moment to drink some water and log it in BetterME.',
        Duration(minutes: intervalMinutes),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hydration_reminders',
            'Hydration Reminders',
            channelDescription: 'Recurring reminders to drink water',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('[Notifications] scheduleHydrationReminder error: $e');
    }
  }

  // Cancel the recurring hydration reminder, if one is scheduled.
  static Future<void> cancelHydrationReminder() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_hydrationNotifId);
    } catch (e) {
      debugPrint('[Notifications] cancelHydrationReminder error: $e');
    }
  }

  static int _taskNotifId(String taskId) =>
      taskId.hashCode.abs() % 2000000000;
  static int _streakNotifId(int streak) => 90000 + streak;
  // Fixed id for the single recurring hydration reminder (there is only ever
  // one at a time). Kept clear of the task/streak id ranges above.
  static const int _hydrationNotifId = 80000;
}
