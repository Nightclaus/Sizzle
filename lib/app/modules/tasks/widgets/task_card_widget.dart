import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../models/task_model.dart';
import '../../../controllers/tasks_controller.dart';
import '../../../forms/add_task_dialog.dart';

class TaskCardWidget extends StatefulWidget {
  final Task task;
  final VoidCallback? onTap;

  const TaskCardWidget({super.key, required this.task, this.onTap});

  @override
  State<TaskCardWidget> createState() => _TaskCardWidgetState();
}

class _TaskCardWidgetState extends State<TaskCardWidget> {
  bool _isExpanded = false;

  Task get task => widget.task;

  TasksController get _tasksController => Get.find<TasksController>();

  static final DateFormat _dateFormat = DateFormat('MMM d');

  void _handleEdit(BuildContext context) {
    showAddTaskDialog(context, task.parentId, task);
  }

  void _handleDelete() {
    _tasksController.deleteTask(task.parentId, task.id);
    Get.snackbar(
      "Operation",
      "Deleted ${task.name}",
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // NOTE: preserved from the original implementation — this always shows
    // "3 days ago" regardless of the task's actual date. Flagging this in
    // case it was meant to read from `task.date` (or similar) instead.
    final displayDate = DateTime.now().subtract(const Duration(days: 3));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: theme.primaryColor.withAlpha(90),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        onTap: () {
          widget.onTap?.call();
          setState(() => _isExpanded = !_isExpanded);
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding:
              const EdgeInsets.only(top: 3, right: 12, left: 12, bottom: 12),
          child: Stack(
            children: [
              SizedBox(
                height: 35,
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      iconSize: 20.0,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _handleEdit(context),
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      iconSize: 20.0,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _handleDelete,
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
                      _buildTag(task.tag.asString, task.tagColor),
                      const SizedBox(width: 6),
                      _buildTag(task.importance.asString, task.importanceColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 80),
                    child: Text(
                      task.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(right: 80),
                      child: Text(
                        task.description,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 14, color: theme.hintColor),
                      const SizedBox(width: 4),
                      Text(
                        _dateFormat.format(displayDate),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ),
                  if (_isExpanded) ...[
                    const Divider(height: 20, thickness: 1),
                    _buildExpandedContent(),
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

  Widget _buildExpandedContent() {
    return Container(
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
    );
  }
}

extension StringExtension on String {
  String get capitalizeFirst => "${this[0].toUpperCase()}${substring(1)}";
}