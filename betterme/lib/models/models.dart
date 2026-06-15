import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  String id;
  String username;
  String avatarUrl;
  int streak;
  int score; // Leaderboard score
  int waterIntake;
  int waterGoal;
  List<String> friendsIds;

  User({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.streak,
    this.score = 0,
    this.waterIntake = 0,
    this.waterGoal = 2500,
    this.friendsIds = const [],
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'avatarUrl': avatarUrl,
      'streak': streak,
      'score': score,
      'waterIntake': waterIntake,
      'waterGoal': waterGoal,
      'friendsIds': friendsIds,
    };
  }

  // Create from Firestore Document
  factory User.fromMap(Map<String, dynamic> map, String documentId) {
    return User(
      id: documentId,
      username: map['username'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      streak: map['streak'] ?? 0,
      score: map['score'] ?? 0,
      waterIntake: map['waterIntake'] ?? 0,
      waterGoal: map['waterGoal'] ?? 2500,
      friendsIds: List<String>.from(map['friendsIds'] ?? []),
    );
  }
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
}

class LogEntry {
  String id;
  String userId;
  DateTime date;
  double sleepHours;
  double moodScore; // 1.0 to 10.0
  String notes;
  String trigger;
  List<String> emotions;

  LogEntry({
    this.id = '',
    this.userId = '',
    required this.date,
    required this.sleepHours,
    required this.moodScore,
    this.notes = '',
    this.trigger = '',
    this.emotions = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'sleepHours': sleepHours,
      'moodScore': moodScore,
      'notes': notes,
      'trigger': trigger,
      'emotions': emotions,
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map, String documentId) {
    return LogEntry(
      id: documentId,
      userId: map['userId'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sleepHours: (map['sleepHours'] as num?)?.toDouble() ?? 0.0,
      moodScore: (map['moodScore'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] ?? '',
      trigger: map['trigger'] ?? '',
      emotions: List<String>.from(map['emotions'] ?? []),
    );
  }
}

class Friend {
  String username;
  String avatarUrl;
  int streak;
  String recentActivity;

  Friend({
    required this.username,
    required this.avatarUrl,
    required this.streak,
    required this.recentActivity,
  });

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'avatarUrl': avatarUrl,
      'streak': streak,
      'recentActivity': recentActivity,
    };
  }

  factory Friend.fromMap(Map<String, dynamic> map) {
    return Friend(
      username: map['username'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      streak: map['streak'] ?? 0,
      recentActivity: map['recentActivity'] ?? '',
    );
  }
}
