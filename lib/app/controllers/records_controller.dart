import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/workspace_service.dart';

class RecordsController extends GetxController {
  final WorkspaceService _workspaceService = Get.find<WorkspaceService>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RxList<Map<String, dynamic>> records = <Map<String, dynamic>>[].obs;
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchRecords();
  }

  Future<void> fetchRecords() async {
    final activeWs = _workspaceService.selectedWorkspace.value;
    if (activeWs == null) return;

    isLoading.value = true;
    try {
      // Accessing Workspaces -> _records -> Records subcollection
      final snapshot = await _firestore
          .collection('Workspaces')
          .doc(activeWs.id)
          .collection('Records')
          .get();

      // Read raw data and prepare for 'data_as_json' parsing later
      records.value = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Placeholder default if data_as_json field is missing in the database
        if (!data.containsKey('data_as_json')) {
          data['data_as_json'] = '{}'; 
        }
        return data;
      }).toList();
    } catch (e) {
      print("Error loading records: $e");
    } finally {
      isLoading.value = false;
    }
  }
}