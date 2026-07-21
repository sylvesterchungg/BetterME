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

    // Build the local DateTime the user intended, convert to UTC, then wrap in
    // a TZDateTime(UTC) so flutter_local_notifications fires at the right wall-
    // clock time without needing flutter_timezone to set tz.local.
    final localDt = DateTime(
      task.dueDate!.year,
      task.dueDate!.month,
      task.dueDate!.day,
      hour,
      minute,
    );
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
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('[Notifications] scheduleTaskReminder error: $e');
    }
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
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('[Notifications] showStreakMilestone error: $e');
    }
  }

  static int _taskNotifId(String taskId) =>
      taskId.hashCode.abs() % 2000000000;
  static int _streakNotifId(int streak) => 90000 + streak;
}
