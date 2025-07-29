import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../models/task_model.dart';
import '../../../controllers/tasks_controller.dart';
//import 'add_task_dialog.dart'; // Edit Button, Edit mode has not been re-added yet
import '../../../../general_purpose_widgets/general_purpose_widgets.dart';

// TODO : Make a getHeight() function to make the column expansion more smooth

class TaskCardWidget extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap; // For opening task details later

  const TaskCardWidget({super.key, required this.task, this.onTap});

  Color lightenColor(Color color, [int amount = 100]) {
    return Color.alphaBlend(Colors.white.withAlpha(amount), color);
  }

  @override
  Widget build(BuildContext context) {
    final tasksController = Get.find<TasksController>();
    return GPSelectableCard(
      title: task.name,
      description: task.description,
      tagText: task.tag.asString, // Avoiding Legacy
      tagColor: task.tagColor,
      importanceText: task.importance.asString,
      importanceColor: task.importanceColor,
      date: DateTime.now().subtract(const Duration(days: 3)),
      onEdit: () {
        Get.snackbar("Action", "Edit button clicked!", snackPosition: SnackPosition.BOTTOM);
      },
      onDelete: () {
        tasksController.deleteTask(task.parentId, task.id);
        Get.snackbar("Operation", "Deleted ${task.name}",
        snackPosition: SnackPosition.BOTTOM);
      },
      expandedChild: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'This is the expanded content. You can put checklists, sub-tasks, or any other widget here.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom String method for capitalising string
extension StringExtension on String {
  String get capitalizeFirst => "${this[0].toUpperCase()}${substring(1)}";
}