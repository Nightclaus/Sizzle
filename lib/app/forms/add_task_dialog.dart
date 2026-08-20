import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../controllers/tasks_controller.dart';
import 'general_purpose_widgets.dart';

Future<void> showAddTaskDialog(BuildContext context, String columnId, [Task? existingTask]) async {
  // FIXED: No longer searching by tag!
  final TasksController tasksController = Get.find<TasksController>();
  final Uuid uuid = const Uuid();

  bool editMode = existingTask != null;

  // Define the structure of your form.
  final formFields = [
    {
      'key': 'name',
      'type': 'text',
      'label': 'Task Name',
      'initialValue': editMode ? existingTask.name : '',
      'required': true,
    },
    {
      'key': 'description',
      'type': 'text',
      'label': 'Description (Optional)',
      'initialValue': editMode ? existingTask.description : '',
      'maxLines': 2,
    },
    {
      'key': 'tag',
      'type': 'dropdown',
      'label': 'Tag',
      'options': const ['work', 'passion'], 
      'initialValue': editMode ? existingTask.tag.asString :'work',
      'required': true,
    },
    {
      'key': 'importance',
      'type': 'dropdown',
      'label': 'Importance',
      'options': const ['high', 'medium', 'low'],
      'initialValue': editMode ? existingTask.importance.asString : 'medium',
      'required': true,
    },
  ];

  return GPWFormDialog.show(
    context: context,
    title: editMode ? 'Edit Task' : 'Add New Task',
    fields: formFields,
    submitButtonText: editMode ? 'Edit' : 'Add Task',
    onSubmit: (formData) {
      Get.snackbar(
        'New Item Added',
        'Data: ${formData.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );

      late Task newTask;
      
      if (!editMode) {
        newTask = Task(
          id: uuid.v4(), 
          name: formData['name'],
          description: formData['description'],
          tag: getTaskTag(formData['tag'])!,
          importance: getTaskImportance(formData['importance'])!,
          parentId: columnId,
        );
      } else {
        newTask = Task(
          id: existingTask.id,
          name: formData['name'],
          description: formData['description'],
          tag: getTaskTag(formData['tag'])!,
          importance: getTaskImportance(formData['importance'])!,
          parentId: columnId,
        );
      }
      tasksController.addTask(columnId, newTask);
    },
  );
}