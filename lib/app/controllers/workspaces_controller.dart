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
    
    final userWorkspacesDoc = await _firestore.collection('UserData').doc(userId).collection('JoinedWorkspaces').doc('list').get();

    if (!userWorkspacesDoc.exists) {
      joinedWorkspaces.clear();
      return;
    }

    final List<String> workspaceIds = List<String>.from(userWorkspacesDoc.data()?['ids'] ?? []);
    if (workspaceIds.isEmpty) {
      joinedWorkspaces.clear();
      return;
    }
    
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

  // This method is unchanged
  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }
}