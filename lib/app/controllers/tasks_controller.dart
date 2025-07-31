import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Models and Services
import '../models/task_column_model.dart';
import '../models/task_model.dart';
import '../models/workspace_model.dart';
import '../helpers/workspace_service.dart'; 
import '../helpers/logging_service.dart'; 

class TasksController extends GetxController {
  // --- CORE PROPERTIES ---
  final bool isWorkspaceMode;
  
  // --- STATE VARIABLES ---
  RxList<TaskColumn> columns = <TaskColumn>[].obs;
  var isLoading = false.obs;

  // --- SERVICES & UTILITIES ---
  final WorkspaceService _workspaceService = Get.find<WorkspaceService>();
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  final _uuid = const Uuid();
  final _root = FirebaseFirestore.instance;

  late String? workspaceId;

  // --- CONSTRUCTOR ---
  TasksController({required this.isWorkspaceMode});

  // --- DYNAMIC DATABASE PATH GETTERS (Unchanged) ---
  CollectionReference<Map<String, dynamic>>? get columnsDbRef {
    if (isWorkspaceMode) {
      workspaceId = _workspaceService.selectedWorkspace.value?.id;
      if (workspaceId == null) return null;
      return _root.collection('Workspaces').doc(workspaceId).collection('Columns');
    } else {
      if (userId == null) return null;
      return _root.collection('UserData').doc(userId).collection('Dashboard');
    }
  }

  CollectionReference<Map<String, dynamic>>? get tasksDbRef {
    if (isWorkspaceMode) {
      workspaceId = _workspaceService.selectedWorkspace.value?.id;
      if (workspaceId == null) return null;
      return _root.collection('Workspaces').doc(workspaceId).collection('Tasks');
    } else {
      if (userId == null) return null;
      return _root.collection('UserData').doc(userId).collection('Tasks');
    }
  }

  @override
  void onInit() {
    super.onInit();
    
    if (isWorkspaceMode) {
      ever(_workspaceService.selectedWorkspace, (Workspace? workspace) {
        if (workspace != null) {
          loadData();
        } else {
          columns.clear();
        }
      });
      if (_workspaceService.selectedWorkspace.value != null) {
        loadData();
      }
    } else {
      loadData();
    }
  }

  // --- REPLACEMENT: Universal data loader with new Workspace Mode logic ---
  void loadData() async {
    isLoading.value = true;
    if (isWorkspaceMode) {
      await _loadDataForWorkspace();
    } else {
      await _loadDataForPersonal();
    }
    isLoading.value = false;
  }

  Future<void> _loadDataForWorkspace() async {
    final workspaceId = _workspaceService.selectedWorkspace.value?.id;
    if (workspaceId == null) {
      columns.clear();
      return;
    }
    debugPrint("[LOADER-W] Loading data for Workspace ID: $workspaceId");

    try {
      final workspaceDoc = await _root.collection('Workspaces').doc(workspaceId).get();
      if (!workspaceDoc.exists) {
        columns.clear();
        Get.snackbar("Error", "Selected workspace not found.");
        return;
      }
      
      final List<String> memberIds = List<String>.from(workspaceDoc.data()?['members'] ?? []);
      if (memberIds.isEmpty) {
        columns.value = [];
        return;
      }

      List<TaskColumn> userColumns = [];
      for (String memberId in memberIds) {
        final profileDoc = await _root.collection('UserData').doc(memberId).collection('ProfileData').doc('main').get();
        final columnName = profileDoc.exists ? profileDoc.data()!['name'] ?? memberId : memberId;
        userColumns.add(TaskColumn(id: memberId, title: columnName));
      }

      final tasksSnapshot = await _root.collection('Workspaces').doc(workspaceId).collection('Tasks').get();
      for (var taskDoc in tasksSnapshot.docs) {
        final task = Task.fromFirestore(taskDoc);
        final parentUserColumn = userColumns.firstWhereOrNull((col) => col.id == task.parentId);
        parentUserColumn?.tasks.add(task);
      }

      columns.value = userColumns;
      debugPrint("[LOADER-W] Successfully loaded ${columns.length} user columns.");

    } catch (e) {
      Get.snackbar("Error", "Failed to load workspace data.");
      debugPrint("[LOADER-W] Firestore Error: $e");
    }
  }

  Future<void> _loadDataForPersonal() async {
    if (columnsDbRef == null || tasksDbRef == null) {
      columns.clear();
      return;
    }
    debugPrint("[LOADER-P] Loading personal data...");
    
    try {
      final columnsSnapshot = await columnsDbRef!.get();
      final fetchedColumns = columnsSnapshot.docs
          .map((doc) => TaskColumn(id: doc.id, title: doc.data()['name'] ?? '...'))
          .toList();

      final tasksSnapshot = await tasksDbRef!.get();
      for (var taskDoc in tasksSnapshot.docs) {
        final task = Task.fromFirestore(taskDoc);
        final parentColumn = fetchedColumns.firstWhereOrNull((col) => col.id == task.parentId);
        parentColumn?.tasks.add(task);
      }
      columns.value = fetchedColumns;
    } catch (e) {
      Get.snackbar("Error", "Failed to load personal data.");
    }
  }
  // --- END OF REPLACEMENT ---
    
