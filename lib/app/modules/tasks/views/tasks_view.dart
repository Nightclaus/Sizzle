import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizzle/app/models/task_column_model.dart';
import 'package:sizzle/app/modules/tasks/widgets/add_task_dialog.dart';
import '../../../controllers/auth_controller.dart'; // For sign out
import '../../../controllers/tasks_controller.dart';
import '../widgets/task_card_widget.dart'; // For Widget Tasks
import '../../../models/task_model.dart';
import '../../../../general_purpose_widgets/general_purpose_widgets.dart';



// Note: All helper methods (_showAddColumnDialog, etc.) and the Scaffold/AppBar
// remain unchanged as they are part of the page's logic. The changes are
// focused entirely within the ListView.builder's itemBuilder.

class TasksPage extends GetView<TasksController> {
    // ... (All code before the build method remains the same) ...
  final AuthController authController = Get.find<AuthController>(); // For logout
  final double  defaultColumnWidth = 300;

  Color lightenColor(Color color, [int amount = 100]) {
    return Color.alphaBlend(Colors.white.withAlpha(amount), color);
  }


  void _showAddColumnDialog(BuildContext context, [TaskColumn? existingColumn]) {
    final theme = Theme.of(context);

    bool editMode = false;
    if (existingColumn != null) {
      editMode = true;
    }

    final TextEditingController columnTitleController = TextEditingController(text: editMode ? existingColumn!.title : "");

    Get.dialog(
      AlertDialog(
        title: Text(editMode ? "Edit Column" : "Add New Column"),
        backgroundColor: Colors.white,
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: editMode ? 80 : 120,
            maxWidth: 200
          ), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(editMode 
                ? "Edit your title!" 
                : "Get started by setting the name of the new group, they can hold as many tasks as you need!"
              ),
              TextField(
                controller: columnTitleController,
                decoration: const InputDecoration(hintText: "Column Title"),
                autofocus: true,
              )
            ]
          )
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: lightenColor(theme.primaryColor.withAlpha(60), 150),
              backgroundColor: theme.primaryColor,
            ),
            onPressed: () {
              if (columnTitleController.text.trim().isNotEmpty) {
                if (editMode) {
                  existingColumn!.title = columnTitleController.text.trim();
                  controller.updateColumnToDatabase(existingColumn);
                } else {
                  controller.addColumn(columnTitleController.text.trim());
                }
                Get.back();
              } else {
                Get.snackbar("Error", "Column title cannot be empty.",
                snackPosition: SnackPosition.BOTTOM);
              }
            },
            child: Text(editMode ? "Finish" : "Add"),
          )
        ],
      ),
    );
  }

  String getOriginId(List<Task?> itemCurrentlyDragged) {
    try {
      return controller.getColumnByTask(itemCurrentlyDragged[0]!).id;
    } catch (e) {
      return '';
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height - 75;
    final tasksController = Get.find<TasksController>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(width: 9),
            Text("Sizle /", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(" My Tasks"),
          ]
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: "Add Column",
            onPressed: () => _showAddColumnDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Sign Out",
            onPressed: () => authController.signOut(),
          )
        ],
      ),
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
                    children: controller.columns.map((column) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        
                        child: GPColumn<Task>(
                          width: defaultColumnWidth,
                          onAccept: (task) {
                            controller.moveTask(
                              task,
                              fromColumn: controller.getColumnByTask(task),
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