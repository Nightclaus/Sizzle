import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskTag { passion, work }                // Set categories
enum TaskImportance { high, medium, low }     // Set categories

extension TaskTagExtension on TaskTag {
  String get asString {
    switch (this) {
      case TaskTag.passion:
        return "passion";
      case TaskTag.work:
        return "work";
    }
  }
}

extension TaskImportanceExtension on TaskImportance {
  String get asString {
    switch (this) {
      case TaskImportance.high:
        return "high";
      case TaskImportance.medium:
        return "medium";
      case TaskImportance.low:
        return "low";
    }
  }
}

TaskTag? getTaskTag(String tag) {
  switch (tag) {
    case "passion":
      return TaskTag.passion;
    case "work":
      return TaskTag.work;
    default:
      return null;
  }
}

TaskImportance? getTaskImportance(String importance) {
  switch (importance.toLowerCase()) {
    case "high":
      return TaskImportance.high;
    case "medium":
      return TaskImportance.medium;
    case "low":
      return TaskImportance.low;
    default:
      return null;
  }
}

class Task {
  final String id;
  String name;
  String description;
  String parentId;
  TaskTag tag;
  TaskImportance importance;
  DateTime createdAt;
  final String? sourceWorkspaceName; // To know where the task came from

  Task({
    required this.id,
    required this.name,
    this.description = '',
    required this.tag,
    required this.importance,
    required this.parentId,
    this.sourceWorkspaceName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // A factory to create a Task from a Firestore document
  factory Task.fromFirestore(DocumentSnapshot doc, {String? workspaceName}) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      name: data['name'] ?? 'Untitled Task',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      parentId: 'FACTORY',
      tag: getTaskTag(data['task_tag'])!,
      importance: getTaskImportance(data['task_importance'])!,
      sourceWorkspaceName: workspaceName,
    );
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

