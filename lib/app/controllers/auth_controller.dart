// lib/app/controllers/auth_controller.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../routes/app_pages.dart'; // For navigation

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    
  );

  // Observables for UI state
  var isLoading = false.obs;
  var isLoginMode = true.obs; // To toggle between Login and Sign Up
  var errorMessage = ''.obs; // To display errors

  // Observable for user state
  Rx<User?> firebaseUser = Rx<User?>(null);

  @override
  void onInit() {
    super.onInit();
    // Listen to auth state changes
    firebaseUser.bindStream(_auth.authStateChanges());
    // Navigate based on user state
    ever(firebaseUser, _setInitialScreen);
  }

  void _setInitialScreen(User? user) {
    if (user == null) {
      if (Get.currentRoute != Routes.LOGIN) Get.offAllNamed(Routes.LOGIN);
    } else {
      Get.offAllNamed(Routes.HOME);
    }
  }

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
