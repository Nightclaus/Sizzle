import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart'; 
import '../../../../general_purpose_widgets/general_purpose_widgets.dart';

class IdTokenWidget extends StatelessWidget {
  const IdTokenWidget({super.key});

  Future<String?> fetchIdToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: fetchIdToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data == null) {
          return const Text('No token found');
        } else {
          return SelectableText('ID Token: ${snapshot.data!}', style: const TextStyle(fontSize: 12));
        }
      },
    );
  }
}

class TestScreen extends GetView<AuthController> {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    // --- Test Case Data ---

    // 2. GPText: A list of styled text spans
    final List<TextSpan> textSpans = [
      const TextSpan(text: 'This is a paragraph with '),
      TextSpan(
        text: 'bold text',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
      ),
      const TextSpan(text: ' and some '),
      TextSpan(
        text: 'italic text.',
        style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.green),
      ),
       TextSpan(
        text: ' You can even add clickable text!',
        style: const TextStyle(color: Colors.purple, decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()..onTap = () {
            // ignore: avoid_print
            print('Clickable text tapped!');
        }
      ),
    ];

// 1. Form Data
final formFields = [
  {
    'key': 'name',
    'type': 'text',
    'label': 'Task Name',
    'initialValue': '',
    'required': true,
  },
  {
    'key': 'description',
    'type': 'text',
    'label': 'Description (Optional)',
    'initialValue': '',
    'maxLines': 2,
  },
  {
    'key': 'tag',
    'type': 'dropdown',
    'label': 'Tag',
    'options': ['work', 'personal', 'study'], // Using simple strings
    'initialValue': 'work',
    'required': true,
  },
  {
    'key': 'importance',
    'type': 'dropdown',
    'label': 'Importance',
    'options': ['high', 'medium', 'low'],
    'initialValue': 'medium',
    'required': true,
  },
];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authController.signOut();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Welcome!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Obx(() {
                final user = authController.firebaseUser.value;
                return Text(user?.email ?? "Not logged in", style: const TextStyle(fontSize: 16));
              }),
              const SizedBox(height: 8),
              const IdTokenWidget(),
              const Divider(height: 40, thickness: 2),

              // --- General Purpose Widgets Test Cases ---

              // 1. GPForm Test
              Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // Button to show the form for adding a new item
    ElevatedButton(
      child: const Text('Add Item'),
      onPressed: () {
        GPFormDialog.show(
          context: context,
          title: 'Add New Task',
          fields: formFields,
          submitButtonText: 'Add Task',
          onSubmit: (formData) {
            Get.snackbar(
              'New Item Added',
              'Data: ${formData.toString()}',
              snackPosition: SnackPosition.BOTTOM,
            );
          },
        );
      },
    ),
    const SizedBox(width: 16),

    // Button to show the form for editing an existing item
    ElevatedButton(
      child: const Text('Edit Item'),
      onPressed: () {
        // Simulate existing data you might get from a database
        final existingData = {
          'name': 'Refactor the UI',
          'description': 'Update all components to use the new design system.',
          'tag': 'work',
          'importance': 'high',
        };

        GPFormDialog.show(
          context: context,
          title: 'Edit Task',
          fields: formFields,
          initialData: existingData,
          submitButtonText: 'Save Changes',
          onSubmit: (formData) {
            Get.snackbar(
              'Item Updated',
              'Data: ${formData.toString()}',
              snackPosition: SnackPosition.BOTTOM,
            );
          },
        );
      },
    ),
  ],
),
              const Divider(height: 40, thickness: 2),

              // 2. GPSelectable Test (Stateful version)
              const Text("GPSelectable Example", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              // In your HomeScreen build method...

// --- Replace the old GPSelectable Test Case with this ---

// 2. GPSelectableCard Test
const Text("GPSelectableCard Example", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
const SizedBox(height: 10),
GPSelectableCard(
  title: "Implement User Authentication",
  description: "Set up Firebase Auth with email/password and Google Sign-In providers for the new mobile app.",
  tagText: "Feature",
  tagColor: Colors.blue,
  importanceText: "High",
  importanceColor: Colors.red,
  date: DateTime.now().subtract(const Duration(days: 3)),
  onEdit: () {
    Get.snackbar("Action", "Edit button clicked!", snackPosition: SnackPosition.BOTTOM);
  },
  onDelete: () {
    Get.snackbar("Action", "Delete button clicked!", snackPosition: SnackPosition.BOTTOM);
  },
  expandedChild: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'This is the expanded content. You can put checklists, sub-tasks, or any other widget here.',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    ),
  ),
),
               const SizedBox(height: 20),
              const Divider(height: 40, thickness: 2),

              // 3. GPText Test
              const Text("GPText Example", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              GPText(
                textSpans: textSpans,
                defaultStyle: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const Divider(height: 40, thickness: 2),

              // 4. GPPopup Test
              const Text("GPPopup Example", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  GPPopup.show(
                    context,
                    content: const Text('This is a general-purpose popup dialog!'),
                  );
                },
                child: const Text('Show Popup'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}