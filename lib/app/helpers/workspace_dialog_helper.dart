import 'package:get/get.dart';
import '../controllers/workspaces_controller.dart';
import '../../general_purpose_widgets.dart';

/// Shows the initial dialog to choose between creating or joining a workspace.
void showAddWorkspaceDialog() {
  final context = Get.context!;
  final controller = Get.find<WorkspacesController>();

  GPFormDialog.show(
    context: context,
    title: "Add Workspace",
    fields: [
      {
        'key': 'action', 'type': 'dropdown', 'label': 'What would you like to do?',
        'options': ['Create a new workspace', 'Join an existing workspace'],
        'initialValue': 'Create a new workspace', 'required': true,
      }
    ],
    submitButtonText: "Next",
    onSubmit: (formData) {
      // 1. Close the current "Add Workspace" dialog first
      Get.back(); 

      final action = formData['action'];
      if (action == 'Join an existing workspace') {
        _showJoinWorkspaceDialog(controller);
      } else {
        _showCreateWorkspaceDialog(controller);
      }
    },
  );
}

/// Shows the dialog to create a new workspace.
void _showCreateWorkspaceDialog(WorkspacesController controller) {
  GPFormDialog.show(
    context: Get.context!,
    title: "Create Workspace",
    fields: [{'key': 'name', 'type': 'text', 'label': 'Workspace Name', 'required': true}],
    submitButtonText: "Create",
    onSubmit: (formData) async {
      try {
        final name = formData['name'] as String;
        await controller.createWorkspace(name);
        
        // 2. Close the dialog on successful creation
        Get.back(); 
      } catch (e) {
        // Handle or show error if creation fails, keeping the dialog open
      }
    },
  );
}

/// Shows the dialog to join a workspace using a code.
void _showJoinWorkspaceDialog(WorkspacesController controller) {
  GPFormDialog.show(
    context: Get.context!,
    title: "Join Workspace",
    fields: [{'key': 'join_code', 'type': 'text', 'label': 'Enter Join Code', 'required': true}],
    submitButtonText: "Join",
    onSubmit: (formData) async {
      try {
        final code = formData['join_code'] as String;
        await controller.joinWorkspace(code);
        
        // 2. Close the dialog on successfully joining
        Get.back(); 
      } catch (e) {
        // Handle or show error if joining fails, keeping the dialog open
      }
    },
  );
}