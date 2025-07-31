import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../models/workspace_model.dart';

class ClipboardController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // --- STATE VARIABLES ---
  var isLoading = true.obs;
  RxList<Task> allTasks = <Task>[].obs;
  var columnTasks = <String, RxList<Task>>{}.obs;

  // Tab management
  var openTabs = <String>['Tasks'].obs;
  var selectedTabIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    columnTasks['Tasks'] = <Task>[].obs;

    fetchAllTasks();
  }

  Future<void> fetchAllTasks() async {
    isLoading.value = true;
    try {
      final personal = await _fetchPersonalTasks();
      final assigned = await _fetchAssignedTasks();
      allTasks.value = [...personal, ...assigned];
    } catch (e) {
      Get.snackbar("Error", "Could not load tasks: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // --- DATA FETCHING LOGIC ---

  Future<List<Task>> _fetchPersonalTasks() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    final snapshot = await _firestore.collection("UserData").doc(userId).collection("Tasks").get();
    return snapshot.docs.map((doc) => Task.fromFirestore(doc, workspaceName: "Personal")).toList();
  }

  Future<List<Task>> _fetchAssignedTasks() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    // NOTE: This multi-step fetch is based on the requested schema.
    // For large-scale apps, denormalizing data or using a different schema
    // would be more efficient than these nested lookups.

    // 1. Get all workspace documents the user has joined
    final joinedWorkspacesSnapshot = await _firestore.collection('UserData').doc(userId).collection('JoinedWorkspaces').get();
    if (joinedWorkspacesSnapshot.docs.isEmpty) return [];

    List<Future<Task?>> taskFutures = [];

    // 2. For each joined workspace, get the assigned tasks
    for (var userWorkspaceDoc in joinedWorkspacesSnapshot.docs) {
      final workspaceId = userWorkspaceDoc.id;
      final assignedTasksRef = userWorkspaceDoc.reference.collection('AssignedTasks');
      final assignedTasksSnapshot = await assignedTasksRef.get();
      
      // Get the full workspace data to pass its name to the Task model
      final workspaceDataDoc = await _firestore.collection('Workspaces').doc(workspaceId).get();
      if (!workspaceDataDoc.exists) continue;
      final workspace = Workspace.fromFirestore(workspaceDataDoc);

      // 3. For each assigned task ID, create a future to fetch its full data
      for (var assignedTaskDoc in assignedTasksSnapshot.docs) {
        final taskId = assignedTaskDoc.id;
        final taskFuture = _firestore.collection('Workspaces').doc(workspaceId).collection('Tasks').doc(taskId).get()
          .then((taskDoc) {
            if (taskDoc.exists) {
              return Task.fromFirestore(taskDoc, workspaceName: workspace.name);
            }
            return null;
          });
        taskFutures.add(taskFuture);
      }
    }

    // 4. Wait for all task fetches to complete in parallel
    final results = await Future.wait(taskFutures);
    // Filter out any nulls that occurred if a task was deleted but the reference remained
    return results.where((task) => task != null).cast<Task>().toList();
  }
  
  // --- TAB MANAGEMENT ---
  void selectTab(int index) {
    selectedTabIndex.value = index;
  }

  void addTab() {
    final newTabName = 'Tasks${openTabs.length + 1}';
    openTabs.add(newTabName);
    selectedTabIndex.value = openTabs.length - 1; // Select the new tab
  }

  void closeTab(int index) {
    openTabs.removeAt(index);
    // Adjust selected index to prevent errors
    if (selectedTabIndex.value >= index && selectedTabIndex.value > 0) {
      selectedTabIndex.value--;
    } else if (openTabs.isEmpty) {
      selectedTabIndex.value = -1; // No tabs left
    }
  }

  /// Handles moving a task FROM the main grid INTO a side column.
  void handleTaskDropOnColumn(Task task, String columnName) {
    // 1. Remove the task from the main grid's source list.
    allTasks.removeWhere((t) => t.id == task.id);
    
    // 2. Add the task to the target column's list.
    if (columnTasks.containsKey(columnName)) {
      columnTasks[columnName]!.add(task);
    } else {
      // This is a safety net in case the column list wasn't initialized
      columnTasks[columnName] = <Task>[task].obs;
    }

    // 3. Persist the change in Firestore (optional, depends on your schema).
    // This is where you might update a "status" or "category" field on the task.
    // For now, we'll just show a snackbar.
    Get.snackbar(
      "Task Assigned",
      "'${task.name}' moved to column '$columnName'.",
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Handles moving a task FROM a side column BACK to the main grid.
  void handleTaskDropOnGrid(Task task) {
    bool taskWasFoundAndMoved = false;

    // 1. Find which column the task is currently in and remove it.
    columnTasks.forEach((columnName, taskList) {
      int taskIndex = taskList.indexWhere((t) => t.id == task.id);
      if (taskIndex != -1) {
        taskList.removeAt(taskIndex);
        taskWasFoundAndMoved = true;
      }
    });

    // 2. If the task was found and removed, add it back to the main grid's list.
    if (taskWasFoundAndMoved) {
      allTasks.add(task);
      Get.snackbar(
        "Task Unassigned",
        "'${task.name}' moved back to the main grid.",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}