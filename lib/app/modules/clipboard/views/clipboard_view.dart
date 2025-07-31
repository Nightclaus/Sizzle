import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../../controllers/clipboard_controller.dart';
import '../../../../general_purpose_widgets/general_purpose_widgets.dart';
import '../../../models/task_model.dart';
import '../../../helpers/nav_bar.dart'; // SizzleNavBar()

class ClipboardScreen extends GetView<ClipboardController> {
  const ClipboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Get.put(ClipboardController());

    return Scaffold(
      appBar: SizzleNavBar(),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildTopTabBar(),
          Expanded(
            child: Row(
              // The main layout Row
              children: [
                _buildSidePanel(),
                _buildMainContent(), // This will now correctly expand
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
          // The ListView.builder itself is no longer wrapped in Obx.
          // We will observe the length directly.
          child: Obx(() => ListView.builder(
              scrollDirection: Axis.horizontal,
              // We observe the length here to rebuild the list if tabs are added/removed.
              itemCount: controller.openTabs.length, 
              itemBuilder: (context, index) {
                // --- THE KEY CHANGE IS HERE ---
                // We wrap the individual tab UI in its own Obx.
                // This makes each tab independently reactive to state changes.
                return Obx(() {
                  final tabName = controller.openTabs[index];
                  // This calculation now happens inside a dedicated reactive scope.
                  final isSelected = controller.selectedTabIndex.value == index;

                  return GestureDetector(
                    onTap: () => controller.selectTab(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // The color is now guaranteed to update.
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
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                });
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
  // --- CORRECTED SIDE PANEL ---
  Widget _buildSidePanel() {
    return Obx(() {
      if (controller.selectedTabIndex.value < 0 || controller.openTabs.isEmpty) {
        return const SizedBox.shrink();
      }
      final tabName = controller.openTabs[controller.selectedTabIndex.value];
      
      return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    width: 250,
    height: double.infinity,
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
          return controller.handleTaskDropOnColumn(task, tabName);
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
        body: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(Get.context!).size.height - 250),
          child: Obx(() {
  // Get the list of tasks for the currently selected tab
  final tasksInColumn = controller.columnTasks[tabName] ?? <Task>[].obs;
  if (tasksInColumn.isEmpty) {
    return Center(child: Text("Drop tasks here"));
  }
  // Build a list of the tasks in the column
  return ListView.builder(
    itemCount: tasksInColumn.length,
    itemBuilder: (context, index) {
      final task = tasksInColumn[index];
      // Each card in the column must also be Draggable
      return Draggable<Task>(
        data: task,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 200, height: 200,
            child: GPSelectableCard(
              title: task.name,
              description: task.description,
              tagText: task.sourceWorkspaceName ?? task.tag.asString,
              tagColor: task.tagColor,
              importanceText: task.importance.asString,
              importanceColor: task.importanceColor,
              date: task.createdAt,
              expandedChild: Text("Details about ${task.name}"),
            ),
          ),
        ),
        child: GPSelectableCard(
          title: task.name,
          description: task.description,
          tagText: task.sourceWorkspaceName ?? task.tag.asString,
          tagColor: task.tagColor,
          importanceText: task.importance.asString,
          importanceColor: task.importanceColor,
          date: task.createdAt,
          expandedChild: Text("Details about ${task.name}"),
        ),
      );
    },
  );
}),
        ),
        footer: 
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(onPressed: () {}, child: const Text("Column Action")),
        ),
      ),
    ),
  );
});
  }

  // --- CORRECTED MAIN CONTENT ---
  Widget _buildMainContent() {
    // FIX: Expanded must be a direct child of Row. We move it up.
    return Expanded(
      child: DragTarget<Task>(
        onAccept: (task) => controller.handleTaskDropOnGrid(task),
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: isHovering ? Colors.lightBlue.withOpacity(0.05) : Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              // The child is now the Obx directly, not another Expanded.
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.allTasks.isEmpty) {
                  return const Center(child: Text("No tasks found."));
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 1,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: controller.allTasks.length + 1,
                  itemBuilder: (context, index) {
                    if (index == controller.allTasks.length) {
                      return _buildAddNewCard();
                    }
                    final task = controller.allTasks[index];
                    // The Draggable implementation here is correct.
                    return Draggable<Task>(
                      data: task,
                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 200, height: 200,
                          child: GPSelectableCard(
                            title: task.name,
                            description: task.description,
                            tagText: task.sourceWorkspaceName ?? task.tag.asString,
                            tagColor: task.tagColor,
                            importanceText: task.importance.asString,
                            importanceColor: task.importanceColor,
                            date: task.createdAt,
                            expandedChild: Text("Details about ${task.name}"),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: GPSelectableCard(
                          title: task.name,
                          description: task.description,
                          tagText: task.sourceWorkspaceName ?? task.tag.asString,
                          tagColor: task.tagColor,
                          importanceText: task.importance.asString,
                          importanceColor: task.importanceColor,
                          date: task.createdAt,
                          expandedChild: Text("Details about ${task.name}"),
                        ),
                      ),
                      child: GPSelectableCard(
                        title: task.name,
                        description: task.description,
                        tagText: task.sourceWorkspaceName ?? task.tag.asString,
                        tagColor: task.tagColor,
                        importanceText: task.importance.asString,
                        importanceColor: task.importanceColor,
                        date: task.createdAt,
                        expandedChild: Text("Details about ${task.name}"),
                      ),
                    );
                  },
                );
              }),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildAddNewCard() {
    return GestureDetector(
      onTap: () {
        // Could call helper to show a GPFormDialog to create a new task
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