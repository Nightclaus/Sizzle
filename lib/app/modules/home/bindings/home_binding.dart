// lib/app/modules/home/bindings/home_binding.dart
import 'package:get/get.dart';
// import '../controllers/home_controller.dart'; // Not created yet

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Get.lazyPut<HomeController>(() => HomeController()); // fenix: true
    // If not, and you need it here:
    // Get.lazyPut<AuthController>(() => AuthController(), fenix: true); // fenix: true keeps it alive
  }
}