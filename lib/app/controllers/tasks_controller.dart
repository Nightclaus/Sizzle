import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Assuming these models are in your project structure
import '../models/task_column_model.dart';
import '../models/task_model.dart';

class TasksController extends GetxController {
  RxList<TaskColumn> columns = <TaskColumn>[].obs;
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final _uuid = const Uuid();
  final root = FirebaseFirestore.instance;

  // ignore: prefer_typing_uninitialized_variables
  var db;

  @override
  void onInit() {
    super.onInit();
    db = root.collection("UserData").doc(userId);
    
    // Load data from Firestore when the controller is initialized
    if (columns.isEmpty) {
      _loadDataFromFirestore();
    }
  }

  /// Loads all columns and their associated tasks directly from Firestore.
  void _loadDataFromFirestore() async {
    debugPrint("[INITIATOR] Loading data from Firestore...");

    // 1. Fetch all columns (from the "Dashboard" collection)
    try {
      final columnsSnapshot = await db.collection("Dashboard").get();
      final fetchedColumns = <TaskColumn>[];

      for (var doc in columnsSnapshot.docs) {
        final data = doc.data();
        fetchedColumns.add(TaskColumn(
          id: doc.id,
          title: data['name'] ?? 'Untitled Column',
        ));
      }
      columns.value = fetchedColumns; // Directly assign the list of columns
      debugPrint("[INITIATOR] Successfully loaded ${columns.length} columns.");

    } catch (e) {
      debugPrint("[INITIATOR] Error fetching columns: $e");
    }

    // 2. Fetch all tasks and assign them to the correct columns
    try {
      final tasksSnapshot = await db.collection("Tasks").get();
      debugPrint("[INITIATOR] Building ${tasksSnapshot.docs.length} tasks...");

      for (var doc in tasksSnapshot.docs) {
          final map = doc.data();
          final parentId = map["parentId"];
          
          // Find the column this task belongs to
          final columnIndex = columns.indexWhere((col) => col.id == parentId);

          if (columnIndex != -1) {
            final task = Task(
              id: doc.id,
              name: map["name"] ?? 'Untitled Task',
              description: map["description"] ?? '',
              tag: _stringToTaskTag[map["task_tag"]] ?? TaskTag.passion, // Safely handle enum conversion
              importance: _stringToTaskImportance[map["task_importance"]] ?? TaskImportance.low,
              parentId: parentId
            );
            columns[columnIndex].tasks.add(task);
          } else {
            // This can happen if a column was deleted but its tasks were not
            debugPrint("[INITIATOR] Warning: Task '${doc.id}' has an invalid or missing parent column ('$parentId'). Skipping.");
          }
      }
    } catch (e) {
        debugPrint("[INITIATOR] Error fetching tasks: $e");
    }
    
    columns.refresh(); // Refresh the UI after all data is loaded
    debugPrint("[INITIATOR] Firestore data loading complete.");
  }

  /// Adds a new column to the UI and creates a document in the "Dashboard" collection.
  Future<void> addColumn(String title, [String? uid]) async {
    if (title.trim().isEmpty) return;

    uid ??= _uuid.v4(); // if uid is null, assign a new UUID
    final newColumn = TaskColumn(id: uid, title: title.trim());

    // Add to Firestore first
    await db.collection("Dashboard").doc(uid).set({
      "name": newColumn.title,
    });

    // Then update the local state for immediate UI feedback
    columns.add(newColumn);
  }

  /// Deletes a column from the UI and Firestore.
  void deleteColumn(String columnUID) {
    // Delete from local state
    columns.removeWhere((col) => col.id == columnUID);
    
    // Delete the column document from Firestore
    db.collection("Dashboard").doc(columnUID).delete();
    
    // Note: This does not automatically delete the tasks within the column.
    // A cloud function or a batch delete would be needed for that.
  }

  /// Adds a new task to a column in the UI and creates a document in the "Tasks" collection.
  Future<void> addTask(String columnId, Task task) async {
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex == -1) {
      debugPrint("[addTask] Error: Column '$columnId' not found.");
      return;
    }

    // Add to Firestore
    await db.collection("Tasks").doc(task.id).set({
      "name": task.name,
      "description": task.description,
      "task_tag": task.tag.toString().split('.').last, // 'TaskTag.work' -> 'work'
      "task_importance": task.importance.toString().split('.').last,
      "parentId": columnId,
    });

    // Add to the local state
    columns[columnIndex].tasks.add(task);
  }

  /// Deletes a task from a column in the UI and from the "Tasks" collection in Firestore.
  void deleteTask(String columnId, String taskId) {
    // Delete from local state
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex != -1) {
      columns[columnIndex].tasks.removeWhere((task) => task.id == taskId);
    }
    
    // Delete from Firestore
    db.collection("Tasks").doc(taskId).delete();
  }

  /// Moves a task from one column to another and updates its parentId in Firestore.
  void moveTask({
    required Task task,
    required TaskColumn fromColumn,
    required TaskColumn toColumn
  }) async {
    // Update local state for instant UI feedback
    fromColumn.tasks.removeWhere((t) => t.id == task.id);
    task.parentId = toColumn.id;
    toColumn.tasks.add(task);

    // Update the parentId field in Firestore
    await db.collection("Tasks").doc(task.id).update({
      "parentId": toColumn.id,
    });
  }
  
  /// Reorders a task within the same column for UI updates (e.g., drag and drop).
  /// This does not require a database update unless you need to persist the order.
  void reorderTaskInColumn(String columnId, int oldIndex, int newIndex) {
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex != -1) {
      final task = columns[columnIndex].tasks.removeAt(oldIndex);
      // Adjust index because the item has been removed
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      columns[columnIndex].tasks.insert(newIndex, task);
    }
  }

  /// Helper to find which column a specific task belongs to.
  TaskColumn? getColumnByTask(Task task) {
    try {
        return columns.firstWhere((col) => col.tasks.any((t) => t.id == task.id));
    } catch(e) {
        return null; // Return null if the task is not found in any column
    }
  }

  // --- Mappers for converting Firestore string data to Enums ---
  final Map<String, TaskTag> _stringToTaskTag = {
    "work": TaskTag.work,
    "passion": TaskTag.passion,
  };

  final Map<String, TaskImportance> _stringToTaskImportance = {
    "high": TaskImportance.high,
    "medium": TaskImportance.medium,
    "low": TaskImportance.low,
  };
}