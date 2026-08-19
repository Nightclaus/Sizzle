import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../models/task_model.dart';
import '../../../controllers/tasks_controller.dart';
import 'add_task_dialog.dart'; 
import '../../../../general_purpose_widgets.dart';

class TaskCardWidget extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap; 

  const TaskCardWidget({super.key, required this.task, this.onTap});

  Color lightenColor(Color color, [int amount = 100]) {
    return Color.alphaBlend(Colors.white.withAlpha(amount), color);
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Removed isWorkspaceMode and tag search!
    final TasksController tasksController = Get.find<TasksController>(); 

    return GPSelectableCard(
      title: task.name,
      description: task.description,
      tagText: task.tag.asString, 
      tagColor: task.tagColor,
      importanceText: task.importance.asString,
      importanceColor: task.importanceColor,
      date: DateTime.now().subtract(const Duration(days: 3)),
      onEdit: () {
        showAddTaskDialog(context, task.parentId, task);
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