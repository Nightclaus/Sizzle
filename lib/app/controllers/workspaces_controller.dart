import 'dart:math';

import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user_profile_data.dart';
import '../models/workspace_model.dart';
import '../models/task_model.dart';
import '../../general_purpose_widgets.dart';
import '../helpers/logging_service.dart';
import '../helpers/workspace_service.dart';
import '../routes/app_pages.dart';
import 'base_firebase_controller.dart';

class WorkspacesController extends BaseFirebaseController {
  String? get currentUserId => userId;

  final WorkspaceService _workspaceService = Get.find<WorkspaceService>();

  Rx<UserProfileData?> userProfile = Rx(null);
  RxList<Workspace> joinedWorkspaces = <Workspace>[].obs;

  /// Every task assigned to the current user, across every workspace
  /// they've joined. Replaces the old Clipboard screen: since tasks only
  /// exist inside workspaces now, "my tasks" is just this list.
  RxList<Task> notifications = <Task>[].obs;

  var latestJoinCode = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();
    ever(latestJoinCode, (String code) {
      if (code.isNotEmpty) _showJoinCodePopup(code);
    });
  }

  /// Called when a workspace card is tapped: makes it the active workspace
  /// and navigates to its task board. (No more `arguments: true` — every
  /// workspace's board is the same "workspace mode" now.)
  void onWorkspaceSelected(Workspace workspace) {
    _workspaceService.selectWorkspace(workspace);
    Get.toNamed(Routes.TEAM);
  }

  Future<void> fetchInitialData() async {
    await runSafely(() async {
      await fetchUserProfile();
      await fetchJoinedWorkspacesAndNotifications();
    });
  }

  Future<void> fetchUserProfile() async {
    if (userId == null) return;
    final doc = await firestore.collection("UserData").doc(userId).collection("ProfileData").doc("main").get();
    if (doc.exists) userProfile.value = UserProfileData.fromMap(doc.data()!);
  }

  Future<void> fetchJoinedWorkspaces() async {
    if (userId == null) {
      joinedWorkspaces.clear();
      return;
    }

    final result = await runSafely(() async {
      final userWorkspacesSnapshot =
          await firestore.collection('UserData').doc(userId).collection('JoinedWorkspaces').get();
      final workspaceIds = userWorkspacesSnapshot.docs.map((d) => d.id).toList();
      if (workspaceIds.isEmpty) return <Workspace>[];

      final querySnapshot =
          await firestore.collection('Workspaces').where(FieldPath.documentId, whereIn: workspaceIds).get();
      return querySnapshot.docs.map(Workspace.fromFirestore).toList();
    }, errorMessage: "Could not load your workspaces.", manageLoading: false);

    joinedWorkspaces.value = result ?? [];
  }

  /// Refetches the workspace list and the notification bar together —
  /// membership changes (join/leave/delete) always change both.
  Future<void> fetchJoinedWorkspacesAndNotifications() async {
    await fetchJoinedWorkspaces();
    await fetchNotifications();
  }

  /// Populates [notifications] with every task assigned to the current
  /// user, found via a depth-first walk of the user's own data:
  ///   user -> each joined workspace (branch) -> that workspace's Tasks
  ///   (leaves) -> keep only tasks whose parentId is this user.
  /// Each workspace branch is fully explored before moving to the next.
  Future<void> fetchNotifications() async {
    if (userId == null) {
      notifications.clear();
      return;
    }

    final result = await runSafely(
      () => _collectAssignedTasksDfs(userId!),
      errorMessage: "Could not load your tasks.",
      manageLoading: false,
    );
    notifications.value = result ?? [];
  }

  Future<List<Task>> _collectAssignedTasksDfs(String uid) async {
    final joined = await firestore.collection('UserData').doc(uid).collection('JoinedWorkspaces').get();
    if (joined.docs.isEmpty) return [];

    final assigned = <Task>[];

    // Visit one workspace branch at a time (depth-first), rather than
    // fanning every workspace out in parallel.
    for (final workspaceRefDoc in joined.docs) {
      final wsId = workspaceRefDoc.id;

      final tasksInWorkspace = await fetchWhere(
        firestore.collection('Workspaces').doc(wsId).collection('Tasks'),
        'parentId',
        uid,
        (doc) => doc,
      );
      if (tasksInWorkspace.isEmpty) continue;

      final workspaceMeta = await firestore.collection('Workspaces').doc(wsId).get();
      final workspaceName = workspaceMeta.data()?['name'] ?? 'Workspace';

      for (final doc in tasksInWorkspace) {
        assigned.add(Task.fromFirestore(doc, workspaceName: workspaceName));
      }
    }

    return assigned;
  }

  Future<void> createWorkspace(String name) async {
    if (userId == null) {
      Get.snackbar("Error", "You must be logged in to create a workspace.");
      return;
    }
    latestJoinCode.value = '';

    await runSafely(() async {
      final newWorkspaceRef = firestore.collection('Workspaces').doc();
      final joinCode = _generateJoinCode();

      await newWorkspaceRef.set({
        'name': name,
        'join_code': joinCode,
        'ownerId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'members': [userId],
      });

      LoggingService.logAction(
        workspaceId: newWorkspaceRef.id,
        userId: userId!,
        actionMessage: "created workspace '$name'",
      );

      await firestore
          .collection('UserData')
          .doc(userId)
          .collection('JoinedWorkspaces')
          .doc(newWorkspaceRef.id)
          .set({'JoinCode': joinCode});

      await fetchJoinedWorkspacesAndNotifications();
      latestJoinCode.value = joinCode;
    }, errorMessage: "Could not create workspace.");
  }

  Future<void> joinWorkspace(String joinCode) async {
    if (userId == null) {
      Get.snackbar("Error", "You must be logged in to join a workspace.");
      return;
    }

    await runSafely(() async {
      final query =
          await firestore.collection('Workspaces').where('join_code', isEqualTo: joinCode.trim()).limit(1).get();

      if (query.docs.isEmpty) {
        Get.snackbar("Error", "No workspace found with that code.", snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final workspaceDoc = query.docs.first;
      final workspaceId = workspaceDoc.id;
      final workspaceRef = firestore.collection('Workspaces').doc(workspaceId);

      await workspaceRef.update({
        'members': FieldValue.arrayUnion([userId]),
      });

      LoggingService.logAction(
        workspaceId: workspaceId,
        userId: userId!,
        actionMessage: "joined workspace '${workspaceDoc['name']}'",
      );

      await firestore
          .collection('UserData')
          .doc(userId)
          .collection('JoinedWorkspaces')
          .doc(workspaceId)
          .set({'JoinCode': joinCode});

      await fetchJoinedWorkspacesAndNotifications();
      Get.snackbar("Success", "You have joined the workspace!", snackPosition: SnackPosition.BOTTOM);
    }, errorMessage: "Could not join workspace.");
  }

  void showEditWorkspaceNameDialog(Workspace workspace) {
    GPFormDialog.show(
      context: Get.context!,
      title: "Edit Workspace Name",
      fields: [
        {'key': 'name', 'type': 'text', 'label': 'New Workspace Name', 'required': true},
      ],
      initialData: {'name': workspace.name},
      submitButtonText: "Save Changes",
      onSubmit: (formData) {
        final newName = (formData['name'] as String?)?.trim() ?? '';
        if (newName.isEmpty || newName == workspace.name) return;
        _updateWorkspaceNameConfirmed(workspace.id, newName);
      },
    );
  }

  Future<void> confirmAndLeaveWorkspace(String workspaceId, String workspaceName) async {
    GPPopup.show(
      title: "Confirm Leave",
      content: _confirmationContent(
        prefix: "Are you sure you want to leave the '",
        name: workspaceName,
        suffix: "' workspace? You will lose access unless you are invited back.",
        confirmLabel: "Leave",
        confirmColor: Colors.orange[800],
        onConfirm: () => _leaveWorkspaceConfirmed(workspaceId),
      ),
    );
  }

  /// Removes the user's reference from a workspace they do not own.
  Future<void> _leaveWorkspaceConfirmed(String workspaceId) async {
    if (userId == null) return;

    await runSafely(() async {
      final workspaceRef = firestore.collection('Workspaces').doc(workspaceId);
      final workspaceDoc = await workspaceRef.get();
      if (!workspaceDoc.exists) throw Exception("Workspace not found.");

      // Owners cannot "leave"; they must delete.
      if (workspaceDoc.data()?['ownerId'] == userId) {
        Get.snackbar(
          "Action Not Allowed",
          "Owners cannot leave a workspace. You must delete it instead.",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final batch = firestore.batch();
      batch.update(workspaceRef, {
        'members': FieldValue.arrayRemove([userId])
      });
      final userListRef = firestore.collection('UserData').doc(userId).collection('JoinedWorkspaces').doc('list');
      batch.update(userListRef, {
        'ids': FieldValue.arrayRemove([workspaceId])
      });
      await batch.commit();

      joinedWorkspaces.removeWhere((ws) => ws.id == workspaceId);
      await fetchNotifications(); // this workspace's tasks are no longer "mine"
      Get.snackbar("Success", "You have left the workspace.", snackPosition: SnackPosition.BOTTOM);
    }, errorMessage: "Could not leave workspace.");
  }

  /// Updates the workspace name in Firestore after verifying ownership.
  Future<void> _updateWorkspaceNameConfirmed(String workspaceId, String newName) async {
    if (userId == null) return;

    await runSafely(() async {
      final workspaceRef = firestore.collection('Workspaces').doc(workspaceId);
      final workspaceDoc = await workspaceRef.get();

      if (workspaceDoc.data()?['ownerId'] != userId) {
        Get.snackbar("Permission Denied", "Only the workspace owner can change the name.",
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      await workspaceRef.update({'name': newName});

      final index = joinedWorkspaces.indexWhere((ws) => ws.id == workspaceId);
      if (index != -1) {
        joinedWorkspaces[index].name = newName;
        joinedWorkspaces.refresh();
      }

      Get.snackbar("Success", "Workspace name updated.", snackPosition: SnackPosition.BOTTOM);
    }, errorMessage: "Could not update name.");
  }

  Future<void> _deleteWorkspaceConfirmed(String workspaceId) async {
    if (userId == null) {
      Get.snackbar("Error", "You must be logged in.");
      return;
    }

    await runSafely(() async {
      final workspaceRef = firestore.collection('Workspaces').doc(workspaceId);
      final workspaceDoc = await workspaceRef.get();
      if (!workspaceDoc.exists) throw Exception("Workspace not found.");

      if (workspaceDoc.data()?['ownerId'] != userId) {
        Get.snackbar("Permission Denied", "Only the workspace owner can delete it.",
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final batch = firestore.batch();

      final memberIds = List<String>.from(workspaceDoc.data()?['members'] ?? []);
      for (final memberId in memberIds) {
        final memberListRef =
            firestore.collection('UserData').doc(memberId).collection('JoinedWorkspaces').doc('list');
        batch.update(memberListRef, {
          'ids': FieldValue.arrayRemove([workspaceId])
        });
      }
      batch.delete(workspaceRef);

      // Subcollections per the current schema: Columns, Tasks, Logs, Records.
      for (final sub in ['Tasks', 'Columns', 'Logs', 'Records']) {
        final snapshot = await workspaceRef.collection(sub).get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }

      await batch.commit();

      joinedWorkspaces.removeWhere((ws) => ws.id == workspaceId);
      await fetchNotifications(); // drop this workspace's tasks from the bar
      Get.snackbar("Success", "Workspace has been deleted.", snackPosition: SnackPosition.BOTTOM);
    }, errorMessage: "Could not delete workspace.");
  }

  Future<void> confirmAndDeleteWorkspace(String workspaceId, String workspaceName) async {
    Get.dialog(
      AlertDialog(
        title: const Text("Confirm Deletion"),
        content: _confirmationContent(
          prefix: "Are you sure you want to permanently delete the '",
          name: workspaceName,
          suffix: "' workspace? This will remove it for all members and cannot be undone.",
          confirmLabel: "Delete",
          confirmColor: Colors.red,
          onConfirm: () => _deleteWorkspaceConfirmed(workspaceId),
        ),
      ),
    );
  }

  void _showJoinCodePopup(String code) {
    GPPopup.show(
      title: "Workspace Created!",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Share this code with others to join:"),
          const SizedBox(height: 20),
          Center(
            child: SelectableText(code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Shared "prefix **name** suffix" confirmation body with Cancel/Confirm
  /// buttons — used by both the leave-workspace and delete-workspace dialogs.
  Widget _confirmationContent({
    required String prefix,
    required String name,
    required String suffix,
    required String confirmLabel,
    required Color? confirmColor,
    required VoidCallback onConfirm,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(
          text: prefix,
          children: [
            TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: suffix),
          ],
        )),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(child: const Text("Cancel"), onPressed: () => Get.back()),
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: confirmColor),
              child: Text(confirmLabel),
              onPressed: () {
                Get.back();
                onConfirm();
              },
            ),
          ],
        ),
      ],
    );
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }
}