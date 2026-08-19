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
    for (final task in tasks) {
      userColumns.firstWhereOrNull((col) => col.id == task.parentId)?.tasks.add(task);
    }

    columns.value = userColumns;
  }

  Future<void> addTask(String columnId, Task task) async {
    if (tasksDbRef == null) return;
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex == -1) return;

    await setDoc(tasksDbRef!, task.id, {
      "name": task.name,
      "description": task.description,
      "task_tag": task.tag.asString,
      "task_importance": task.importance.asString,
      "parentId": columnId,
      "createdAt": FieldValue.serverTimestamp(),
    });

    columns[columnIndex].tasks.removeWhere((t) => t.id == task.id);
    columns[columnIndex].tasks.add(task);
  }

  Future<void> deleteTask(String columnId, String taskId) async {
    if (tasksDbRef == null) return;
    await deleteDoc(tasksDbRef!, taskId);
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex != -1) {
      columns[columnIndex].tasks.removeWhere((task) => task.id == taskId);
    }
  }

  Future<void> moveTask({
    required Task task,
    required TaskColumn fromColumn,
    required TaskColumn toColumn,
  }) async {
    if (tasksDbRef == null) return;

    fromColumn.tasks.removeWhere((t) => t.id == task.id);
    task.parentId = toColumn.id;
    toColumn.tasks.add(task);

    await updateDoc(tasksDbRef!, task.id, {"parentId": toColumn.id});
  }

  void reorderTaskInColumn(String columnId, int oldIndex, int newIndex) {
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex == -1) return;
    final task = columns[columnIndex].tasks.removeAt(oldIndex);
    if (oldIndex < newIndex) newIndex -= 1;
    columns[columnIndex].tasks.insert(newIndex, task);
  }

  TaskColumn? getColumnByTask(Task task) {
    return columns.firstWhereOrNull((col) => col.tasks.any((t) => t.id == task.id));
  }

  /// Tasks currently assigned to [uid]'s column within this workspace.
  List<Task> getTasksForUser(String uid) {
    return columns.firstWhereOrNull((col) => col.id == uid)?.tasks.toList() ?? [];
  }
}