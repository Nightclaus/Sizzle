import 'package:flutter/material.dart';

enum TaskTag { passion, work }                // Set categories
enum TaskImportance { high, medium, low }     // Set categories

class Task {
  final String id;
  String name;
  String description;
  TaskTag tag;
  TaskImportance importance;
  DateTime createdAt;
  // String columnId; // To associate with a column if storing separately

  Task({
    required this.id,
    required this.name,
    this.description = '',
    required this.tag,
    required this.importance,
    // required this.columnId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get task_tag {
    switch (tag) {
      case TaskTag.passion:
        return "passion";
      case TaskTag.work:
        return "work";
    }
  }

  String get task_importance {
    switch (importance) {
      case TaskImportance.high:
        return "high";
      case TaskImportance.medium:
        return "medium";
      case TaskImportance.low:
        return "low";
    }
  }
  // Helper to get color for importance
  Color get importanceColor {
    switch (importance) {
      case TaskImportance.high:
        return Colors.redAccent;
      case TaskImportance.medium:
        return Colors.orangeAccent;
      case TaskImportance.low:
        return Colors.greenAccent;
      //default: // No need, all values are covered
      //  return Colors.grey;
    }
  }

  // Helper to get color for tag
  Color get tagColor {
    switch (tag) {
      case TaskTag.passion:
        return Colors.purpleAccent;
      case TaskTag.work:
        return Colors.blueAccent;
      //default:
      //  return Colors.grey;
    }
  }
}