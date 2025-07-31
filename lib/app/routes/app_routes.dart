// lib/app/routes/app_routes.dart
part of 'app_pages.dart'; // Connected

abstract class Routes {
  Routes._(); // Private constructor to prevent instantiation

  static const LOGIN = _Paths.LOGIN;
  static const HOME = _Paths.HOME;
  static const TASKS = _Paths.TASKS;
  static const TEST = _Paths.TEST;
  static const SPLASH = _Paths.SPLASH;
  static const CLIPBOARD = _Paths.CLIPBOARD;
  // Other routes here aswell
}

abstract class _Paths {
  _Paths._();

  static const LOGIN = '/login';
  static const HOME = '/home';
  static const TASKS = '/tasks';
  static const TEST = '/test';
  static const SPLASH = '/splash';
  static const CLIPBOARD = '/clipboard';
  // Additional paths will be added here
}