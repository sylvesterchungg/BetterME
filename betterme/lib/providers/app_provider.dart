import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/ai_insight_service.dart';
import '../services/notification_service.dart';

class AppProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? currentUser;
  // Owner-only PII (birth date, phone), kept out of the world-readable `users`
  // doc. Backed by its own private stream (see _initUserListeners).
  PrivateProfile privateProfile = const PrivateProfile();
  List<Task> tasks = [];
  List<TaskCategory> taskCategories = [];
  List<LogEntry> logs = [];
  List<User> friends = []; // Dynamic friends
  List<LogEntry> friendsSharedLogs = [];
  List<FriendRequest> incomingRequests = [];
  List<ProductivityRecord> productivityRecords = [];
  List<AppNotification> notifications = [];
  // Most recent cached AI insight (client-side cache; see AIInsightService).
  AIInsight? cachedInsight;
  // Most recent cached AI coping suggestions (shown when rough days cluster).
  AICopingTips? cachedCoping;
  // Personalized morning nudge for the dashboard (client-side cached).
  MorningNudge? morningNudge;
  bool morningNudgeLoading = false;
  // Guards ensureMorningNudge() so repeated dashboard rebuilds don't refire.
  String? _nudgeHandledSignature;

  int get unreadNotificationCount =>
      notifications.where((n) => !n.isRead).length;

  // Friends-only leaderboard: the current user is ranked against the friends
  // they've actually added/accepted — you must be friends to see someone's
  // streak here. Computed from `currentUser` + `friends` (both kept live by
  // their streams), sorted by streak descending (FR_505 / LeaderboardEntry),
  // with username as a deterministic tie-breaker.
  List<User> get leaderboard {
    final list = <User>[
      ?currentUser,
      ...friends,
    ];
    list.sort((a, b) {
      final byStreak = b.streak.compareTo(a.streak);
      return byStreak != 0 ? byStreak : a.username.compareTo(b.username);
    });
    return list;
  }

  // The current user's rank within the friends-only leaderboard (1-based).
  int get myLeaderboardRank {
    if (currentUser == null) return 0;
    final idx = leaderboard.indexWhere((u) => u.id == currentUser!.id);
    return idx >= 0 ? idx + 1 : 0;
  }

  // Active Stream Subscriptions
  StreamSubscription? _userSub;
  StreamSubscription? _tasksSub;
  StreamSubscription? _taskCategoriesSub;
  StreamSubscription? _logsSub;
  StreamSubscription? _friendsSub;
  StreamSubscription? _friendsLogsSub;
  StreamSubscription? _productivitySub;
  StreamSubscription? _requestsSub;
  StreamSubscription? _notificationsSub;
  StreamSubscription? _privateProfileSub;


  AppProvider() {
    _initAuthListener();
  }

  // Listen to Firebase Auth state changes
  void _initAuthListener() {
    _auth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser == null) {
        _cancelSubscriptions();
        currentUser = null;
        privateProfile = const PrivateProfile();
        tasks = [];
        taskCategories = [];
        logs = [];
        friends = [];
        friendsSharedLogs = [];
        incomingRequests = [];
        productivityRecords = [];
        notifications = [];
        cachedInsight = null;
        cachedCoping = null;
        morningNudge = null;
        _nudgeHandledSignature = null;
        notifyListeners();
      } else {
        await _loadOrCreateProfile(firebaseUser);
      }
    });
  }

  // Extra sign-up details (birth date, phone) captured in registerWithEmail and
  // consumed once when the auth-state listener creates the new profile doc.
  Map<String, dynamic>? _pendingProfileExtras;

  Future<void> _loadOrCreateProfile(firebase_auth.User firebaseUser) async {
    final userId = firebaseUser.uid;
    var profile = await _dbService.getUserProfile(userId);

    if (profile == null) {
      final extras = _pendingProfileExtras;
      final pendingName = (extras?['username'] as String?)?.trim();

      // Now that we're authenticated, upload the sign-up photo (if any). Storage
      // rules require request.auth.uid == userId, which only holds here. A real
      // Google photo is used as the fallback; otherwise blank, so the UI shows
      // the user's initials/person-icon default instead of a stock face.
      var avatarUrl = firebaseUser.photoURL ?? '';
      final pendingPhoto = extras?['photo'];
      if (pendingPhoto is File) {
        try {
          avatarUrl = await _dbService.uploadProfilePhoto(pendingPhoto, userId);
        } catch (e) {
          debugPrint('[Signup] avatar upload failed: $e');
        }
      }

      profile = User(
        id: userId,
        username: (pendingName != null && pendingName.isNotEmpty)
            ? pendingName
            : firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User',
        name: (extras?['name'] as String?) ?? '',
        avatarUrl: avatarUrl,
        streak: 0,
        waterIntake: 0,
        friendsIds: [],
      );
      await _dbService.saveUserProfile(profile);

      // PII (birth date, phone) goes into the owner-only private doc, never the
      // world-readable `users` doc. Only write when something was provided.
      final birthDate = extras?['birthDate'] as DateTime?;
      final phone = (extras?['phoneNumber'] as String?) ?? '';
      if (birthDate != null || phone.isNotEmpty) {
        await _dbService.savePrivateProfile(
          userId,
          PrivateProfile(birthDate: birthDate, phoneNumber: phone),
        );
      }
    }
    _pendingProfileExtras = null;

    currentUser = profile;
    _initUserListeners(userId);
    notifyListeners();
    // Request OS notification permission on first login if notifications are enabled
    if (profile.notificationsEnabled) {
      NotificationService.requestPermission();
    }
    // Re-arm the recurring hydration reminder for this session. OS schedules
    // don't reliably survive reboots/reinstalls, so we reschedule on each login
    // based on the interval saved to the profile.
    if (profile.hydrationReminderMinutes > 0) {
      NotificationService.scheduleHydrationReminder(profile.hydrationReminderMinutes);
    }
  }

  // Initialize listeners for logged-in user
  void _initUserListeners(String userId) {
    _cancelSubscriptions();

    // 1. Listen to User Profile changes
    _userSub = _dbService.streamUserProfile(userId).listen((user) {
      currentUser = user;

      // Update friends stream if friendIds changed
      if (user != null) {
        _friendsSub?.cancel();
        _friendsSub = _dbService.streamFriends(user.friendsIds).listen((friendList) {
          friends = friendList;
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] friends stream error: $e'));

        _friendsLogsSub?.cancel();
        _friendsLogsSub = _dbService.streamFriendsSharedLogs(user.friendsIds).listen((sharedLogs) {
          friendsSharedLogs = sharedLogs;
          notifyListeners();
        }, onError: (e) => debugPrint('[Firestore] friends shared logs stream error: $e'));
      }
      notifyListeners();
    }, onError: (e) => debugPrint('[Firestore] user profile stream error: $e'));

    // 2. Listen to User's Tasks — save a productivity snapshot on every emission
    // including the initial load, so today always has a record even if the user
    // doesn't toggle any tasks during this session.
    _tasksSub = _dbService.streamTasks(userId).listen((newTasks) {
      tasks = newTasks;
      _saveProductivityRecord(userId);
      notifyListeners();
      _checkAndHandleOverdueTasks();
    }, onError: (e) => debugPrint('[Firestore] tasks stream error: $e'));

    _taskCategoriesSub = _dbService.streamTaskCategories(userId).listen((newCategories) {
      taskCategories = newCategories;
      notifyListeners();
    }, onError: (e) => debugPrint('[Firestore] taskCategories stream error: $e'));

    // 3. Listen to User's Logs (Sleep, Mood, Notes, Triggers)
    //    The daily-log streak is derived purely from these dates, so recompute
    //    it on every emission (including the initial load — this is what resets
    //    a broken streak to 0 when the app is reopened after a missed day).
    _logsSub = _dbService.streamLogEntries(userId).listen((newLogs) {
      logs = newLogs;
      notifyListeners();
      checkAndUpdateStreak();
    }, onError: (e) => debugPrint('[Firestore] logs stream error: $e'));

    // 4. Leaderboard is friends-only and derived from `currentUser` + `friends`
    //    (both kept live by the streams above), so no separate query is needed.

    // 4b. Listen to the owner-only private profile (birth date, phone).
    _privateProfileSub =
        _dbService.streamPrivateProfile(userId).listen((profile) {
      privateProfile = profile;
      notifyListeners();
    }, onError: (e) => debugPrint('[Firestore] private profile stream error: $e'));

    // 5. Listen to Productivity Records
    _productivitySub = _dbService.streamProductivityRecords(userId).listen((records) {
      productivityRecords = records;
      notifyListeners();
    }, onError: (e) => debugPrint('[Firestore] productivity stream error: $e'));

    // 6. Listen to Incoming Friend Requests (FR_502 / FR_503)
    _requestsSub = _dbService.streamIncomingRequests(userId).listen((requests) {
      incomingRequests = requests;
      notifyListeners();
    }, onError: (e) => debugPrint('[Firestore] incoming requests stream error: $e'));

    // 7. Listen to In-App Notifications (FR_902, FR_903)
    _notificationsSub =
        _dbService.streamNotifications(userId).listen((notifList) {
      notifications = notifList;
      notifyListeners();
    }, onError: (e) => debugPrint('[Firestore] notifications stream error: $e'));

    // 8. Load any cached AI insight + coping tips once (client-side cache;
    //    regenerated on demand by the Trends screen when recent data changes).
    _dbService.getCachedInsight(userId).then((insight) {
      cachedInsight = insight;
      notifyListeners();
    }).catchError((e) {
      debugPrint('[Firestore] cached insight load error: $e');
    });
    _dbService.getCachedCoping(userId).then((coping) {
      cachedCoping = coping;
      notifyListeners();
    }).catchError((e) {
      debugPrint('[Firestore] cached coping load error: $e');
    });
    _dbService.getCachedNudge(userId).then((nudge) {
      morningNudge = nudge;
      notifyListeners();
    }).catchError((e) {
      debugPrint('[Firestore] cached nudge load error: $e');
    });
  }

  /// Persist a freshly generated AI insight to the client-side cache.
  Future<void> persistInsight(AIInsight insight) async {
    cachedInsight = insight;
    final userId = currentUser?.id;
    if (userId == null) return;
    try {
      await _dbService.saveInsight(userId, insight);
    } catch (e) {
      debugPrint('[Firestore] save insight error: $e');
    }
  }

  /// Persist freshly generated coping suggestions to the client-side cache.
  Future<void> persistCoping(AICopingTips coping) async {
    cachedCoping = coping;
    final userId = currentUser?.id;
    if (userId == null) return;
    try {
      await _dbService.saveCoping(userId, coping);
    } catch (e) {
      debugPrint('[Firestore] save coping error: $e');
    }
  }

  // ── Morning nudge ──────────────────────────────────────────────────────────

  /// Most recent log that actually carries sleep or mood, and is recent enough
  /// (within 2 days) for a "this morning" nudge to make sense.
  LogEntry? _latestRelevantLog() {
    LogEntry? latest;
    for (final l in logs) {
      if (l.sleepHours <= 0 && l.moodScore <= 0) continue;
      if (latest == null || l.date.isAfter(latest.date)) latest = l;
    }
    if (latest == null) return null;
    return DateTime.now().difference(latest.date).inDays <= 2 ? latest : null;
  }

  /// Incomplete tasks due today or already overdue (i.e. "left to do today").
  int get _pendingTasksToday {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return tasks
        .where((t) =>
            !t.isCompleted && (t.dueDate == null || !t.dueDate!.isAfter(end)))
        .length;
  }

  /// Generates the morning nudge only when it's stale (guarded so repeated
  /// dashboard rebuilds don't refire). Cheap and idempotent to call every build.
  Future<void> ensureMorningNudge({bool force = false}) async {
    if (currentUser == null || morningNudgeLoading) return;
    final latest = _latestRelevantLog();
    final sig = AIInsightService.nudgeSignatureFor(latest, _pendingTasksToday,
        streak: currentUser?.streak);
    if (!force) {
      if (_nudgeHandledSignature == sig) return;
      final cached = morningNudge;
      final fresh = cached != null &&
          cached.signature == sig &&
          DateTime.now().difference(cached.generatedAt) <
              const Duration(hours: 12);
      if (fresh) {
        _nudgeHandledSignature = sig;
        return;
      }
    }
    _nudgeHandledSignature = sig;
    if (latest == null) return; // nothing personal to say yet
    morningNudgeLoading = true;
    notifyListeners();
    final result = await AIInsightService.generateMorningNudge(
      latest: latest,
      pendingTasks: _pendingTasksToday,
      streak: currentUser?.streak,
    );
    morningNudgeLoading = false;
    if (result != null) {
      morningNudge = result;
      final userId = currentUser?.id;
      if (userId != null) {
        try {
          await _dbService.saveNudge(userId, result);
        } catch (e) {
          debugPrint('[Firestore] save nudge error: $e');
        }
      }
    }
    notifyListeners();
  }

  void _cancelSubscriptions() {
    _userSub?.cancel();
    _tasksSub?.cancel();
    _taskCategoriesSub?.cancel();
    _logsSub?.cancel();
    _friendsSub?.cancel();
    _friendsLogsSub?.cancel();
    _productivitySub?.cancel();
    _requestsSub?.cancel();
    _notificationsSub?.cancel();
    _privateProfileSub?.cancel();
  }

  // Detect incomplete tasks past their due date; reset the task streak if found.
  // The daily-log streak is derived purely from log dates (see _computeLogStreak)
  // and is deliberately left untouched here — an overdue task shouldn't wipe out
  // a logging streak.
  void _checkAndHandleOverdueTasks() {
    if (currentUser == null || tasks.isEmpty) return;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final hasOverdue = tasks.any(
      (t) => !t.isCompleted && t.dueDate != null && t.dueDate!.isBefore(todayStart),
    );
    if (hasOverdue && currentUser!.taskStreak > 0) {
      _dbService.updateLeaderboardData(currentUser!.id, {
        'taskStreak': 0,
      });
    }
  }

  void _saveProductivityRecord(String userId) {
    final total = tasks.length;
    final completed = tasks.where((t) => t.isCompleted).length;
    final rate = total > 0 ? completed / total : 0.0;
    final today = User.todayDateString();
    final record = ProductivityRecord(
      userId: userId,
      date: today,
      completionRate: rate,
      completedTasks: completed,
      totalTasks: total,
    );
    _dbService.saveProductivityRecord(record);
  }

  // ==========================================
  // AUTH / PROFILE METHODS
  // ==========================================

  Future<void> loginWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> registerWithEmail(
    String email,
    String password,
    String username, {
    String? name,
    DateTime? birthDate,
    String? phoneNumber,
    File? photo,
  }) async {
    // Stash the chosen username + optional extras so _loadOrCreateProfile (fired
    // by the auth-state listener below) can persist them onto the brand-new
    // profile document. Carrying them here avoids a race where the profile is
    // created before updateDisplayName() has propagated, and lets the photo be
    // uploaded once we're authenticated (Storage rules require a matching uid).
    _pendingProfileExtras = {
      'username': username.trim(),
      'name': (name ?? '').trim(),
      'birthDate': birthDate,
      'phoneNumber': (phoneNumber ?? '').trim(),
      'photo': photo,
    };
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (credential.user != null) {
      await credential.user!.updateDisplayName(username);
      // Wait for authStateChanges listener to pick up the new user and create the profile
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> loginWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return; // User canceled

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = firebase_auth.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await _auth.signInWithCredential(credential);
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> updateUsername(String newName) async {
    if (currentUser != null && newName.isNotEmpty) {
      currentUser!.username = newName;
      await _dbService.saveUserProfile(currentUser!);
      if (_auth.currentUser != null) {
        await _auth.currentUser!.updateDisplayName(newName);
      }
    }
  }

  /// Update the user's real/display name on the public profile.
  Future<void> updateName(String newName) async {
    if (currentUser == null) return;
    currentUser!.name = newName.trim();
    await _dbService.saveUserProfile(currentUser!);
    notifyListeners();
  }

  /// Re-authenticate an email/password user with their current password. Firebase
  /// requires a recent login before sensitive changes like updatePassword; this
  /// also serves to verify the old password before allowing a change. Throws a
  /// FirebaseAuthException (e.g. 'wrong-password') on failure.
  Future<void> reauthenticateWithPassword(String currentPassword) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw firebase_auth.FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in email account to re-authenticate.',
      );
    }
    final cred = firebase_auth.EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);
  }

  /// Change the password. Callers must re-authenticate first
  /// (see [reauthenticateWithPassword]) so the old password is verified.
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updatePassword(newPassword);
  }

  /// Update the owner-only private profile (birth date, phone). Passing null for
  /// a field leaves it unchanged; pass an empty string to clear the phone
  /// number. Writes to `privateProfile/{userId}`; the stream refreshes
  /// `privateProfile` after the write.
  Future<void> updateProfileDetails({DateTime? birthDate, String? phoneNumber}) async {
    if (currentUser == null) return;
    final updated = PrivateProfile(
      birthDate: birthDate ?? privateProfile.birthDate,
      phoneNumber:
          phoneNumber != null ? phoneNumber.trim() : privateProfile.phoneNumber,
    );
    privateProfile = updated; // optimistic; stream will confirm
    await _dbService.savePrivateProfile(currentUser!.id, updated);
    notifyListeners();
  }

  /// The current daily-log streak, derived purely from the log dates: the
  /// number of consecutive calendar days that have at least one log, ending at
  /// today (if logged today) or yesterday (if logged yesterday but not yet
  /// today, so the streak stays alive for the day). Returns 0 when there are no
  /// logs, or when the most recent log is older than yesterday (streak broken).
  int _computeLogStreak() {
    if (logs.isEmpty) return 0;

    // Collapse logs to the distinct calendar days they fall on.
    final loggedDays = <DateTime>{
      for (final log in logs) DateTime(log.date.year, log.date.month, log.date.day),
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Anchor the streak at today if logged today, otherwise yesterday. If the
    // newest log is older than yesterday, the streak is already broken.
    DateTime cursor;
    if (loggedDays.contains(today)) {
      cursor = today;
    } else if (loggedDays.contains(yesterday)) {
      cursor = yesterday;
    } else {
      return 0;
    }

    // Walk backwards day by day for as long as each day has a log.
    int streak = 0;
    while (loggedDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<void> checkAndUpdateStreak() async {
    if (currentUser == null) return;

    final newStreak = _computeLogStreak();
    if (newStreak != currentUser!.streak) {
      await _dbService.updateStreak(currentUser!.id, newStreak);
      await _maybeSendStreakMilestone(newStreak);
    }
  }

  static const _streakMilestones = {7, 14, 30, 60, 100};

  Future<void> _maybeSendStreakMilestone(int streak) async {
    if (currentUser == null) return;
    if (!_streakMilestones.contains(streak)) return;

    // OS banner (FR_902)
    if (currentUser!.streakAlertsNotif) {
      await NotificationService.showStreakMilestone(streak);
    }

    // Persistent in-app notification
    if (currentUser!.streakAlertsNotif) {
      await _dbService.addNotification(AppNotification(
        userId: currentUser!.id,
        type: 'streak_milestone',
        title: '$streak-Day Streak!',
        body: "You've logged $streak days in a row — amazing consistency!",
        createdAt: DateTime.now(),
      ));
    }
  }

  // ==========================================
  // TASK METHODS
  // ==========================================

  Future<void> addTask(String title, {String category = 'General', String? categoryIconKey, DateTime? dueDate, String? reminderTime, String repeatInterval = 'None'}) async {
    if (currentUser == null || title.isEmpty) return;

    final task = Task(
      id: '',
      userId: currentUser!.id,
      title: title,
      isCompleted: false,
      category: category,
      categoryIconKey: categoryIconKey,
      dueDate: dueDate,
      reminderTime: reminderTime,
      repeatInterval: repeatInterval,
    );

    final id = await _dbService.addTask(task);
    if (currentUser!.notificationsEnabled && reminderTime != null) {
      await NotificationService.scheduleTaskReminder(
          Task(id: id, userId: task.userId, title: task.title,
               dueDate: task.dueDate, reminderTime: task.reminderTime,
               repeatInterval: task.repeatInterval));
    }
  }

  Future<void> toggleTask(String id) async {
    final index = tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final newStatus = !tasks[index].isCompleted;
      await _dbService.toggleTask(id, newStatus);
      // Cancel the OS reminder when the task is marked complete
      if (newStatus) await NotificationService.cancelTaskReminder(id);
      // Completing a task advances the task streak; unchecking reverts it.
      if (currentUser != null) {
        final newTaskStreak = (currentUser!.taskStreak + (newStatus ? 1 : -1)).clamp(0, 9999);
        await _dbService.updateLeaderboardData(currentUser!.id, {'taskStreak': newTaskStreak});
      }
    }
  }

  Future<void> updateTask(Task task) async {
    if (task.id.isEmpty || task.title.trim().isEmpty) return;
    await _dbService.updateTask(task);
    // Re-schedule with updated fields (cancel old, schedule new if applicable)
    await NotificationService.cancelTaskReminder(task.id);
    if (currentUser?.notificationsEnabled == true && task.reminderTime != null) {
      await NotificationService.scheduleTaskReminder(task);
    }
  }

  Future<void> deleteTask(String id) async {
    await NotificationService.cancelTaskReminder(id);
    await _dbService.deleteTask(id);
  }

  Future<TaskCategory?> addTaskCategory(String name, String iconKey) async {
    final trimmedName = name.trim();
    if (currentUser == null || trimmedName.isEmpty) return null;

    final category = TaskCategory(
      id: '',
      userId: currentUser!.id,
      name: trimmedName,
      iconKey: iconKey,
    );
    final id = await _dbService.addTaskCategory(category);
    return TaskCategory(
      id: id,
      userId: category.userId,
      name: category.name,
      iconKey: category.iconKey,
    );
  }

  // ==========================================
  // SLEEP & MOOD LOG METHODS
  // ==========================================

  Future<void> addLog(LogEntry entry) async {
    if (currentUser == null) return;

    final databaseEntry = LogEntry(
      id: '',
      userId: currentUser!.id,
      date: entry.date,
      sleepHours: entry.sleepHours.clamp(0.0, 24.0),
      moodScore: entry.moodScore.clamp(1.0, 10.0),
      sleepQuality: entry.sleepQuality.clamp(0, 10),
      hadNightmare: entry.hadNightmare,
      notes: entry.notes,
      trigger: entry.trigger,
      emotions: entry.emotions,
    );

    await _dbService.addLogEntry(databaseEntry);

    // Mirror today's mood onto the public profile for friend circles.
    if (databaseEntry.moodScore > 0) {
      await _dbService.updateUserMood(
          currentUser!.id, databaseEntry.moodScore, User.todayDateString());
    }

    // Streak check
    await checkAndUpdateStreak();
  }

  Future<void> patchLog(String logId, Map<String, dynamic> fields) async {
    if (currentUser == null || logId.isEmpty) return;
    await _dbService.patchLogEntry(logId, fields);

    // Mirror today's mood onto the public profile for friend circles.
    if (fields.containsKey('moodScore')) {
      await _dbService.updateUserMood(currentUser!.id,
          (fields['moodScore'] as num).toDouble(), User.todayDateString());
    }

    await checkAndUpdateStreak();
  }

  Future<void> upsertModeLog(Map<String, dynamic> modeFields) async {
    if (currentUser == null) return;
    await _dbService.upsertModeLog(currentUser!.id, DateTime.now(), modeFields);
    await checkAndUpdateStreak();
  }

  Future<void> saveLogNote(DateTime date, String notes) async {
    if (currentUser == null) return;
    await _dbService.upsertModeLog(currentUser!.id, date, {'notes': notes});
  }

  // Full-field upsert for a specific day's journal entry (create or edit).
  // Unlike updateLog(), this doesn't require an existing document id — it
  // relies on upsertModeLog's deterministic {userId}_{date} doc id, so it
  // works whether the entry already exists or is being created for the first time.
  Future<void> saveLogFields(DateTime date, Map<String, dynamic> fields) async {
    if (currentUser == null) return;
    await _dbService.upsertModeLog(currentUser!.id, date, fields);

    final isToday = User.todayDateString() ==
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (isToday && fields.containsKey('moodScore')) {
      await _dbService.updateUserMood(currentUser!.id,
          (fields['moodScore'] as num).toDouble(), User.todayDateString());
    }

    await checkAndUpdateStreak();
  }

  Future<void> toggleLogSharing(LogEntry log) async {
    if (currentUser == null) return;
    await _dbService.upsertModeLog(
      currentUser!.id,
      log.date,
      {'isSharedWithFriends': !log.isSharedWithFriends},
    );
  }

  Future<void> updateLog(LogEntry entry) async {
    if (currentUser == null) return;

    final databaseEntry = LogEntry(
      id: entry.id,
      userId: currentUser!.id,
      date: entry.date,
      sleepHours: entry.sleepHours.clamp(0.0, 24.0),
      moodScore: entry.moodScore.clamp(1.0, 10.0),
      sleepQuality: entry.sleepQuality.clamp(0, 10),
      hadNightmare: entry.hadNightmare,
      notes: entry.notes,
      trigger: entry.trigger,
      emotions: entry.emotions,
    );

    await _dbService.updateLogEntry(databaseEntry);

    // Streak check
    await checkAndUpdateStreak();
  }

  // ==========================================
  // WATER INTAKE METHODS
  // ==========================================

  Future<void> addWaterIntake(int amount) async {
    if (currentUser == null) return;
    final today = User.todayDateString();
    if (currentUser!.waterIntakeDate != today) {
      // New day — reset to this amount (clamped to 0 for undo on a fresh day)
      await _dbService.setWaterIntake(currentUser!.id, amount.clamp(0, 99999), today);
    } else {
      await _dbService.updateWaterIntake(currentUser!.id, amount, today);
    }
  }

  Future<void> updateWaterGoal(int goal) async {
    if (currentUser != null) {
      await _dbService.updateWaterGoal(currentUser!.id, goal);
    }
  }

  // Set the recurring hydration-reminder interval (in minutes; 0 = off).
  // Persists the choice on the profile, requests OS permission when enabling,
  // and (re)arms the local notification via NotificationService.
  Future<void> setHydrationReminder(int minutes) async {
    if (currentUser == null) return;
    currentUser!.hydrationReminderMinutes = minutes;
    notifyListeners();
    await _dbService
        .updateLeaderboardData(currentUser!.id, {'hydrationReminderMinutes': minutes});
    if (minutes > 0) {
      await NotificationService.requestPermission();
    }
    await NotificationService.scheduleHydrationReminder(minutes);
  }

  // ==========================================
  // COMMUNITY METHODS (FR_502 / FR_503)
  // ==========================================

  Future<void> sendFriendRequest(String toUsername) async {
    if (currentUser == null) return;
    await _dbService.sendFriendRequest(currentUser!, toUsername);
  }

  Future<void> respondToRequest(String requestId, String fromId, bool accept) async {
    if (currentUser == null) return;
    await _dbService.respondToFriendRequest(requestId, fromId, currentUser!.id, accept);
    // FR_903: notify the sender that their request was accepted
    if (accept) {
      await _dbService.addNotification(AppNotification(
        userId: fromId,
        type: 'friend_accepted',
        title: 'Friend Request Accepted',
        body: '${currentUser!.username} accepted your friend request!',
        createdAt: DateTime.now(),
      ));
    }
  }

  // ==========================================
  // NOTIFICATION METHODS (FR_901–FR_904)
  // ==========================================

  Future<void> markNotificationRead(String notifId) async {
    await _dbService.markNotificationRead(notifId);
  }

  Future<void> markAllNotificationsRead() async {
    if (currentUser == null) return;
    await _dbService.markAllNotificationsRead(currentUser!.id);
  }

  Future<void> updateNotificationPrefs({
    bool? notificationsEnabled,
    bool? friendActivityNotif,
    bool? streakAlertsNotif,
  }) async {
    if (currentUser == null) return;
    final updates = <String, dynamic>{};
    if (notificationsEnabled != null) {
      updates['notificationsEnabled'] = notificationsEnabled;
    }
    if (friendActivityNotif != null) {
      updates['friendActivityNotif'] = friendActivityNotif;
    }
    if (streakAlertsNotif != null) {
      updates['streakAlertsNotif'] = streakAlertsNotif;
    }
    if (updates.isEmpty) return;
    // Request OS permission when the master toggle is turned on
    if (notificationsEnabled == true) {
      await NotificationService.requestPermission();
    }
    await _dbService.updateLeaderboardData(currentUser!.id, updates);
  }

  // ==========================================
  // PROFILE METHODS
  // ==========================================

  Future<void> uploadProfilePhoto(File imageFile) async {
    if (currentUser != null) {
      final url = await _dbService.uploadProfilePhoto(imageFile, currentUser!.id);
      currentUser!.avatarUrl = url;
      await _dbService.saveUserProfile(currentUser!);
      notifyListeners();
    }
  }

  // Uploads a photo for a journal entry and returns its download URL. The caller
  // is responsible for persisting the URL onto the log (via saveLogFields).
  Future<String> uploadJournalPhoto(File imageFile, DateTime date) async {
    if (currentUser == null) return '';
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _dbService.uploadJournalPhoto(imageFile, currentUser!.id, dateKey);
  }

  // ==========================================
  // COMPUTED PROPERTIES (Progress Reports)
  // ==========================================

  double get averageMood {
    if (logs.isEmpty) return 0.0;
    return logs.map((l) => l.moodScore).reduce((a, b) => a + b) / logs.length;
  }

  double get averageSleep {
    if (logs.isEmpty) return 0.0;
    return logs.map((l) => l.sleepHours).reduce((a, b) => a + b) / logs.length;
  }

  double get taskCompletionRate {
    if (tasks.isEmpty) return 0.0;
    final completed = tasks.where((t) => t.isCompleted).length;
    return completed / tasks.length;
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
