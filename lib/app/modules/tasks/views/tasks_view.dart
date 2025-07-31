import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizzle/app/models/task_column_model.dart';
import 'package:sizzle/app/modules/tasks/widgets/add_task_dialog.dart';
import '../../../controllers/auth_controller.dart'; // For sign out
import '../../../controllers/tasks_controller.dart';
import '../widgets/task_card_widget.dart'; // For Widget Tasks
import '../../../models/task_model.dart';
import '../../../../general_purpose_widgets/general_purpose_widgets.dart';
import '../../../helpers/nav_bar.dart'; // SizzleNavBar()

class TasksPage extends GetView<TasksController> {
  final AuthController authController = Get.find<AuthController>(); // For logout
  final double  defaultColumnWidth = 300;

  Color lightenColor(Color color, [int amount = 100]) {
    return Color.alphaBlend(Colors.white.withAlpha(amount), color);
  }

  void _showAddColumnDialog(BuildContext context, [TaskColumn? existingColumn]) {
    // 1. Set up mode-specific variables
    final bool editMode = existingColumn != null;
    final String dialogTitle = editMode ? "Edit Column" : "Add New Column";
    final String submitText = editMode ? "Finish" : "Add";

    // 2. Define the form structure as data
    //    This replaces the manual Column, Text, and TextField.
    final formFields = [
      {
        'key': 'title',
        'type': 'text',
        'label': 'Column Title',
        'required': true,
      },
      // Note: The descriptive text ("Get started by...") is omitted for simplicity,
      // as our GPFormDialog focuses purely on the form fields.
    ];

    // 3. Set initial data for edit mode
    final initialData = editMode ? {'title': existingColumn.title} : null;

    // 4. Call our reusable General Purpose Widget
    GPFormDialog.show(
      context: context,
      title: dialogTitle,
      fields: formFields,
      initialData: initialData,
      submitButtonText: submitText,
      // The submission logic is now neatly contained in this callback.
      onSubmit: (formData) {
        // The GPFormDialog already validates that the field isn't empty
        // because we set 'required': true.
        final String newTitle = (formData['title'] as String?)?.trim() ?? '';

        if (editMode) {
          controller.addColumn(newTitle, existingColumn.id);
        } else {
          controller.addColumn(newTitle);
        }
        // Get.back() is handled automatically by GPFormDialog on success.
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height - 75;
    final tasksController = Get.find<TasksController>();

    return Scaffold(
      appBar: SizzleNavBar(),
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/harvest.jpg', fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withAlpha(100)),
            ),
            Obx(() {
              if (controller.columns.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("No columns yet. Add one to get started!"),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Add Column"),
                        onPressed: () => _showAddColumnDialog(context),
                      )
                    ],
                  ),
                );
              }
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight), // still respected
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: controller.columns.map((column) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        /// Column initiation
                        child: GPColumn<Task>(
                          width: defaultColumnWidth,
                          onAccept: (task) {
                            controller.moveTask(
                              task: task,
                              fromColumn: controller.getColumnByTask(task)!,
                              toColumn: column,
                            );
                          },

                          // --- HEADER ---
                          header: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8, bottom: 8, left: 3, right: 36),
                                    child: Text(
                                      column.title,
                                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (choice) {
                                        if (choice == 'Edit') {
                                          _showAddColumnDialog(context, column);
                                        } else if (choice == 'Delete') {
                                          tasksController.deleteColumn(column.id);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(value: 'Edit', child: Text('Edit')),
                                        PopupMenuItem(value: 'Delete', child: Text('Delete')),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Container(height: 2, color: theme.primaryColor),
                            ],
                          ),

                          // --- BODY ---
                          body: Obx(
                            () => ListView.builder(
                              shrinkWrap: true,
                              itemCount: column.tasks.length,
                              itemBuilder: (ctx, taskIndex) {
                                final task = column.tasks[taskIndex];
                                final card = TaskCardWidget(task: task);
                                // The Draggable wrapper remains here, as it's specific to the items
                                // within the column, not the column itself.
                                return Draggable<Task>(
                                  data: task,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: SizedBox(width: defaultColumnWidth - 24, child: card),
                                  ),
                                  childWhenDragging: Opacity(opacity: 0.5, child: card),
                                  child: card,
                                );
                              }
                            ),
                          ),

                          // --- FOOTER ---
                          footer: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 40),
                              foregroundColor: lightenColor(theme.primaryColor.withAlpha(60), 150),
                              backgroundColor: theme.colorScheme.primary.withAlpha(200),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Add a card"),
                            onPressed: () => showAddTaskDialog(context, column.id),
                          ),
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