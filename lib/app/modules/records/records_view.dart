import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/records_controller.dart';
import '../../helpers/nav_bar.dart';
import '../../models/records_model.dart';
import '../../forms/record_form_dialog.dart';

class RecordsView extends StatefulWidget {
  const RecordsView({Key? key}) : super(key: key);

  @override
  State<RecordsView> createState() => _RecordsViewState();
}

class _RecordsViewState extends State<RecordsView> {
  final RecordsController controller = Get.find<RecordsController>();

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedIds = {};
  String _query = '';

  // 'All' | 'Animal' | 'Equipment' | 'Inventory' — drives filterByType via
  // the controller's DFS filter + merge sort.
  String _typeFilter = 'All';
  RecordSortField _sortField = RecordSortField.name;
  SortDirection _sortDirection = SortDirection.ascending;

  // 'All' or an actual handle — matches records where that handle is
  // EITHER the author or the editor (same field, if never edited since
  // creation). One control, not separate author/editor dropdowns.
  String _userFilter = 'All';

  // Sort is always visible/enabled — touching it (rather than requiring a
  // type/date filter to already be active) is itself what switches the
  // body from the tree to the flat, DFS-filtered, merge-sorted list.
  bool _sortActivated = false;
  bool _isExporting = false;

  // null = "no date filter, full range". Values are milliseconds-since-
  // epoch (what RangeSlider needs — it only takes doubles), normalized to
  // whole days when actually used for a query. Backed by
  // RecordsController.findRecordsByDateRange, i.e. the binary-search index.
  RangeValues? _selectedRange;

