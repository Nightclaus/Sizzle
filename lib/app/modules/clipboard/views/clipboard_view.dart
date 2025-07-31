import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../../controllers/clipboard_controller.dart';
import '../../../../general_purpose_widgets/general_purpose_widgets.dart';
import '../../../models/task_model.dart';

class ClipboardScreen extends GetView<ClipboardController> {
  const ClipboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Put the controller into memory
    Get.put(ClipboardController());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildTopTabBar(),
          Expanded(
            child: Row(
              children: [
                _buildSidePanel(),
                _buildMainContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTabBar() {
    return Container(
      height: 40,
      color: const Color(0xFF424242),
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: controller.openTabs.length,
                itemBuilder: (context, index) {
                  final tabName = controller.openTabs[index];
                  final isSelected = controller.selectedTabIndex.value == index;
                  return GestureDetector(
                    onTap: () => controller.selectTab(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color: isSelected ? const Color(0xFFF5F5F5) : Colors.transparent,
                      child: Row(
                        children: [
                          Text(
                            tabName,
                            style: TextStyle(color: isSelected ? Colors.black : Colors.white),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => controller.closeTab(index),
                            child: Icon(Icons.close, size: 16, color: isSelected ? Colors.black : Colors.white),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => controller.addTab(),
            tooltip: "Add New Tab",
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    return Obx(() {
      // If no tab is selected, show an empty container
      if (controller.selectedTabIndex.value < 0 || controller.openTabs.isEmpty) {
        return const SizedBox.shrink();
      }
      final tabName = controller.openTabs[controller.selectedTabIndex.value];
      
      // Animate the appearance of the side panel
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 250,
        color: const Color(0xFF424242),
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(12),
          ),
          // Using your GPColumn as the content
          child: GPColumn<Task>(
            onAccept: (task) {
              Get.snackbar("Action", "Task '${task.name}' dropped on column '${tabName}'");
            },
            header: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tabName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                  const Icon(Icons.menu),
                ],
              ),
            ),
            body: Center(child: Text("Content for $tabName")),
            footer: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(onPressed: () {}, child: const Text("Column Action")),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildMainContent() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("My Tasks", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.black, thickness: 3),
            const SizedBox(height: 24),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.allTasks.isEmpty) {
                  return const Center(child: Text("No tasks found."));
                }
                // GridView to display all tasks
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 1,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: controller.allTasks.length + 1, // +1 for the add button
                  itemBuilder: (context, index) {
                    if (index == controller.allTasks.length) {
                      return _buildAddNewCard();
                    }
                    final task = controller.allTasks[index];
                    return GPSelectableCard(
                      title: task.name,
                      description: task.description,
                      tagText: task.sourceWorkspaceName ?? task.tag.asString,
                      tagColor: task.tagColor,
                      importanceText: task.importance.asString,
                      importanceColor: task.importanceColor,
                      date: task.createdAt,
                      expandedChild: Text("Details about ${task.name}"),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewCard() {
    return GestureDetector(
      onTap: () {
        // Here you would call a helper to show a GPFormDialog to create a new task
        Get.snackbar("Action", "Add New Task button pressed!");
      },
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(20),
        dashPattern: const [10, 6],
        strokeWidth: 3,
        color: Colors.black54,
        child: const SizedBox(
          width: 150,
          height: 150,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 48),
              SizedBox(height: 8),
              Text("Add New", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}