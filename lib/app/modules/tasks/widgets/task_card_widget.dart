import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/task_model.dart';

class TaskCardWidget extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap; // For opening task details later

  const TaskCardWidget({super.key, required this.task, this.onTap});

  Color lightenColor(Color color, [int amount = 100]) {
    return Color.alphaBlend(Colors.white.withAlpha(amount), color);
  }

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row for tags/labels (similar to Trello)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: task.tagColor.withAlpha(120),      // Use 60 and remove lighten colour to switch the roles
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      task.tag.toString().split('.').last.capitalizeFirst,
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
                      task.importance.toString().split('.').last.capitalizeFirst,
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
        ),
      ),
    );
  }
}

// Custom String method for capitalising string
extension StringExtension on String {
  String get capitalizeFirst => "${this[0].toUpperCase()}${substring(1)}";
}