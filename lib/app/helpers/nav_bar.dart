import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/app_pages.dart'; // Import your routes
import '../controllers/auth_controller.dart'; // Import your routes

class SizzleNavBar extends StatelessWidget implements PreferredSizeWidget {
  /// An optional list of action widgets to display on the right side.
  final List<Widget>? actions;

  const SizzleNavBar({Key? key, this.actions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AuthController authController = Get.find<AuthController>();

    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 2.0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Static brand text
          const Text(
            "Sizzle",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(width: 24),
          _buildNavButton(
            title: 'Workspaces',
            route: Routes.HOME,
            theme: theme,
          ),

          _buildNavButton(
            title: 'Tasks',
            route: Routes.TASKS,
            theme: theme,
          ),

          // _buildNavButton(
          //   title: 'My Farm',
          //   route: Routes.FARM,
          //   theme: theme,
          // ),

          _buildNavButton(
            title: 'Logs',
            route: Routes.LOGS,
            theme: theme,
          ),

          Spacer(),

          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Sign Out",
            onPressed: () {
              // This calls the signOut method on the global AuthController instance.
              authController.signOut();
            },
          ),
        ],
      ),
      actions: actions,
    );
  }

  /// --- THE NEW, MORE POWERFUL HELPER METHOD ---
  ///
  /// Builds a navigation button.
  /// - [onPressed] is an optional custom callback.
  /// - If [onPressed] is null, it defaults to simple navigation (`Get.offAllNamed`).
  Widget _buildNavButton({
    required String title,
    required String route,
    required ThemeData theme,
    VoidCallback? onPressed, // <-- Optional custom action
  }) {
    // Determine if this button's route is the currently active one.
    // This is purely for styling.
    final bool isActive = Get.currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: TextButton(
        // If a custom `onPressed` is provided, use it. Otherwise, use the default.
        onPressed: onPressed ?? () => Get.offAllNamed(route),
        style: TextButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? theme.primaryColor : Colors.black87,
            decoration: isActive ? TextDecoration.underline : TextDecoration.none,
            decorationThickness: 2,
            decorationColor: theme.primaryColor,
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}