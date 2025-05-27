//import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
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
  RxList<TaskColumn> columns = <TaskColumn>[].obs;
  final String tasksReference = "Tasks";
  final Uuid _uuid = const Uuid();

  @override
  void onInit() {
    super.onInit();
    // Load initial data or leave empty
    if (columns.isEmpty) {
      _addDefaultColumns(); // Retrieve user data
    }
  }

  Future<void> addColumn(String title, [String? uid]) async {
    String userToken = await fetchIdToken() ?? '';
    FirestorePipe pipe = FirestorePipe(jwt: userToken);

    if (title.trim().isEmpty) return;
    if (uid == null) {
      uid ??= _uuid.v4();
      pipe.updateValue("Dashboard", {
        uid: {
          "name": title,
          "tasks": {}
        }
      });
    }
    final newColumn = TaskColumn(id: uid, title: title.trim());
    columns.add(newColumn);
  }

  // Internal Function
  void deleteColumnFromDatabase(String columnUID) async { // ColumnUID is redundant, waiting for removal
    String userToken = await fetchIdToken() ?? '';
    FirestorePipe pipe = FirestorePipe(jwt: userToken);
    pipe.updateValue("Dashboard",{
        columnUID: null,
      }
    );
  }

  void deleteColumn(String columnUID) {
    columns.removeWhere((col) => col.id == columnUID);
    deleteColumnFromDatabase(columnUID);
  }

  void addTaskToColumn(String columnId, Task task) {
    print("column id is $columnId");
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex != -1) {
      columns[columnIndex].tasks.add(task);
      // columns.refresh(); // May not be needed if TaskColumn.tasks is RxList
    } else {
      //Get.snackbar("Error", "Column not found to add task.");
      debugPrint("[Error] Column not found to add task.");
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

  // Internal Function
  void deleteTaskFromDatabase(String columnUID, String taskId) async { // ColumnUID is redundant, waiting for removal
    String userToken = await fetchIdToken() ?? '';
    FirestorePipe pipe = FirestorePipe(jwt: userToken);
    pipe.updateValue(tasksReference,{
        taskId: null,
      }
    );
  }

  void deleteTask(String columnUID, String taskId) {
    final columnIndex = columns.indexWhere((col) => col.id == columnUID);
    if (columnIndex != -1) {
      columns[columnIndex].tasks.removeWhere((task) => task.id == taskId);
    }
    deleteTaskFromDatabase(columnUID, taskId);
  }

  void clearTask(String parentId, String taskId) { // Soft delete
    final columnIndex = columns.indexWhere((col) => col.id == parentId);
    if (columnIndex != -1) {
      columns[columnIndex].tasks.removeWhere((task) => task.id == taskId);
    }
  }

  void addTaskToDatabase(String columnUID, Task taskData) async {
    String userToken = await fetchIdToken() ?? '';
    FirestorePipe pipe = FirestorePipe(jwt: userToken);
    pipe.updateValue(tasksReference, {
        taskData.id: {
          "name": taskData.name,
          "description": taskData.description,
          "task_tag": taskData.task_tag,
          "task_importance": taskData.task_importance,
          "parentId": taskData.parentId,
        }
      }
    );
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

  void moveTask(Task task, {required TaskColumn fromColumn, required TaskColumn toColumn}) async {
    fromColumn.tasks.remove(task);
    task.parentId = toColumn.id;
    toColumn.tasks.add(task);

    String userToken = await fetchIdToken() ?? '';
    FirestorePipe pipe = FirestorePipe(jwt: userToken);
    pipe.updateValue(tasksReference, {
        task.id: {
          //"name": task.name,
          //"description": task.description,
          //"task_tag": task.task_tag,
          //"task_importance": task.task_importance,
          "parentId": task.parentId,
        }
      }
    );
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

  final Map stringToObs = {
    "work": TaskTag.work.obs,
    "passion": TaskTag.passion.obs,
    "high": TaskImportance.high.obs,
    "medium": TaskImportance.medium.obs,
    "low": TaskImportance.low.obs
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
    allColumns.removeWhere((key, value) => value == null);
    allColumns.forEach((columnUid, columnData) async {
      await addColumn(columnData["name"], columnUid);
    });
    pipe.updateValue("Dashboard", allColumns); // Change db to allow both to be in one

    Map<dynamic, dynamic> allTasks = await pipe.getValue(tasksReference);
    allTasks.removeWhere((key, value) => value == null);
    allTasks.forEach((taskUid, map) {
      try {
        addTaskToColumn(
          map["parentId"], // Parent Location
          Task(
            id: taskUid, // map["uid"]
            name: map["name"],
            description: map["description"],
            tag: stringToImportance[map["task_tag"]],
            importance: stringToImportance[map["task_importance"]],
            parentId: map["parentId"]
          )
        );
      } catch (e) {
        if (taskUid == "NullTerminator") {
          debugPrint("[Safe] Reached Tasking Loading Terminator");
        } else {
          allTasks.removeWhere((key, value) => value.id == taskUid); // Clearing tasks if parent were deleted but they were not deleted
          debugPrint("Loading Error: Task missing Column or Task data");
        }
      }
    });
    pipe.updateValue(tasksReference, allTasks); // Update the cleaned
  }
}