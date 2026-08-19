import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile_data.dart';
import '../models/workspace_model.dart';
import '../models/task_model.dart';
import '../helpers/workspace_service.dart';
import '../routes/app_pages.dart';
import 'base_firebase_controller.dart';

class WorkspacesController extends BaseFirebaseController {
  String? get currentUserId => userId;

  final WorkspaceService _workspaceService = Get.find<WorkspaceService>();

  Rx<UserProfileData?> userProfile = Rx(null);
  RxList<Workspace> joinedWorkspaces = <Workspace>[].obs;

  /// Every task assigned to the current user, across the two main workspaces.
  RxList<Task> notifications = <Task>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();
  }

  /// Called when a workspace card is tapped: makes it the active workspace
  void onWorkspaceSelected(Workspace workspace) {
    _workspaceService.selectWorkspace(workspace);
    Get.toNamed(Routes.TASKS);
  }

  Future<void> fetchInitialData() async {
    await runSafely(() async {
      await fetchUserProfile();
      await _ensureDefaultWorkspacesExist();
      await fetchJoinedWorkspacesAndNotifications();

      final recentId = userProfile.value?.mostRecentWorkspaceId;
      if (_workspaceService.selectedWorkspace.value == null && recentId != null) {
        try {
          final recentWs = joinedWorkspaces.firstWhere((ws) => ws.id == recentId);
          _workspaceService.selectWorkspace(recentWs);
        } catch (_) {
          // Fallback if the workspace is missing from their list
        }
      }
    });
  }

  Future<void> saveAndSelectWorkspace(Workspace workspace) async {
    _workspaceService.selectWorkspace(workspace);

    if (userId == null) return;

    try {
      await firestore
          .collection("UserData")
          .doc(userId)
          .collection("ProfileData")
          .doc("main")
          .update({'mostRecentWorkspaceId': workspace.id});

      if (userProfile.value != null) {
        final current = userProfile.value!;
        userProfile.value = UserProfileData(
          name: current.name,
          handle: current.handle,
          description: current.description,
          mostRecentWorkspaceId: workspace.id,
        );
      }
    } catch (e) {
      print("Failed to save recent workspace: $e");
    }
  }

  Future<void> fetchUserProfile() async {
    if (userId == null) return;
    final doc = await firestore.collection("UserData").doc(userId).collection("ProfileData").doc("main").get();
    if (doc.exists) userProfile.value = UserProfileData.fromMap(doc.data()!);
  }

  Future<void> _ensureDefaultWorkspacesExist() async {
    if (userId == null) return;
    
    const requiredWorkspaces = ['tks_farm', 'tutor_house_farm', '_records'];

    for (final wsName in requiredWorkspaces) {
      // Using the exact name as the document ID guarantees uniqueness
      final wsRef = firestore.collection('Workspaces').doc(wsName);
      final wsSnap = await wsRef.get();

      if (!wsSnap.exists) {
        await wsRef.set({
          'name': wsName,
          'ownerId': 'system', 
          'createdAt': FieldValue.serverTimestamp(),
          'members': [userId], 
        });
      } else {
        // Just in case the workspace was built by someone else, ensure this user is inside 'members'
        final data = wsSnap.data();
        if (data != null) {
          final members = List<String>.from(data['members'] ?? []);
          if (!members.contains(userId)) {
            await wsRef.update({
              'members': FieldValue.arrayUnion([userId])
            });
          }
        }
      }

      // Maintain user data compatibility so legacy methods won't break if they depend on this structure
      final userJoinedRef = firestore
          .collection('UserData')
          .doc(userId)
          .collection('JoinedWorkspaces')
          .doc(wsName);
      
      final userJoinedSnap = await userJoinedRef.get();
      if (!userJoinedSnap.exists) {
        await userJoinedRef.set({'JoinCode': 'system_default'});
      }
    }
  }

  Future<void> fetchJoinedWorkspaces() async {
    if (userId == null) {
      joinedWorkspaces.clear();
      return;
    }

    final result = await runSafely(() async {
      // Directly fetch only the exact two workspaces
      final docs = await Future.wait([
        firestore.collection('Workspaces').doc('tks_farm').get(),
        firestore.collection('Workspaces').doc('tutor_house_farm').get(),
        firestore.collection('Workspaces').doc('_records').get(),
      ]);

      return docs.where((d) => d.exists).map(Workspace.fromFirestore).toList();
    }, errorMessage: "Could not load your workspaces.", manageLoading: false);

    joinedWorkspaces.value = result ?? [];
  }

  /// Refetches the workspace list and the notification bar together
  Future<void> fetchJoinedWorkspacesAndNotifications() async {
    await fetchJoinedWorkspaces();
    await fetchNotifications();
  }

  /// Populates [notifications] with every task assigned to the current user
  /// looking ONLY inside "tks_farm" and "tutor_house_farm".
  Future<void> fetchNotifications() async {
    if (userId == null) {
      notifications.clear();
      return;
    }

    final result = await runSafely(
      () => _collectAssignedTasks(userId!),
      errorMessage: "Could not load your tasks.",
      manageLoading: false,
    );
    notifications.value = result ?? [];
  }

  Future<List<Task>> _collectAssignedTasks(String uid) async {
    final assigned = <Task>[];
    const targetWorkspaces = ['tks_farm', 'tutor_house_farm'];

    for (final wsId in targetWorkspaces) {
      final tasksInWorkspace = await fetchWhere(
        firestore.collection('Workspaces').doc(wsId).collection('Tasks'),
        'parentId',
        uid,
        (doc) => doc,
      );
      
      if (tasksInWorkspace.isEmpty) continue;

      for (final doc in tasksInWorkspace) {
        assigned.add(Task.fromFirestore(doc, workspaceName: wsId));
      }
    }

    return assigned;
  }
}