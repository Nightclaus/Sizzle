// lib/app/routes/app_pages.dart

import 'package:get/get.dart';
import 'package:sizzle/app/modules/tasks/bindings/tasks_binding.dart';
import 'package:sizzle/app/modules/tasks/views/tasks_view.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/login_screen.dart';
import '../modules/test/bindings/test_binding.dart';
import '../modules/test/views/test_screen.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/clipboard/bindings/clipboard_binding.dart';
import '../modules/clipboard/views/clipboard_view.dart';
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
      name: _Paths.TEST,
      page: () => TestScreen(),
      binding: TestBinding(),
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
      name: _Paths.CLIPBOARD,
      page: () => ClipboardScreen(),
      binding: ClipboardBinding(),
    ),
    GetPage( // Used, NavBar uses toNamed to pass argument but this is needed to seperate Tasks from Team
      name: _Paths.TEAM,
      page: () => TasksPage(),
      binding: TasksBinding(),
    ),
    GetPage(
      name: _Paths.SPLASH,
      page: () => SplashScreen(),
    ),
  ];
}