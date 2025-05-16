// lib/app/routes/app_routes.dart
part of 'app_pages.dart'; // Connected

abstract class Routes {
  Routes._(); // Private constructor to prevent instantiation

  static const LOGIN = _Paths.LOGIN;
  static const HOME = _Paths.HOME;
  // Other routes here aswell
}

abstract class _Paths {
  _Paths._();

  static const LOGIN = '/login';
  static const HOME = '/home';
  // Additional paths will be added here
}