import 'package:get/get.dart';
import 'task_model.dart';

class TaskColumn {
  final String id;
  String title;
  RxList<Task> tasks = <Task>[].obs;

  TaskColumn({
    required this.id,
    required this.title,
    List<Task>? initialTasks,
  }) {
    if (initialTasks != null) {    // generating test views
      tasks.addAll(initialTasks);
    }
  }

  double get getHeight => tasks.length * 137; // Getter for height
  double get getFullHeight => (tasks.isEmpty) ? getHeight + 130 : getHeight + 150; // Better bottom for empty columns
}