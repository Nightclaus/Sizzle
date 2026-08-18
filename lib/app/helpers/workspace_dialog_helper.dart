//import 'package:flutter/material.dart';
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
      final name = formData['name'] as String;
      await controller.createWorkspace(name);
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
      final code = formData['join_code'] as String;
      await controller.joinWorkspace(code);
    },
  );
}