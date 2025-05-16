// lib/app/modules/auth/views/login_screen.dart
import 'package:flutter/material.dart';
//import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../controllers/auth_controller.dart';
// String? idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

class LoginScreen extends GetView<AuthController> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= 450) {
      return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/harvest.jpg',
              fit: BoxFit.cover, // Ensures it fully covers the background
            ),
          ), 
          Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
              child: Container( 
                padding: EdgeInsets.only(
                  top: 15,
                  left: 35,
                  right: 35,
                  bottom: 25
                ),
                color: Colors.white,
                child: content(context)
              ),
            ),
          ),
          ),
        ])
      );
    } else {
      return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/harvest.jpg',
              fit: BoxFit.cover, // Ensures it fully covers the background
            ),
          ), 
          Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320, maxHeight: 500),
              child: Container( 
                padding: EdgeInsets.only(
                  top: 15,
                  left: 20,
                  right: 20,
                  bottom: 25
                ),
                color: Colors.white,
                child: content(context)
              ),
            ),
          ),
          ),
        ])
      );
    }
  }

  Widget content(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          //FlutterLogo(size: 80, style: FlutterLogoStyle.markOnly),
          //const SizedBox(height: 20),

          Obx(() => Text(
                controller.isLoginMode.value ? 'Sign in' : 'Create account',
                textAlign: TextAlign.start,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
              )),
          const SizedBox(height: 24),

          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email address',
              hintText: 'someone@example.com',
              prefixIcon: Icon(Icons.email_outlined, color: theme.hintColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: theme.dividerColor)),
              filled: true,
              fillColor: isDarkMode ? theme.colorScheme.surface.withOpacity(0.1) : Colors.grey[100],
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your email';
              if (!GetUtils.isEmail(value)) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline, color: theme.hintColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: theme.dividerColor)),
              filled: true,
              fillColor: isDarkMode ? theme.colorScheme.surface.withOpacity(0.1) : Colors.grey[100],
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your password';
              if (value.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 24),

          Obx(() {
            if (controller.errorMessage.value.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  controller.errorMessage.value,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          Obx(() => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: controller.isLoading.value
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          if (controller.isLoginMode.value) {
                            controller.signInWithEmailPassword(
                              _emailController.text.trim(),
                              _passwordController.text.trim(),
                            );
                          } else {
                            controller.signUpWithEmailPassword(
                              _emailController.text.trim(),
                              _passwordController.text.trim(),
                            );
                          }
                        }
                      },
                child: controller.isLoading.value
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                        ),
                      )
                    : Text(controller.isLoginMode.value ? 'Sign in' : 'Create account'),
              )),
          const SizedBox(height: 16),

          Obx(() => TextButton(
                onPressed: controller.isLoading.value ? null : controller.toggleLoginMode,
                child: Text(
                  controller.isLoginMode.value ? 'No account? Create one' : 'Already have an account? Sign in',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              )),
          const SizedBox(height: 20),

          Row(
            children: <Widget>[
              Expanded(child: Divider(thickness: 1, color: theme.dividerColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text('Or', style: TextStyle(color: theme.hintColor)),
              ),
              Expanded(child: Divider(thickness: 1, color: theme.dividerColor)),
            ],
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? theme.colorScheme.surface : Colors.white,
              foregroundColor: isDarkMode ? theme.colorScheme.onSurface : Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0), side: BorderSide(color: theme.dividerColor)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            icon: FaIcon(FontAwesomeIcons.google, size: 20, color: isDarkMode ? null : Colors.redAccent),
            label: const Text('Sign in with Google'),
            onPressed: controller.isLoading.value ? null : controller.signInWithGoogle,
          ),
        ],
      ),
    );
  }
}
