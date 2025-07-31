import 'package:get/get.dart';
import '../../../controllers/clipboard_controller.dart';

class ClipboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ClipboardController>(
      () => ClipboardController(),
    );
  }
}