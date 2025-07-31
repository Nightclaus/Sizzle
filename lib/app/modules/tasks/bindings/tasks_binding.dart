import 'package:get/get.dart';
import '../../../controllers/tasks_controller.dart';

class TasksBinding extends Bindings {
  @override
  void dependencies() {
    final bool isWorkspaceMode = Get.arguments as bool? ?? false;
    
    // This correctly puts the controller into a drawer labeled 'true' or 'false'.
    Get.lazyPut<TasksController>(
      () => TasksController(isWorkspaceMode: isWorkspaceMode),
      tag: isWorkspaceMode.toString(),
    );
  }
}