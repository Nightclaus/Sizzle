// lib/app/routes/app_pages.dart
import 'package:get/get.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/login_screen.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_screen.dart';

part 'app_routes.dart'; // Connected

class AppPages {
  AppPages._();

  // TODO: Implement logic to check auth state and set initial route accordingly
  static const INITIAL = Routes.LOGIN; // Might have a splash screen but that is tbd

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
  ];
}