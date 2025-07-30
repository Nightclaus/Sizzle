// lib/app/controllers/auth_controller.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../routes/app_pages.dart'; // For navigation

import '../helpers/profile_dialogue_helper.dart'; // For navigation
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late GoogleSignIn _googleSignIn;

  // Observables
  var isLoading = false.obs;
  var isLoginMode = true.obs;
  var errorMessage = ''.obs;
  Rx<User?> firebaseUser = Rx<User?>(null);

  @override
  void onInit() {
    super.onInit();

    final clientId = dotenv.env['GOOGLE_CLIENT_ID'];
    assert(clientId != null, 'GOOGLE_CLIENT_ID is missing from .env');

    _googleSignIn = kIsWeb
        ? GoogleSignIn(clientId: clientId!)
        : GoogleSignIn();

    firebaseUser.bindStream(_auth.authStateChanges());
    ever(firebaseUser, _setInitialScreen);
  }

  void _setInitialScreen(User? user) {
    if (user == null) {
      // User is logged out, go to the login screen.
      if (Get.currentRoute != Routes.LOGIN) Get.offAllNamed(Routes.LOGIN);
    } else {
      // A user is logged in. Check if their profile is complete before navigating.
      _checkProfileAndNavigate(user);
    }
  }

  // --- NEW METHOD TO HANDLE THE USER SETUP CHECK AND NAVIGATION ---
  Future<void> _checkProfileAndNavigate(User user) async {
    const destination = Routes.HOME;
    try {
      final profileDocRef = FirebaseFirestore.instance
          .collection("UserData")
          .doc(user.uid)
          .collection("ProfileData")
          .doc("main");

      final doc = await profileDocRef.get();

      if (doc.exists) {
        // Profile exists, go to the main app screen.
        Get.offAllNamed(destination);
      } else {
        // Profile does not exist. Show the setup dialog.
        // Add a small delay to ensure the UI is fully ready after login.
        await Future.delayed(const Duration(milliseconds: 300));
        showProfileSetupDialog(() {Get.offAllNamed(destination);});
      }
    } catch (e) {
      Get.snackbar('Error', 'Could not verify user profile. Navigating to home.');
      // Fallback: If the check fails, just send the user to the main screen.
      Get.offAllNamed(destination);
    }
  }
  // --- END OF NEW METHOD ---

  void toggleLoginMode() {
    isLoginMode.value = !isLoginMode.value;
    errorMessage.value = '';
  }

  // Sign in with Google, supporting Web and Mobile
  Future<void> signInWithGoogle() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        await _auth.signInWithPopup(provider);
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return; // cancelled
        final auth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        );
        await _auth.signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      errorMessage.value = e.message ?? 'Google Sign-In failed.';
      Get.snackbar('Google Sign-In Error', errorMessage.value, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      errorMessage.value = 'Unexpected error during Google Sign-In.';
      Get.snackbar('Error', errorMessage.value, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  // Email/Password sign-in
  Future<void> signInWithEmailPassword(String email, String password) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      errorMessage.value = e.message ?? 'Login failed.';
      Get.snackbar('Login Error', errorMessage.value, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      errorMessage.value = 'Unexpected error.';
      Get.snackbar('Error', errorMessage.value, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  // Email/Password sign-up
  Future<void> signUpWithEmailPassword(String email, String password) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      errorMessage.value = e.message ?? 'Sign up failed.';
      Get.snackbar('Sign Up Error', errorMessage.value, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      errorMessage.value = 'Unexpected error.';
      Get.snackbar('Error', errorMessage.value, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    isLoading.value = true;
    try {
      if (!kIsWeb) await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      Get.snackbar('Sign Out Error', 'Could not sign out: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }
}