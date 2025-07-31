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

class TasksController extends GetxController {
  // --- CORE PROPERTIES ---
  final bool isWorkspaceMode; // This flag, set at creation, determines all behavior.
  
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

  // --- DYNAMIC DATABASE PATH GETTERS ---

  /// Dynamically returns the correct Firestore reference for COLUMNS
  /// based on the controller's mode. Returns null if prerequisites are not met.
  CollectionReference<Map<String, dynamic>>? get columnsDbRef {
    if (isWorkspaceMode) {
      workspaceId = _workspaceService.selectedWorkspace.value?.id ?? null;
      if (workspaceId == null) return null; // No workspace selected
      return _root.collection('Workspaces').doc(workspaceId).collection('Columns');
    } else {
      if (userId == null) return null; // No user logged in
      return _root.collection('UserData').doc(userId).collection('Dashboard');
    }
  }

  /// Dynamically returns the correct Firestore reference for TASKS
  /// based on the controller's mode. Returns null if prerequisites are not met.
  CollectionReference<Map<String, dynamic>>? get tasksDbRef {
    if (isWorkspaceMode) {
      final workspaceId = _workspaceService.selectedWorkspace.value?.id;
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
      // --- WORKSPACE MODE LOGIC ---
      // This controller instance will react to global workspace changes.
      ever(_workspaceService.selectedWorkspace, (Workspace? workspace) {
        // When the selected workspace changes, reload the data.
        if (workspace != null) {
          loadData();
        } else {
          // If workspace is cleared, empty the columns.
          columns.clear();
        }
      });

      // Also load data for the initially selected workspace, if there is one.
      if (_workspaceService.selectedWorkspace.value != null) {
        loadData();
      }
    } else {
      // --- PERSONAL MODE LOGIC ---
      // This controller instance will only load the user's personal data once.
      loadData();
    }
  }

  /// Universal data loader that uses the dynamic DB getters.
  void loadData() async {
    // Abort if the required database paths are not available.
    if (columnsDbRef == null || tasksDbRef == null) {
      columns.clear();
      return;
    }
    isLoading.value = true;
    debugPrint("[LOADER] Loading data in ${isWorkspaceMode ? 'Workspace' : 'Personal'} mode...");

    try {
      final columnsSnapshot = await columnsDbRef!.get();
      final fetchedColumns = columnsSnapshot.docs
          .map((doc) => TaskColumn(id: doc.id, title: doc.data()['name'] ?? 'Untitled Column'))
          .toList();

      final tasksSnapshot = await tasksDbRef!.get();
      for (var taskDoc in tasksSnapshot.docs) {
        final task = Task.fromFirestore(taskDoc);
        // Find the column this task belongs to and add it.
        final parentColumn = fetchedColumns.firstWhereOrNull((col) => col.id == task.parentId);
        parentColumn?.tasks.add(task);
      }

      columns.value = fetchedColumns;
      debugPrint("[LOADER] Successfully loaded ${columns.length} columns.");
    } catch (e) {
      Get.snackbar("Error", "Failed to load data from the database.");
      debugPrint("[LOADER] Firestore Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /// Adds a new column to the correct Firestore location.
  Future<void> addColumn(String title, [String? uid]) async {
  if (title.trim().isEmpty || columnsDbRef == null) return;

    final newColumnId = uid ?? _uuid.v4();
    final newColumn = TaskColumn(id: newColumnId, title: title.trim());
    
    // Add to Firestore
    await columnsDbRef!.doc(newColumnId).set({"name": newColumn.title});
    // Add to local state for immediate UI update
    columns.removeWhere((column) => column.id == uid); // Attempts to clear
    columns.add(newColumn);
  }

  Future<void> deleteColumn(String columnId) async {
  // Use the dynamic getters. If they are null, something is wrong, so we abort.
  if (columnsDbRef == null || tasksDbRef == null) return;
  
  debugPrint("DELETING COLUMN: $columnId");
  final batch = _root.batch();

  // 1. Mark the column document for deletion.
  final columnRef = columnsDbRef!.doc(columnId);
  batch.delete(columnRef);

  // 2. Find all tasks that belong to this column using the correct path.
  //    The 'tasksDbRef' getter automatically points to either the user's or the workspace's tasks.
  final tasksQuery = await tasksDbRef!
      .where('parentId', isEqualTo: columnId)
      .get();
      
  // 3. Mark each of those tasks for deletion.
  for (var doc in tasksQuery.docs) {
    batch.delete(doc.reference);
  }

  // 4. Commit all deletion operations in a single atomic transaction.
  await batch.commit();

  // 5. Update the local UI state *after* the database operation succeeds.
  columns.removeWhere((col) => col.id == columnId);
}

  /// Adds a new task to the correct Firestore location.
  Future<void> addTask(String columnId, Task task) async {
    if (tasksDbRef == null) return;
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex == -1) return;
    
    // Add to Firestore
    await tasksDbRef!.doc(task.id).set({
      "name": task.name,
      "description": task.description,
      "task_tag": task.tag.asString,
      "task_importance": task.importance.asString,
      "parentId": columnId,
      // You might want to add a createdAt timestamp here as well
      "createdAt": FieldValue.serverTimestamp(),
    });
    
    // Add to local state
    columns[columnIndex].tasks.add(task);
  }

  /// Deletes a task from the correct Firestore location.
  void deleteTask(String columnId, String taskId) async {
    if (tasksDbRef == null) return;
    
    // Delete from Firestore
    await tasksDbRef!.doc(taskId).delete();
    // Delete from local state
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex != -1) {
      columns[columnIndex].tasks.removeWhere((task) => task.id == taskId);
    }
  }

  /// Moves a task from one column to another in the correct Firestore location.
  Future<void> moveTask({
    required Task task,
    required TaskColumn fromColumn,
    required TaskColumn toColumn,
  }) async {
    if (tasksDbRef == null) return;

    // Update local state for instant UI feedback
    fromColumn.tasks.removeWhere((t) => t.id == task.id);
    task.parentId = toColumn.id;
    toColumn.tasks.add(task);

    // Update the parentId field in Firestore
    await tasksDbRef!.doc(task.id).update({"parentId": toColumn.id});
  }
  
  /// Reorders a task within the same column (local state only).
  void reorderTaskInColumn(String columnId, int oldIndex, int newIndex) {
    final columnIndex = columns.indexWhere((col) => col.id == columnId);
    if (columnIndex != -1) {
      final task = columns[columnIndex].tasks.removeAt(oldIndex);
      if (oldIndex < newIndex) newIndex -= 1;
      columns[columnIndex].tasks.insert(newIndex, task);
      // Note: No DB update is needed unless you need to persist order.
    }
  }

  /// Helper to find which column a specific task belongs to.
  TaskColumn? getColumnByTask(Task task) {
    try {
        return columns.firstWhere((col) => col.tasks.any((t) => t.id == task.id));
    } catch(e) {
        return null;
    }
  }
}