  /// Adds a new column. In Workspace Mode, this is disabled as columns are users.
  Future<void> addColumn(String title, [String? uid]) async {
    if (isWorkspaceMode) {
      Get.snackbar("Info", "In Workspace mode, columns represent users and cannot be added manually.");
      return;
    }
    if (title.trim().isEmpty || columnsDbRef == null) return;

    final newColumnId = uid ?? _uuid.v4();
    final newColumn = TaskColumn(id: newColumnId, title: title.trim());
    
    await columnsDbRef!.doc(newColumnId).set({"name": newColumn.title});
    // This logic is for editing, it's better to have a separate update method.
    columns.removeWhere((column) => column.id == uid);
    columns.add(newColumn);

    // --- ADD LOGGING (only if in a workspace) ---
    if (isWorkspaceMode && workspaceId != null && userId != null) {
      LoggingService.logAction(
        workspaceId: workspaceId!,
        userId: userId!,
        actionMessage: "added column '$title'",
      );
    }
    // --- END LOGGING ---
  }

  /// Deletes a column. In Workspace Mode, this might mean "remove user from workspace".
  Future<void> deleteColumn(String columnId) async {
    if (isWorkspaceMode) {
      Get.snackbar("Info", "To delete this column, remove the user from the workspace settings.");
      return;
    }
    if (columnsDbRef == null || tasksDbRef == null) return;
    
    debugPrint("DELETING PERSONAL COLUMN: $columnId");
    final batch = _root.batch();
    final columnRef = columnsDbRef!.doc(columnId);
    batch.delete(columnRef);

    final tasksQuery = await tasksDbRef!.where('parentId', isEqualTo: columnId).get();
    for (var doc in tasksQuery.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    final columnToDelete = columns.firstWhereOrNull((c) => c.id == columnId);

    columns.remove(columnToDelete);

    // --- ADD LOGGING (only if in a workspace) ---
    if (isWorkspaceMode && workspaceId != null && userId != null && columnToDelete != null) {
      LoggingService.logAction(
        workspaceId: workspaceId!,
        userId: userId!,
        actionMessage: "deleted column '${columnToDelete.title}'",
      );
    }
    // --- END LOGGING ---
  }

  /// Adds a new task to a column.
  Future<void> addTask(String columnId, Task task) async {
    if (tasksDbRef == null) return;
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex == -1) return;
    
    await tasksDbRef!.doc(task.id).set({
      "name": task.name,
      "description": task.description,
      "task_tag": task.tag.asString,
      "task_importance": task.importance.asString,
      "parentId": columnId,
      "createdAt": FieldValue.serverTimestamp(),
    });

    columns[columnIndex].tasks.removeWhere((t) => t.id == task.id);
    columns[columnIndex].tasks.add(task);

    // --- ADD LOGGING (only if in a workspace) ---
    if (isWorkspaceMode && workspaceId != null && userId != null) {
      LoggingService.logAction(
        workspaceId: workspaceId!,
        userId: userId!,
        actionMessage: "created task '${task.name}'",
      );
    }
    // --- END LOGGING ---
  }

  /// Deletes a task from a column. (Unchanged)
  void deleteTask(String columnId, String taskId) async {
    if (tasksDbRef == null) return;

    final taskToDelete = columns.firstWhereOrNull((c) => c.id == columnId)?.tasks.firstWhereOrNull((t) => t.id == taskId);
    
    await tasksDbRef!.doc(taskId).delete(); // Remove repeat
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex != -1) {
      columns[columnIndex].tasks.removeWhere((task) => task.id == taskId);
    }

    // --- ADD LOGGING (only if in a workspace) ---
    if (isWorkspaceMode && workspaceId != null && userId != null && taskToDelete != null) {
      LoggingService.logAction(
        workspaceId: workspaceId!,
        userId: userId!,
        actionMessage: "deleted task '${taskToDelete.name}'",
      );
    }
    // --- END LOGGING ---
  }

  /// Moves a task from one column to another.
  Future<void> moveTask({
    required Task task,
    required TaskColumn fromColumn,
    required TaskColumn toColumn,
  }) async {
    if (tasksDbRef == null) return;

    fromColumn.tasks.removeWhere((t) => t.id == task.id);
    // The toColumn.id is the new parentId (either a column ID or a user ID)
    task.parentId = toColumn.id;
    toColumn.tasks.add(task);

    await tasksDbRef!.doc(task.id).update({"parentId": toColumn.id});
  }
  
  /// Reorders a task within the same column. (Unchanged)
  void reorderTaskInColumn(String columnId, int oldIndex, int newIndex) {
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex != -1) {
      final task = columns[columnIndex].tasks.removeAt(oldIndex);
      if (oldIndex < newIndex) newIndex -= 1;
      columns[columnIndex].tasks.insert(newIndex, task);
    }
  }

  /// Helper to find which column a specific task belongs to. (Unchanged)
  TaskColumn? getColumnByTask(Task task) {
    try {
        return columns.firstWhere((col) => col.tasks.any((t) => t.id == task.id));
    } catch(e) {
        return null;
    }
  }

  // --- NEW PUBLIC METHOD ---
  /// Returns a list of all tasks from the currently loaded columns that are
  /// assigned to a specific user ID. Only relevant in Workspace Mode.
  List<Task> getTasksForUser(String userId) {
    if (!isWorkspaceMode) return [];
    final userColumn = columns.firstWhereOrNull((col) => col.id == userId);
    return userColumn?.tasks.toList() ?? [];
  }
}