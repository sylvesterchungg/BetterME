import 'package:flutter/material.dart';

class Task {
  String id;
  String userId;
  String title;
  bool isCompleted;
  String category;
  String? categoryIconKey;
  DateTime? dueDate;
  String? reminderTime; // Format: "HH:mm"
  String repeatInterval; // "None", "Daily", "Weekly", "Monthly", "Custom"

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.isCompleted = false,
    this.category = 'General',
    this.categoryIconKey,
    this.dueDate,
    this.reminderTime,
    this.repeatInterval = 'None',
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'isCompleted': isCompleted,
      'category': category,
      'categoryIconKey': categoryIconKey,
      'dueDate': dueDate?.toIso8601String(),
      'reminderTime': reminderTime,
      'repeatInterval': repeatInterval,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map, String documentId) {
    return Task(
      id: documentId,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      category: map['category'] ?? 'General',
      categoryIconKey: map['categoryIconKey'],
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate']) : null,
      reminderTime: map['reminderTime'],
      repeatInterval: map['repeatInterval'] ?? 'None',
    );
  }
}

class TaskCategory {
  String id;
  String userId;
  String name;
  String iconKey;

  TaskCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.iconKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'iconKey': iconKey,
    };
  }

  factory TaskCategory.fromMap(Map<String, dynamic> map, String documentId) {
    return TaskCategory(
      id: documentId,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      iconKey: map['iconKey'] ?? 'list',
    );
  }

  static IconData iconFromKey(String key) {
    switch (key) {
      case 'self_improvement':
        return Icons.self_improvement;
      case 'restaurant':
        return Icons.restaurant;
      case 'medication':
        return Icons.medication;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'water_drop':
        return Icons.water_drop;
      case 'book':
        return Icons.menu_book;
      case 'bedtime':
        return Icons.bedtime;
      case 'favorite':
        return Icons.favorite;
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'schedule':
        return Icons.schedule;
      case 'list':
      default:
        return Icons.list_alt;
    }
  }
}
