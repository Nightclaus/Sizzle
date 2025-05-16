// lib/app/routes/app_pages.dart
import 'package:get/get.dart';
import 'package:sizzle/app/modules/tasks/bindings/tasks_binding.dart';
import 'package:sizzle/app/modules/tasks/views/tasks_view.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/login_screen.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_screen.dart';

part 'app_routes.dart'; // Connected

class AppPages {
  AppPages._();

  // TODO: Implement logic to check auth state and set initial route accordingly
  static const INITIAL = Routes.TASKS; // Change back to login after testing is finished // Might have a splash screen but that is tbd

  static final routes = [
    GetPage(
      name: _Paths.LOGIN,
      page: () => LoginScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.HOME,
      page: () => HomeScreen(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.TASKS,
      page: () => TasksPage(),
      binding: TasksBinding(),
    ),
  ];
}