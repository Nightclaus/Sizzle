import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import '../../../models/task_model.dart';
import '../../../controllers/tasks_controller.dart';
import '../../../../general_purpose_widgets/general_purpose_widgets.dart';

Future<void> showAddTaskDialog(BuildContext context, String columnId, [Task? existingTask]) async {
  final bool isWorkspaceMode = Get.arguments as bool? ?? false;
  final TasksController tasksController = Get.find<TasksController>(tag: isWorkspaceMode.toString());
  final Uuid uuid = const Uuid();

  bool editMode = false; // ie title: Text((editMode ? 'Edit Task' : 'Add New Task')),
  if (existingTask != null) {
    editMode = true;
  }

  // Define the structure of your form. This can be stored anywhere.
  final formFields = [
    {
      'key': 'name',
      'type': 'text',
      'label': 'Task Name',
      'initialValue': '',
      'required': true,
    },
    {
      'key': 'description',
      'type': 'text',
      'label': 'Description (Optional)',
      'initialValue': '',
      'maxLines': 2,
    },
    {
      'key': 'tag',
      'type': 'dropdown',
      'label': 'Tag',
      'options': ['work', 'passion'], // Using simple strings
      'initialValue': 'work',
      'required': true,
    },
    {
      'key': 'importance',
      'type': 'dropdown',
      'label': 'Importance',
        'options': ['high', 'medium', 'low'],
        'initialValue': 'medium',
        'required': true,
      },
    ];

    return GPFormDialog.show(
      context: context,
      title: 'Add New Task',
      fields: formFields,
      submitButtonText: 'Add Task',
      onSubmit: (formData) {
        Get.snackbar(
          'New Item Added',
          'Data: ${formData.toString()}',
          snackPosition: SnackPosition.BOTTOM,
        );

        late Task newTask;
        //if (formData.isNotEmpty) {
        if (!editMode) {
          newTask = Task(
            id: uuid.v4(), // Used v4 for full randomness
            name: formData['name'],
            description: formData['description'],
            tag: getTaskTag(formData['tag'])!,
            importance: getTaskImportance(formData['importance'])!,
            parentId: columnId,
          );
        } else { // TODO : RE-ADD EDIT FUNCTION
          newTask = Task(
            id: uuid.v4(), // Used v4 for full randomness
            name: formData['name'],
            description: formData['description'],
            tag: getTaskTag(formData['tag'])!,
            importance: getTaskImportance(formData['importance'])!,
            parentId: columnId,
          );
          //tasksController.clearTask(columnId, originalId);
        }
        tasksController.addTask(columnId, newTask);
        Get.back(); // Close the dialog
      },
    );
  }