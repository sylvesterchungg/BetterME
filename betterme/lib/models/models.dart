import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class User {
  String id;
  String username;
  // The user's real/display name (e.g. "Jane Doe"), shown on their profile.
  // Distinct from [username], which is the unique handle used for friend search.
  String name;
  String avatarUrl;
  int streak;
  int waterIntake;
  int waterGoal;
  String waterIntakeDate; // "YYYY-MM-DD" — resets intake when date changes
  List<String> friendsIds;
  // Denormalized "today's mood" so friends can see it without reading private
  // logs. Only meaningful when moodDate == today (see fromMap).
  double moodScore; // 0.0 = no mood logged today
  String moodDate; // "YYYY-MM-DD"
  // Task-completion streak (increments per task completed; resets on overdue).
  int taskStreak;
  // FR_904 — notification preferences
  bool notificationsEnabled; // master switch for task-reminder local notifications
  bool friendActivityNotif;  // in-app friend-accepted notifications
  bool streakAlertsNotif;    // in-app and OS streak milestone notifications
  // Recurring hydration reminder interval in minutes (0 = off). Drives a
  // repeating OS notification scheduled by NotificationService.
  int hydrationReminderMinutes;

  User({
    required this.id,
    required this.username,
    this.name = '',
    required this.avatarUrl,
    required this.streak,
    this.waterIntake = 0,
    this.waterGoal = 2500,
    this.waterIntakeDate = '',
    this.friendsIds = const [],
    this.moodScore = 0.0,
    this.moodDate = '',
    this.taskStreak = 0,
    this.notificationsEnabled = true,
    this.friendActivityNotif = true,
    this.streakAlertsNotif = true,
    this.hydrationReminderMinutes = 0,
  });

  static String todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'avatarUrl': avatarUrl,
      'streak': streak,
      'waterIntake': waterIntake,
      'waterGoal': waterGoal,
      'waterIntakeDate': waterIntakeDate,
      'friendsIds': friendsIds,
      'moodScore': moodScore,
      'moodDate': moodDate,
      'taskStreak': taskStreak,
      'notificationsEnabled': notificationsEnabled,
      'friendActivityNotif': friendActivityNotif,
      'streakAlertsNotif': streakAlertsNotif,
      'hydrationReminderMinutes': hydrationReminderMinutes,
    };
  }

  // Create from Firestore Document
  factory User.fromMap(Map<String, dynamic> map, String documentId) {
    final storedDate = map['waterIntakeDate'] as String? ?? '';
    final today = todayDateString();
    // If the stored date is not today, treat intake as 0
    final intake = storedDate == today ? (map['waterIntake'] as int? ?? 0) : 0;

    // Mood only counts for today; a stale mood from a previous day reads as 0.
    final storedMoodDate = map['moodDate'] as String? ?? '';
    final mood = storedMoodDate == today
        ? ((map['moodScore'] as num?)?.toDouble() ?? 0.0)
        : 0.0;

    return User(
      id: documentId,
      username: map['username'] ?? '',
      name: map['name'] as String? ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      streak: map['streak'] ?? 0,
      waterIntake: intake,
      waterGoal: map['waterGoal'] as int? ?? 2500,
      waterIntakeDate: storedDate,
      friendsIds: List<String>.from(map['friendsIds'] ?? []),
      moodScore: mood,
      moodDate: storedMoodDate,
      taskStreak: map['taskStreak'] as int? ?? 0,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      friendActivityNotif: map['friendActivityNotif'] as bool? ?? true,
      streakAlertsNotif: map['streakAlertsNotif'] as bool? ?? true,
      hydrationReminderMinutes: map['hydrationReminderMinutes'] as int? ?? 0,
    );
  }
}

/// Owner-only personal details (PII). Stored in `privateProfile/{userId}`, which
/// is readable/writable ONLY by the owner (see firestore.rules) — unlike the
/// `users` doc, which is world-readable for the leaderboard/friend search. Keep
/// anything personal (birth date, phone) here, never on [User].
class PrivateProfile {
  final DateTime? birthDate;
  final String phoneNumber;

  const PrivateProfile({this.birthDate, this.phoneNumber = ''});

  Map<String, dynamic> toMap() => {
        'birthDate': birthDate?.toIso8601String(),
        'phoneNumber': phoneNumber,
      };

  factory PrivateProfile.fromMap(Map<String, dynamic> map) => PrivateProfile(
        birthDate: map['birthDate'] != null
            ? DateTime.tryParse(map['birthDate'] as String)
            : null,
        phoneNumber: map['phoneNumber'] as String? ?? '',
      );
}

