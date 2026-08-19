import 'dart:convert';

import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/workspace_service.dart';
import '../models/records_model.dart';

/// Where a record currently sits: the record itself, its immediate parent
/// (null if it's a top-level root), and which root index in
/// [RecordsController.records] its tree belongs to.
class RecordLocation {
  final FarmRecord record;
  final FarmRecord? parent;
  final int rootIndex;

  RecordLocation({
    required this.record,
    required this.parent,
    required this.rootIndex,
  });
}

class RecordsController extends GetxController {
  final WorkspaceService _workspaceService = Get.find<WorkspaceService>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Each entry is a top-level record (its own tree); the collection as a
  // whole is a forest — a workspace can have several root-level
  // Folders/Animals/etc. side by side.
  RxList<FarmRecord> records = <FarmRecord>[].obs;
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
      final snapshot = await _firestore
          .collection('Workspaces')
          .doc(activeWs.id)
          .collection('Records')
          .get();

      final parsed = <FarmRecord>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawJson = data['data_as_json'] as String? ?? '{}';
        try {
          final Map<String, dynamic> map = jsonDecode(rawJson);
          map['id'] = doc.id;
          parsed.add(FarmRecord.fromMap(map));
        } catch (e) {
          print("Skipping malformed record ${doc.id}: $e");
        }
      }

      records.value = parsed;
    } catch (e) {
      print("Error loading records: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // -------------------------------------------------------------------
  // BFS-backed read access. Each of these runs the relevant FarmRecord
  // traversal once per root and merges results — the BFS itself lives on
  // the model (FarmRecord.bfs/findById/search/findPath/findParentOf).
  // -------------------------------------------------------------------

  List<FarmRecord> get allRecordsFlat =>
      records.expand((root) => root.bfs()).toList();

  FarmRecord? findRecordById(String id) {
    for (final root in records) {
      final match = root.findById(id);
      if (match != null) return match;
    }
    return null;
  }

  List<FarmRecord> searchRecords(bool Function(FarmRecord record) test) {
    return records.expand((root) => root.search(test)).toList();
  }

  /// Case-insensitive name search across the whole forest, via BFS.
  List<FarmRecord> searchByName(String query) {
    if (query.trim().isEmpty) return [];
    final lower = query.toLowerCase();
    return searchRecords((r) => r.name.toLowerCase().contains(lower));
  }

  List<FarmRecord>? getPathTo(String id) {
    for (final root in records) {
      final path = root.findPath(id);
      if (path != null) return path;
    }
    return null;
  }

  String? getFolderPathString(String id, {String separator = ' / '}) {
    final path = getPathTo(id);
    if (path == null) return null;
    return path.map((r) => r.name).join(separator);
  }

  /// Finds [id] anywhere in the forest and reports its parent + which root
  /// tree it belongs to (both via BFS). Backs move/update/delete below,
  /// and lets the viewer validate drop targets before calling moveRecord.
  RecordLocation? locate(String id) {
    for (var i = 0; i < records.length; i++) {
      final root = records[i];
      if (root.id == id) {
        return RecordLocation(record: root, parent: null, rootIndex: i);
      }
      final match = root.findById(id);
      if (match != null) {
        final parent = root.findParentOf(id);
        return RecordLocation(record: match, parent: parent, rootIndex: i);
      }
    }
    return null;
  }

  /// A client-generated id for a new record, before it's ever persisted.
  String generateId() => _firestore.collection('Records').doc().id;

  // -------------------------------------------------------------------
  // Mutations — mutate the in-memory forest, then re-persist whichever
  // root doc(s) actually changed.
  // -------------------------------------------------------------------

  /// Creates [record] as a new top-level root ([parentId] null) or nested
  /// inside the Folder identified by [parentId] (located via BFS).
  Future<void> createRecord(FarmRecord record, {String? parentId}) async {
    if (parentId == null) {
      records.add(record);
      await _persistRoot(record);
    } else {
      final location = locate(parentId);
      if (location == null) {
        throw ArgumentError('Parent $parentId not found.');
      }
      if (location.record is! Folder) {
        throw ArgumentError('Records can only be created inside a Folder.');
      }
      (location.record as Folder).addChild(record);
      await _persistRoot(records[location.rootIndex]);
    }
    records.refresh();
  }

  /// Replaces [updated]'s own fields in place, preserving its existing
  /// children and its current position in the tree.
  Future<bool> updateRecord(FarmRecord updated) async {
    final location = locate(updated.id);
    if (location == null) return false;

    updated.children
      ..clear()
      ..addAll(location.record.children);

    if (location.parent == null) {
      records[location.rootIndex] = updated;
      await _persistRoot(updated);
    } else {
      final siblings = location.parent!.children;
      final childIndex = siblings.indexWhere((c) => c.id == updated.id);
      if (childIndex == -1) return false;
      siblings[childIndex] = updated;
      await _persistRoot(records[location.rootIndex]);
    }

    records.refresh();
    return true;
  }

  /// Deletes the record (and, implicitly, its whole subtree) identified
  /// by [id], wherever it sits in the forest.
  Future<bool> deleteRecord(String id) async {
    final location = locate(id);
    if (location == null) return false;

    if (location.parent == null) {
      records.removeAt(location.rootIndex);
      await _deleteRootDoc(id);
    } else {
      location.parent!.removeChild(id);
      await _persistRoot(records[location.rootIndex]);
    }

    records.refresh();
    return true;
  }

  /// Moves [recordId] out of its current parent (or off the top-level
  /// roots list) and into the Folder identified by [newParentId] — both
  /// located via BFS. This is what a drag-and-drop drop event should call.
  Future<bool> moveRecord(String recordId, String newParentId) async {
    if (recordId == newParentId) return false;

    final source = locate(recordId);
    if (source == null) return false;

    final destinationBefore = locate(newParentId);
    if (destinationBefore == null) return false;
    if (destinationBefore.record is! Folder) {
      throw ArgumentError('Can only drop records onto a Folder.');
    }

    // Reject moving a folder into its own descendant — would create a
    // cycle and break every traversal.
    if (source.record.findById(newParentId) != null) {
      throw ArgumentError('Cannot move a folder into its own descendant.');
    }

    final moving = source.record;

    if (source.parent == null) {
      records.removeAt(source.rootIndex);
    } else {
      source.parent!.removeChild(recordId);
    }

    // Re-locate the destination fresh: removing a root above it in the
    // list would have shifted every later rootIndex.
    final destination = locate(newParentId)!;
    (destination.record as Folder).addChild(moving);

    // Persist whichever root(s) actually changed — dedup by id in case
    // the move happened within the same tree.
    final rootsToPersist = <String, FarmRecord>{};
    final destRoot = records[destination.rootIndex];
    rootsToPersist[destRoot.id] = destRoot;
    if (source.parent != null) {
      final oldRootLocation = locate(source.parent!.id);
      if (oldRootLocation != null) {
        final oldRoot = records[oldRootLocation.rootIndex];
        rootsToPersist[oldRoot.id] = oldRoot;
      }
    }
    for (final root in rootsToPersist.values) {
      await _persistRoot(root);
    }
    if (source.parent == null) {
      // The moved node used to be its own standalone doc — gone now that
      // it's embedded inside another root's tree.
      await _deleteRootDoc(moving.id);
    }

    records.refresh();
    return true;
  }

  /// Detaches [recordId] from its current parent and promotes it to a
  /// top-level root with its own Firestore doc (the inverse of a nested
  /// move — used when something is dragged out to the top level).
  Future<bool> moveToRoot(String recordId) async {
    final source = locate(recordId);
    if (source == null) return false;
    if (source.parent == null) return true; // already a root

    source.parent!.removeChild(recordId);
    final oldRoot = records[source.rootIndex];

    records.add(source.record);
    await _persistRoot(source.record);
    await _persistRoot(oldRoot);

    records.refresh();
    return true;
  }

  // -------------------------------------------------------------------
  // Firestore persistence helpers
  // -------------------------------------------------------------------

  Future<void> _persistRoot(FarmRecord root) async {
    final activeWs = _workspaceService.selectedWorkspace.value;
    if (activeWs == null) return;
    await _firestore
        .collection('Workspaces')
        .doc(activeWs.id)
        .collection('Records')
        .doc(root.id)
        .set({'data_as_json': root.toJson()}, SetOptions(merge: true));
  }

  Future<void> _deleteRootDoc(String rootId) async {
    final activeWs = _workspaceService.selectedWorkspace.value;
    if (activeWs == null) return;
    await _firestore
        .collection('Workspaces')
        .doc(activeWs.id)
        .collection('Records')
        .doc(rootId)
        .delete();
  }
}