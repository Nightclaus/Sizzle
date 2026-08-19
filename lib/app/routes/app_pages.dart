// lib/app/routes/app_pages.dart

import 'package:get/get.dart';
import 'package:sizzle/app/modules/tasks/tasks_binding.dart';
import 'package:sizzle/app/modules/tasks/tasks_view.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/login_screen.dart';
import '../modules/home/home_binding.dart';
import '../modules/home/workspace_view.dart';
import '../modules/splash_screen.dart';

part 'app_routes.dart'; // Connected

class AppPages {
  AppPages._();

  static const INITIAL = Routes.LOGIN; // Change back to login after testing is finished // Might have a splash screen but that is tbd

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
    GetPage(
      name: _Paths.SPLASH,
      page: () => SplashScreen(),
    ),
  ];
}