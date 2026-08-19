import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/workspaces_controller.dart';
import '../../models/task_model.dart';
import '../../helpers/profile_dialogue_helper.dart';
import '../../helpers/nav_bar.dart';
import '../../routes/app_pages.dart';
import '../../helpers/workspace_service.dart';


// Workspace Viewer
class HomeScreen extends GetView<WorkspacesController> {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SizzleNavBar(),
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
      width: 350,
      color: const Color(0xFF424242), // Dark Grey
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
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
          showProfileSetupDialog(() {
            controller.fetchUserProfile();
          });
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
        padding: const EdgeInsets.only(
          top: 30,
          left: 20,
          right: 12,
          bottom: 50,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFE0E0E0), // Light Grey
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Notifications",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Obx(() {
                final tasks = controller.notifications;

                if (controller.isLoading.value && tasks.isEmpty) {
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                if (tasks.isEmpty) {
                  return const Text(
                    "No tasks assigned to you yet.",
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: tasks.length,
                  itemBuilder: (context, index) => _buildTaskNotification(tasks[index]),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskNotification(Task task) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (task.sourceWorkspaceName != null)
            Text(
              task.sourceWorkspaceName!,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
        ],
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
                
                return Column(
                  children: [
                    _buildStackedBar(
                      title: "TKS Farm",
                      color: const Color(0xFF0D47A1), // Dark Blue
                      onTap: () => _goToWorkspace('tks_farm'),
                    ),
                    const SizedBox(height: 20),
                    _buildStackedBar(
                      title: "Tutor House Farm",
                      color: const Color(0xFF2E7D32), // Dark Green
                      onTap: () => _goToWorkspace('tutor_house_farm'),
                    ),
                    const SizedBox(height: 20),
                    _buildStackedBar(
                      title: "Records",
                      color: const Color(0xFFE65100), // Dark Orange
                      onTap: () {
                        // Placeholder for Records implementation
                        Get.snackbar("Coming Soon", "The Records portal is under construction.");
                      },
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedBar({required String title, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }

  /// Helper to find the pre-built workspace from the controller and navigate
  void _goToWorkspace(String workspaceId) {
    final WorkspaceService workspaceService = Get.find<WorkspaceService>();
    
    try {
      // 1. Find the real, fully-loaded Workspace object from the controller's list
      final workspace = controller.joinedWorkspaces.firstWhere((ws) => ws.id == workspaceId);
      
      // 2. Call the correct METHOD on the service (selectWorkspace, not selectedWorkspace)
      workspaceService.selectWorkspace(workspace);
      
      // 3. Navigate to Tasks! (Add arguments: true if your TasksBinding needs to know it's workspace mode)
      Get.offAllNamed(Routes.TASKS, arguments: true); 
      
    } catch (e) {
      Get.snackbar(
        "Loading", 
        "Workspace data is still syncing, please wait a moment.",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}