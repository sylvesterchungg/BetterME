class ProductivityRecord {
  String id;
  String userId;
  String date; // "YYYY-MM-DD"
  double completionRate; // 0.0–1.0
  int completedTasks;
  int totalTasks;

  ProductivityRecord({
    this.id = '',
    this.userId = '',
    required this.date,
    required this.completionRate,
    required this.completedTasks,
    required this.totalTasks,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'date': date,
    'completionRate': completionRate,
    'completedTasks': completedTasks,
    'totalTasks': totalTasks,
  };

  factory ProductivityRecord.fromMap(Map<String, dynamic> map, String documentId) {
    return ProductivityRecord(
      id: documentId,
      userId: map['userId'] ?? '',
      date: map['date'] ?? '',
      completionRate: (map['completionRate'] as num?)?.toDouble() ?? 0.0,
      completedTasks: map['completedTasks'] as int? ?? 0,
      totalTasks: map['totalTasks'] as int? ?? 0,
    );
  }
}
