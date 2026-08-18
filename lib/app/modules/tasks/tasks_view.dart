import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizzle/app/models/task_column_model.dart';
import 'package:sizzle/app/modules/tasks/widgets/add_task_dialog.dart';
import '../../controllers/tasks_controller.dart';
import 'widgets/task_card_widget.dart';
import '../../models/task_model.dart';
import '../../../general_purpose_widgets.dart';
import '../../helpers/nav_bar.dart';
import '../../helpers/workspace_service.dart';

class TasksPage extends GetView<TasksController> {
  final double defaultColumnWidth = 300;

  TasksPage({Key? key}) : super(key: key);

  Color lightenColor(Color color, [int amount = 100]) {
    return Color.alphaBlend(Colors.white.withAlpha(amount), color);
  }

  @override
  Widget build(BuildContext context) {
    final workspaceService = Get.find<WorkspaceService>();
    final theme = Theme.of(context);
    const double appBarHeight = 75.0;
    final maxHeight = MediaQuery.of(context).size.height - appBarHeight;

    return Obx(() {
      final bool isInvalidState = workspaceService.selectedWorkspace.value == null;

      // Render prompt screen if no workspace is selected
      if (isInvalidState) {
        return Scaffold(
          appBar: SizzleNavBar(),
          backgroundColor: Colors.white,
          body: const Center(
            child: Text(
              'Select a Workspace to continue!',
              style: TextStyle(fontSize: 24, color: Colors.black54),
            ),
          ),
        );
      }

      // Render the task board once a workspace is active
      return Scaffold(
        appBar: SizzleNavBar(),
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: Stack(
            children: [
              // Stylistic Background
              Positioned.fill(
                child: Image.asset('assets/harvest.jpg', fit: BoxFit.cover),
              ),
              Positioned.fill(
                child: Container(color: Colors.black.withAlpha(100)),
              ),
              
              // Handle loading or empty states reactively
              if (controller.isLoading.value)
                const Center(child: CircularProgressIndicator())
              else if (controller.columns.isEmpty)
                const Center(
                  child: Text(
                    "No members in this workspace yet!",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: controller.columns.map((column) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: GPColumn<Task>(
                            width: defaultColumnWidth,
                            onAccept: (droppedTask) {
                              final fromColumn = controller.getColumnByTask(droppedTask);
                              if (fromColumn != null) {
                                controller.moveTask(
                                  task: droppedTask,
                                  fromColumn: fromColumn,
                                  toColumn: column,
                                );
                              }
                            },
                            header: _buildColumnHeader(context, theme, column),
                            body: _buildTaskList(column),
                            footer: _buildColumnFooter(context, theme, column.id),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  // --- HELPER METHODS FOR CLEAN UI CODE ---

  Widget _buildColumnHeader(BuildContext context, ThemeData theme, TaskColumn column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Text(
                  column.title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Note: Manual column editing/deletion menus have been removed 
            // because columns are now defined by workspace membership.
          ],
        ),
        Container(height: 2, color: theme.primaryColor),
      ],
    );
  }

  Widget _buildTaskList(TaskColumn column) {
    return Obx(
      () => ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: column.tasks.length,
        itemBuilder: (ctx, taskIndex) {
          final task = column.tasks[taskIndex];
          final card = TaskCardWidget(task: task);
          return Draggable<Task>(
            data: task,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(width: defaultColumnWidth - 24, child: card),
            ),
            childWhenDragging: Opacity(opacity: 0.5, child: card),
            child: card,
          );
        },
      ),
    );
  }

  Widget _buildColumnFooter(BuildContext context, ThemeData theme, String columnId) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 40),
        foregroundColor: lightenColor(theme.primaryColor.withAlpha(60), 150),
        backgroundColor: theme.colorScheme.primary.withAlpha(200),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: const Text("Add a card"),
      onPressed: () => showAddTaskDialog(context, columnId), 
    );
  }
}