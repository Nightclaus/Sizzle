import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile_data.dart';
import '../models/workspace_model.dart';
import 'package:flutter/material.dart';
import '../../general_purpose_widgets/general_purpose_widgets.dart';
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

  // --- NEW STATE VARIABLE ---
  // This will hold the join code of the most recently created workspace.
  var latestJoinCode = ''.obs;
  // --- END OF NEW VARIABLE ---

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();

    // --- SET UP THE WORKER ---
    // This worker listens to changes in 'latestJoinCode'.
    ever(latestJoinCode, (String code) {
      // If the code is not empty, it means we just created a workspace
      // and need to show the popup.
      if (code.isNotEmpty) {
        _showJoinCodePopup(code);
      }
    });
    // --- END OF WORKER SETUP ---
  }

  Future<void> createWorkspace(String name) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Clear any previous code before starting.
    latestJoinCode.value = '';
    isLoading.value = true;

    try {
      final newWorkspaceRef = _firestore.collection('Workspaces').doc();
      final joinCode = _generateJoinCode();
      await newWorkspaceRef.set({
        'name': name,
        'join_code': joinCode,
        'ownerId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final userWorkspacesRef = _firestore.collection('UserData').doc(userId).collection('JoinedWorkspaces').doc('list');
      await userWorkspacesRef.set({
        'ids': FieldValue.arrayUnion([newWorkspaceRef.id])
      }, SetOptions(merge: true));

      await fetchJoinedWorkspaces(); // Refresh the list
      
      // --- CRITICAL CHANGE ---
      // Instead of showing a popup, we just update the state.
      // The 'ever' worker will handle showing the UI.
      latestJoinCode.value = joinCode;

    } catch (e) {
      Get.snackbar("Error", "Could not create workspace.");
    } finally {
      isLoading.value = false;
    }
  }

  // --- NEW HELPER METHOD INSIDE THE CONTROLLER ---
  // This method builds and shows the popup. It's called by the 'ever' worker.
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
      // No 'actions' are provided, so it will automatically get a "Close" button.
    );
  }

  Future<void> fetchInitialData() async {
    isLoading.value = true;
    await fetchUserProfile();
    await fetchJoinedWorkspaces();
    isLoading.value = false;
  }

  Future<void> fetchUserProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final doc = await _firestore.collection("UserData").doc(userId).collection("ProfileData").doc("main").get();
    if (doc.exists) {
      userProfile.value = UserProfileData.fromMap(doc.data()!);
    }
  }

  Future<void> fetchJoinedWorkspaces() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    // In a real app, you might have a document per user listing their workspace IDs
    // For this example, we'll assume a subcollection or array exists.
    // This logic assumes an array 'workspaceIds' in a doc called 'list'.
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

    // Fetch all workspace documents in a single query
    final querySnapshot = await _firestore.collection('Workspaces').where(FieldPath.documentId, whereIn: workspaceIds).get();
    
    joinedWorkspaces.value = querySnapshot.docs.map((doc) => Workspace.fromFirestore(doc)).toList();
  }

  Future<void> joinWorkspace(String joinCode) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    isLoading.value = true;
    try {
      // Find the workspace with the given join code
      final query = await _firestore.collection('Workspaces').where('join_code', isEqualTo: joinCode.trim()).limit(1).get();

      if (query.docs.isEmpty) {
        Get.snackbar("Error", "No workspace found with that code.", snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final workspaceId = query.docs.first.id;

      // Add it to the user's list of joined workspaces
      final userWorkspacesRef = _firestore.collection('UserData').doc(userId).collection('JoinedWorkspaces').doc('list');
      await userWorkspacesRef.set({
        'ids': FieldValue.arrayUnion([workspaceId])
      }, SetOptions(merge: true));

      await fetchJoinedWorkspaces(); // Refresh the list
      Get.snackbar("Success", "You have joined the workspace!", snackPosition: SnackPosition.BOTTOM);

    } catch(e) {
      Get.snackbar("Error", "Could not join workspace.", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }
}