import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/ai_insight_service.dart';
import '../services/notification_service.dart';
import '../utils/image_helpers.dart';
import '../utils/stats.dart';
import '../utils/stream_error_tracker.dart';

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
  // their streams), sorted by streak descending (FR_604 / LeaderboardEntry),
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

  // The friendsIds the friends/friends-logs streams were last built for. The
  // user doc changes often (streak ticks, mood mirror, water intake), so we
  // only tear down and rebuild those two streams when friendsIds truly changes.
  List<String>? _friendsIdsForSubs;

  // Which listeners are currently failing. Without this, a stream error was
  // only ever debugPrinted: the affected data silently froze at its last value
  // with nothing in the interface to say so.
  final StreamErrorTracker _streamErrors = StreamErrorTracker();

  bool get hasStreamError => _streamErrors.hasError;
  String get streamErrorSummary => _streamErrors.summary;
  List<String> get failedStreams => _streamErrors.failedStreams;

  /// Records a listener failure. Rebuilds only when the error is new — a
  /// broken listener re-emits the same error repeatedly.
  void _onStreamError(String stream, Object error) {
    debugPrint('[Firestore] $stream stream error: $error');
    if (_streamErrors.record(stream, error)) notifyListeners();
  }

  /// Marks [stream] healthy after a successful emission. Deliberately does not
  /// notify on its own — every caller already calls notifyListeners() with the
  /// new data, and clearing is a no-op on a healthy stream anyway.
  void _onStreamData(String stream) => _streamErrors.clear(stream);

  /// Re-subscribes every listener after a failure. Safe at any time —
  /// [_initUserListeners] cancels the existing subscriptions first.
  void retryStreams() {
    final userId = currentUser?.id ?? _auth.currentUser?.uid;
    if (userId == null) return;
    _streamErrors.clearAll();
    notifyListeners();
    _initUserListeners(userId);
  }


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

      // Encode the sign-up photo (if any) as base64 for the profile doc — the
      // free Spark plan has no Cloud Storage, so images live in Firestore. A
      // real Google photo is the fallback; otherwise blank, so the UI shows the
      // user's initials/person-icon default instead of a stock face.
      var avatarUrl = firebaseUser.photoURL ?? '';
      final pendingPhoto = extras?['photo'];
      if (pendingPhoto is File) {
        try {
          final encoded = await fileToBase64(pendingPhoto);
          if (encoded != null) avatarUrl = encoded;
        } catch (e) {
          debugPrint('[Signup] avatar encode failed: $e');
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
    // Same for the daily logging reminder (FR_905). The logs stream refines this
    // as soon as it emits — this call just makes sure a reminder exists even if
    // that stream is slow or errors.
    _syncLogReminder();
  }

  // Initialize listeners for logged-in user
  void _initUserListeners(String userId) {
    _cancelSubscriptions();

    // 1. Listen to User Profile changes
    _userSub = _dbService.streamUserProfile(userId).listen((user) {
      _onStreamData('profile');
      currentUser = user;

      // Only (re)build the friends streams when friendsIds actually changed —
      // rebuilding on every user-doc emission churns two Firestore listeners
      // needlessly (and bills the reads) on every streak/mood/water update.
      if (user != null && !listEquals(_friendsIdsForSubs, user.friendsIds)) {
        _friendsIdsForSubs = List<String>.from(user.friendsIds);

        _friendsSub?.cancel();
        _friendsSub = _dbService.streamFriends(user.friendsIds).listen((friendList) {
          _onStreamData('friends');
          friends = friendList;
          notifyListeners();
        }, onError: (e) => _onStreamError('friends', e));

        _friendsLogsSub?.cancel();
        _friendsLogsSub = _dbService.streamFriendsSharedLogs(user.friendsIds).listen((sharedLogs) {
          _onStreamData('friend activity');
          friendsSharedLogs = sharedLogs;
          notifyListeners();
        }, onError: (e) => _onStreamError('friend activity', e));
      }
      notifyListeners();
    }, onError: (e) => _onStreamError('profile', e));

    // 2. Listen to User's Tasks — save a productivity snapshot (scoped to today's
    // due tasks, see _saveProductivityRecord) on every emission including the
    // initial load, so today has an up-to-date record as soon as anything about
    // the task list changes.
    _tasksSub = _dbService.streamTasks(userId).listen((newTasks) {
      _onStreamData('tasks');
      tasks = newTasks;
      _saveProductivityRecord(userId);
      notifyListeners();
      _checkAndHandleOverdueTasks();
    }, onError: (e) => _onStreamError('tasks', e));

    _taskCategoriesSub = _dbService.streamTaskCategories(userId).listen((newCategories) {
      _onStreamData('categories');
      taskCategories = newCategories;
      notifyListeners();
    }, onError: (e) => _onStreamError('categories', e));

    // 3. Listen to User's Logs (Sleep, Mood, Notes, Triggers)
    //    The daily-log streak is derived purely from these dates, so recompute
    //    it on every emission (including the initial load — this is what resets
    //    a broken streak to 0 when the app is reopened after a missed day).
    _logsSub = _dbService.streamLogEntries(userId).listen((newLogs) {
      _onStreamData('logs');
      logs = newLogs;
      notifyListeners();
      checkAndUpdateStreak();
      // Re-arm the daily logging reminder against the new log set, so logging
      // today immediately pushes tonight's nudge out to tomorrow (FR_905).
      _syncLogReminder();
    }, onError: (e) => _onStreamError('logs', e));

    // 4. Leaderboard is friends-only and derived from `currentUser` + `friends`
    //    (both kept live by the streams above), so no separate query is needed.

    // 4b. Listen to the owner-only private profile (birth date, phone).
    _privateProfileSub =
        _dbService.streamPrivateProfile(userId).listen((profile) {
      _onStreamData('personal details');
      privateProfile = profile;
      notifyListeners();
    }, onError: (e) => _onStreamError('personal details', e));

    // 5. Listen to Productivity Records
    _productivitySub = _dbService.streamProductivityRecords(userId).listen((records) {
      _onStreamData('productivity');
      productivityRecords = records;
      notifyListeners();
    }, onError: (e) => _onStreamError('productivity', e));

    // 6. Listen to Incoming Friend Requests (FR_601 / FR_602)
    _requestsSub = _dbService.streamIncomingRequests(userId).listen((requests) {
      _onStreamData('friend requests');
      incomingRequests = requests;
      notifyListeners();
    }, onError: (e) => _onStreamError('friend requests', e));

    // 7. Listen to In-App Notifications (FR_904)
    _notificationsSub =
        _dbService.streamNotifications(userId).listen((notifList) {
      _onStreamData('notifications');
      notifications = notifList;
      notifyListeners();
    }, onError: (e) => _onStreamError('notifications', e));

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
    // Consent gate (FR_1004-equivalent): null (never asked) or false
    // (declined/turned off) both mean no data leaves the device.
    if (currentUser!.aiInsightsEnabled != true) return;
    final latest = _latestRelevantLog();
    final sig =
        AIInsightService.nudgeSignatureFor(latest, streak: currentUser?.streak);
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
    // Force the friends streams to rebuild on the next login/user switch.
    _friendsIdsForSubs = null;
    // Don't carry the previous session's failures into the next one.
    _streamErrors.clearAll();
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
    // Scoped to tasks actually DUE today, not the user's whole task list —
    // using the full list here made every day's "daily" record really just
    // a slow-moving all-time completion rate re-saved under today's date,
    // which flattens the 14-day trend chart into a lifetime average instead
    // of a real day-by-day signal (see NFR_007 known gap).
    final now = DateTime.now();
    final dueToday = tasks.where((t) =>
        t.dueDate != null &&
        t.dueDate!.year == now.year &&
        t.dueDate!.month == now.month &&
        t.dueDate!.day == now.day);
    final total = dueToday.length;
    // Nothing due today: leave a gap rather than writing a misleading 0% —
    // the trends chart already renders missing days as "no data".
    if (total == 0) return;
    final completed = dueToday.where((t) => t.isCompleted).length;
    final rate = completed / total;
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
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (credential.user != null) {
        await credential.user!.updateDisplayName(username);
        // Wait for authStateChanges listener to pick up the new user and create the profile
      }
    } catch (e) {
      // Registration didn't complete — clear the stash so these extras (name,
      // phone, birth date, photo) can't leak onto a later, unrelated sign-in
      // (e.g. the user retries with Google and gets a brand-new profile).
      _pendingProfileExtras = null;
      rethrow;
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
      // Targeted field update, not a full-object saveUserProfile() — the
      // cached currentUser can be stale on fields another session just
      // changed (friendsIds via a friend-accept, streak, mood, water); a
      // full merge:true write of the whole object would silently revert
      // those concurrent server-side changes back to the stale local value.
      await _dbService.updateLeaderboardData(currentUser!.id, {'username': newName});
      if (_auth.currentUser != null) {
        await _auth.currentUser!.updateDisplayName(newName);
      }
    }
  }

  /// Update the user's real/display name on the public profile.
  Future<void> updateName(String newName) async {
    if (currentUser == null) return;
    final trimmed = newName.trim();
    currentUser!.name = trimmed;
    notifyListeners();
    await _dbService.updateLeaderboardData(currentUser!.id, {'name': trimmed});
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
  int _computeLogStreak() => computeLogStreak(logs.map((l) => l.date));

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

    // OS banner (FR_804)
    if (currentUser!.streakAlertsNotif) {
      // Other notification paths (task/hydration reminders) request OS
      // permission right before firing; this one didn't, so on a device
      // that never triggered those paths the banner was silently dropped.
      await NotificationService.requestPermission();
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
      // Make sure the OS notification permission is granted before scheduling,
      // otherwise the reminder is silently dropped.
      await NotificationService.requestPermission();
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
      // FieldValue.increment(), not a client-computed absolute value — two
      // rapid toggles before the profile stream catches up would otherwise
      // both read the same stale base and lose one of the two updates.
      if (currentUser != null) {
        final delta = newStatus ? 1 : -1;
        currentUser!.taskStreak = (currentUser!.taskStreak + delta).clamp(0, 9999);
        notifyListeners();
        await _dbService.updateLeaderboardData(
            currentUser!.id, {'taskStreak': FieldValue.increment(delta)});
      }
    }
  }

  Future<void> updateTask(Task task) async {
    if (task.id.isEmpty || task.title.trim().isEmpty) return;
    await _dbService.updateTask(task);
    // Re-schedule with updated fields (cancel old, schedule new if applicable)
    await NotificationService.cancelTaskReminder(task.id);
    if (currentUser?.notificationsEnabled == true && task.reminderTime != null) {
      await NotificationService.requestPermission();
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
    // Bound the magnitude of a single add/undo so a bad input (or a stray
    // extra digit) can't push the stored total to an absurd value — this is
    // a per-call clamp, not a total clamp, because the same-day path uses
    // FieldValue.increment() and doesn't know the running total client-side.
    final safeAmount = amount.clamp(-20000, 20000);
    final today = User.todayDateString();
    if (currentUser!.waterIntakeDate != today) {
      // New day — reset to this amount (clamped to 0 for undo on a fresh day)
      await _dbService.setWaterIntake(currentUser!.id, safeAmount.clamp(0, 99999), today);
    } else {
      await _dbService.updateWaterIntake(currentUser!.id, safeAmount, today);
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

  // True when today already has a log entry. Drives the FR_905 reminder, which
  // exists to reach users who have *not* logged.
  bool get hasLoggedToday {
    final now = DateTime.now();
    return logs.any((l) =>
        l.date.year == now.year &&
        l.date.month == now.month &&
        l.date.day == now.day);
  }

  // (Re)arm the daily logging reminder against current state. Called on login,
  // on every logs-stream emission, and when the user changes the time — so the
  // schedule always reflects whether today has been logged.
  void _syncLogReminder() {
    final minutes = currentUser?.logReminderMinutes ?? -1;
    if (minutes < 0) {
      NotificationService.cancelLogReminder();
      return;
    }
    NotificationService.scheduleLogReminder(minutes, skipToday: hasLoggedToday);
  }

  // Set the daily logging-reminder time (minutes from midnight; -1 = off).
  // Persists the choice, requests OS permission when enabling, and re-arms the
  // local notification (FR_905).
  Future<void> setLogReminder(int minutesFromMidnight) async {
    if (currentUser == null) return;
    currentUser!.logReminderMinutes = minutesFromMidnight;
    notifyListeners();
    await _dbService.updateLeaderboardData(
        currentUser!.id, {'logReminderMinutes': minutesFromMidnight});
    if (minutesFromMidnight >= 0) {
      await NotificationService.requestPermission();
    }
    _syncLogReminder();
  }

  // ==========================================
  // COMMUNITY METHODS (FR_601 / FR_602)
  // ==========================================

  Future<void> sendFriendRequest(String toUsername) async {
    if (currentUser == null) return;
    await _dbService.sendFriendRequest(currentUser!, toUsername);
  }

  Future<void> respondToRequest(String requestId, String fromId, bool accept) async {
    if (currentUser == null) return;
    await _dbService.respondToFriendRequest(requestId, fromId, currentUser!.id, accept);
    // FR_602 / FR_904: notify the sender that their request was accepted
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

  /// FR_1004-equivalent consent gate. `null` = never asked, `false` =
  /// declined/turned off, `true` = consented — AI insights/coping/morning-nudge
  /// generation all check this before sending any data to Gemini.
  Future<void> setAiInsightsEnabled(bool enabled) async {
    if (currentUser == null) return;
    currentUser!.aiInsightsEnabled = enabled;
    notifyListeners();
    await _dbService.updateLeaderboardData(
        currentUser!.id, {'aiInsightsEnabled': enabled});
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

  /// Sets the profile photo from a picked (already-resized) image, storing it as
  /// base64 on the profile doc — no Firebase Storage. Returns false if the image
  /// is too large to fit in a Firestore document, true on success.
  Future<bool> uploadProfilePhoto(File imageFile) async {
    if (currentUser == null) return false;
    final encoded = await fileToBase64(imageFile);
    if (encoded == null) return false;
    currentUser!.avatarUrl = encoded;
    notifyListeners();
    // Targeted field update — see updateUsername() for why not saveUserProfile().
    await _dbService.updateLeaderboardData(currentUser!.id, {'avatarUrl': encoded});
    return true;
  }

  // ==========================================
  // COMPUTED PROPERTIES (Progress Reports)
  // ==========================================

  // Averages exclude "no data" days: because mood and sleep are logged
  // independently, a mood-only day stores sleepHours == 0 and a sleep-only day
  // stores moodScore == 0. Counting those zeros would drag the mean down (and
  // disagree with the Trends screen, which already ignores them).
  double get averageMood => meanIgnoringZero(logs.map((l) => l.moodScore));

  double get averageSleep => meanIgnoringZero(logs.map((l) => l.sleepHours));

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
