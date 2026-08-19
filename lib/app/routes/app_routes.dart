// lib/app/routes/app_routes.dart
part of 'app_pages.dart'; // Connected

abstract class Routes {
  Routes._(); // Private constructor to prevent instantiation

  static const LOGIN = _Paths.LOGIN;
  static const HOME = _Paths.HOME;
  static const TASKS = _Paths.TASKS;
  static const SPLASH = _Paths.SPLASH;
  static const RECORDS = _Paths.RECORDS;
  // Other routes here aswell
}

abstract class _Paths {
  _Paths._();

  static const LOGIN = '/login';
  static const HOME = '/home';
  static const TASKS = '/tasks';
  static const RECORDS = '/records';
  static const SPLASH = '/splash';
}