  static const _bg = Color(0xFFFAF8F5);
  static const _cardColor = Color(0xFFC7B9A9);
  static const _textColor = Color(0xFF3E2F23);
  static const _accent = Color(0xFF948473);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  Widget _buildDownloadButton() {
    return IconButton(
      tooltip: 'Download records as CSV',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _textColor,
      ),
      icon: _isExporting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
            )
          : const Icon(Icons.download),
      onPressed: _isExporting ? null : _exportCsv,
    );
}

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    try {
      await controller.exportRecordsAsCsv();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV export ready — check your downloads.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SizzleNavBar(),
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accent,
        icon: const Icon(Icons.add),
        label: const Text('New record'),
        onPressed: () => _createRecord(parentId: null),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search records…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 8),
                _buildDownloadButton(),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                    child: CircularProgressIndicator(color: _accent));
              }

              // Filter bar lives inside this same Obx (not a separate one)
              // — it needs to rebuild whenever records/isLoading changes
              // (e.g. new earliest/latest bounds for the slider after a
              // create/delete), but on its own it reads no Rx value at
              // all (earliestCreatedAt/latestCreatedAt are plain getters
              // over a non-Rx DateIndex field), so a standalone Obx around
              // it would throw GetX's "no observables found" assertion.
              return Column(
                children: [
                  _buildFilterBar(),
                  Expanded(child: _buildBody()),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_query.trim().isNotEmpty) {
      return _buildSearchResults();
    }

    if (_typeFilter != 'All' ||
        _dateRangeActive ||
        _sortActivated ||
        _userFilter != 'All') {
      return _buildFilteredList();
    }

    if (controller.records.isEmpty) {
      return const Center(
        child: Text(
          "No records found in this workspace yet.",
          style: TextStyle(fontSize: 18, color: Colors.black54),
        ),
      );
    }

    return _buildTree();
  }

  // -------------------------------------------------------------------
  // Filter bar — type filter, date-range slider, and sort are all always
  // visible and always enabled. Sort isn't gated on "already filtering":
  // touching it is itself what activates the flat, DFS-filtered,
  // merge-sorted view (see _sortActivated) — so nothing here appears or
  // disappears based on the other controls' state.
  // -------------------------------------------------------------------
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<String>(
            value: _typeFilter,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All types')),
              DropdownMenuItem(value: 'Animal', child: Text('Animals')),
              DropdownMenuItem(value: 'Equipment', child: Text('Equipment')),
              DropdownMenuItem(value: 'Inventory', child: Text('Inventory')),
            ],
            onChanged: (v) => setState(() => _typeFilter = v!),
          ),
          _buildDateRangeSlider(),
          _buildHandleFilterDropdown(
            value: _userFilter,
            handles: controller.distinctContributorHandles,
            allLabel: 'Any user',
            onChanged: (v) => setState(() => _userFilter = v),
          ),
          DropdownButton<RecordSortField>(
            value: _sortField,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                  value: RecordSortField.name, child: Text('Sort: Name')),
              DropdownMenuItem(
                  value: RecordSortField.createdAt,
                  child: Text('Sort: Created')),
              DropdownMenuItem(
                  value: RecordSortField.updatedAt,
                  child: Text('Sort: Updated')),
              DropdownMenuItem(
                  value: RecordSortField.author,
                  child: Text('Sort: Author')),
              DropdownMenuItem(
                  value: RecordSortField.editor,
                  child: Text('Sort: Editor')),
            ],
            onChanged: (v) => setState(() {
              _sortField = v!;
              _sortActivated = true;
            }),
          ),
          IconButton(
            tooltip: _sortDirection == SortDirection.ascending
                ? 'Ascending'
                : 'Descending',
            icon: Icon(_sortDirection == SortDirection.ascending
                ? Icons.arrow_upward
                : Icons.arrow_downward),
            onPressed: () => setState(() {
              _sortDirection = _sortDirection == SortDirection.ascending
                  ? SortDirection.descending
                  : SortDirection.ascending;
              _sortActivated = true;
            }),
          ),
          if (_sortActivated &&
              _typeFilter == 'All' &&
              !_dateRangeActive &&
              _userFilter == 'All')
            // Sort is the only reason we're off the tree right now — give
            // a way back that doesn't require touching the others too.
            InkWell(
              onTap: () => setState(() => _sortActivated = false),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.clear, size: 16, color: Colors.black45),
              ),
            ),
          if (_query.trim().isNotEmpty)
            const Text(
              '(search is active — clear it to see the filter)',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
        ],
      ),
    );
  }

  /// Shared builder for the author and editor dropdowns — same shape,
  /// different data source. Labels are resolved handle -> display name via
  /// controller.displayNameFor; the dropdown *value* stays the handle
  /// (stable-ish identifier) even though what's shown is the friendly name.
  Widget _buildHandleFilterDropdown({
    required String value,
    required List<String> handles,
    required String allLabel,
    required ValueChanged<String> onChanged,
  }) {
    if (handles.isEmpty) return const SizedBox.shrink();
    return DropdownButton<String>(
      value: value,
      underline: const SizedBox(),
      items: [
        DropdownMenuItem(value: 'All', child: Text(allLabel)),
        for (final handle in handles)
          DropdownMenuItem(
              value: handle, child: Text(controller.displayNameFor(handle))),
      ],
      onChanged: (v) => onChanged(v!),
    );
  }

  /// to latest — read straight off the date index, O(1), since it's
  /// already sorted). Dragging it narrows `_selectedRange`; queries against
  /// it go through RecordsController.findRecordsByDateRange, i.e. the
  /// binary-search index, not a manual scan.
  Widget _buildDateRangeSlider() {
    final earliest = controller.earliestCreatedAt;
    final latest = controller.latestCreatedAt;
    if (earliest == null || latest == null) {
      return const SizedBox.shrink(); // nothing to slide over yet
    }

    final min = earliest.millisecondsSinceEpoch.toDouble();
    final max = latest.millisecondsSinceEpoch.toDouble();
    if (max <= min) {
      return const SizedBox.shrink(); // every record on the same day
    }

    final current = _selectedRange ?? RangeValues(min, max);

    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _dateRangeActive
                    ? '${_fmtDate(_toDate(current.start))} – ${_fmtDate(_toDate(current.end))}'
                    : 'Created: any date',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              if (_dateRangeActive)
                InkWell(
                  onTap: () => setState(() => _selectedRange = null),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child:
                        Icon(Icons.clear, size: 14, color: Colors.black45),
                  ),
                ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _accent,
              thumbColor: _accent,
              overlayColor: _accent.withAlpha(40),
            ),
            child: RangeSlider(
              min: min,
              max: max,
              values: current,
              onChanged: (v) => setState(() => _selectedRange = v),
            ),
          ),
        ],
      ),
    );
  }

  /// True once the slider has actually been moved off the full extremes —
  /// small tolerance since exact double equality after a drag is fussy.
  bool get _dateRangeActive {
    final range = _selectedRange;
    final earliest = controller.earliestCreatedAt;
    final latest = controller.latestCreatedAt;
    if (range == null || earliest == null || latest == null) return false;
    final min = earliest.millisecondsSinceEpoch.toDouble();
    final max = latest.millisecondsSinceEpoch.toDouble();
    const slack = 1000; // ~1 second
    return (range.start - min).abs() > slack || (range.end - max).abs() > slack;
  }

  DateTime _toDate(double millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis.round());
    return DateTime(dt.year, dt.month, dt.day); // day granularity
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Combines the date-range slider (via [RecordsController.findRecordsByDateRange]
  /// — the binary-search index) with the type dropdown (a plain narrowing
  /// of that already-small candidate set) and merge sort. Querying the
  /// index first, then narrowing by type, means the type check only runs
  /// over the k records the date search already found — not the whole
  /// forest — which is the correct order to get real use out of the index.
  Widget _buildFilteredList() {
    final earliest = controller.earliestCreatedAt;
    final latest = controller.latestCreatedAt;
    if (earliest == null || latest == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          _buildFilteredBanner('Showing filtered results'),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('No records yet.')),
          ),
        ],
      );
    }

    final rangeStart =
        _dateRangeActive ? _toDate(_selectedRange!.start) : earliest;
    // findRecordsByDateRange is half-open [start, end) — push the end one
    // day past whatever the slider/latest-record day is, so that day's
    // records are actually included.
    final rangeEndExclusive = (_dateRangeActive
            ? _toDate(_selectedRange!.end)
            : DateTime(latest.year, latest.month, latest.day))
        .add(const Duration(days: 1));

    final inRange = controller.findRecordsByDateRange(
        rangeStart, rangeEndExclusive);

    List<FarmRecord> typed;
    switch (_typeFilter) {
      case 'Animal':
        typed = inRange.whereType<Animal>().toList();
        break;
      case 'Equipment':
        typed = inRange.whereType<Equipment>().toList();
        break;
      case 'Inventory':
        typed = inRange.whereType<Inventory>().toList();
        break;
      default:
        // 'All' still leaves out Folders here — a flat results list of
        // container nodes isn't very useful; browse those in the tree.
        typed = inRange.where((r) => r is! Folder).toList();
    }

    if (_userFilter != 'All') {
      // OR, not AND — matches this record if the selected user is either
      // its author or its editor (same field, if never edited since
      // creation).
      typed = typed
          .where((r) =>
              r.createdByHandle == _userFilter ||
              r.updatedByHandle == _userFilter)
          .toList();
    }

    final sorted = controller.mergeSort<FarmRecord>(typed,
        field: _sortField, direction: _sortDirection);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        _buildFilteredBanner('Showing filtered results'),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No records match these filters.',
                  style: TextStyle(fontSize: 16, color: Colors.black54)),
            ),
          )
        else
          for (final record in sorted) _buildRecordListTile(record),
      ],
    );
  }

  /// The card used for any flat (non-tree) row — search results and the
  /// type-filtered list both share this.
  /// "By <author>" or, once a record has actually been edited by someone
  /// else, "By <author> · edited by <editor>". Obx because names resolve
  /// asynchronously (displayNameFor may return a raw handle on first call
  /// and the real name a moment later) — this rebuilds when that happens
  /// rather than freezing on whatever was known at first paint.
  Widget _buildAuthorEditorCaption(FarmRecord record) {
    return Obx(() {
      final author = controller.displayNameFor(record.createdByHandle);
      final editedByDifferentPerson = record.updatedByHandle != null &&
          record.updatedByHandle != record.createdByHandle;
      final text = editedByDifferentPerson
          ? 'By $author · edited by ${controller.displayNameFor(record.updatedByHandle)}'
          : 'By $author';
      return Text(text,
          style: const TextStyle(fontSize: 11, color: Colors.black45));
    });
  }

  Widget _buildRecordListTile(FarmRecord record) {
    final path = controller.getFolderPathString(record.id);
    return Card(
      color: _cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_iconFor(record), color: _textColor),
        title: Text(record.name,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: _textColor)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(path ?? record.getSummary(),
                style: const TextStyle(fontStyle: FontStyle.italic)),
            _buildAuthorEditorCaption(record),
          ],
        ),
        trailing: _rowActions(record),
        onTap: () => _openRecord(record),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Search mode — flat results from the controller's DFS search, each
  // annotated with its folder path (BFS, via findPath — the one place
  // that still wants BFS's shortest-path guarantee).
  // -------------------------------------------------------------------
  Widget _buildSearchResults() {
    final results = controller.searchByName(_query);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        _buildFilteredBanner('Showing search results'),
        const SizedBox(height: 8),
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No records match "$_query".',
                  style: const TextStyle(fontSize: 16, color: Colors.black54)),
            ),
          )
        else
          for (final record in results) _buildRecordListTile(record),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Tree mode — file-explorer style: nested, expandable, draggable.
  // -------------------------------------------------------------------
  Widget _buildTree() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      children: [
        _buildRootDropZone(),
        const SizedBox(height: 8),
        for (final root in controller.records) _buildNode(root, depth: 0),
      ],
    );
  }

  /// Same padding/border/icon-slot shape as [_buildRootDropZone] — sits in
  /// that exact spot whenever the tree is replaced by a flat list, so
  /// switching between tree and filtered/search view never changes the
  /// bar's size and nothing jumps.
  Widget _buildFilteredBanner(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: _accent.withAlpha(30),
        border: Border.all(color: _accent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 16, color: Colors.black45),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      ),
    );
  }

  /// A persistent drop target at the top of the tree — dragging a nested
  /// record here promotes it back to the top level via [moveToRoot].
  Widget _buildRootDropZone() {
    return DragTarget<FarmRecord>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        controller.moveToRoot(details.data.id);
      },
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: active ? _accent.withAlpha(60) : Colors.transparent,
            border: Border.all(color: active ? _accent : Colors.black26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.vertical_align_top, size: 16, color: Colors.black45),
              SizedBox(width: 6),
              Text('Drop here to move to top level',
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNode(FarmRecord record, {required int depth}) {
    final isFolder = record is Folder;
    final isExpanded = _expandedIds.contains(record.id);

    final tile = Card(
      color: _cardColor,
      margin: EdgeInsets.only(bottom: 6, left: depth * 20.0),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFolder)
              IconButton(
                icon:
                    Icon(isExpanded ? Icons.expand_more : Icons.chevron_right),
                onPressed: () => setState(() {
                  isExpanded
                      ? _expandedIds.remove(record.id)
                      : _expandedIds.add(record.id);
                }),
              )
            else
              const SizedBox(width: 8),
            Icon(_iconFor(record), color: _textColor),
          ],
        ),
        title: Text(record.name,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: _textColor)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(record.getSummary()),
            _buildAuthorEditorCaption(record),
          ],
        ),
        trailing: _rowActions(record, parentButton: isFolder),
        onTap: () => _openRecord(record),
      ),
    );

    // Every node can be picked up and dragged...
    final draggableTile = Draggable<FarmRecord>(
      data: record,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          color: _cardColor,
          child: Text(record.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: tile,
    );

    // ...and only Folders can accept a drop (matches how the model
    // requires drop targets to be Folder in RecordsController.moveRecord).
    final row = isFolder
        ? DragTarget<FarmRecord>(
            onWillAcceptWithDetails: (details) => details.data.id != record.id,
            onAcceptWithDetails: (details) {
              if (details.data.id == record.id) return;
              try {
                controller.moveRecord(details.data.id, record.id);
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            builder: (context, candidate, rejected) {
              final active = candidate.isNotEmpty;
              return Container(
                decoration: active
                    ? BoxDecoration(
                        border: Border.all(color: _accent, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: draggableTile,
              );
            },
          )
        : draggableTile;

    if (!isFolder || !isExpanded) return row;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        for (final child in record.children)
          _buildNode(child, depth: depth + 1),
      ],
    );
  }

  Widget _rowActions(FarmRecord record, {bool parentButton = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (parentButton)
          IconButton(
            tooltip: 'Add inside',
            icon: const Icon(Icons.create_new_folder_outlined, size: 20),
            onPressed: () => _createRecord(parentId: record.id),
          ),
        IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit, size: 20),
          onPressed: () => _editRecord(record),
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete, size: 20),
          onPressed: () => _confirmDelete(record),
        ),
      ],
    );
  }

  IconData _iconFor(FarmRecord record) {
    if (record is Folder) return Icons.folder;
    if (record is Animal) return Icons.pets;
    if (record is Equipment) return Icons.agriculture;
    if (record is Inventory) return Icons.inventory_2;
    return Icons.description;
  }

  // -------------------------------------------------------------------
  // CRUD actions
  // -------------------------------------------------------------------

  Future<void> _createRecord({required String? parentId}) async {
    final created =
        await showRecordFormDialog(context, controller: controller);
    if (created == null) return;
    try {
      await controller.createRecord(created, parentId: parentId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _editRecord(FarmRecord record) async {
    final edited = await showRecordFormDialog(context,
        controller: controller, existing: record);
    if (edited == null) return;
    await controller.updateRecord(edited);
  }

  Future<void> _confirmDelete(FarmRecord record) async {
    final isFolder = record is Folder;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete record'),
        content: Text(isFolder && record.children.isNotEmpty
            ? 'Delete "${record.name}" and everything inside it? This can\'t be undone.'
            : 'Delete "${record.name}"? This can\'t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteRecord(record.id);
    }
  }

  void _openRecord(FarmRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _RecordDetailSheet(
        record: record,
        controller: controller,
        folderPath: controller.getFolderPathString(record.id),
        onEdit: () {
          Navigator.pop(context);
          _editRecord(record);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(record);
        },
      ),
    );
  }
}

class _RecordDetailSheet extends StatelessWidget {
  final FarmRecord record;
  final RecordsController controller;
  final String? folderPath;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecordDetailSheet({
    required this.record,
    required this.controller,
    required this.folderPath,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fields = record.toMap()
      ..remove('children')
      ..remove('type')
      ..remove('id')
      // Shown explicitly below (resolved to a display name), not dumped
      // as a raw handle alongside the rest of the fields.
      ..remove('createdByHandle')
      ..remove('updatedByHandle');

    return SafeArea(
      // The sheet as a whole scrolls (title, path, fields, buttons — all of
      // it), capped below full screen height. Previously only the field
      // list scrolled internally, so a long name/description or a small
      // screen could still overflow around it.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              if (folderPath != null) ...[
                const SizedBox(height: 4),
                Text(folderPath!,
                    style: const TextStyle(
                        fontStyle: FontStyle.italic, color: Colors.black54)),
              ],
              const SizedBox(height: 4),
              Text(record.recordType,
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
              // Obx, not a one-shot read: displayNameFor can return a raw
              // handle on first call and resolve the real name a moment
              // later (async Firestore lookup) — this rebuilds when it does,
              // rather than freezing on whatever was known when the sheet
              // first opened.
              Obx(() => Text(
                    'Created by ${controller.displayNameFor(record.createdByHandle)}'
                    ' · last updated by ${controller.displayNameFor(record.updatedByHandle)}',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black45),
                  )),
              const Divider(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: fields.entries
                    .where((e) => e.value != null)
                    .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text('${e.key}: ${e.value}'),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}