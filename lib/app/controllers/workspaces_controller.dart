import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile_data.dart';
import '../models/workspace_model.dart';
import 'package:flutter/material.dart';
import '../../general_purpose_widgets/general_purpose_widgets.dart';

import '../helpers/workspace_service.dart';
import '../routes/app_pages.dart';
import 'dart:math';

class WorkspacesController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  String? get currentUserId => _auth.currentUser?.uid;


  // --- OBSERVABLES ---
  var isLoading = false.obs;
  Rx<UserProfileData?> userProfile = Rx(null);
  RxList<Workspace> joinedWorkspaces = <Workspace>[].obs;
  
  // Dummy data for notifications
  RxList<String> notifications = <String>["- Join a workspace"].obs;

  // This will hold the join code of the most recently created workspace.
  var latestJoinCode = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();

    // This worker listens to changes in 'latestJoinCode'.
    ever(latestJoinCode, (String code) {
      if (code.isNotEmpty) {
        _showJoinCodePopup(code);
      }
    });
  }

  final WorkspaceService _workspaceService = Get.find<WorkspaceService>();

  // ... (all your existing properties and methods are unchanged)

  /// This method is called when a user taps a workspace card in the UI.
  void onWorkspaceSelected(Workspace workspace) {
    // 1. Tell the global service which workspace is now active.
    _workspaceService.selectWorkspace(workspace);

    // 2. Navigate to the screen that displays the tasks for that workspace.
    Get.toNamed(Routes.TEAM, arguments: true); // Go to tasks but in Workspace Mode
  }

  Future<void> createWorkspace(String name) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      Get.snackbar("Error", "You must be logged in to create a workspace.");
      return;
    }

    latestJoinCode.value = '';
    isLoading.value = true;

    try {
      final newWorkspaceRef = _firestore.collection('Workspaces').doc();
      final joinCode = _generateJoinCode();
      
      // --- MODIFICATION #1 ---
      // We add the 'members' field during workspace creation.
      await newWorkspaceRef.set({
        'name': name,
        'join_code': joinCode,
        'ownerId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        // The creator is automatically the first member.
        'members': [userId],
      });
      // --- END OF MODIFICATION ---

      // This part is unchanged: add the workspace ID to the user's personal list.
      final userWorkspacesRef = _firestore.collection('UserData').doc(userId).collection('JoinedWorkspaces').doc(newWorkspaceRef.id);
      await userWorkspacesRef.set({
        'JoinCode': joinCode,
      });

      await fetchJoinedWorkspaces(); // Refresh the list
      
      // This part is unchanged: trigger the popup via the state variable.
      latestJoinCode.value = joinCode;

    } catch (e) {
      Get.snackbar("Error", "Could not create workspace.");
    } finally {
      isLoading.value = false;
    }
  }

  // This method is unchanged
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
            child: SelectableText(
              code,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // This method is unchanged
  Future<void> fetchInitialData() async {
    isLoading.value = true;
    await fetchUserProfile();
    await fetchJoinedWorkspaces();
    isLoading.value = false;
  }

  // This method is unchanged
  Future<void> fetchUserProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final doc = await _firestore.collection("UserData").doc(userId).collection("ProfileData").doc("main").get();
    if (doc.exists) {
      userProfile.value = UserProfileData.fromMap(doc.data()!);
    }
  }

  // This method is unchanged
  Future<void> fetchJoinedWorkspaces() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    final userWorkspacesDoc = await _firestore
    .collection('UserData')
    .doc(userId)
    .collection('JoinedWorkspaces')
    .get();

    final List<String> workspaceIds = userWorkspacesDoc.docs.map((doc) => doc.id).toList();

    final querySnapshot = await _firestore.collection('Workspaces').where(FieldPath.documentId, whereIn: workspaceIds).get();
    
    joinedWorkspaces.value = querySnapshot.docs.map((doc) => Workspace.fromFirestore(doc)).toList();
  }

  Future<void> joinWorkspace(String joinCode) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      Get.snackbar("Error", "You must be logged in to join a workspace.");
      return;
    }

    isLoading.value = true;
    try {
      final query = await _firestore.collection('Workspaces').where('join_code', isEqualTo: joinCode.trim()).limit(1).get();

      if (query.docs.isEmpty) {
        Get.snackbar("Error", "No workspace found with that code.", snackPosition: SnackPosition.BOTTOM);
        isLoading.value = false; // Stop loading indicator
        return;
      }

      final workspaceDoc = query.docs.first;
      final workspaceId = workspaceDoc.id;

      // --- MODIFICATION #2 ---
      // Get a reference to the specific workspace document.
      final workspaceRef = _firestore.collection('Workspaces').doc(workspaceId);

      // Atomically add the current user's UID to the 'members' array.
      // arrayUnion prevents duplicates if the user is already a member.
      await workspaceRef.update({
        'members': FieldValue.arrayUnion([userId]),
      });
      // --- END OF MODIFICATION ---

      final userWorkspacesRef = _firestore.collection('UserData').doc(userId).collection('JoinedWorkspaces').doc(workspaceId);
      await userWorkspacesRef.set({
        'JoinCode': joinCode,
      });

      await fetchJoinedWorkspaces(); // Refresh the list
      Get.snackbar("Success", "You have joined the workspace!", snackPosition: SnackPosition.BOTTOM);

    } catch(e) {
      Get.snackbar("Error", "Could not join workspace.", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  void showEditWorkspaceNameDialog(Workspace workspace) {
    // We leverage the GPFormDialog for consistency.
    GPFormDialog.show(
      context: Get.context!, // Use Get's context safely
      title: "Edit Workspace Name",
      fields: [
        {
          'key': 'name',
          'type': 'text',
          'label': 'New Workspace Name',
          'required': true,
        },
      ],
      // Pre-fill the form with the current name for a better user experience.
      initialData: {
        'name': workspace.name,
      },
      submitButtonText: "Save Changes",
      onSubmit: (formData) {
        final newName = (formData['name'] as String?)?.trim() ?? '';

        // Don't do anything if the name is empty or unchanged.
        if (newName.isEmpty || newName == workspace.name) {
          return;
        }

        // Call the private method to handle the update logic.
        _updateWorkspaceNameConfirmed(workspace.id, newName);
      },
    );
  }

   Future<void> confirmAndLeaveWorkspace(String workspaceId, String workspaceName) async {
    GPPopup.show(
      title: "Confirm Leave",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: "Are you sure you want to leave the '",
              children: [
                TextSpan(
                  text: workspaceName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: "' workspace? You will lose access unless you are invited back."),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Get.back(),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.orange[800]),
                child: const Text("Leave"),
                onPressed: () {
                  Get.back(); // Close the dialog first
                  _leaveWorkspaceConfirmed(workspaceId);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  // --- NEW: Private method for the leave logic ---
  /// Removes the user's reference from a workspace they do not own.
  Future<void> _leaveWorkspaceConfirmed(String workspaceId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    isLoading.value = true;
    try {
      final workspaceRef = _firestore.collection('Workspaces').doc(workspaceId);
      final workspaceDoc = await workspaceRef.get();

      if (!workspaceDoc.exists) throw Exception("Workspace not found.");

      // --- CRITICAL PERMISSION CHECK ---
      // An owner cannot "leave"; they must delete.
      if (workspaceDoc.data()?['ownerId'] == userId) {
        Get.snackbar(
          "Action Not Allowed", 
          "Owners cannot leave a workspace. You must delete it instead.",
          snackPosition: SnackPosition.BOTTOM,
        );
        isLoading.value = false;
        return;
      }

      // Use a batch write to ensure both updates succeed or neither do.
      final batch = _firestore.batch();

      // Operation 1: Remove user from the main workspace's 'members' list.
      batch.update(workspaceRef, {
        'members': FieldValue.arrayRemove([userId])
      });

      // Operation 2: Remove the workspace ID from the user's personal list.
      final userListRef = _firestore.collection('UserData').doc(userId).collection('JoinedWorkspaces').doc('list');
      batch.update(userListRef, {
        'ids': FieldValue.arrayRemove([workspaceId])
      });

      // Commit both operations atomically.
      await batch.commit();

      // Update the local UI state for an instant response.
      joinedWorkspaces.removeWhere((ws) => ws.id == workspaceId);
      Get.snackbar("Success", "You have left the workspace.", snackPosition: SnackPosition.BOTTOM);

    } catch (e) {
      Get.snackbar("Error", "Could not leave workspace: ${e.toString()}", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  // --- NEW: Private method for the actual update logic ---
  /// Updates the workspace name in Firestore after verifying ownership.
  Future<void> _updateWorkspaceNameConfirmed(String workspaceId, String newName) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    isLoading.value = true;
    try {
      final workspaceRef = _firestore.collection('Workspaces').doc(workspaceId);
      final workspaceDoc = await workspaceRef.get();

      // Permission Check: Only the owner can edit the name.
      if (workspaceDoc.data()?['ownerId'] != userId) {
        Get.snackbar("Permission Denied", "Only the workspace owner can change the name.", snackPosition: SnackPosition.BOTTOM);
        isLoading.value = false;
        return;
      }

      // Perform the update in Firestore.
      await workspaceRef.update({'name': newName});

      // --- Update the local UI state ---
      final index = joinedWorkspaces.indexWhere((ws) => ws.id == workspaceId);
      if (index != -1) {
        // To make GetX recognize a change in an object's property within an RxList,
        // we update the property and then call refresh() on the list.
        joinedWorkspaces[index].name = newName;
        joinedWorkspaces.refresh();
      }

      Get.snackbar("Success", "Workspace name updated.", snackPosition: SnackPosition.BOTTOM);

    } catch (e) {
      Get.snackbar("Error", "Could not update name: ${e.toString()}", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _deleteWorkspaceConfirmed(String workspaceId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      Get.snackbar("Error", "You must be logged in.");
      return;
    }

    isLoading.value = true;
    try {
      // Step 1: Get the workspace document to verify ownership and get member list
      final workspaceRef = _firestore.collection('Workspaces').doc(workspaceId);
      final workspaceDoc = await workspaceRef.get();

      if (!workspaceDoc.exists) {
        throw Exception("Workspace not found.");
      }

      // Step 2: Verify the current user is the owner
      if (workspaceDoc.data()?['ownerId'] != userId) {
        Get.snackbar("Permission Denied", "Only the workspace owner can delete it.", snackPosition: SnackPosition.BOTTOM);
        isLoading.value = false;
        return;
      }

      // --- Start a Batch Write for Atomic Deletion ---
      final batch = _firestore.batch();

      // Step 3: Remove the workspace ID from each member's personal list
      final List<String> memberIds = List<String>.from(workspaceDoc.data()?['members'] ?? []);
      
      for (final memberId in memberIds) {
        final memberListRef = _firestore.collection('UserData').doc(memberId).collection('JoinedWorkspaces').doc('list');
        batch.update(memberListRef, {
          'ids': FieldValue.arrayRemove([workspaceId])
        });
      }

      // Step 4: Delete the main workspace document
      batch.delete(workspaceRef);

      // Step 4.1: Delete subcollections
      // Delete tasks
      final tasksRef = workspaceRef.collection('Tasks');
      final tasksSnapshot = await tasksRef.get();
      for (final doc in tasksSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete Columns
      final columnsRef = workspaceRef.collection('Columns');
      final columnsSnapshot = await columnsRef.get();
      for (final doc in columnsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Step 5: Commit all operations in the batch at once
      await batch.commit();

      // Step 6: Refresh the local UI state
      joinedWorkspaces.removeWhere((ws) => ws.id == workspaceId);
      Get.snackbar("Success", "Workspace has been deleted.", snackPosition: SnackPosition.BOTTOM);

    } catch (e) {
      Get.snackbar("Error", "Could not delete workspace: ${e.toString()}", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }


  /// Shows a confirmation dialog before proceeding with workspace deletion.
  Future<void> confirmAndDeleteWorkspace(String workspaceId, String workspaceName) async {
    // We use the existing GPPopup system for a consistent look and feel.
    Get.dialog(
      AlertDialog(
        // Set the title using a Text widget for proper styling.
        title: Text("Confirm Deletion"),
        // The content of the popup is a custom widget we build here.
        content: Column(
          mainAxisSize: MainAxisSize.min, // Use minimum space
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Inform the user about the consequences of their action.
            Text.rich(
              TextSpan(
                text: "Are you sure you want to permanently delete the '",
                children: [
                  TextSpan(
                    text: workspaceName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text: "' workspace? This will remove it for all members and cannot be undone.",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // A row for the action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end, // Align buttons to the right
              children: [
                // The "Cancel" button simply closes the dialog.
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () => Get.back(), // GetX's way to close a dialog
                ),
                const SizedBox(width: 8),
                // The "Delete" button is styled to indicate a dangerous action.
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text("Delete"),
                  onPressed: () {
                    // First, close the dialog.
                    Get.back();
                    // Then, call the actual deletion logic.
                    _deleteWorkspaceConfirmed(workspaceId);
                  },
                ),
              ],
            ),
          ],
        ),
      )
    );
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }
}