import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizzle/app/models/task_column_model.dart';
import 'package:sizzle/app/modules/tasks/widgets/add_task_dialog.dart';
import '../../../controllers/tasks_controller.dart';
import '../widgets/task_card_widget.dart';
import '../../../models/task_model.dart';
import '../../../../general_purpose_widgets/general_purpose_widgets.dart';
import '../../../helpers/nav_bar.dart';
import '../../../helpers/workspace_service.dart';


class TasksPage extends GetView<TasksController> {
  // --- CRITICAL GETX RENDERING FIX ---
  // This override ensures GetView finds the correct controller instance
  // based on the argument passed to the page (e.g., from your TasksBinding).
  @override
  String? get tag {
    final bool isWorkspaceMode = Get.arguments as bool? ?? false;
    return isWorkspaceMode.toString();
  }

  final double defaultColumnWidth = 300;

  TasksPage({Key? key}) : super(key: key);

  Color lightenColor(Color color, [int amount = 100]) {
    return Color.alphaBlend(Colors.white.withAlpha(amount), color);
  }

  // --- STYLISTIC DIALOGUE PRESERVED ---
  // This helper method for showing the dialog remains unchanged,
  // preserving its functionality and appearance.
  void _showAddColumnDialog(BuildContext context, [TaskColumn? existingColumn]) {
    final bool isEditMode = existingColumn != null;
    final String dialogTitle = isEditMode ? "Edit Column" : "Add New Column";
    final String submitText = isEditMode ? "Save Changes" : "Add";
    final formFields = [{'key': 'title', 'type': 'text', 'label': 'Column Title', 'required': true}];
    final initialData = isEditMode ? {'title': existingColumn.title} : null;

    GPFormDialog.show(
      context: context,
      title: dialogTitle,
      fields: formFields,
      initialData: initialData,
      submitButtonText: submitText,
      onSubmit: (formData) {
        final String newTitle = (formData['title'] as String?)?.trim() ?? '';
        if (isEditMode) {
          controller.addColumn(newTitle, existingColumn.id);
        } else {
          controller.addColumn(newTitle);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspaceService = Get.find<WorkspaceService>();
    final bool isInvalidState = controller.isWorkspaceMode && workspaceService.selectedWorkspace.value == null;

    if (isInvalidState) {
      // --- RENDER THE PROMPT SCREEN ---
      // If the state is invalid, we return a completely different UI.
      return Scaffold(
        appBar: SizzleNavBar(),
        backgroundColor: Colors.white,
        body: const Center(
          child: Text(
            'Select a Workspace to continue!', // Changed text to be more instructive
            style: TextStyle(fontSize: 24, color: Colors.black54),
          ),
        ),
      );
    } else {
    final theme = Theme.of(context);
    const double appBarHeight = 75.0;
    final maxHeight = MediaQuery.of(context).size.height - appBarHeight;

    return Scaffold(
      appBar: SizzleNavBar(),
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // --- STYLISTIC ELEMENTS PRESERVED ---
            Positioned.fill(
              child: Image.asset('assets/harvest.jpg', fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withAlpha(100)),
            ),
            Obx(() {
              // --- NEW LOADING STATE ---
              // Shows a progress indicator while data is being fetched.
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              // Shows the "empty" message if there are no columns.
              if (controller.columns.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "No columns yet. Add one to get started!",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Add Column"),
                        onPressed: () => _showAddColumnDialog(context),
                      )
                    ],
                  ),
                );
              }
              
              // --- MAIN UI RENDERED FROM REFINED HELPER METHODS ---
              return ConstrainedBox(
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
              );
            }),
          ],
        ),
      ),
    );
  }
    
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (choice) {
                if (choice == 'Edit') {
                  _showAddColumnDialog(context, column);
                } else if (choice == 'Delete') {
                  controller.deleteColumn(column.id);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'Edit', child: Text('Edit')),
                PopupMenuItem(value: 'Delete', child: Text('Delete')),
              ],
            ),
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