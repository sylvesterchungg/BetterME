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
