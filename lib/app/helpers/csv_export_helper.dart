import '../models/records_model.dart';
import 'csv_download/csv_download.dart';

/// Splits [flatRecords] by concrete type and writes three CSV files
/// (Animals / Equipment / Inventory) — each preserving every field that
/// type's model defines — then triggers a client-side download for each
/// non-empty file. Folders are container nodes with no type-specific
/// fields of their own, so they're excluded from all three sheets;
/// browse those in the app's tree view instead.
///
/// [resolveDisplayName] and [folderPathFor] are optional. When supplied,
/// every row also gets a resolved author/editor name (alongside the raw
/// handle, which is always included) and a breadcrumb-style folder path —
/// context that only exists on the tree and would otherwise be lost once
/// records are flattened into rows.
Future<void> exportFarmRecordsToCsv(
  List<FarmRecord> flatRecords, {
  String Function(String? handle)? resolveDisplayName,
  String? Function(String recordId)? folderPathFor,
  DateTime Function()? now,
}) async {
  final timestamp = _timestampFor(now?.call() ?? DateTime.now());

  final animals = flatRecords.whereType<Animal>().toList();
  final equipment = flatRecords.whereType<Equipment>().toList();
  final inventory = flatRecords.whereType<Inventory>().toList();

  if (animals.isNotEmpty) {
    await downloadCsvFile(
      'animals_$timestamp.csv',
      _buildAnimalsCsv(animals, resolveDisplayName, folderPathFor),
    );
  }
  if (equipment.isNotEmpty) {
    await downloadCsvFile(
      'equipment_$timestamp.csv',
      _buildEquipmentCsv(equipment, resolveDisplayName, folderPathFor),
    );
  }
  if (inventory.isNotEmpty) {
    await downloadCsvFile(
      'inventory_$timestamp.csv',
      _buildInventoryCsv(inventory, resolveDisplayName, folderPathFor),
    );
  }
}

// ---------------------------------------------------------------------
// Shared base columns — every FarmRecord field that isn't type-specific.
// ---------------------------------------------------------------------

const _baseHeaders = [
  'id',
  'name',
  'description',
  'location',
  'folderPath',
  'isActive',
  'createdAt',
  'updatedAt',
  'createdByHandle',
  'createdByName',
  'updatedByHandle',
  'updatedByName',
];

List<dynamic> _baseValues(
  FarmRecord r,
  String Function(String? handle)? resolveDisplayName,
  String? Function(String recordId)? folderPathFor,
) {
  return [
    r.id,
    r.name,
    r.description ?? '',
    r.location,
    folderPathFor?.call(r.id) ?? '',
    r.isActive,
    r.createdAt.toIso8601String(),
    r.updatedAt.toIso8601String(),
    r.createdByHandle ?? '',
    resolveDisplayName != null ? resolveDisplayName(r.createdByHandle) : '',
    r.updatedByHandle ?? '',
    resolveDisplayName != null ? resolveDisplayName(r.updatedByHandle) : '',
  ];
}

// ---------------------------------------------------------------------
// Animals
// ---------------------------------------------------------------------

String _buildAnimalsCsv(
  List<Animal> records,
  String Function(String? handle)? resolveDisplayName,
  String? Function(String recordId)? folderPathFor,
) {
  const typeHeaders = [
    'species',
    'breed',
    'sex',
    'dateOfBirth',
    'weight',
    'healthStatus',
    'lastVaccination',
    'nextVaccination',
    'lastVetCheck',
    'isPregnant',
    'expectedBirth',
    'requiresAttention',
  ];

  final rows = <List<dynamic>>[
    [..._baseHeaders, ...typeHeaders],
    for (final a in records)
      [
        ..._baseValues(a, resolveDisplayName, folderPathFor),
        a.species,
        a.breed,
        a.sex,
        a.dateOfBirth.toIso8601String(),
        a.weight ?? '',
        a.healthStatus,
        a.lastVaccination?.toIso8601String() ?? '',
        a.nextVaccination?.toIso8601String() ?? '',
        a.lastVetCheck?.toIso8601String() ?? '',
        a.isPregnant,
        a.expectedBirth?.toIso8601String() ?? '',
        a.requiresAttention,
      ],
  ];
  return _toCsv(rows);
}

