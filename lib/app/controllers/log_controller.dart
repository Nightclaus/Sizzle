import 'package:get/get.dart';

import '../models/log_entry_model.dart';
import '../helpers/workspace_service.dart';
import 'base_firebase_controller.dart';

enum SortType { timestamp, operation, user }

class LogsController extends BaseFirebaseController {
  final WorkspaceService _workspaceService = Get.find<WorkspaceService>();

  var logs = <LogEntry>[].obs;
  var currentSortType = SortType.timestamp.obs;

  @override
  void onInit() {
    super.onInit();
    fetchLogs();
  }

  Future<void> fetchLogs() async {
    final workspaceId = _workspaceService.selectedWorkspace.value?.id;

    final fetched = await runSafely(
      () => fetchCollection(
        firestore
            .collection('Workspaces')
            .doc(workspaceId)
            .collection('Logs')
            .orderBy('timestamp', descending: true),
        LogEntry.fromFirestore,
      ),
      errorMessage: "Could not fetch logs.",
    );

    if (fetched != null) logs.value = fetched;
  }

  /// Re-sorts the already-loaded logs locally (no refetch).
  void sortLogs(SortType newSortType) {
    currentSortType.value = newSortType;
    isLoading.value = true; // brief loading indicator for feedback

    switch (newSortType) {
      case SortType.timestamp:
        logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case SortType.operation:
        logs.sort((a, b) => a.operationType.compareTo(b.operationType));
        break;
      case SortType.user:
        logs.sort((a, b) => a.userName.compareTo(b.userName));
        break;
    }

    Future.delayed(const Duration(milliseconds: 100), () => isLoading.value = false);
  }
}