class Task {
  String id;
  String userId;
  String title;
  bool isCompleted;
  String category;
  String? categoryIconKey;
  DateTime? dueDate;
  String? reminderTime; // Format: "HH:mm"
  String repeatInterval; // "None", "Daily", "Weekly", "Monthly", "Custom"

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.isCompleted = false,
    this.category = 'General',
    this.categoryIconKey,
    this.dueDate,
    this.reminderTime,
    this.repeatInterval = 'None',
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'isCompleted': isCompleted,
      'category': category,
      'categoryIconKey': categoryIconKey,
      'dueDate': dueDate?.toIso8601String(),
      'reminderTime': reminderTime,
      'repeatInterval': repeatInterval,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map, String documentId) {
    return Task(
      id: documentId,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      category: map['category'] ?? 'General',
      categoryIconKey: map['categoryIconKey'],
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate']) : null,
      reminderTime: map['reminderTime'],
      repeatInterval: map['repeatInterval'] ?? 'None',
    );
  }
}

class TaskCategory {
  String id;
  String userId;
  String name;
  String iconKey;

  TaskCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.iconKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'iconKey': iconKey,
    };
  }

  factory TaskCategory.fromMap(Map<String, dynamic> map, String documentId) {
    return TaskCategory(
      id: documentId,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      iconKey: map['iconKey'] ?? 'list',
    );
  }

  static IconData iconFromKey(String key) {
    switch (key) {
      case 'self_improvement':
        return Icons.self_improvement;
      case 'restaurant':
        return Icons.restaurant;
      case 'medication':
        return Icons.medication;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'water_drop':
        return Icons.water_drop;
      case 'book':
        return Icons.menu_book;
      case 'bedtime':
        return Icons.bedtime;
      case 'favorite':
        return Icons.favorite;
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'schedule':
        return Icons.schedule;
      case 'list':
      default:
        return Icons.list_alt;
    }
  }
}

class FriendRequest {
  String id;
  String fromId;
  String fromUsername;
  String fromAvatarUrl;
  String toId;
  String status; // 'pending' | 'accepted' | 'rejected'

