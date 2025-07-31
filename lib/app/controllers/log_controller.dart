import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/log_entry_model.dart';
import '../helpers/workspace_service.dart';

// Enum to define our sorting options
enum SortType { timestamp, operation, user }

class LogsController extends GetxController {
  final _firestore = FirebaseFirestore.instance;
  final WorkspaceService _workspaceService = Get.find<WorkspaceService>();

  // --- STATE VARIABLES ---
  var isLoading = true.obs;
  var logs = <LogEntry>[].obs;
  var currentSortType = SortType.timestamp.obs;


  @override
  void onInit() {
    super.onInit();

    fetchLogs();
  }

  Future<void> fetchLogs() async {
    isLoading.value = true;
    try {
      final workspaceId = _workspaceService.selectedWorkspace.value?.id;

      final snapshot = await _firestore
          .collection('Workspaces')
          .doc(workspaceId)
          .collection('Logs')
          // Always fetch sorted by most recent first
          .orderBy('timestamp', descending: true)
          .get();
      
      logs.value = snapshot.docs.map((doc) => LogEntry.fromFirestore(doc)).toList();
      
    } catch (e) {
      Get.snackbar("Error", "Could not fetch logs.");
      print("Log fetch error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /// It takes the list and re-sorts it based on the selected type.
  void sortLogs(SortType newSortType) {
    currentSortType.value = newSortType;
    isLoading.value = true; // Show a brief loading indicator for feedback
    // Partially leverages tim sort
    switch (newSortType) {
      case SortType.timestamp:
        // Sort by most recent (descending)
        logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case SortType.operation:
        // Sort alphabetically by the extracted operation type
        logs.sort((a, b) => a.operationType.compareTo(b.operationType));
        break;
      case SortType.user:
        // Sort alphabetically by the extracted user name
        logs.sort((a, b) => a.userName.compareTo(b.userName));
        break;
    }
    
    // Use a small delay to make the loading indicator visible
    Future.delayed(const Duration(milliseconds: 100), () {
      isLoading.value = false;
    });
  }
}