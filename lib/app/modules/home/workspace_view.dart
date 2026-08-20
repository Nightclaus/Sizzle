import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../../controllers/workspaces_controller.dart';
import '../../models/task_model.dart';
import '../../forms/profile_dialogue_helper.dart';
import '../../helpers/nav_bar.dart';
import '../../routes/app_pages.dart';

// Workspace Viewer
class HomeScreen extends GetView<WorkspacesController> {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SizzleNavBar(),
      backgroundColor: const Color(0xFFFAF8F5), // Warm off-white background
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
      color: const Color(0xFF3E2F23), // Deep earthy brown background
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
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      }
      return GestureDetector(
        onTap: () {
          showProfileSetupDialog(() {
            controller.fetchUserProfile();
          });
        },
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFC7B9A9), // Matching soft brown
              child: Icon(Icons.person, color: Color(0xFF3E2F23), size: 30),
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
          color: Color(0xFF736353), // Slightly deeper brown than the reference color
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Upcoming Tasks",
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                decoration: TextDecoration.underline,
                color: Colors.white, // High contrast text on deeper brown
                decorationColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                final tasks = controller.notifications;

                if (controller.isLoading.value && tasks.isEmpty) {
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  );
                }

                if (tasks.isEmpty) {
                  return const Text(
                    "No tasks assigned to you yet. You're all caught up!",
                    style: TextStyle(fontSize: 13, color: Colors.white70),
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

  /// Task cards using a softer brown than the reference image
  Widget _buildTaskNotification(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFFC7B9A9), // Softer, lighter brown than reference
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Complete (Delete) Button
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Color(0xFF3E2F23), size: 28),
            tooltip: "Mark as Complete",
            onPressed: () => _completeTask(task),
          ),
          const SizedBox(width: 8),

          // 2. Task Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF3E2F23)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                
                // Tags and Importance badges
                Row(
                  children: [
                    _buildBadge(task.tag.asString, task.tagColor),
                    const SizedBox(width: 6),
                    _buildBadge(task.importance.asString, task.importanceColor),
                  ],
                ),

                if (task.sourceWorkspaceName != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.sourceWorkspaceName == 'tks_farm' ? 'TKS Farm' : 'Tutor House Farm',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF5D4E3F), fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                  ),
                ]
              ],
            ),
          ),

          // 3. Edit / Go To Workspace Button
          IconButton(
            icon: const Icon(Icons.edit_note, color: Color(0xFF3E2F23), size: 28),
            tooltip: "Edit in Workspace",
            onPressed: () {
              if (task.sourceWorkspaceName != null) {
                _goToWorkspace(task.sourceWorkspaceName!, Routes.TASKS);
                Get.snackbar(
                  "Workspace Opened", 
                  "You can edit '${task.name}' here.",
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: const Color(0xFF736353),
                  colorText: Colors.white,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _completeTask(Task task) async {
    try {
      if (task.sourceWorkspaceName != null) {
        await FirebaseFirestore.instance
            .collection('Workspaces')
            .doc(task.sourceWorkspaceName)
            .collection('Tasks')
            .doc(task.id)
            .delete();
        
        controller.notifications.removeWhere((t) => t.id == task.id);
        
        Get.snackbar(
          "Task Completed", 
          "Great job finishing '${task.name}'!",
          backgroundColor: const Color(0xFF736353),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar("Error", "Could not complete task: $e");
    }
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
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF3E2F23)),
            ),
            const Divider(color: Color(0xFF3E2F23), thickness: 3),
            const SizedBox(height: 24),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value && controller.joinedWorkspaces.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF948473)));
                }
                
                return Column(
                  children: [
                    _buildStackedBar(
                      title: "TKS Farm",
                      backgroundColor: const Color(0xFF948473), // Matches the tasks brown/reference image
                      onTap: () => _goToWorkspace('tks_farm', Routes.TASKS),
                    ),
                    const SizedBox(height: 20),
                    _buildStackedBar(
                      title: "Tutor House Farm",
                      backgroundColor: const Color(0xFF948473),
                      onTap: () => _goToWorkspace('tutor_house_farm', Routes.TASKS),
                    ),
                    const SizedBox(height: 20),
                    _buildStackedBar(
                      title: "Records",
                      backgroundColor: const Color(0xFF948473),
                      onTap: () => _goToWorkspace('_records', Routes.RECORDS),
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

  /// Flat, uniform solid-color stacked workspace bars
  Widget _buildStackedBar({required String title, required Color backgroundColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
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

  void _goToWorkspace(String workspaceId, String targetRoute) {
    try {
      final workspace = controller.joinedWorkspaces.firstWhere((ws) => ws.id == workspaceId);
      controller.saveAndSelectWorkspace(workspace);
      Get.offAllNamed(targetRoute); 
    } catch (e) {
      Get.snackbar(
        "Loading", 
        "Workspace data is still syncing, please wait a moment.",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}