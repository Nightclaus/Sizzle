//import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart'; // Add uuid to pubspec.yaml: `flutter pub add uuid`
import '../models/task_column_model.dart';
import '../models/task_model.dart';

import '../../../../firebase_pipe.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<String?> fetchIdToken() async {
  return await FirebaseAuth.instance.currentUser?.getIdToken();
}

class TasksController extends GetxController {
  var columns = <TaskColumn>[].obs;
  final Uuid _uuid = const Uuid();

  @override
  void onInit() {
    super.onInit();
    // Load initial data or leave empty
    if (columns.isEmpty) {
      _addDefaultColumns(); // Retrieve user data
    }
  }

  void addColumn(String title, [String? uid]) {
    uid ??= _uuid.v4();
    if (title.trim().isEmpty) return;
    final newColumn = TaskColumn(id: uid, title: title.trim());
    columns.add(newColumn);
  }

  void addTaskToColumn(String columnId, Task task) {
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex != -1) {
      columns[columnIndex].tasks.add(task);
      // columns.refresh(); // May not be needed if TaskColumn.tasks is RxList
    } else {
      Get.snackbar("Error", "Column not found to add task.");
    }
  }

  void updateTask(String columnId, Task updatedTask) {
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex != -1) {
      final taskIndex = columns[columnIndex].tasks.indexWhere((task) => task.id == updatedTask.id);
      if (taskIndex != -1) {
        columns[columnIndex].tasks[taskIndex] = updatedTask;
        // columns.refresh(); // Force UI update for the column
      }
    }
  }

  void deleteTask(String columnId, String taskId) {
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex != -1) {
      columns[columnIndex].tasks.removeWhere((task) => task.id == taskId);
    }
  }

  // Placeholder for reordering tasks within a column (for drag & drop later)
  void reorderTaskInColumn(String columnId, int oldIndex, int newIndex) {
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex != -1) {
      final task = columns[columnIndex].tasks.removeAt(oldIndex);
      var adjustedNewIndex = newIndex;
      if (oldIndex < newIndex) {
        adjustedNewIndex -= 1; // Adjust index if item moved down
      }
      columns[columnIndex].tasks.insert(adjustedNewIndex, task);
    }
  }

  // Placeholder for moving task between columns (for drag & drop later)
   void moveTaskToColumn(String oldColumnId, String newColumnId, String taskId, int newIndexInColumn) {
    Task? taskToMove;
    // Remove from old column
    final oldColumnIndex = columns.indexWhere((col) => col.id == oldColumnId);
    if (oldColumnIndex != -1) {
      final taskIndex = columns[oldColumnIndex].tasks.indexWhere((t) => t.id == taskId);
      if (taskIndex != -1) {
        taskToMove = columns[oldColumnIndex].tasks.removeAt(taskIndex);
      }
    }

    // Add to new column
    if (taskToMove != null) {
      final newColumnIndex = columns.indexWhere((col) => col.id == newColumnId);
      if (newColumnIndex != -1) {
        // Ensure index is within bounds
        int insertAtIndex = newIndexInColumn.clamp(0, columns[newColumnIndex].tasks.length);
        columns[newColumnIndex].tasks.insert(insertAtIndex, taskToMove);
      } else {
        // If new column not found, add back to old (or handle error)
        if (oldColumnIndex != -1) {
          columns[oldColumnIndex].tasks.add(taskToMove); // Or some other error recovery
        }
      }
    }
  }

  void moveTask(Task task, {required TaskColumn fromColumn, required TaskColumn toColumn}) {
    fromColumn.tasks.remove(task);
    toColumn.tasks.add(task);
  }

  TaskColumn getColumnByTask(Task task) {
  return columns.firstWhere((col) => col.tasks.contains(task));
  }

  final Map stringToImportance = {
    "work": TaskTag.work,
    "passion": TaskTag.passion,
    "high": TaskImportance.high,
    "medium": TaskImportance.medium,
    "low": TaskImportance.low
  };


  void _addDefaultColumns() async { // Testcase
    String userToken = await fetchIdToken() ?? '';
    FirestorePipe pipe = FirestorePipe(jwt: userToken);

    /*
    String res = await pipe.testFirestoreFlow();
    print(res);
    */

    String dashboard = "Dashboard";
    Map<dynamic, dynamic> allColumns = await pipe.getValue(dashboard);

    allColumns.forEach((columnUid, columnData) async {
      addColumn(columnData["name"], columnUid);
      Map<String, dynamic> tasksInColumn = columnData["tasks"];

      tasksInColumn.forEach((taskUid, map) {
        addTaskToColumn(
          columnUid, 
          Task(
            id: taskUid, // map["uid"]
            name: map["name"],
            description: map["description"],
            tag: stringToImportance[map["task_tag"]],
            importance: stringToImportance[map["task_importance"]]
          )
        );
      });
    });
    
    /*
    addColumn("Todo");
    addColumn("Completed");

    // Add a sample task
    if (columns.isNotEmpty && columns.first.tasks.isEmpty) {
      addTaskToColumn(
        columns.first.id,
        Task(
          id: _uuid.v4(),
          name: "Setup project environment",
          description: "Install Flutter, VS Code, and necessary plugins.",
          tag: TaskTag.work,
          importance: TaskImportance.high,
        ),
      );
       addTaskToColumn(
        columns.first.id,
        Task(
          id: _uuid.v4(),
          name: "Plan passion project",
          description: "Brainstorm ideas for a fun side project.",
          tag: TaskTag.passion,
          importance: TaskImportance.medium,
        ),
      );
    }
    */
  }
}