import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/records_controller.dart';
import '../../helpers/nav_bar.dart';
import '../../models/records_model.dart';
import '../../helpers/record_form_dialog.dart';

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

  static const _bg = Color(0xFFFAF8F5);
  static const _cardColor = Color(0xFFC7B9A9);
  static const _textColor = Color(0xFF3E2F23);
  static const _accent = Color(0xFF948473);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                    child: CircularProgressIndicator(color: _accent));
              }

              if (_query.trim().isNotEmpty) {
                return _buildSearchResults();
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
            }),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Search mode — flat results from the controller's BFS search, each
  // annotated with its folder path (also BFS, via findPath).
  // -------------------------------------------------------------------
  Widget _buildSearchResults() {
    final results = controller.searchByName(_query);

    if (results.isEmpty) {
      return Center(
        child: Text('No records match "$_query".',
            style: const TextStyle(fontSize: 16, color: Colors.black54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final record = results[index];
        final path = controller.getFolderPathString(record.id);
        return Card(
          color: _cardColor,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(_iconFor(record), color: _textColor),
            title: Text(record.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: _textColor)),
            subtitle: Text(path ?? record.getSummary(),
                style: const TextStyle(fontStyle: FontStyle.italic)),
            trailing: _rowActions(record),
            onTap: () => _openRecord(record),
          ),
        );
      },
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
        subtitle: Text(record.getSummary()),
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
  final String? folderPath;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecordDetailSheet({
    required this.record,
    required this.folderPath,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fields = record.toMap()
      ..remove('children')
      ..remove('type')
      ..remove('id');

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