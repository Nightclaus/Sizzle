import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class ClipboardController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // --- STATE VARIABLES ---
  var isLoading = true.obs;
  RxList<Task> allTasks = <Task>[].obs; // Holds "uncategorized" tasks for the main grid
  var columnTasks = <String, RxList<Task>>{}.obs; // Holds categorised tasks for each tab
  var openTabs = <String>[].obs;
  var selectedTabIndex = 0.obs;

  // Helper to get the current user's database path
  DocumentReference<Map<String, dynamic>>? get _userDbRef => 
      _auth.currentUser?.uid != null ? _firestore.collection("UserData").doc(_auth.currentUser!.uid) : null;

  // --- LOCAL AUTH STATE ---
  // Create a local Rx variable to hold the user state for this controller.
  final Rx<User?> _firebaseUser = Rx<User?>(null);

  @override
  void onInit() {
    super.onInit();
    // We bind the fetchAllData method to the auth state.
    // This will automatically run when the user logs in.
    _firebaseUser.bindStream(_auth.authStateChanges());

    // 2. Use 'ever' to listen to OUR Rx variable, not the raw stream.
    //    This worker will now fire whenever _firebaseUser changes.
    ever(_firebaseUser, (User? user) {
      if (user == null) {
        // If the user logs out, clear all the data to prevent showing
        // the previous user's data.
        isLoading.value = false;
        allTasks.clear();
        columnTasks.clear();
        openTabs.clear();
      } else {
        // If a user logs in (or is already logged in), fetch their data.
        fetchAllData();
      }
    });   
  }
  
  /// Main data loading function. Fetches everything needed for the screen.
  Future<void> fetchAllData() async {
    if (_userDbRef == null) return; // Don't run if user is not logged in
    isLoading.value = true;
    
    try {
      // 1. Fetch ALL personal tasks first into a master list.
      final tasksSnapshot = await _userDbRef!.collection("Tasks").get();
      final masterTaskList = tasksSnapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();

      // 2. Fetch all "Checkbox" documents, which define our tabs and their contents.
      final checkboxesSnapshot = await _userDbRef!.collection("Checkboxes").get();
      
      final Set<String> categorizedTaskIds = {};
      final List<String> fetchedTabs = [];

      // Clear previous state
      columnTasks.clear();

      for (var doc in checkboxesSnapshot.docs) {
        final tabName = doc.id;
        fetchedTabs.add(tabName);

        final taskIdsInColumn = List<String>.from(doc.data()['taskIds'] ?? []);
        
        // Find the full Task objects from the master list that belong in this column
        final tasksForThisColumn = masterTaskList.where((task) => taskIdsInColumn.contains(task.id)).toList();
        columnTasks[tabName] = tasksForThisColumn.obs;
        
        // Keep track of which tasks have been categorized
        categorizedTaskIds.addAll(taskIdsInColumn);
      }
      
      // If no tabs were found, initialize the default 'Tasks' tab
      if (fetchedTabs.isEmpty) {
        fetchedTabs.add('Tasks');
        columnTasks['Tasks'] = <Task>[].obs;
      }
      
      openTabs.value = fetchedTabs;

      // 3. The "main grid" tasks are any tasks NOT in a category.
      allTasks.value = masterTaskList.where((task) => !categorizedTaskIds.contains(task.id)).toList();

      ///// IN PRODUCTION this will be used to fetch assigned tasks from the workspace, but that has not been set up yet ////
      //final assigned = await _fetchAssignedTasks();
      //allTasks.addAll(assigned);
    } catch (e) {
      Get.snackbar("Error", "Could not load clipboard data: $e");
    } finally {
      isLoading.value = false;
    }
  }

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