  FriendRequest({
    this.id = '',
    required this.fromId,
    required this.fromUsername,
    required this.fromAvatarUrl,
    required this.toId,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() => {
    'fromId': fromId,
    'fromUsername': fromUsername,
    'fromAvatarUrl': fromAvatarUrl,
    'toId': toId,
    'status': status,
  };

  factory FriendRequest.fromMap(Map<String, dynamic> map, String documentId) {
    return FriendRequest(
      id: documentId,
      fromId: map['fromId'] ?? '',
      fromUsername: map['fromUsername'] ?? '',
      fromAvatarUrl: map['fromAvatarUrl'] ?? '',
      toId: map['toId'] ?? '',
      status: map['status'] ?? 'pending',
    );
  }
}

class ProductivityRecord {
  String id;
  String userId;
  String date; // "YYYY-MM-DD"
  double completionRate; // 0.0–1.0
  int completedTasks;
  int totalTasks;

  ProductivityRecord({
    this.id = '',
    this.userId = '',
    required this.date,
    required this.completionRate,
    required this.completedTasks,
    required this.totalTasks,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'date': date,
    'completionRate': completionRate,
    'completedTasks': completedTasks,
    'totalTasks': totalTasks,
  };

  factory ProductivityRecord.fromMap(Map<String, dynamic> map, String documentId) {
    return ProductivityRecord(
      id: documentId,
      userId: map['userId'] ?? '',
      date: map['date'] ?? '',
      completionRate: (map['completionRate'] as num?)?.toDouble() ?? 0.0,
      completedTasks: map['completedTasks'] as int? ?? 0,
      totalTasks: map['totalTasks'] as int? ?? 0,
    );
  }
}

/// A short, digestible AI wellness insight (FR_405/FR_406). Cached in Firestore
/// so the dashboard loads instantly and Gemini is only called when the user's
/// recent data actually changes (or the cache is older than a day).
class AIInsight {
  /// e.g. "Positive Sleep-Productivity Link"
  final String correlationType;

  /// One encouraging sentence, e.g. "Sufficient sleep is driving your focus."
  final String headline;

  /// 1-2 plain-language sentences grounded in the user's own numbers.
  final String breakdown;

  /// One gentle, specific, non-judgmental suggestion.
  final String nudge;

  /// Fingerprint of the 7-day data window this insight was generated from.
  /// When the live data's signature differs, the insight is regenerated.
  final String dataSignature;

  /// When this insight was produced (used for the 24-hour freshness check).
  final DateTime generatedAt;

  AIInsight({
    required this.correlationType,
    required this.headline,
    required this.breakdown,
    required this.nudge,
    this.dataSignature = '',
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  bool get isEmpty => headline.isEmpty && breakdown.isEmpty && nudge.isEmpty;

  /// Parses the raw JSON returned by Gemini (snake_case keys).
  factory AIInsight.fromJson(Map<String, dynamic> json) => AIInsight(
        correlationType: (json['correlation_type'] ?? '').toString().trim(),
        headline: (json['headline_insight'] ?? '').toString().trim(),
        breakdown: (json['detailed_breakdown'] ?? '').toString().trim(),
        nudge: (json['actionable_nudge'] ?? '').toString().trim(),
      );

  /// Reads back a cached insight from Firestore.
  factory AIInsight.fromMap(Map<String, dynamic> map) => AIInsight(
        correlationType: (map['correlationType'] ?? '').toString(),
        headline: (map['headline'] ?? '').toString(),
        breakdown: (map['breakdown'] ?? '').toString(),
        nudge: (map['nudge'] ?? '').toString(),
        dataSignature: (map['dataSignature'] ?? '').toString(),
        generatedAt: DateTime.tryParse((map['generatedAt'] ?? '').toString()),
      );

  Map<String, dynamic> toMap() => {
        'correlationType': correlationType,
        'headline': headline,
        'breakdown': breakdown,
        'nudge': nudge,
        'dataSignature': dataSignature,
        'generatedAt': generatedAt.toIso8601String(),
      };

  AIInsight copyWith({String? dataSignature, DateTime? generatedAt}) =>
      AIInsight(
        correlationType: correlationType,
        headline: headline,
        breakdown: breakdown,
        nudge: nudge,
        dataSignature: dataSignature ?? this.dataSignature,
        generatedAt: generatedAt ?? this.generatedAt,
      );
}

/// A single calming coping action suggested by the AI.
class AICopingTip {
  final String title; // short action, e.g. "Wind-down routine"
  final String detail; // one supportive sentence explaining how

  const AICopingTip({required this.title, required this.detail});

  factory AICopingTip.fromMap(Map<String, dynamic> map) => AICopingTip(
        title: (map['title'] ?? '').toString().trim(),
        detail: (map['detail'] ?? '').toString().trim(),
      );

  Map<String, dynamic> toMap() => {'title': title, 'detail': detail};
}

/// AI-generated coping support shown when rough days (nightmares, symptoms,
/// low mood) cluster in the recent logs. Gentle, non-clinical self-care ideas.
class AICopingTips {
  /// One warm sentence acknowledging the rough patch.
  final String intro;

  /// 2-3 tailored coping actions.
  final List<AICopingTip> tips;

  /// Fingerprint of the rough-day content this was generated for.
  final String signature;

  /// When it was produced (for the freshness check).
  final DateTime generatedAt;

  AICopingTips({
    required this.intro,
    required this.tips,
    this.signature = '',
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  bool get isEmpty => tips.isEmpty;

  /// Parses the raw JSON returned by Gemini (snake_case keys).
  factory AICopingTips.fromJson(Map<String, dynamic> json) {
    final rawTips = (json['tips'] as List?) ?? const [];
    return AICopingTips(
      intro: (json['intro'] ?? '').toString().trim(),
      tips: rawTips
          .whereType<Map>()
          .map((m) => AICopingTip.fromMap(Map<String, dynamic>.from(m)))
          .where((t) => t.title.isNotEmpty || t.detail.isNotEmpty)
          .toList(),
    );
  }

  /// Reads back cached coping tips from Firestore.
  factory AICopingTips.fromMap(Map<String, dynamic> map) {
    final rawTips = (map['tips'] as List?) ?? const [];
    return AICopingTips(
      intro: (map['intro'] ?? '').toString(),
      tips: rawTips
          .whereType<Map>()
          .map((m) => AICopingTip.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      signature: (map['signature'] ?? '').toString(),
      generatedAt: DateTime.tryParse((map['generatedAt'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toMap() => {
        'intro': intro,
        'tips': tips.map((t) => t.toMap()).toList(),
        'signature': signature,
        'generatedAt': generatedAt.toIso8601String(),
      };

  AICopingTips copyWith({String? signature, DateTime? generatedAt}) =>
      AICopingTips(
        intro: intro,
        tips: tips,
        signature: signature ?? this.signature,
        generatedAt: generatedAt ?? this.generatedAt,
      );
}

/// One-line personalized "good morning" tip for the dashboard, built from last
/// night's sleep/mood + today's task load. Cached like [AIInsight]/[AICopingTips]
/// so it loads instantly and only calls Gemini when its inputs change.
class MorningNudge {
  /// The single friendly sentence shown to the user.
  final String text;

  /// Fingerprint of the inputs it was built from (see nudgeSignatureFor).
  final String signature;

  /// When it was produced (for the freshness check).
  final DateTime generatedAt;

  MorningNudge({required this.text, this.signature = '', DateTime? generatedAt})
      : generatedAt = generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  bool get isEmpty => text.isEmpty;

  /// Parses the raw JSON returned by Gemini.
  factory MorningNudge.fromJson(Map<String, dynamic> json) =>
      MorningNudge(text: (json['nudge'] ?? '').toString().trim());

  /// Reads back a cached nudge from Firestore.
  factory MorningNudge.fromMap(Map<String, dynamic> map) => MorningNudge(
        text: (map['text'] ?? '').toString(),
        signature: (map['signature'] ?? '').toString(),
        generatedAt: DateTime.tryParse((map['generatedAt'] ?? '').toString()),
      );

  Map<String, dynamic> toMap() => {
        'text': text,
        'signature': signature,
        'generatedAt': generatedAt.toIso8601String(),
      };

  MorningNudge copyWith({String? signature, DateTime? generatedAt}) =>
      MorningNudge(
        text: text,
        signature: signature ?? this.signature,
        generatedAt: generatedAt ?? this.generatedAt,
      );
}

class LogEntry {
  String id;
  String userId;
  DateTime date;
  double sleepHours;
  double moodScore; // 1.0 to 10.0
  int sleepQuality; // 1–10; 0 = not set
  bool hadNightmare;
  String notes;
  String trigger;
  List<String> emotions;
  // Non-zero only when the day's entry was updated (stores the score before the update)
  double previousMoodScore;
  double previousSleepHours;
  bool isSharedWithFriends; // whether this entry is visible to mutual friends
  String photoUrl; // optional attached photo for the day; empty = none

  LogEntry({
    this.id = '',
    this.userId = '',
    required this.date,
    required this.sleepHours,
    required this.moodScore,
    this.sleepQuality = 0,
    this.hadNightmare = false,
    this.notes = '',
    this.trigger = '',
    this.emotions = const [],
    this.previousMoodScore = 0.0,
    this.previousSleepHours = 0.0,
    this.isSharedWithFriends = false,
    this.photoUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'sleepHours': sleepHours,
      'moodScore': moodScore,
      'sleepQuality': sleepQuality,
      'hadNightmare': hadNightmare,
      'notes': notes,
      'trigger': trigger,
      'emotions': emotions,
      'previousMoodScore': previousMoodScore,
      'previousSleepHours': previousSleepHours,
      'isSharedWithFriends': isSharedWithFriends,
      'photoUrl': photoUrl,
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map, String documentId) {
    return LogEntry(
      id: documentId,
      userId: map['userId'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sleepHours: (map['sleepHours'] as num?)?.toDouble() ?? 0.0,
      moodScore: (map['moodScore'] as num?)?.toDouble() ?? 0.0,
      sleepQuality: map['sleepQuality'] as int? ?? 0,
      hadNightmare: map['hadNightmare'] as bool? ?? false,
      notes: map['notes'] ?? '',
      trigger: map['trigger'] ?? '',
      emotions: List<String>.from(map['emotions'] ?? []),
      previousMoodScore: (map['previousMoodScore'] as num?)?.toDouble() ?? 0.0,
      previousSleepHours: (map['previousSleepHours'] as num?)?.toDouble() ?? 0.0,
      isSharedWithFriends: map['isSharedWithFriends'] as bool? ?? false,
      photoUrl: map['photoUrl'] ?? '',
    );
  }
}

// In-app notifications stored in Firestore (FR_902, FR_903)
class AppNotification {
  String id;
  String userId;
  String type; // 'streak_milestone' | 'friend_accepted' | 'friend_request'
  String title;
  String body;
  DateTime createdAt;
  bool isRead;

  AppNotification({
    this.id = '',
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'type': type,
    'title': title,
    'body': body,
    'createdAt': Timestamp.fromDate(createdAt),
    'isRead': isRead,
  };

  factory AppNotification.fromMap(Map<String, dynamic> map, String documentId) {
    return AppNotification(
      id: documentId,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
    );
  }
}

