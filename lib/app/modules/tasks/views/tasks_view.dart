import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizzle/app/modules/tasks/widgets/add_task_dialog.dart';
import '../../../controllers/auth_controller.dart'; // For sign out
import '../../../controllers/tasks_controller.dart';
import '../widgets/task_card_widget.dart';
import '../../../models/task_model.dart';

class TasksPage extends GetView<TasksController> {
  TasksPage({super.key});

  final AuthController authController = Get.find<AuthController>(); // For logout

  Color lightenColor(Color color, [int amount = 100]) {
    return Color.alphaBlend(Colors.white.withAlpha(amount), color);
  }

  void _showAddColumnDialog(BuildContext context) {
    final theme = Theme.of(context);
    final TextEditingController columnTitleController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text("Add New Column"),
        backgroundColor: Colors.white,
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 120,
            maxWidth: 200
          ), 
          child:Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Get started by setting the name of the new group, they can hold as many tasks as you need!"),
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
                controller.addColumn(columnTitleController.text.trim());
                Get.back();
              } else {
                Get.snackbar("Error", "Column title cannot be empty.",
                    snackPosition: SnackPosition.BOTTOM);
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height - 75;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(width: 9),
            Text("Sizle /",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
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
            onPressed: () {
              authController.signOut();
            },
          )
        ],
      ),
      backgroundColor: Colors.black,//Theme.of(context).colorScheme.primary.withAlpha(255),
      body: SizedBox.expand( // No2 Op
        child: Stack(
          children: [
            // Background image, Make dynamic
            Positioned.fill(
              child: Image.asset(
                'assets/harvest.jpg',
                fit: BoxFit.cover,
              ),
            ),

            // Overlay color
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha(100), // Adjust opacity as needed
              ),
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
              return Obx(() => 
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxHeight,
                  ),
                  child: ListView.builder( // List builder is actually no1 op
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: controller.columns.length,
                    itemBuilder: (context, index) {
                      final column = controller.columns[index];
                      return DragTarget<Task>(
                        onWillAcceptWithDetails: (task) => true,
                        onAccept: (task) {
                          controller.moveTask(task, fromColumn: controller.getColumnByTask(task), toColumn: column);
                        },
                        builder: (_, __, ___) {
                          return Stack(
                            children: [
                              Container(
                              width: 300, // Width of each column
                              height: column.getFullHeight,
                              margin: const EdgeInsets.only(right: 16.0),
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: theme.cardColor, // Or Colors.grey[200]
                                borderRadius: BorderRadius.circular(12.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withAlpha(255),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      bottom: 8,
                                      left: 3,
                                      right: 8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          column.title,
                                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        // IconButton(icon: Icon(Icons.more_vert), onPressed: () { /* Column options */ })
                                      ],
                                    ),
                                  ),
                                  Container(
                                    height: 2,
                                    width: 270,
                                    color: theme.primaryColor,
                                  ),
                                  SizedBox(
                                    height: 7,
                                  ),
                                  Obx(() => SizedBox(  // Observe changes to tasks within this specific column
                                      height: column.getHeight,
                                      child: ListView.builder(
                                        itemCount: column.tasks.length,
                                        itemBuilder: (ctx, taskIndex) {
                                          Task task = column.tasks[taskIndex];
                                          return Draggable<Task>(
                                            data: task, // This is the data you'll receive in DragTarget
                                            feedback: Material( // Must be Material to show shadows etc.
                                              color: Colors.transparent,
                                              child: SizedBox(
                                                width: 280, // match your card width
                                                child: TaskCardWidget(task: task),
                                              ),
                                            ),
                                            childWhenDragging: Opacity(
                                              opacity: 0.5,
                                              child: TaskCardWidget(task: task),
                                            ),
                                            child: TaskCardWidget(
                                              task: task,
                                              onTap: () {
                                                Get.snackbar("Task Tapped", task.name);
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 40,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(double.infinity, 40), // Make button wider
                                        foregroundColor: lightenColor(theme.primaryColor.withAlpha(60), 150),
                                        backgroundColor: WidgetStateColor.resolveWith(
                                          (Set<WidgetState> states) {
                                            return theme.colorScheme.primary.withAlpha(200);
                                          },
                                        ),
                                        overlayColor: WidgetStateColor.resolveWith((Set<WidgetState> states) {return Colors.yellow.shade600;}), // ← removes splash

                                        //elevation: 0, // Looks weird depending on my mental state
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8), // smaller radius
                                        ),
                                      ),
                                      onPressed: () => showAddTaskDialog(context, column.id),
                                      child: Row(children:[
                                        const Icon(Icons.add, size: 18), 
                                        const Text("Add a card"),
                                      ]),
                                    ),
                                  )
                                ],
                              )
                            )
                          ]);
                        }
                      );
                    },
                  )
                )
              );
            },
          )
        ])
      )
    );
  }
}