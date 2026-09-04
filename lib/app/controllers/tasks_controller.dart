import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task_column_model.dart';
import '../models/task_model.dart';
import '../models/workspace_model.dart';
import '../helpers/workspace_service.dart';
import 'base_firebase_controller.dart';

/// Task board for the currently selected workspace. Every task now lives
/// inside a workspace, so there is no more personal-vs-workspace mode:
/// columns are always the workspace's members, and tasks are always the
/// workspace's Tasks subcollection.
class TasksController extends BaseFirebaseController {
  RxList<TaskColumn> columns = <TaskColumn>[].obs;

  final WorkspaceService _workspaceService = Get.find<WorkspaceService>();

  String? workspaceId;

  CollectionReference<Map<String, dynamic>>? get tasksDbRef {
    workspaceId = _workspaceService.selectedWorkspace.value?.id;
    if (workspaceId == null) return null;
    return firestore.collection('Workspaces').doc(workspaceId).collection('Tasks');
  }

  @override
  void onInit() {
    super.onInit();
    ever(_workspaceService.selectedWorkspace, (Workspace? workspace) {
      workspace != null ? loadData() : columns.clear();
    });
    if (_workspaceService.selectedWorkspace.value != null) loadData();
  }

  void loadData() {
    runSafely(_loadDataForWorkspace, errorMessage: "Failed to load data.");
  }

  Future<void> _loadDataForWorkspace() async {
    final wsId = _workspaceService.selectedWorkspace.value?.id;
    if (wsId == null) {
      columns.clear();
      return;
    }

    final workspaceDoc = await firestore.collection('Workspaces').doc(wsId).get();
    if (!workspaceDoc.exists) {
      columns.clear();
      Get.snackbar("Error", "Selected workspace not found.");
      return;
    }

    // Columns are the workspace's members, one per user.
    final memberIds = List<String>.from(workspaceDoc.data()?['members'] ?? []);
    if (memberIds.isEmpty) {
      columns.value = [];
      return;
    }

    final userColumns = <TaskColumn>[];
    for (final memberId in memberIds) {
      final profileDoc = await firestore
          .collection('UserData')
          .doc(memberId)
          .collection('ProfileData')
          .doc('main')
          .get();
      final columnName = profileDoc.exists ? (profileDoc.data()!['name'] ?? memberId) : memberId;
      userColumns.add(TaskColumn(id: memberId, title: columnName));
    }

    final tasks = await fetchCollection(
      firestore.collection('Workspaces').doc(wsId).collection('Tasks'),
      Task.fromFirestore,
    );

    // Linear Search replacement for matching tasks to columns
    for (final task in tasks) {
      TaskColumn? targetColumn;
      for (final col in userColumns) {
        if (col.id == task.parentId) {
          targetColumn = col;
          break; // Stop searching once found
        }
      }
      targetColumn?.tasks.add(task);
    }

    columns.value = userColumns;
  }

  Future<void> addTask(String columnId, Task task) async {
    if (tasksDbRef == null) return;

    // Linear Search to find column index
    int columnIndex = -1;
    for (int i = 0; i < columns.length; i++) {
      if (columns[i].id == columnId) {
        columnIndex = i;
        break;
      }
    }
    if (columnIndex == -1) return;

    await setDoc(tasksDbRef!, task.id, {
      "name": task.name,
      "description": task.description,
      "task_tag": task.tag.asString,
      "task_importance": task.importance.asString,
      "parentId": columnId,
      "createdAt": FieldValue.serverTimestamp(),
    });

    // Linear Search to find and remove duplicate task before adding
    final tasksList = columns[columnIndex].tasks;
    for (int i = 0; i < tasksList.length; i++) {
      if (tasksList[i].id == task.id) {
        tasksList.removeAt(i);
        break;
      }
    }
    columns[columnIndex].tasks.add(task);
  }

  Future<void> deleteTask(String columnId, String taskId) async {
    if (tasksDbRef == null) return;
    await deleteDoc(tasksDbRef!, taskId);

    // Linear Search to find column index
    int columnIndex = -1;
    for (int i = 0; i < columns.length; i++) {
      if (columns[i].id == columnId) {
        columnIndex = i;
        break;
      }
    }

    // Linear Search to find and remove the task inside the column
    if (columnIndex != -1) {
      final tasksList = columns[columnIndex].tasks;
      for (int i = 0; i < tasksList.length; i++) {
        if (tasksList[i].id == taskId) {
          tasksList.removeAt(i);
          break;
        }
      }
    }
  }

  Future<void> moveTask({
    required Task task,
    required TaskColumn fromColumn,
    required TaskColumn toColumn,
  }) async {
    if (tasksDbRef == null) return;

    // Linear Search to find and remove task from the source column
    for (int i = 0; i < fromColumn.tasks.length; i++) {
      if (fromColumn.tasks[i].id == task.id) {
        fromColumn.tasks.removeAt(i);
        break;
      }
    }

    task.parentId = toColumn.id;
    toColumn.tasks.add(task);

    await updateDoc(tasksDbRef!, task.id, {"parentId": toColumn.id});
  }

  void reorderTaskInColumn(String columnId, int oldIndex, int newIndex) {
    // Linear Search to find column index
    int columnIndex = -1;
    for (int i = 0; i < columns.length; i++) {
      if (columns[i].id == columnId) {
        columnIndex = i;
        break;
      }
    }
    if (columnIndex == -1) return;
    
    final task = columns[columnIndex].tasks.removeAt(oldIndex);
    if (oldIndex < newIndex) newIndex -= 1;
    columns[columnIndex].tasks.insert(newIndex, task);
  }

  // Nested Linear Search to find a column containing the target task
  TaskColumn? getColumnByTask(Task task) {
    for (final col in columns) {
      for (final t in col.tasks) {
        if (t.id == task.id) {
          return col;
        }
      }
    }
    return null;
  }

  // Linear Search to find a user's column by uid
  List<Task> getTasksForUser(String uid) {
    for (final col in columns) {
      if (col.id == uid) {
        return col.tasks.toList();
      }
    }
    return [];
  }
}