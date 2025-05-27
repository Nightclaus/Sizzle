import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../models/task_model.dart';
import '../../../controllers/tasks_controller.dart';
import 'add_task_dialog.dart';

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
    final theme = Theme.of(context);
    final DateFormat dateFormat = DateFormat('MMM d'); // For displaying date

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
      color: theme.primaryColor.withAlpha(90),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell( // for dynamic feel
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.only(
            top: 3,
            right: 12,
            left: 12,
            bottom: 12,
          ),
          child: Stack(
            children: [
              Row(
                children: [
                Expanded( 
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.edit),
                      iconSize: 20.0,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        // Edit placeholder
                        showAddTaskDialog(context, task.parentId, task);
                        Get.snackbar(
                          "Operation",
                          "Editing ${task.name}",
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                    ),
                  ),
                ),
                
                SizedBox(width: 5,),
                IconButton(
                  icon: Icon(Icons.delete),
                  iconSize: 20.0,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    // Deleted placeholder
                    tasksController.deleteTask(task.parentId, task.id);
                    Get.snackbar("Operation", "Deleted ${task.name}",
                    snackPosition: SnackPosition.BOTTOM);
                  },
                )
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 9),
                Row( // Top row for tags/labels (similar to Trello)
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: task.tagColor.withAlpha(120),      // Use 60 and remove lighten colour to switch the roles
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        StringExtension(task.tag.toString().split('.').last).capitalizeFirst,
                        style: TextStyle(color: lightenColor(task.tagColor), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: task.importanceColor.withAlpha(120),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        StringExtension(task.importance.toString().split('.').last).capitalizeFirst,
                        style: TextStyle(color: lightenColor(task.importanceColor), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  task.name,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), // use existing format
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.description,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Placeholder for icons like comments, attachments
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 14, color: theme.hintColor),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(task.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                    // Placeholder for avatars
                    // CircleAvatar(radius: 12, child: Text(task.assigneeInitial ?? "A"))
                  ],
                )
              ],
            ),
        ]),
      )
    )
    );
  }
}

// Custom String method for capitalising string
extension StringExtension on String {
  String get capitalizeFirst => "${this[0].toUpperCase()}${substring(1)}";
}