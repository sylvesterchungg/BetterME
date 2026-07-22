import 'package:cloud_firestore/cloud_firestore.dart';

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
