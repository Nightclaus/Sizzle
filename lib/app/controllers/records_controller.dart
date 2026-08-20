import 'dart:convert';

import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/workspace_service.dart';
import '../models/records_model.dart';
import '../helpers/date_index.dart';

const RECORDS = "_records";

/// Fields records can be sorted by.
enum RecordSortField { createdAt, updatedAt, name }

enum SortDirection { ascending, descending }

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

  // Secondary index: the *same* FarmRecord objects as the trees in
  // [records], held flat and sorted by createdAt for O(log n + k)
  // date-range queries via binary search — see DateIndex for why this is
  // architecturally separate from the tree. moveRecord/moveToRoot never
  // touch this: re-parenting a node changes neither its createdAt nor its
  // object identity, so the index doesn't go stale when the tree shape
  // changes.
  final DateIndex dateIndex = DateIndex();

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
          .doc(RECORDS)
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
      dateIndex.rebuild(parsed.expand((root) => root.dfs()));
    } catch (e) {
      print("Error loading records: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // -------------------------------------------------------------------
  // Read access backed by the model's traversal methods. Most of these
  // use DFS under the hood (see FarmRecord for why) — the exception is
  // getPathTo/getFolderPathString, which need findPath's BFS shortest-path
  // guarantee for a correct breadcrumb.
  // -------------------------------------------------------------------

  List<FarmRecord> get allRecordsFlat =>
      records.expand((root) => root.dfs()).toList();

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

  // -------------------------------------------------------------------
  // Date-range queries via the secondary index. O(log n + k) — see
  // DateIndex for the binary search this is built on. Interval
  // convention matches DateIndex: start <= createdAt < end.
  // -------------------------------------------------------------------

  List<FarmRecord> findRecordsByDateRange(DateTime start, DateTime end) =>
      dateIndex.findRecordsByDateRange(start, end);

  DateTime? get earliestCreatedAt => dateIndex.earliest;
  DateTime? get latestCreatedAt => dateIndex.latest;

  // -------------------------------------------------------------------
  // DFS-backed filtering. Each of these DFS-walks every root's subtree
  // (FarmRecord.dfs) and merges the results into one flat 1D list — the
  // traversal itself lives on the model, same as the BFS methods above.
  // -------------------------------------------------------------------

  /// DFS-filters the whole forest down to instances of [T] — e.g.
  /// `filterByType<Animal>()`, `filterByType<Equipment>()`,
  /// `filterByType<Inventory>()`. Unsorted; pass the result to
  /// [mergeSort] to order it.
  List<T> filterByType<T extends FarmRecord>() {
    return records.expand((root) => root.dfs()).whereType<T>().toList();
  }

  /// DFS-filters the whole forest with an arbitrary predicate.
  List<FarmRecord> filterRecordsDfs(bool Function(FarmRecord record) test) {
    return records.expand((root) => root.dfs()).where(test).toList();
  }

  // -------------------------------------------------------------------
  // Merge sort. A standalone utility over any flat list of FarmRecord —
  // not tied to how that list was produced, so it works equally well on
  // filterByType output, filterRecordsDfs output, or searchByName output.
  // O(n log n), stable (equal elements keep their relative order).
  // -------------------------------------------------------------------

  /// Sorts [input] by [field]/[direction] using merge sort. Does not
  /// mutate [input]; returns a new list.
  List<T> mergeSort<T extends FarmRecord>(
    List<T> input, {
    required RecordSortField field,
    SortDirection direction = SortDirection.ascending,
  }) {
    if (input.length <= 1) return List<T>.from(input);

    final mid = input.length ~/ 2;
    final left = mergeSort(input.sublist(0, mid),
        field: field, direction: direction);
    final right = mergeSort(input.sublist(mid),
        field: field, direction: direction);

    return _merge(left, right, field, direction);
  }

  List<T> _merge<T extends FarmRecord>(
    List<T> left,
    List<T> right,
    RecordSortField field,
    SortDirection direction,
  ) {
    final merged = <T>[];
    var i = 0, j = 0;

    while (i < left.length && j < right.length) {
      // <= (not <) keeps the sort stable: on a tie, the element from the
      // left half — which came first in the original list — wins.
      if (_compareRecords(left[i], right[j], field, direction) <= 0) {
        merged.add(left[i]);
        i++;
      } else {
        merged.add(right[j]);
        j++;
      }
    }
    merged.addAll(left.sublist(i));
    merged.addAll(right.sublist(j));
    return merged;
  }

  int _compareRecords(
    FarmRecord a,
    FarmRecord b,
    RecordSortField field,
    SortDirection direction,
  ) {
    late final int result;
    switch (field) {
      case RecordSortField.createdAt:
        result = a.createdAt.compareTo(b.createdAt);
        break;
      case RecordSortField.updatedAt:
        result = a.updatedAt.compareTo(b.updatedAt);
        break;
      case RecordSortField.name:
        result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        break;
    }
    return direction == SortDirection.ascending ? result : -result;
  }

  /// Convenience: DFS-filter by type, then merge-sort the result in one
  /// call. Equivalent to `mergeSort(filterByType<T>(), field: ..., ...)`.
  List<T> filterAndSort<T extends FarmRecord>({
    RecordSortField field = RecordSortField.name,
    SortDirection direction = SortDirection.ascending,
  }) {
    return mergeSort(filterByType<T>(), field: field, direction: direction);
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
    dateIndex.addToDateIndex(record);
    records.refresh();
  }

  /// Replaces [updated]'s own fields in place, preserving its existing
  /// children and its current position in the tree.
  Future<bool> updateRecord(FarmRecord updated) async {
    final location = locate(updated.id);
    if (location == null) return false;

    // The date index holds object references, not ids — grab the pre-edit
    // object now, before it's replaced, so it can be swapped out below.
    final previous = location.record;

    updated.children
      ..clear()
      ..addAll(previous.children);

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

    dateIndex.removeFromDateIndex(previous);
    dateIndex.addToDateIndex(updated);

    records.refresh();
    return true;
  }

  /// Deletes the record (and, implicitly, its whole subtree) identified
  /// by [id], wherever it sits in the forest.
  Future<bool> deleteRecord(String id) async {
    final location = locate(id);
    if (location == null) return false;

    // A folder's whole subtree disappears with it, so every one of those
    // nodes needs to come out of the date index too — not just the folder.
    for (final node in location.record.dfs()) {
      dateIndex.removeFromDateIndex(node);
    }

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
        .doc(RECORDS)
        .collection('Records')
        .doc(root.id)
        .set({'data_as_json': root.toJson()}, SetOptions(merge: true));
  }

  Future<void> _deleteRootDoc(String rootId) async {
    final activeWs = _workspaceService.selectedWorkspace.value;
    if (activeWs == null) return;
    await _firestore
        .collection('Workspaces')
        .doc(RECORDS)
        .collection('Records')
        .doc(rootId)
        .delete();
  }
}