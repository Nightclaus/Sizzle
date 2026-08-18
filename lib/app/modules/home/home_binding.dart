// lib/app/modules/auth/bindings/auth_binding.dart
import 'package:get/get.dart';
import '../../controllers/workspaces_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WorkspacesController>(
      () => WorkspacesController(),
    );
  }
}