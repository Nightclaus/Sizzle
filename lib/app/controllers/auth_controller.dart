import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../routes/app_pages.dart';
import '../forms/profile_dialogue_helper.dart';
import 'base_firebase_controller.dart';

class AuthController extends BaseFirebaseController {
  late GoogleSignIn _googleSignIn;

  var isLoginMode = true.obs;
  var errorMessage = ''.obs;
  Rx<User?> firebaseUser = Rx<User?>(null);

  @override
  void onInit() {
    super.onInit();

    final clientId = dotenv.env['GOOGLE_CLIENT_ID'];
    assert(clientId != null, 'GOOGLE_CLIENT_ID is missing from .env');
    _googleSignIn = kIsWeb ? GoogleSignIn(clientId: clientId!) : GoogleSignIn();

    firebaseUser.bindStream(auth.authStateChanges());
    ever(firebaseUser, _setInitialScreen);
  }

  void _setInitialScreen(User? user) {
    if (user == null) {
      if (Get.currentRoute != Routes.LOGIN) Get.offAllNamed(Routes.LOGIN);
    } else {
      _checkProfileAndNavigate(user);
    }
  }

  Future<void> _checkProfileAndNavigate(User user) async {
    const destination = Routes.HOME;

    final doc = await runSafely(
      () => firestore.collection("UserData").doc(user.uid).collection("ProfileData").doc("main").get(),
      manageLoading: false,
      errorMessage: "Could not verify user profile. Navigating to home.",
    );

    if (doc == null) {
      // Lookup failed; fall back to home rather than stranding the user.
      Get.offAllNamed(destination);
      return;
    }

    if (doc.exists) {
      Get.offAllNamed(destination);
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      showProfileSetupDialog(() => Get.offAllNamed(destination));
    }
  }

  void toggleLoginMode() {
    isLoginMode.value = !isLoginMode.value;
    errorMessage.value = '';
  }

  /// Shared wrapper for the four auth flows below: resets the error,
  /// toggles [isLoading], and surfaces FirebaseAuthException messages
  /// (falling back to [fallbackMessage]) via a snackbar.
  Future<void> _authAction(Future<void> Function() action, String fallbackMessage) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      errorMessage.value = e.message ?? fallbackMessage;
      Get.snackbar('Authentication Error', errorMessage.value, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      errorMessage.value = fallbackMessage;
      Get.snackbar('Error', errorMessage.value, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithGoogle() => _authAction(() async {
        if (kIsWeb) {
          await auth.signInWithPopup(GoogleAuthProvider());
          return;
        }
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return; // cancelled
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await auth.signInWithCredential(credential);
      }, 'Google Sign-In failed.');

  Future<void> signInWithEmailPassword(String email, String password) => _authAction(
        () => auth.signInWithEmailAndPassword(email: email, password: password),
        'Login failed.',
      );

  Future<void> signUpWithEmailPassword(String email, String password) => _authAction(
        () => auth.createUserWithEmailAndPassword(email: email, password: password),
        'Sign up failed.',
      );

  Future<void> signOut() => _authAction(() async {
        if (!kIsWeb) await _googleSignIn.signOut();
        await auth.signOut();
      }, 'Could not sign out.');
}