// ---------------------------------------------------------------------
// Equipment
// ---------------------------------------------------------------------

String _buildEquipmentCsv(
  List<Equipment> records,
  String Function(String? handle)? resolveDisplayName,
  String? Function(String recordId)? folderPathFor,
) {
  const typeHeaders = [
    'equipmentType',
    'manufacturer',
    'model',
    'serialNumber',
    'purchaseDate',
    'purchasePrice',
    'currentValue',
    'operatingHours',
    'warrantyExpiry',
    'insuranceExpiry',
    'lastService',
    'nextServiceHours',
    'maintenanceCost',
    'depreciation',
    'requiresAttention',
  ];

  final rows = <List<dynamic>>[
    [..._baseHeaders, ...typeHeaders],
    for (final e in records)
      [
        ..._baseValues(e, resolveDisplayName, folderPathFor),
        e.equipmentType,
        e.manufacturer,
        e.model,
        e.serialNumber,
        e.purchaseDate.toIso8601String(),
        e.purchasePrice,
        e.currentValue,
        e.operatingHours,
        e.warrantyExpiry?.toIso8601String() ?? '',
        e.insuranceExpiry?.toIso8601String() ?? '',
        e.lastService?.toIso8601String() ?? '',
        e.nextServiceHours ?? '',
        e.maintenanceCost,
        e.depreciation,
        e.requiresAttention,
      ],
  ];
  return _toCsv(rows);
}

// ---------------------------------------------------------------------
// Inventory
// ---------------------------------------------------------------------

String _buildInventoryCsv(
  List<Inventory> records,
  String Function(String? handle)? resolveDisplayName,
  String? Function(String recordId)? folderPathFor,
) {
  const typeHeaders = [
    'category',
    'unit',
    'quantity',
    'minimumStock',
    'reorderLevel',
    'unitCost',
    'expiryDate',
    'purchaseDate',
    'batchNumber',
    'supplier',
    'totalValue',
    'needsReordering',
    'isExpired',
    'requiresAttention',
  ];

  final rows = <List<dynamic>>[
    [..._baseHeaders, ...typeHeaders],
    for (final i in records)
      [
        ..._baseValues(i, resolveDisplayName, folderPathFor),
        i.category,
        i.unit,
        i.quantity,
        i.minimumStock,
        i.reorderLevel,
        i.unitCost,
        i.expiryDate?.toIso8601String() ?? '',
        i.purchaseDate?.toIso8601String() ?? '',
        i.batchNumber ?? '',
        i.supplier ?? '',
        i.totalValue,
        i.needsReordering,
        i.isExpired,
        i.requiresAttention,
      ],
  ];
  return _toCsv(rows);
}

// ---------------------------------------------------------------------
// CSV formatting utilities
// ---------------------------------------------------------------------

String _toCsv(List<List<dynamic>> rows) {
  final buffer = StringBuffer();
  for (final row in rows) {
    buffer.writeln(row.map(_csvField).join(','));
  }
  return buffer.toString();
}

/// RFC 4180-style field escaping: quote (and double up internal quotes)
/// whenever the value contains a comma, quote, or newline.
String _csvField(dynamic value) {
  final s = value?.toString() ?? '';
  final needsQuoting =
      s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r');
  if (!needsQuoting) return s;
  return '"${s.replaceAll('"', '""')}"';
}

String _timestampFor(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}${two(dt.month)}${two(dt.day)}_'
      '${two(dt.hour)}${two(dt.minute)}${two(dt.second)}';
}