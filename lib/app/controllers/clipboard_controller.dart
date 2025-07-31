import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class ClipboardController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // --- STATE VARIABLES ---
  var isLoading = true.obs;
  RxList<Task> allTasks = <Task>[].obs;
  var columnTasks = <String, RxList<Task>>{}.obs;
  var openTabs = <String>[].obs;
  var selectedTabIndex = 0.obs;

  final Rx<User?> _firebaseUser = Rx<User?>(null);

  DocumentReference<Map<String, dynamic>>? get _userDbRef =>
      _firebaseUser.value?.uid != null
          ? _firestore.collection("UserData").doc(_firebaseUser.value!.uid)
          : null;

  @override
  void onInit() {
    super.onInit();
    _firebaseUser.bindStream(_auth.authStateChanges());
    ever(_firebaseUser, (User? user) {
      if (user == null) {
        // Clear all data on logout
        isLoading.value = false;
        allTasks.clear();
        columnTasks.clear();
        openTabs.clear();
      } else {
        fetchAllData();
      }
    });
  }

  /// Main data loading function. Fetches everything needed for the screen.
  Future<void> fetchAllData() async {
    final userId = _firebaseUser.value?.uid;
    if (userId == null) return;
    isLoading.value = true;
    
    try {
      // 1. Fetch ALL personal tasks into a master list.
      final personalTasksSnapshot = await _userDbRef!.collection("Tasks").get();
      final masterTaskList = personalTasksSnapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();

      // 2. Fetch all "Checkbox" documents to categorize the personal tasks.
      final checkboxesSnapshot = await _userDbRef!.collection("Checkboxes").get();
      final Set<String> categorizedTaskIds = {};
      final List<String> fetchedTabs = [];
      columnTasks.clear();

      for (var doc in checkboxesSnapshot.docs) {
        final tabName = doc.id;
        fetchedTabs.add(tabName);
        final taskIdsInColumn = List<String>.from(doc.data()['taskIds'] ?? []);
        final tasksForThisColumn = masterTaskList.where((task) => taskIdsInColumn.contains(task.id)).toList();
        columnTasks[tabName] = tasksForThisColumn.obs;
        categorizedTaskIds.addAll(taskIdsInColumn);
      }
      
      if (fetchedTabs.isEmpty) {
        fetchedTabs.add('Tasks');
        columnTasks['Tasks'] = <Task>[].obs;
      }
      openTabs.value = fetchedTabs;

      // 3. The "main grid" tasks are any PERSONAL tasks NOT in a category.
      final uncategorizedPersonalTasks = masterTaskList.where((task) => !categorizedTaskIds.contains(task.id)).toList();

      // 4. Fetch all tasks assigned to the user from ALL their workspaces.
      final assignedWorkspaceTasks = await _fetchAssignedTasks(userId);
      
      // 5. Combine everything for the main grid.
      allTasks.value = [...uncategorizedPersonalTasks, ...assignedWorkspaceTasks];

    } catch (e) {
      Get.snackbar("Error", "Could not load clipboard data: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // --- THIS IS THE NEW, REFACTORED METHOD ---
  /// Fetches all tasks from all joined workspaces where the task's parentId
  /// matches the current user's ID.
  Future<List<Task>> _fetchAssignedTasks(String userId) async {
    print("[CLIPBOARD] Fetching assigned tasks for user $userId...");
    final List<Task> assignedTasks = [];

    try {
      // 1. Get the list of workspace references from the user's data.
      // This assumes a schema of /UserData/{userId}/JoinedWorkspaces/{workspaceId}
      final joinedWorkspacesSnapshot = await _firestore
          .collection('UserData')
          .doc(userId)
          .collection('JoinedWorkspaces')
          .get();
          
      if (joinedWorkspacesSnapshot.docs.isEmpty) {
        print("[CLIPBOARD] User has not joined any workspaces.");
        return []; // Return early if the user has no workspaces.
      }

      // Extract the workspace IDs from the document IDs.
      final List<String> workspaceIds = joinedWorkspacesSnapshot.docs.map((doc) => doc.id).toList();

      // 2. Create a list of futures to query all workspaces in parallel for efficiency.
      List<Future<QuerySnapshot<Map<String, dynamic>>>> taskQueries = [];
      for (final workspaceId in workspaceIds) {
        final query = _firestore
            .collection('Workspaces')
            .doc(workspaceId)
            .collection('Tasks')
            .where('parentId', isEqualTo: userId) // The core logic!
            .get();
        taskQueries.add(query);
      }

      // 3. Wait for all the network requests to complete.
      final List<QuerySnapshot<Map<String, dynamic>>> results = await Future.wait(taskQueries);

      // 4. Process the results and build the final Task list.
      // We also fetch the workspace name for better UI context.
      for (int i = 0; i < results.length; i++) {
        final snapshot = results[i];
        if (snapshot.docs.isNotEmpty) {
          // Get the workspace name for context.
          final workspaceId = workspaceIds[i];
          final workspaceDoc = await _firestore.collection('Workspaces').doc(workspaceId).get();
          final workspaceName = workspaceDoc.data()?['name'] ?? 'Workspace';

          for (final doc in snapshot.docs) {
            assignedTasks.add(Task.fromFirestore(doc, workspaceName: workspaceName));
          }
        }
      }
      
      print("[CLIPBOARD] Found ${assignedTasks.length} assigned tasks across ${workspaceIds.length} workspaces.");
      return assignedTasks;
    } catch (e) {
      print("[CLIPBOARD] Error fetching assigned tasks: $e");
      return []; // Always return an empty list on error to prevent crashes.
    }
  }
  // --- END OF THE REFACTORED METHOD ---
  /// Handles moving a task FROM the main grid INTO a side column.
  Future<void> handleTaskDropOnColumn(Task task, String columnName) async {
    if (_userDbRef == null) return;

    // --- UI Update First (for instant feedback) ---
    allTasks.removeWhere((t) => t.id == task.id);

    for (var entry in columnTasks.entries) { // Clear the original, it is now being dragged so it doesnt exist
      entry.value.removeWhere((t) => t.id == task.id);
    }
    columnTasks[columnName]!.add(task);

    // --- Persist the Change in Firestore ---
    try {
      final columnDocRef = _userDbRef!.collection("Checkboxes").doc(columnName);
      // Atomically add the task's ID to the 'taskIds' array in the column's document.
      // Using set with merge:true creates the document if it doesn't exist.
      await columnDocRef.set({
        'taskIds': FieldValue.arrayUnion([task.id])
      }, SetOptions(merge: true));
    } catch (e) {
      Get.snackbar("Error", "Could not move task. Reverting.");
      // --- Revert UI on Failure ---
      columnTasks[columnName]!.removeWhere((t) => t.id == task.id);
      allTasks.add(task);
    }
  }

  /// Handles moving a task FROM a side column BACK to the main grid.
  Future<void> handleTaskDropOnGrid(Task task) async {
    if (_userDbRef == null) return;

    String? sourceColumnName;
    // Find which column the task is currently in.
    columnTasks.forEach((columnName, taskList) {
      if (taskList.any((t) => t.id == task.id)) {
        sourceColumnName = columnName;
      }
    });

    if (sourceColumnName == null) {
      // This means the task was dragged from the grid and dropped back onto the grid. Do nothing.
      return;
    }

    // --- UI Update First ---
    columnTasks[sourceColumnName]!.removeWhere((t) => t.id == task.id);
    allTasks.add(task);

    // --- Persist the Change in Firestore ---
    try {
      final columnDocRef = _userDbRef!.collection("Checkboxes").doc(sourceColumnName!);
      // Atomically remove the task's ID from the 'taskIds' array.
      await columnDocRef.update({
        'taskIds': FieldValue.arrayRemove([task.id])
      });
    } catch (e) {
      Get.snackbar("Error", "Could not move task. Reverting.");
      // --- Revert UI on Failure ---
      allTasks.removeWhere((t) => t.id == task.id);
      columnTasks[sourceColumnName]!.add(task);
    }
  }

  // --- Other Methods (Tab management, other data fetching) ---
  //Future<List<Task>> _fetchAssignedTasks() async { /* ... unchanged ... */ }

  void selectTab(int index) {
    selectedTabIndex.value = index;
  }

  void addTab() {
    final newTabName = 'Tasks${openTabs.length + 1}';
    openTabs.add(newTabName);
    columnTasks[newTabName] = <Task>[].obs;
    selectedTabIndex.value = openTabs.length - 1;
    // Note: The new tab document in Firestore will be created automatically
    // the first time a task is dropped into it.
  }

  void closeTab(int index) {
    if (_userDbRef == null) return;
    
    final tabName = openTabs[index];
    // Move all tasks from the closing tab back to the main grid
    if (columnTasks.containsKey(tabName)) {
      allTasks.addAll(columnTasks[tabName]!);
      columnTasks.remove(tabName);
    }
    
    openTabs.removeAt(index);
    if (selectedTabIndex.value >= index && selectedTabIndex.value > 0) {
      selectedTabIndex.value--;
    } else if (openTabs.isEmpty) {
      selectedTabIndex.value = -1;
    }

    // Delete the document from Firestore
    _userDbRef!.collection("Checkboxes").doc(tabName).delete();
  }
}