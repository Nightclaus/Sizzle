import 'package:get/get.dart';
import '../../../controllers/log_controller.dart';

class LogsBinding extends Bindings {
  @override
  void dependencies() {
    // Get the workspaceId passed as an argument from the previous screen.
    
    Get.lazyPut<LogsController>(
      () => LogsController(),
    );
  }
}