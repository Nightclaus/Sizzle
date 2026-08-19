import 'package:get/get.dart';
import '../models/workspace_model.dart'; // Make sure path is correct

class WorkspaceService extends GetxController {
  final Rx<Workspace?> selectedWorkspace = Rx<Workspace?>(null);

  void selectWorkspace(Workspace workspace) {
    if (selectedWorkspace.value?.id != workspace.id) {
      selectedWorkspace.value = workspace;
    }
  }

  void clearWorkspace() {
    selectedWorkspace.value = null;
  }
}