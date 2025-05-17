import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../models/task_model.dart';
import '../../../controllers/tasks_controller.dart'; // To find TasksController

Future<void> showAddTaskDialog(BuildContext context, String columnId) async {
  final tasksController = Get.find<TasksController>();
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  var selectedTag = TaskTag.work.obs;
  var selectedImportance = TaskImportance.medium.obs;
  final Uuid uuid = const Uuid();
  final theme = Theme.of(context);
  Color lightenColor(Color color, [int amount = 100]) {
    return Color.alphaBlend(Colors.white.withAlpha(amount), color);
  }
  Color dropdownMenuColor = lightenColor(theme.primaryColor, 70);

  return Get.dialog( // Using Get.dialog for simplicity
    AlertDialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: 24
      ),
      title: const Text('Add New Task'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: SizedBox(
            width: 300,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Task Name'),
                validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
              ),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description (Optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Obx(() => DropdownButtonFormField<TaskTag>(
                    decoration: const InputDecoration(labelText: 'Tag'),
                    dropdownColor: dropdownMenuColor,
                    value: selectedTag.value,
                    items: TaskTag.values
                        .map((tag) => DropdownMenuItem(
                              value: tag,
                              child: Text(tag.toString().split('.').last.capitalizeFirst!),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) selectedTag.value = value;
                    },
                  )),
              Obx(() => DropdownButtonFormField<TaskImportance>(
                    decoration: const InputDecoration(labelText: 'Importance'),
                    dropdownColor: dropdownMenuColor,
                    value: selectedImportance.value,
                    items: TaskImportance.values
                        .map((imp) => DropdownMenuItem(
                              value: imp,
                              child: Text(imp.toString().split('.').last.capitalizeFirst!),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) selectedImportance.value = value;
                    },
                  )),
            ],
          ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8))
            )
          ),
          child: const Text('Cancel'),
          onPressed: () => Get.back(),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor: lightenColor(theme.primaryColor.withAlpha(60), 150),
            backgroundColor: theme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8))
            )
          ),
          child: const Text('Add Task'),
          onPressed: () {
            if (formKey.currentState!.validate()) {
              final newTask = Task(
                id: uuid.v4(), // Used v4 for full randomness
                name: nameController.text.trim(),
                description: descriptionController.text.trim(),
                tag: selectedTag.value,
                importance: selectedImportance.value,
              );
              tasksController.addTaskToColumn(columnId, newTask);
              Get.back(); // Close the dialog
            }
          },
        ),
      ],
    ),
  );
}