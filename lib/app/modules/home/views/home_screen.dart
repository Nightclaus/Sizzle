// lib/app/modules/home/views/home_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart'; // To access user info and sign out

class IdTokenWidget extends StatelessWidget {
  const IdTokenWidget({super.key});

  Future<String?> fetchIdToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: fetchIdToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(); // Loading
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}'); // Error case
        } else if (!snapshot.hasData || snapshot.data == null) {
          return const Text('No token found'); // Null case
        } else {
          return SelectableText('ID Token: ${snapshot.data!}'); // Show token
        }
      },
    );
  }
}

class HomeScreen extends GetView<AuthController> { // HomeController tbm
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the AuthController if it's globally available or injected via HomeBinding
    final AuthController authController = Get.find<AuthController>(); // Fenin is true, so .find will either find it or recreate it
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authController.signOut();
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Welcome!",
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            Obx(() {
              // Display user email if available
              final user = authController.firebaseUser.value;
              return Text(user?.email ?? "Not logged in");
            }),
            IdTokenWidget(),
          ],
        ),
      ),
    );
  }
}