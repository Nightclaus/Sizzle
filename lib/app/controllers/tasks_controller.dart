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
          //"tasks": {} // Redundant
        }
      });
    }
    final newColumn = TaskColumn(id: uid, title: title.trim());
    columns.add(newColumn);
  }

  void updateColumnToDatabase(TaskColumn newColumn) async {
    String userToken = await fetchIdToken() ?? '';
    FirestorePipe pipe = FirestorePipe(jwt: userToken);
    columns.refresh();

    pipe.updateValue(
      "Dashboard", {
        newColumn.id: {
          "name": newColumn.title,
        }
      }
    );
  }
  // Internal Function
  void deleteColumnFromDatabase(String columnUID) async {
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
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex != -1) {
      columns[columnIndex].tasks.add(task);
      debugPrint("[INITIATOR] Built task: ${task.name}");
      // columns.refresh(); // May not be needed if TaskColumn.tasks is RxList
    } else {
      //Get.snackbar("Error", "Column not found to add task.");
      debugPrint("[Error] Column not found to add task.");
      throw ArgumentError("Removing Task");
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
    debugPrint("[INITIATOR] Starting : Setting Credentials'");
    String userToken = await fetchIdToken() ?? '';
    FirestorePipe pipe = FirestorePipe(jwt: userToken);

    /*
    String res = await pipe.testFirestoreFlow();
    print(res);
    */
    
    String dashboard = "Dashboard";
    int columnFixSuccess = 0;
    int columnFixFailures = 0;
    debugPrint("[INITIATOR] Getting 'Dashboard'");
    Map<dynamic, dynamic> allColumns = await pipe.getValue(dashboard);

    debugPrint("[INITIATOR] Sanitising Columns");
    allColumns.removeWhere((key, value) => value == null);

    debugPrint("[INITIATOR] Building Columns...");
    allColumns.forEach((columnUid, columnData) async {
      try {
        await addColumn(columnData["name"], columnUid);
      } catch (e) {
        debugPrint("[INITIATOR] INTERNAL ERROR : INVALID DATATYPE | Auto fixing..."); 
        try {
          allColumns.removeWhere((key, value) => key == columnUid); // Deleting Value
          debugPrint("[INITIATOR] Autofix : Succeeded in fixing target (${columnFixSuccess++})");
        } catch (e) {
          debugPrint("[INITIATOR] Autofix : Failed to fix target (${columnFixFailures++})"); // Shouldnt reach here
        }
      }
    });
    debugPrint("[INITIATOR] Pushing cleaning changes to 'Columns'. Removed [${columnFixSuccess + columnFixFailures}] task(s)");
    await pipe.updateValue("Dashboard", {}); // Clear first
    await pipe.updateValue("Dashboard", allColumns); // Change db to allow both to be in one
    debugPrint("[INITIATOR] Finished Updating 'Columns'");

    int numberRemoved = 0;
    debugPrint("[INITIATOR] Getting 'Tasks'");
    Map<dynamic, dynamic> allTasks = await pipe.getValue(tasksReference);
    debugPrint("[INITIATOR] Sanitising Tasks");
    allTasks.removeWhere((key, value) => value == null);
    debugPrint("[INITIATOR] Building Tasks...");
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
          debugPrint("[INITIATOR] Reached Terminator (Legacy)");
        } else {
          try {
            allTasks.removeWhere((key, value) => key == taskUid); // Clearing tasks if parent were deleted but they were not deleted
            numberRemoved++;
            debugPrint("[INITIATOR] Loading Error: Task missing Column or Task data");
          } catch (e) {
            debugPrint("[INITIATOR] INTERNAL ERROR: UNEXPECTED DATATYPE WHILE CLEARING TASKS MAP");
          }

        }
      }
    });
    debugPrint("[INITIATOR] Pushing cleaning changes to 'Tasks'. Removed [$numberRemoved] task(s)");
    await pipe.updateValue(tasksReference, {}); // Clear first
    await pipe.updateValue(tasksReference, allTasks); // Update the cleaned map back into DB
    debugPrint("[INITIATOR] Finished Updating 'Tasks'");
  }
}