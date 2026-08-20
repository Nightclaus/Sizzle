import 'dart:collection';

import '../models/records_model.dart';

/// A mutable box for counting comparisons during benchmarking — pass one in
/// to get real algorithmic operation counts instead of relying solely on
/// wall-clock timing, which is noisy and affected by unrelated system
/// factors. Leave it null (the default) in normal application use; the
/// null-check per comparison is negligible and doesn't change any
/// algorithm's complexity.
class ComparisonCounter {
  int count = 0;
}

/// Returns the index of the first record in [records] (assumed already
/// sorted ascending by createdAt) whose createdAt is >= [target] — a
/// "lower bound" binary search. If every record's createdAt is before
/// [target], returns records.length (one past the end — the conventional
/// "not found here, insert at the end" result for this kind of search).
///
/// O(log n): each iteration discards half of whatever interval remains.
int binarySearchDate(
  List<FarmRecord> records,
  DateTime target, {
  ComparisonCounter? counter,
}) {
  var low = 0;
  var high = records.length;
  while (low < high) {
    final mid = low + ((high - low) >> 1);
    counter?.count++;
    if (records[mid].createdAt.isBefore(target)) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

/// The O(n) baseline the date index exists to beat: inspects every record
/// regardless of how far [start]/[end] narrow the actual result.
/// Interval convention: start <= createdAt < end.
List<FarmRecord> findRecordsByDateRangeLinear(
  List<FarmRecord> records,
  DateTime start,
  DateTime end, {
  ComparisonCounter? counter,
}) {
  final results = <FarmRecord>[];
  for (final record in records) {
    counter?.count++;
    if (!record.createdAt.isBefore(start)) {
      counter?.count++;
      if (record.createdAt.isBefore(end)) {
        results.add(record);
      }
    }
  }
  return results;
}

/// A secondary, one-dimensional index of FarmRecords sorted ascending by
/// createdAt — deliberately independent of the hierarchical tree. It holds
/// the *same* FarmRecord object references the tree does (no copies), just
/// in a different order for a different access pattern: "everything
/// created in this date window", which BFS/DFS can only answer by
/// inspecting every node. This index answers it in O(log n + k).
///
/// The tree (children / bfs / dfs / findById / search / findPath /
/// findParentOf, all on FarmRecord) remains the right tool for
/// hierarchical operations and is untouched by any of this — this class
/// doesn't know the tree exists, it just holds references into it.
class DateIndex {
  final List<FarmRecord> _sorted = [];

  /// Read-only view of the current sorted index. O(1) to obtain — this
  /// wraps the underlying list rather than copying it (UnmodifiableListView,
  /// not List.unmodifiable, which *does* copy and would quietly turn every
  /// external read into an O(n) operation).
  List<FarmRecord> get all => UnmodifiableListView(_sorted);

  int get length => _sorted.length;

  DateTime? get earliest => _sorted.isEmpty ? null : _sorted.first.createdAt;
  DateTime? get latest => _sorted.isEmpty ? null : _sorted.last.createdAt;

  /// Rebuilds the whole index from [records] via an explicit merge sort —
  /// O(n log n). Used for the initial bulk load (right after fetching from
  /// Firestore): sorting once here is far cheaper than n individual
  /// addToDateIndex calls, which — despite each search being O(log n) —
  /// would still be O(n^2) overall once you account for n separate O(n)
  /// array shifts.
  void rebuild(Iterable<FarmRecord> records) {
    final materialized = records.toList();
    final sorted =
        materialized.length > 1 ? _mergeSort(materialized) : materialized;
    _sorted
      ..clear()
      ..addAll(sorted);
  }

  List<FarmRecord> _mergeSort(List<FarmRecord> list) {
    if (list.length <= 1) return list;
    final mid = list.length ~/ 2;
    final left = _mergeSort(list.sublist(0, mid));
    final right = _mergeSort(list.sublist(mid));
    return _merge(left, right);
  }

  List<FarmRecord> _merge(List<FarmRecord> left, List<FarmRecord> right) {
    final merged = <FarmRecord>[];
    var i = 0, j = 0;
    while (i < left.length && j < right.length) {
      // <= keeps this stable: on a tie, the element from the left half
      // (which came first in the original list) wins.
      if (!left[i].createdAt.isAfter(right[j].createdAt)) {
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

  /// Binary-searches for the first record >= [start] and the first record
  /// >= [end], then slices between them.
  /// O(log n + k): the two searches are O(log n) each; extracting the k
  /// matching records is O(k).
  /// Interval convention: start <= createdAt < end.
  List<FarmRecord> findRecordsByDateRange(DateTime start, DateTime end) {
    final startIndex = binarySearchDate(_sorted, start);
    final endIndex = binarySearchDate(_sorted, end);
    if (startIndex >= endIndex) return [];
    return _sorted.sublist(startIndex, endIndex);
  }

  /// Inserts [record] at its correct sorted position. Finding that
  /// position is O(log n) via binary search; the actual insertion is O(n)
  /// worst case, since List.insert has to shift every element after the
  /// insertion point. The O(log n) claim is about the *search*, not the
  /// physical insert — don't conflate the two.
  void addToDateIndex(FarmRecord record) {
    final insertAt = binarySearchDate(_sorted, record.createdAt);
    _sorted.insert(insertAt, record);
  }

  /// Removes [record] (matched by id, not object identity or createdAt
  /// alone — createdAt isn't guaranteed unique) from the index, preserving
  /// sort order. Binary-searches to the start of its createdAt's
  /// duplicate-timestamp run — O(log n) — then scans that run for the
  /// matching id — O(d), where d is how many records share that exact
  /// timestamp, typically small. The physical removal is O(n) worst case,
  /// same shifting caveat as insertion.
  void removeFromDateIndex(FarmRecord record) {
    final start = binarySearchDate(_sorted, record.createdAt);
    for (var i = start;
        i < _sorted.length &&
            _sorted[i].createdAt.isAtSameMomentAs(record.createdAt);
        i++) {
      if (_sorted[i].id == record.id) {
        _sorted.removeAt(i);
        return;
      }
    }
  }
}