import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task_model.dart';
import 'base_firebase_controller.dart';

class ClipboardController extends BaseFirebaseController {
  RxList<Task> allTasks = <Task>[].obs;
  var columnTasks = <String, RxList<Task>>{}.obs;
  var openTabs = <String>[].obs;
  var selectedTabIndex = 0.obs;

  final Rx<User?> _firebaseUser = Rx<User?>(null);

  DocumentReference<Map<String, dynamic>>? get _userDbRef => _firebaseUser.value?.uid != null
      ? firestore.collection("UserData").doc(_firebaseUser.value!.uid)
      : null;

  @override
  void onInit() {
    super.onInit();
    _firebaseUser.bindStream(auth.authStateChanges());
    ever(_firebaseUser, (User? user) {
      if (user == null) {
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
    final uid = _firebaseUser.value?.uid;
    if (uid == null) return;

    await runSafely(() async {
      // 1. All personal tasks.
      final masterTaskList = await fetchCollection(_userDbRef!.collection("Tasks"), Task.fromFirestore);

      // 2. "Checkbox" docs categorize a subset of those tasks into tabs.
      final checkboxesSnapshot = await _userDbRef!.collection("Checkboxes").get();
      final categorizedTaskIds = <String>{};
      final fetchedTabs = <String>[];
      columnTasks.clear();

      for (final doc in checkboxesSnapshot.docs) {
        final tabName = doc.id;
        fetchedTabs.add(tabName);
        final taskIdsInColumn = List<String>.from(doc.data()['taskIds'] ?? []);
        columnTasks[tabName] =
            masterTaskList.where((task) => taskIdsInColumn.contains(task.id)).toList().obs;
        categorizedTaskIds.addAll(taskIdsInColumn);
      }

      if (fetchedTabs.isEmpty) {
        fetchedTabs.add('Tasks');
        columnTasks['Tasks'] = <Task>[].obs;
      }
      openTabs.value = fetchedTabs;

      // 3. Main-grid tasks = personal tasks not in any tab...
      final uncategorized = masterTaskList.where((task) => !categorizedTaskIds.contains(task.id)).toList();
      // 4. ...plus everything assigned to this user across their workspaces.
      final assigned = await _fetchAssignedTasks(uid);

      allTasks.value = [...uncategorized, ...assigned];
    }, errorMessage: "Could not load clipboard data.");
  }

  /// Tasks assigned to [uid] (parentId == uid) across every workspace they've joined.
  Future<List<Task>> _fetchAssignedTasks(String uid) async {
    final joined = await firestore.collection('UserData').doc(uid).collection('JoinedWorkspaces').get();
    if (joined.docs.isEmpty) return [];

    final workspaceIds = joined.docs.map((d) => d.id).toList();

    // Query every joined workspace in parallel.
    final results = await Future.wait(workspaceIds.map(
      (wsId) => fetchWhere(
        firestore.collection('Workspaces').doc(wsId).collection('Tasks'),
        'parentId',
        uid,
        (doc) => doc,
      ),
    ));

    final assignedTasks = <Task>[];
    for (var i = 0; i < results.length; i++) {
      if (results[i].isEmpty) continue;
      final wsId = workspaceIds[i];
      final workspaceDoc = await firestore.collection('Workspaces').doc(wsId).get();
      final workspaceName = workspaceDoc.data()?['name'] ?? 'Workspace';
      for (final doc in results[i]) {
        assignedTasks.add(Task.fromFirestore(doc, workspaceName: workspaceName));
      }
    }
    return assignedTasks;
  }

  /// Moves a task FROM the main grid INTO a side column (tab).
  Future<void> handleTaskDropOnColumn(Task task, String columnName) async {
    if (_userDbRef == null) return;

    allTasks.removeWhere((t) => t.id == task.id);
    for (final entry in columnTasks.entries) {
      entry.value.removeWhere((t) => t.id == task.id);
    }
    columnTasks[columnName]!.add(task);

    try {
      await setDoc(
        _userDbRef!.collection("Checkboxes"),
        columnName,
        {'taskIds': FieldValue.arrayUnion([task.id])},
        merge: true,
      );
    } catch (e) {
      Get.snackbar("Error", "Could not move task. Reverting.");
      columnTasks[columnName]!.removeWhere((t) => t.id == task.id);
      allTasks.add(task);
    }
  }

  /// Moves a task FROM a side column BACK to the main grid.
  Future<void> handleTaskDropOnGrid(Task task) async {
    if (_userDbRef == null) return;

    String? sourceColumnName;
    columnTasks.forEach((columnName, taskList) {
      if (taskList.any((t) => t.id == task.id)) sourceColumnName = columnName;
    });
    if (sourceColumnName == null) return; // dropped back where it came from

    columnTasks[sourceColumnName]!.removeWhere((t) => t.id == task.id);
    allTasks.add(task);

    try {
      await updateDoc(
        _userDbRef!.collection("Checkboxes"),
        sourceColumnName!,
        {'taskIds': FieldValue.arrayRemove([task.id])},
      );
    } catch (e) {
      Get.snackbar("Error", "Could not move task. Reverting.");
      allTasks.removeWhere((t) => t.id == task.id);
      columnTasks[sourceColumnName]!.add(task);
    }
  }

  void selectTab(int index) => selectedTabIndex.value = index;

  void addTab() {
    final newTabName = 'Tasks${openTabs.length + 1}';
    openTabs.add(newTabName);
    columnTasks[newTabName] = <Task>[].obs;
    selectedTabIndex.value = openTabs.length - 1;
    // The Firestore doc for this tab is created lazily on first task drop.
  }

  void closeTab(int index) {
    if (_userDbRef == null) return;

    final tabName = openTabs[index];
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

    _userDbRef!.collection("Checkboxes").doc(tabName).delete();
  }
}