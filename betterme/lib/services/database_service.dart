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

  Future<void> addFriend(String currentUserId, String friendUsername) async {
    // 1. Find the friend by username
    final snapshot = await _db
        .collection('users')
        .where('username', isEqualTo: friendUsername)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final friendId = snapshot.docs.first.id;
      
      // 2. Add friendId to current user's friendsIds list
      await _db.collection('users').doc(currentUserId).update({
        'friendsIds': FieldValue.arrayUnion([friendId])
      });
    } else {
      throw Exception('User not found');
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
  // LEADERBOARD OPERATION
  // ==========================================

  // Stream top users ranked by score
  Stream<List<User>> streamLeaderboard({int limit = 10}) {
    return _db
        .collection('users')
        .orderBy('score', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => User.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}
