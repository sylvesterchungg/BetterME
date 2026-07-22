import 'package:cloud_firestore/cloud_firestore.dart';

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
  // Optional attached photo for the day; empty = none. Holds a base64-encoded
  // image, stored inline (no Cloud Storage on the free plan). Legacy entries may
  // still hold an http Storage URL, which renders via NetworkImage.
  String photoUrl;

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
