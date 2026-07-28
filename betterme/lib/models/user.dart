class User {
  String id;
  String username;
  // The user's real/display name (e.g. "Jane Doe"), shown on their profile.
  // Distinct from [username], which is the unique handle used for friend search.
  String name;
  // Either an http(s) URL (a Google profile photo) or a base64-encoded image
  // (uploaded avatars are stored inline in Firestore — the free Spark plan has
  // no Cloud Storage). Empty = show initials/person-icon default.
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
  // FR_901 — notification preferences
  bool notificationsEnabled; // master switch for task-reminder local notifications
  bool friendActivityNotif;  // in-app friend-accepted notifications
  bool streakAlertsNotif;    // in-app and OS streak milestone notifications
  // Recurring hydration reminder interval in minutes (0 = off). Drives a
  // repeating OS notification scheduled by NotificationService.
  int hydrationReminderMinutes;
  // FR_905 — daily logging reminder, stored as minutes from midnight
  // (e.g. 1260 = 21:00). -1 = off. The reminder is suppressed on any day that
  // already has a log entry; see AppProvider._syncLogReminder.
  int logReminderMinutes;
  // Consent gate for sending log data to the third-party Gemini AI service.
  // null = never asked yet (AI features stay off until answered); false =
  // declined/turned off; true = consented, AI features active.
  bool? aiInsightsEnabled;

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
    this.logReminderMinutes = 1260, // 21:00
    this.aiInsightsEnabled,
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
      'logReminderMinutes': logReminderMinutes,
      'aiInsightsEnabled': aiInsightsEnabled,
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
      logReminderMinutes: map['logReminderMinutes'] as int? ?? 1260,
      aiInsightsEnabled: map['aiInsightsEnabled'] as bool?,
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
