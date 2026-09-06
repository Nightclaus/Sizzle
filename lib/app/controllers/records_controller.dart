import 'dart:convert';

import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/records_model.dart';
import '../models/user_profile_data.dart';
import '../helpers/date_index.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'workspaces_controller.dart';
import '../helpers/csv_export_helper.dart';

const RECORDS = "_records";

/// Fields records can be sorted by. author/editor sort by the *resolved
/// display name*, not the raw handle — sorting by handle would put people
/// in a different order than what's actually shown on screen.
enum RecordSortField { createdAt, updatedAt, name, author, editor }

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

  // Current user's handle. Prefers whatever WorkspacesController already
  // has loaded in its `userProfile` Rx — avoids a duplicate Firestore
  // round trip and stays consistent with whatever the rest of the app
  // considers "the current user" — falling back to a direct fetch at
  // UserData/{uid}/ProfileData/main if that controller isn't registered
  // yet or hasn't loaded a profile yet. Only the successful result is
  // cached, never null, so a call that fails early (e.g. before
  // WorkspacesController has loaded) will simply retry next time rather
  // than sticking with a stale null.
  // Caveat: if the signed-in user changes mid-session (sign out/in) this
  // stale-caches the old one; not handling that here since it's a step
  // beyond what was asked, but flagging it as a real gap.
  String? _cachedCurrentHandle;

  Future<String?> _currentUserHandle() async {
    if (_cachedCurrentHandle != null) return _cachedCurrentHandle;

    try {
      final existing = Get.find<WorkspacesController>().userProfile.value;
      if (existing != null) {
        _cachedCurrentHandle = existing.handle;
        return existing.handle;
      }
    } catch (_) {
      // WorkspacesController not registered, or not reachable this way in
      // your DI setup — fall through to a direct fetch below.
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // ignore: avoid_print
      print('[RecordsController] _currentUserHandle: no signed-in '
          'FirebaseAuth user, and WorkspacesController has no cached '
          'profile either — author/editor will be stamped null.');
      return null;
    }

    try {
      final doc = await _firestore
          .collection('UserData')
          .doc(uid)
          .collection('ProfileData')
          .doc('main')
          .get();
      if (!doc.exists) {
        // ignore: avoid_print
        print('[RecordsController] _currentUserHandle: no '
            'UserData/$uid/ProfileData/main doc.');
        return null;
      }
      final profile = UserProfileData.fromMap(doc.data()!);
      if (profile.handle.isEmpty || profile.handle == 'No Handle') {
        // ignore: avoid_print
        print('[RecordsController] _currentUserHandle: profile exists but '
            'has no handle field set.');
      }
      _cachedCurrentHandle = profile.handle;
      return profile.handle;
    } catch (e) {
      // ignore: avoid_print
      print('[RecordsController] _currentUserHandle: lookup threw — $e');
      return null;
    }
  }

  // handle -> display name cache. Populated lazily via displayNameFor
  // (called from the UI) and pre-warmed in bulk after fetchRecords, so
  // names are usually already resolved by the time anything renders. An
  // RxMap so any Obx reading displayNameFor rebuilds once a name actually
  // resolves.
  final RxMap<String, String> _displayNameCache = <String, String>{}.obs;

  /// Resolves a handle to a display name. Returns the cached name once
  /// resolved; until then (and if resolution fails, e.g. the handle no
  /// longer matches anyone — see the trade-off note on FarmRecord), falls
  /// back to showing the raw handle so the UI always has *something*
  /// rather than blanking.
  String displayNameFor(String? handle) {
    // Touch the cache unconditionally, before any early return — a caller
    // wrapping this in Obx needs a real Rx read on every code path, or
    // GetX throws its "no observables found" assertion on records where
    // the handle is null (no author/editor stamped yet). Reading .length
    // is enough to register the dependency; the value itself is unused.
    // ignore: unnecessary_statements
    _displayNameCache.length;

    if (handle == null || handle.isEmpty) return 'Unknown';
    final cached = _displayNameCache[handle];
    if (cached != null) return cached;
    _resolveDisplayName(handle); // fire-and-forget; updates cache async
    return handle;
  }

  Future<void> _resolveDisplayName(String handle) async {
    if (_displayNameCache.containsKey(handle)) return;
    _displayNameCache[handle] = handle; // placeholder — stops duplicate fetches
    try {
      // Profiles live at UserData/{uid}/ProfileData/main — a subcollection
      // under each user, not a top-level collection — so finding "the user
      // with this handle" needs a collectionGroup query, not a regular one.
      // NOTE: this requires a Firestore collection-group index on
      // ProfileData.handle. If this throws failed-precondition, Firestore's
      // error message includes a direct link to create it.
      final query = await _firestore
          .collectionGroup('ProfileData')
          .where('handle', isEqualTo: handle)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final profile = UserProfileData.fromMap(query.docs.first.data());
        _displayNameCache[handle] = profile.name;
      }
    } catch (e) {
      // ignore: avoid_print
      print('[RecordsController] _resolveDisplayName($handle): query '
          'threw — $e. If this says failed-precondition, follow the link '
          'in the error to create the required index.');
      // Leave the handle placeholder in place — already a reasonable
      // fallback.
    }
  }

  Future<void> _prewarmDisplayNames(Iterable<FarmRecord> allRecords) async {
    final handles = <String>{};
    for (final r in allRecords) {
      if (r.createdByHandle != null) handles.add(r.createdByHandle!);
      if (r.updatedByHandle != null) handles.add(r.updatedByHandle!);
    }
    await Future.wait(handles.map(_resolveDisplayName));
  }

  @override
  void onInit() {
    super.onInit();
    fetchRecords();
  }

  Future<void> fetchRecords() async {

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
      _prewarmDisplayNames(parsed.expand((root) => root.dfs())); // fire-and-forget
    } catch (e) {
      print("Error loading records: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // -------------------------------------------------------------------
  // CSV export — flattens the forest (DFS, via allRecordsFlat) and hands
  // it to the CSV helper, which splits it back out by concrete type into
  // three files (Animals / Equipment / Inventory) and triggers the actual
  // download. Folders carry no type-specific fields, so they're filtered
  // out before the helper ever sees the list.
  // -------------------------------------------------------------------
  Future<void> exportRecordsAsCsv() async {
    final flat = allRecordsFlat.where((r) => r is! Folder).toList();

    // The CSV is a one-shot snapshot, not a rebuilding Obx widget — resolve
    // every author/editor handle it references *before* writing rows, so
    // the file isn't full of raw handles that would've resolved a moment
    // later on screen.
    await _prewarmDisplayNames(flat);

    await exportFarmRecordsToCsv(
      flat,
      resolveDisplayName: displayNameFor,
      folderPathFor: getFolderPathString,
    );
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

  /// Every record authored by [handle], via DFS across the forest.
  List<FarmRecord> filterByAuthor(String handle) =>
      filterRecordsDfs((r) => r.createdByHandle == handle);

  /// Every record whose most recent edit was by [handle], via DFS.
  List<FarmRecord> filterByEditor(String handle) =>
      filterRecordsDfs((r) => r.updatedByHandle == handle);

  /// Distinct author handles present anywhere in the forest — for
  /// populating an author-filter dropdown.
  List<String> get distinctAuthorHandles => allRecordsFlat
      .map((r) => r.createdByHandle)
      .whereType<String>()
      .toSet()
      .toList();

  /// Distinct editor handles present anywhere in the forest — for
  /// populating a last-editor-filter dropdown.
  List<String> get distinctEditorHandles => allRecordsFlat
      .map((r) => r.updatedByHandle)
      .whereType<String>()
      .toSet()
      .toList();

  /// Every record touched by [handle] — as author, editor, or both (the
  /// same field if it's never been edited since creation). This is the
  /// one the single "filter by user" dropdown uses; filterByAuthor/
  /// filterByEditor above stay available separately for anyone who wants
  /// the narrower, single-field version.
  List<FarmRecord> filterByContributor(String handle) => filterRecordsDfs(
      (r) => r.createdByHandle == handle || r.updatedByHandle == handle);

  /// Distinct handles that appear as either author or editor anywhere in
  /// the forest — for populating the single "filter by user" dropdown.
  List<String> get distinctContributorHandles => {
        ...distinctAuthorHandles,
        ...distinctEditorHandles,
      }.toList();

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
      case RecordSortField.author:
        result = displayNameFor(a.createdByHandle)
            .toLowerCase()
            .compareTo(displayNameFor(b.createdByHandle).toLowerCase());
        break;
      case RecordSortField.editor:
        result = displayNameFor(a.updatedByHandle)
            .toLowerCase()
            .compareTo(displayNameFor(b.updatedByHandle).toLowerCase());
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
    final handle = await _currentUserHandle();
    record.createdByHandle = handle;
    record.updatedByHandle = handle;

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

    // Authorship never changes on edit; editorship always does.
    updated.createdByHandle = previous.createdByHandle;
    updated.updatedByHandle = await _currentUserHandle();

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
    await _firestore
        .collection('Workspaces')
        .doc(RECORDS)
        .collection('Records')
        .doc(root.id)
        .set({'data_as_json': root.toJson()}, SetOptions(merge: true));
  }

  Future<void> _deleteRootDoc(String rootId) async {
    await _firestore
        .collection('Workspaces')
        .doc(RECORDS)
        .collection('Records')
        .doc(rootId)
        .delete();
  }
}