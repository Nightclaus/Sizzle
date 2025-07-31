import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/app_pages.dart'; // Import your routes

class SizzleNavBar extends StatelessWidget implements PreferredSizeWidget {
  /// An optional list of action widgets to display on the right side.
  final List<Widget>? actions;

  const SizzleNavBar({Key? key, this.actions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      // We use a white/light background for a clean look
      backgroundColor: Colors.white,
      foregroundColor: Colors.black, // Makes icons and text black
      elevation: 2.0, // A subtle shadow
      automaticallyImplyLeading: false, // We handle all navigation, so no back button

      // The title is now our main navigation row
      title: Row(
        children: [
          // This part is static, inspired by your design
          const Text(
            "Sizzle /",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(width: 24),

          // Navigation buttons
          _buildNavButton(
            title: 'Workspaces',
            route: Routes.HOME, // Assuming HOME is your workspaces screen
            theme: theme,
          ),
          _buildNavButton(
            title: 'My Tasks',
            route: Routes.TASKS,
            theme: theme,
          ),
          _buildNavButton(
            title: 'Clipboard',
            route: Routes.CLIPBOARD,
            theme: theme,
          ),
          // _buildNavButton(
          //   title: 'My Farm',
          //   route: Routes.FARM,
          //   theme: theme,
          // ),
        ],
      ),
      actions: actions,
    );
  }

  /// Helper method to build a single navigation button.
  /// It styles itself based on whether its route is currently active.
  Widget _buildNavButton({
    required String title,
    required String route,
    required ThemeData theme,
  }) {
    // Check if this button's route is the current active route
    final bool isActive = Get.currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: TextButton(
        // Use Get.offAllNamed to clear the navigation stack, which is common
        // for top-level navigation. Use Get.toNamed for other cases.
        onPressed: () => Get.offAllNamed(route),
        style: TextButton.styleFrom(
          // Remove the default splash effect for a cleaner look
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