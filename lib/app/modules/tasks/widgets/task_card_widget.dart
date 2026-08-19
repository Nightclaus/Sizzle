import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../models/task_model.dart';
import '../../../controllers/tasks_controller.dart';
import 'add_task_dialog.dart'; 

class tasks_card_widget extends StatefulWidget {
  // Content Parameters
  final String title;
  final String description;
  final String tagText;
  final Color tagColor;
  final String importanceText;
  final Color importanceColor;
  final DateTime date;
  final Widget expandedChild;

  // Interaction Parameters
  final bool isExpandable;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onClick;

  const tasks_card_widget({
    Key? key,
    required this.title,
    this.description = '',
    required this.tagText,
    this.tagColor = Colors.grey,
    required this.importanceText,
    this.importanceColor = Colors.blue,
    required this.date,
    required this.expandedChild,
    this.isExpandable = true,
    this.onEdit,
    this.onDelete,
    this.onClick,
  }) : super(key: key);

  @override
  _tasks_card_widget createState() => _tasks_card_widget();
}

class _tasks_card_widget extends State<tasks_card_widget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: theme.primaryColor.withAlpha(90),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        onTap: () {
          widget.onClick?.call();

          if (widget.isExpandable) {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          }
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.only(top: 3, right: 12, left: 12, bottom: 12),
          child: Stack(
            children: [
              if (widget.onEdit != null || widget.onDelete != null)
                SizedBox(height: 35, child: 
                  Row(
                    children: [
                      const Spacer(), 
                      if (widget.onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          iconSize: 20.0,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: widget.onEdit,
                        ),
                      if (widget.onEdit != null && widget.onDelete != null)
                        const SizedBox(width: 5),
                      if (widget.onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete),
                          iconSize: 20.0,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: widget.onDelete,
                        ),
                    ],
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      _buildTag(widget.tagText, widget.tagColor),
                      const SizedBox(width: 6),
                      _buildTag(widget.importanceText, widget.importanceColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 80), 
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(right: 80), 
                      child: Text(
                        widget.description,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: theme.hintColor),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(widget.date),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isExpanded) ...[
                    const Divider(height: 20, thickness: 1),
                    widget.expandedChild,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final formattedText = text.length > 1
        ? '${text[0].toUpperCase()}${text.substring(1)}'
        : text.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        formattedText,
        style: TextStyle(
          color: color, 
          fontSize: 10, 
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}


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

    return tasks_card_widget(
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