import 'package:get/get.dart';
import '../models/workspace_model.dart'; // Make sure path is correct

class WorkspaceService extends GetxController {
  // --- THE GLOBAL STATE VARIABLE ---
  // Any part of the app can listen to this.
  final Rx<Workspace?> selectedWorkspace = Rx<Workspace?>(null);

  /// Sets the currently active workspace for the entire application.
  void selectWorkspace(Workspace workspace) {
    if (selectedWorkspace.value?.id != workspace.id) {
      print("Switching global workspace to: ${workspace.name} (ID: ${workspace.id})");
      selectedWorkspace.value = workspace;
    }
  }

  /// Clears the currently selected workspace, e.g., on logout or when returning to the workspace list.
  void clearWorkspace() {
    print("Clearing global workspace selection.");
    selectedWorkspace.value = null;
  }
}