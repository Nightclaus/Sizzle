import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile_data.dart';
import '../models/workspace_model.dart';
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

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();
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

  Future<void> createWorkspace(String name) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    isLoading.value = true;
    try {
      // Create the new workspace
      final newWorkspaceRef = _firestore.collection('Workspaces').doc();
      final joinCode = _generateJoinCode();
      await newWorkspaceRef.set({
        'name': name,
        'join_code': joinCode,
        'ownerId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add it to the user's list of joined workspaces
      final userWorkspacesRef = _firestore.collection('UserData').doc(userId).collection('JoinedWorkspaces').doc('list');
      await userWorkspacesRef.set({
        'ids': FieldValue.arrayUnion([newWorkspaceRef.id])
      }, SetOptions(merge: true));

      await fetchJoinedWorkspaces(); // Refresh the list
      Get.snackbar("Success", "Workspace '$name' created!");

    } catch(e) {
      Get.snackbar("Error", "Could not create workspace.");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> joinWorkspace(String joinCode) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    isLoading.value = true;
    try {
      // Find the workspace with the given join code
      final query = await _firestore.collection('Workspaces').where('join_code', isEqualTo: joinCode.trim()).limit(1).get();

      if (query.docs.isEmpty) {
        Get.snackbar("Error", "No workspace found with that code.");
        return;
      }

      final workspaceId = query.docs.first.id;

      // Add it to the user's list of joined workspaces
      final userWorkspacesRef = _firestore.collection('UserData').doc(userId).collection('JoinedWorkspaces').doc('list');
      await userWorkspacesRef.set({
        'ids': FieldValue.arrayUnion([workspaceId])
      }, SetOptions(merge: true));

      await fetchJoinedWorkspaces(); // Refresh the list
      Get.snackbar("Success", "You have joined the workspace!");

    } catch(e) {
      Get.snackbar("Error", "Could not join workspace.");
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