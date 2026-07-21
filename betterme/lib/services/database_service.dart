import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import '../models/models.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==========================================
  // USER PROFILE OPERATIONS
  // ==========================================

  // Save or update user profile
  Future<void> saveUserProfile(User user) async {
    await _db.collection('users').doc(user.id).set(user.toMap(), SetOptions(merge: true));
  }

  // Get user profile
  Future<User?> getUserProfile(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (doc.exists && doc.data() != null) {
      return User.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // Upload profile photo
  Future<String> uploadProfilePhoto(File imageFile, String userId) async {
    final storageRef = FirebaseStorage.instance.ref().child('avatars').child('$userId.jpg');
    final uploadTask = storageRef.putFile(imageFile);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Upload a journal entry photo. One photo per user per day (deterministic path
  // so re-uploading replaces the previous image).
  Future<String> uploadJournalPhoto(File imageFile, String userId, String dateKey) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('journal_photos')
        .child(userId)
        .child('$dateKey.jpg');
    final snapshot = await storageRef.putFile(imageFile);
    return await snapshot.ref.getDownloadURL();
  }

  // Stream user profile for real-time updates
  Stream<User?> streamUserProfile(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return User.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  Future<void> updateStreak(String userId, int newStreak) async {
    await _db.collection('users').doc(userId).update({'streak': newStreak});
  }

  Future<void> updateLeaderboardData(String userId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).update(data);
  }

  // Denormalize today's mood onto the user's public profile so friends can see
  // it in the friend circles without reading the owner-only `logs` collection.
  Future<void> updateUserMood(String userId, double moodScore, String dateStr) async {
    await _db.collection('users').doc(userId).update({
      'moodScore': moodScore,
      'moodDate': dateStr,
    });
  }

  // ==========================================
  // TASK OPERATIONS
  // ==========================================

  // Add a task
  Future<String> addTask(Task task) async {
    final docRef = await _db.collection('tasks').add(task.toMap());
    return docRef.id;
  }

  // Get tasks as a real-time stream
  Stream<List<Task>> streamTasks(String userId) {
    return _db
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Task.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Toggle task completion
  Future<void> toggleTask(String taskId, bool isCompleted) async {
    await _db.collection('tasks').doc(taskId).update({
      'isCompleted': isCompleted,
    });
  }

  // Update task fields
  Future<void> updateTask(Task task) async {
    await _db.collection('tasks').doc(task.id).update(task.toMap());
  }

  // Delete task
  Future<void> deleteTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).delete();
  }

  Future<String> addTaskCategory(TaskCategory category) async {
    final docRef = await _db.collection('taskCategories').add(category.toMap());
    return docRef.id;
  }

  Stream<List<TaskCategory>> streamTaskCategories(String userId) {
    return _db
        .collection('taskCategories')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TaskCategory.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ==========================================
  // SLEEP LOG & MOOD LOG OPERATIONS
  // ==========================================

  // Add a mood & sleep log entry
  Future<String> addLogEntry(LogEntry entry) async {
    final docRef = await _db.collection('logs').add(entry.toMap());
    return docRef.id;
  }

  // Update a mood & sleep log entry (full overwrite)
  Future<void> updateLogEntry(LogEntry entry) async {
    await _db.collection('logs').doc(entry.id).update(entry.toMap());
  }

  // Patch specific fields on an existing log document (used to update mood or sleep independently)
  Future<void> patchLogEntry(String logId, Map<String, dynamic> fields) async {
    await _db.collection('logs').doc(logId).update(fields);
  }

  // Upsert mood or sleep fields using a deterministic doc ID ({userId}_{YYYY-MM-DD}).
  // set+merge creates the doc on first write and updates only the supplied fields on
  // subsequent writes — the other mode's data is physically untouched.
  Future<void> upsertModeLog(String userId, DateTime date, Map<String, dynamic> modeFields) async {
    final d = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final docId = '${userId}_$d';
    await _db.collection('logs').doc(docId).set(
      {'userId': userId, 'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)), ...modeFields},
      SetOptions(merge: true),
    );
  }

  // Stream logs for progressive reports and charts
  Stream<List<LogEntry>> streamLogEntries(String userId) {
    return _db
        .collection('logs')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LogEntry.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Stream shared log entries from a user's friends (up to 10 friend IDs).
  // The isSharedWithFriends == true filter MUST be part of the query (not just
  // client-side): the security rule only allows reading a friend's log when it
  // is shared, and Firestore rules are not filters — an unconstrained query
  // would be rejected wholesale. Requires the composite index in
  // firestore.indexes.json (isSharedWithFriends + userId). Sorted client-side.
  Stream<List<LogEntry>> streamFriendsSharedLogs(List<String> friendIds) {
    if (friendIds.isEmpty) return Stream.value([]);
    final ids = friendIds.take(10).toList();
    return _db
        .collection('logs')
        .where('userId', whereIn: ids)
        .where('isSharedWithFriends', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final result = snap.docs
          .map((d) => LogEntry.fromMap(d.data(), d.id))
          .toList();
      result.sort((a, b) => b.date.compareTo(a.date));
      return result;
    });
  }



  // ==========================================
  // WATER INTAKE OPERATIONS
  // ==========================================

  Future<void> updateWaterIntake(String userId, int amount, String dateStr) async {
    await _db.collection('users').doc(userId).update({
      'waterIntake': FieldValue.increment(amount),
      'waterIntakeDate': dateStr,
    });
  }

  Future<void> setWaterIntake(String userId, int amount, String dateStr) async {
    await _db.collection('users').doc(userId).update({
      'waterIntake': amount.clamp(0, 99999),
      'waterIntakeDate': dateStr,
    });
  }

  Future<void> updateWaterGoal(String userId, int goal) async {
    await _db.collection('users').doc(userId).update({'waterGoal': goal});
  }

  // ==========================================
  // COMMUNITY OPERATIONS
  // ==========================================

  // ==========================================
  // FRIEND REQUEST OPERATIONS (FR_502 / FR_503)
  // ==========================================

  // Send a friend request by username; throws descriptive exceptions on failure
  Future<void> sendFriendRequest(User fromUser, String toUsername) async {
    // 1. Find target user by username
    final snap = await _db
        .collection('users')
        .where('username', isEqualTo: toUsername)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) throw Exception('User not found');

    final toDoc = snap.docs.first;
    final toId = toDoc.id;

    if (toId == fromUser.id) throw Exception('Cannot add yourself');

    // 2. Already friends?
    if (fromUser.friendsIds.contains(toId)) throw Exception('Already friends');

    // 3. Duplicate pending request?
    final existing = await _db
        .collection('friendRequests')
        .where('fromId', isEqualTo: fromUser.id)
        .where('toId', isEqualTo: toId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) throw Exception('Request already sent');

    // 4. Create the request
    final request = FriendRequest(
      fromId: fromUser.id,
      fromUsername: fromUser.username,
      fromAvatarUrl: fromUser.avatarUrl,
      toId: toId,
    );
    await _db.collection('friendRequests').add(request.toMap());
  }

  // Stream incoming pending requests for the current user
  Stream<List<FriendRequest>> streamIncomingRequests(String userId) {
    return _db
        .collection('friendRequests')
        .where('toId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FriendRequest.fromMap(d.data(), d.id))
            .toList());
  }

  // Accept or reject a friend request
  Future<void> respondToFriendRequest(
    String requestId,
    String fromId,
    String toId,
    bool accept,
  ) async {
    if (accept) {
      // Mutual add
      final batch = _db.batch();
      batch.update(_db.collection('users').doc(toId), {
        'friendsIds': FieldValue.arrayUnion([fromId]),
      });
      batch.update(_db.collection('users').doc(fromId), {
        'friendsIds': FieldValue.arrayUnion([toId]),
      });
      batch.update(_db.collection('friendRequests').doc(requestId), {
        'status': 'accepted',
      });
      await batch.commit();
    } else {
      await _db
          .collection('friendRequests')
          .doc(requestId)
          .update({'status': 'rejected'});
    }
  }

  Stream<List<User>> streamFriends(List<String> friendIds) {
    if (friendIds.isEmpty) return Stream.value([]);
    
    // Firestore 'whereIn' limits to 10 elements. Assuming a small list for now.
    // For larger lists, we'd query them individually and combine streams.
    final limitedIds = friendIds.take(10).toList();
    
    return _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: limitedIds)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => User.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ==========================================
  // NOTIFICATION OPERATIONS (FR_902, FR_903)
  // ==========================================

  Future<void> addNotification(AppNotification notif) async {
    await _db.collection('notifications').add(notif.toMap());
  }

  Stream<List<AppNotification>> streamNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppNotification.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> markNotificationRead(String notifId) async {
    await _db.collection('notifications').doc(notifId).update({'isRead': true});
  }

  Future<void> markAllNotificationsRead(String userId) async {
    final snap = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ==========================================
  // PRODUCTIVITY OPERATIONS
  // ==========================================

  // Upsert today's productivity record using a deterministic doc ID
  Future<void> saveProductivityRecord(ProductivityRecord record) async {
    final docId = '${record.userId}_${record.date}';
    await _db.collection('productivity').doc(docId).set(
      record.toMap(),
      SetOptions(merge: true),
    );
  }

  // Stream all productivity records for a user, sorted by date ascending
  Stream<List<ProductivityRecord>> streamProductivityRecords(String userId) {
    return _db
        .collection('productivity')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs
          .map((doc) => ProductivityRecord.fromMap(doc.data(), doc.id))
          .toList();
      records.sort((a, b) => a.date.compareTo(b.date));
      return records;
    });
  }

  // ==========================================
  // AI INSIGHT CACHE
  // ==========================================
  // Client-side cache (no Cloud Function): the most recent AI insight is stored
  // per user so the dashboard loads instantly and Gemini is only called when the
  // user's recent data changes. One doc per user: `${userId}_latest`.

  Future<void> saveInsight(String userId, AIInsight insight) async {
    await _db.collection('insights').doc('${userId}_latest').set(
      {'userId': userId, ...insight.toMap()},
      SetOptions(merge: true),
    );
  }

  Future<AIInsight?> getCachedInsight(String userId) async {
    final doc = await _db.collection('insights').doc('${userId}_latest').get();
    final data = doc.data();
    if (data == null) return null;
    return AIInsight.fromMap(data);
  }
}
