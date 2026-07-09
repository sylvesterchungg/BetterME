import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pedometer/pedometer.dart';
import '../models/models.dart';
import '../services/database_service.dart';

class AppProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? currentUser;
  List<Task> tasks = [];
  List<TaskCategory> taskCategories = [];
  List<LogEntry> logs = [];
  List<User> friends = []; // Dynamic friends
  List<LogEntry> friendsSharedLogs = [];
  List<FriendRequest> incomingRequests = [];
  List<ProductivityRecord> productivityRecords = [];

  // Friends-only leaderboard: the current user is ranked against the friends
  // they've actually added/accepted — you must be friends to see someone's
  // score/streak here. Computed from `currentUser` + `friends` (both kept live
  // by their streams), sorted by score descending.
  List<User> get leaderboard {
    final list = <User>[
      ?currentUser,
      ...friends,
    ];
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }

  // The current user's rank within the friends-only leaderboard (1-based).
  int get myLeaderboardRank {
    if (currentUser == null) return 0;
    final idx = leaderboard.indexWhere((u) => u.id == currentUser!.id);
    return idx >= 0 ? idx + 1 : 0;
  }

  // Pedometer State
  int currentSteps = 0;
  StreamSubscription<StepCount>? _stepCountStream;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusStream;

  // Active Stream Subscriptions
  StreamSubscription? _userSub;
  StreamSubscription? _tasksSub;
  StreamSubscription? _taskCategoriesSub;
  StreamSubscription? _logsSub;
  StreamSubscription? _friendsSub;
  StreamSubscription? _friendsLogsSub;
  StreamSubscription? _productivitySub;
  StreamSubscription? _requestsSub;

  // Skip first task-stream emission (initial load); only save on user changes
  bool _tasksInitialized = false;

  AppProvider() {
    _initAuthListener();
    _initPedometer();
  }

  void _initPedometer() {
    try {
      _stepCountStream = Pedometer.stepCountStream.listen((StepCount event) {
        currentSteps = event.steps;
        notifyListeners();
      }, onError: (error) {
        debugPrint("Pedometer error: $error");
      });
    } catch (e) {
      debugPrint("Failed to initialize pedometer: $e");
    }
  }

  // Listen to Firebase Auth state changes
  void _initAuthListener() {
    _auth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser == null) {
        _cancelSubscriptions();
        currentUser = null;
        tasks = [];
        taskCategories = [];
        logs = [];
        friends = [];
        friendsSharedLogs = [];
        incomingRequests = [];
        productivityRecords = [];
        _tasksInitialized = false;
        notifyListeners();
      } else {
        await _loadOrCreateProfile(firebaseUser);
      }
    });
  }

  Future<void> _loadOrCreateProfile(firebase_auth.User firebaseUser) async {
    final userId = firebaseUser.uid;
    var profile = await _dbService.getUserProfile(userId);
    
    if (profile == null) {
      profile = User(
        id: userId,
        username: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User',
        avatarUrl: firebaseUser.photoURL ?? 'https://i.pravatar.cc/150?img=${userId.hashCode % 70 + 1}',
        streak: 1,
        score: 100,
        waterIntake: 0,
        friendsIds: [],
      );
      await _dbService.saveUserProfile(profile);
    }
    
    currentUser = profile;
    _initUserListeners(userId);
    notifyListeners();
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

    // 2. Listen to User's Tasks — save productivity snapshot on every change after initial load
    _tasksInitialized = false;
    _tasksSub = _dbService.streamTasks(userId).listen((newTasks) {
      tasks = newTasks;
      if (!_tasksInitialized) {
        _tasksInitialized = true;
      } else {
        _saveProductivityRecord(userId);
      }
      notifyListeners();
      _checkAndHandleOverdueTasks();
    }, onError: (e) => debugPrint('[Firestore] tasks stream error: $e'));

    _taskCategoriesSub = _dbService.streamTaskCategories(userId).listen((newCategories) {
      taskCategories = newCategories;
      notifyListeners();
    }, onError: (e) => debugPrint('[Firestore] taskCategories stream error: $e'));

    // 3. Listen to User's Logs (Sleep, Mood, Notes, Triggers)
    _logsSub = _dbService.streamLogEntries(userId).listen((newLogs) {
      logs = newLogs;
      notifyListeners();
      _recomputeLeaderboardScores();
    }, onError: (e) => debugPrint('[Firestore] logs stream error: $e'));

    // 4. Leaderboard is friends-only and derived from `currentUser` + `friends`
    //    (both kept live by the streams above), so no separate query is needed.

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
  }

  // Detect incomplete tasks past their due date; reset both streaks if found.
  void _checkAndHandleOverdueTasks() {
    if (currentUser == null || tasks.isEmpty) return;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final hasOverdue = tasks.any(
      (t) => !t.isCompleted && t.dueDate != null && t.dueDate!.isBefore(todayStart),
    );
    if (hasOverdue && (currentUser!.taskStreak > 0 || currentUser!.streak > 1)) {
      _dbService.updateLeaderboardData(currentUser!.id, {
        'taskStreak': 0,
        'streak': 1,
      });
      _recomputeLeaderboardScores();
    }
  }

  // Recompute mood/sleep leaderboard scores and overall score from current logs.
  void _recomputeLeaderboardScores() {
    if (currentUser == null) return;
    final moodLogs = logs.where((l) => l.moodScore > 0).toList();
    final sleepLogs = logs.where((l) => l.sleepQuality > 0).toList();
    final moodScore = moodLogs.isEmpty
        ? 0.0
        : moodLogs.map((l) => l.moodScore).reduce((a, b) => a + b) / moodLogs.length;
    final sleepScore = sleepLogs.isEmpty
        ? 0.0
        : sleepLogs.map((l) => l.sleepQuality.toDouble()).reduce((a, b) => a + b) / sleepLogs.length;
    final taskPts = currentUser!.taskStreak;
    final overall = (moodScore * 10 + sleepScore * 10 + taskPts).round();
    _dbService.updateLeaderboardData(currentUser!.id, {
      'moodLeaderboardScore': moodScore,
      'sleepLeaderboardScore': sleepScore,
      'score': overall,
    });
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

  Future<void> registerWithEmail(String email, String password, String username) async {
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

  Future<void> checkAndUpdateStreak() async {
    if (currentUser == null) return;
    
    if (logs.isEmpty) {
      // First log ever, streak is 1
      await _dbService.updateStreak(currentUser!.id, 1);
      return;
    }

    // Since logs are streamed ordered by date descending, logs[0] might be the one we just added if it's already in the stream.
    // However, if checkAndUpdateStreak is called immediately after addLog (before stream updates), 
    // logs[0] is the PREVIOUS log. Wait, we should just check the most recent log's date in `logs` before the new one is added, 
    // or just calculate based on all logs.
    // Let's sort logs locally just in case, but they should be sorted.
    // Wait, if it's called AFTER `addLog` finishes, the new log might already be in the stream.
    // To be safe, let's find the most recent log that is NOT today.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    // Find logs from yesterday
    bool loggedYesterday = logs.any((log) {
      final d = DateTime(log.date.year, log.date.month, log.date.day);
      return d.isAtSameMomentAs(yesterday);
    });

    // Find logs from today
    bool loggedToday = logs.any((log) {
      final d = DateTime(log.date.year, log.date.month, log.date.day);
      return d.isAtSameMomentAs(today);
    });

    // If we haven't logged today yet (meaning this call is about to log today, or evaluating),
    // and we logged yesterday, streak goes up. 
    // If we already logged today, streak stays the same (no increment).
    // If we didn't log yesterday or today, streak resets to 1.
    int newStreak = currentUser!.streak;
    
    if (loggedYesterday && !loggedToday) {
      newStreak += 1;
    } else if (!loggedYesterday && !loggedToday) {
      newStreak = 1;
    }
    // If loggedToday is true, we don't change the streak.

    if (newStreak != currentUser!.streak) {
      await _dbService.updateStreak(currentUser!.id, newStreak);
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

    await _dbService.addTask(task);
  }

  Future<void> toggleTask(String id) async {
    final index = tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final newStatus = !tasks[index].isCompleted;
      await _dbService.toggleTask(id, newStatus);
      // Completing a task advances the task streak; unchecking reverts it.
      if (currentUser != null) {
        final newTaskStreak = (currentUser!.taskStreak + (newStatus ? 1 : -1)).clamp(0, 9999);
        await _dbService.updateLeaderboardData(currentUser!.id, {'taskStreak': newTaskStreak});
        _recomputeLeaderboardScores();
      }
    }
  }

  Future<void> updateTask(Task task) async {
    if (task.id.isEmpty || task.title.trim().isEmpty) return;
    await _dbService.updateTask(task);
  }

  Future<void> deleteTask(String id) async {
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
    _stepCountStream?.cancel();
    _pedestrianStatusStream?.cancel();
    super.dispose();
  }
}
