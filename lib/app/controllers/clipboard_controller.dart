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

  // Tab management
  var openTabs = <String>['Tasks'].obs;
  var selectedTabIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
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
}