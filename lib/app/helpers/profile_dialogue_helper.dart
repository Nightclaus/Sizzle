import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Make sure this path points to your actual GPFormDialog file
import '../../../general_purpose_widgets/general_purpose_widgets.dart';
import '../models/user_profile_data.dart';

// This is the callable function that shows our form.
void showProfileSetupDialog(VoidCallback onComplete) {
  // Use Get.context! to safely get the current build context for theming.
  // The delay in the controller ensures this context is available.
  final context = Get.context!;
  final userId = FirebaseAuth.instance.currentUser?.uid;

  // This should never happen if called from the controller, but it's a good safety check.
  if (userId == null) return;

  final formFields = [
    {'key': 'name', 'type': 'text', 'label': 'Full Name', 'required': true},
    {'key': 'handle', 'type': 'text', 'label': 'Username / Handle', 'required': true},
    {'key': 'description', 'type': 'text', 'label': 'Bio / Description', 'maxLines': 4, 'required': false},
  ];

  GPFormDialog.show(
    context: context,
    title: 'Complete Your Profile',
    fields: formFields,
    submitButtonText: 'Save and Continue',
    onSubmit: (formData) async {
      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

      try {
        final profileDocRef = FirebaseFirestore.instance
            .collection("UserData")
            .doc(userId)
            .collection("ProfileData")
            .doc("main");
        
        final profileData = UserProfileData.fromMap(formData);
        await profileDocRef.set(profileData.toMap());

        Get.back(); // Close loading dialog
        Get.snackbar('Welcome!', 'Your profile has been set up.', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);
        onComplete();
      } catch (e) {
        Get.back(); // Close loading dialog
        Get.snackbar('Error', 'Failed to save profile. Please try again.', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
        onComplete();
      }
    },
  );
}