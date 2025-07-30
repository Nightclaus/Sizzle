import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dotted_border/dotted_border.dart'; // Could make this a general purpose widget aswell
import '../../../controllers/workspaces_controller.dart';
import '../../../helpers/workspace_dialog_helper.dart';
import '../../../models/workspace_model.dart';
import '../../../helpers/profile_dialogue_helper.dart'; 

class HomeScreen extends GetView<WorkspacesController> {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // controller is lazy loaded via bindings, but it is here aswell
    Get.put(WorkspacesController());

    return Scaffold(
      body: Row(
        children: [
          _buildLeftPanel(),
          _buildRightPanel(),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      width: 250,
      color: const Color(0xFF424242), // Dark Grey
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10), // Just padding bonus, dont look 4 lines above
          _buildUserProfilePreview(),
          const SizedBox(height: 18),
          const Divider(color: Colors.white54),
          const SizedBox(height: 16),
          _buildNotificationsPanel(),
        ],
      ),
    );
  }

  Widget _buildUserProfilePreview() {
    return Obx(() {
      final profile = controller.userProfile.value;
      if (profile == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return GestureDetector(
        onTap: () {
          // Re-opens the account setup dialog for editing
          showProfileSetupDialog(() {controller.fetchUserProfile();}); 
        },
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.grey, size: 30),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  "@${profile.handle}",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            )
          ],
        ),
      );
    });
  }

  Widget _buildNotificationsPanel() {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only( // Visual Style
          top: 30,
          left: 20,
          right: 12,
          bottom: 50,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0), // Light Grey
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Notifications",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
            ),
            const SizedBox(height: 8),
            Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: controller.notifications.map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(note, style: const TextStyle(fontSize: 14)),
              )).toList(),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Workspaces",
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const Divider(color: Colors.black, thickness: 3),
            const SizedBox(height: 24),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value && controller.joinedWorkspaces.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    ...controller.joinedWorkspaces.map((ws) => _buildWorkspaceCard(ws)),
                    _buildAddNewCard(),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceCard(Workspace workspace) {
    return GestureDetector(
      onTap: () {
        /// Do something Placeholder
        Get.snackbar("Workspace Tapped", "You pressed on '${workspace.name}'", snackPosition: SnackPosition.BOTTOM);
        // Example: Get.toNamed(Routes.TASKS, arguments: workspace.id);
      },
      child: SizedBox(
        width: 150,
        height: 150,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.lightBlue[200],
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1), // Dark Blue
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    workspace.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewCard() {
    return GestureDetector(
      onTap: showAddWorkspaceDialog,
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(20),
        dashPattern: const [10, 6],
        strokeWidth: 3,
        color: Colors.black54,
        child: SizedBox(
          width: 150,
          height: 150,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 48),
              const SizedBox(height: 8),
              const Text("Add New", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}