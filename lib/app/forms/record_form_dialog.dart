import 'package:flutter/material.dart';
import '../controllers/records_controller.dart';
import '../models/records_model.dart';
import 'general_purpose_widgets.dart';

enum _RecordKind { folder, animal, equipment, inventory }

Future<FarmRecord?> showRecordFormDialog(
  BuildContext context, {
  required RecordsController controller,
  FarmRecord? existing,
}) async {
  final kind = existing == null
      ? await _pickRecordKind(context)
      : _kindOf(existing);
  if (kind == null) return null; // cancelled the type picker

  FarmRecord? result;

  await GPWFormDialog.show(
    context: context,
    title: existing == null ? 'New ${_kindLabel(kind)}' : 'Edit ${_kindLabel(kind)}',
    submitButtonText: existing == null ? 'Create' : 'Save',
    fields: _fieldsFor(kind),
    initialData: existing == null ? null : _toFormData(existing),
    onSubmit: (formData) {
      result = _buildRecord(kind, formData,
          existing: existing, controller: controller);
    },
  );

  return result;
}

Future<_RecordKind?> _pickRecordKind(BuildContext context) {
  return showDialog<_RecordKind>(
    context: context,
    builder: (_) => SimpleDialog(
      title: const Text('What kind of record?'),
      children: _RecordKind.values
          .map((k) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, k),
                child: Text(_kindLabel(k)),
              ))
          .toList(),
    ),
  );
}

_RecordKind _kindOf(FarmRecord r) {
  if (r is Animal) return _RecordKind.animal;
  if (r is Equipment) return _RecordKind.equipment;
  if (r is Inventory) return _RecordKind.inventory;
  return _RecordKind.folder;
}

String _kindLabel(_RecordKind k) {
  switch (k) {
    case _RecordKind.folder:
      return 'Folder';
    case _RecordKind.animal:
      return 'Animal';
    case _RecordKind.equipment:
      return 'Equipment';
    case _RecordKind.inventory:
      return 'Inventory';
  }
}

// -------------------------------------------------------------------
// Field definitions — one list per type, fed straight to GPWFormDialog.
// -------------------------------------------------------------------

List<Map<String, dynamic>> _commonFields({required bool includeLocation}) {
  return [
    {'key': 'name', 'label': 'Name', 'type': 'text', 'required': true},
    {'key': 'description', 'label': 'Description', 'type': 'text'},
    // Folders are always 'System' and not user-editable — see
    // _buildRecord — so the field is omitted entirely rather than shown
    // and ignored.
    if (includeLocation)
      {
        'key': 'location',
        'label': 'Location',
        'type': 'dropdown',
        'options': ['TKS', 'Tutor'],
        'required': true,
      },
    {'key': 'createdAt', 'label': 'Created', 'type': 'date'},
    {'key': 'isActive', 'label': 'Active', 'type': 'toggle'},
  ];
}

List<Map<String, dynamic>> _fieldsFor(_RecordKind kind) {
  switch (kind) {
    case _RecordKind.folder:
      return _commonFields(includeLocation: false);

    case _RecordKind.animal:
      return [
        ..._commonFields(includeLocation: true),
        {'key': 'species', 'label': 'Species', 'type': 'text', 'required': true},
        {'key': 'breed', 'label': 'Breed', 'type': 'text', 'required': true},
        {
          'key': 'sex',
          'label': 'Sex',
          'type': 'dropdown',
          'options': ['Female', 'Male'],
          'required': true,
        },
        {'key': 'dateOfBirth', 'label': 'Date of birth', 'type': 'date'},
        {'key': 'weight', 'label': 'Weight (kg)', 'type': 'text', 'numeric': true},
        {
          'key': 'healthStatus',
          'label': 'Health status',
          'type': 'dropdown',
          'options': ['Healthy', 'Sick', 'Injured', 'Under observation'],
          'required': true,
        },
        {'key': 'lastVaccination', 'label': 'Last vaccination', 'type': 'date', 'nullable': true},
        {'key': 'nextVaccination', 'label': 'Next vaccination due', 'type': 'date', 'nullable': true},
        {'key': 'lastVetCheck', 'label': 'Last vet check', 'type': 'date', 'nullable': true},
        {'key': 'isPregnant', 'label': 'Pregnant', 'type': 'toggle'},
        {'key': 'expectedBirth', 'label': 'Expected birth', 'type': 'date', 'nullable': true},
      ];

    case _RecordKind.equipment:
      return [
        ..._commonFields(includeLocation: true),
        {'key': 'equipmentType', 'label': 'Equipment type', 'type': 'text', 'required': true},
        {'key': 'manufacturer', 'label': 'Manufacturer', 'type': 'text'},
        {'key': 'model', 'label': 'Model', 'type': 'text'},
        {'key': 'serialNumber', 'label': 'Serial number', 'type': 'text', 'required': true},
        {'key': 'purchaseDate', 'label': 'Purchase date', 'type': 'date'},
        {'key': 'purchasePrice', 'label': 'Purchase price', 'type': 'text', 'numeric': true},
        {'key': 'currentValue', 'label': 'Current value', 'type': 'text', 'numeric': true},
        {'key': 'operatingHours', 'label': 'Operating hours', 'type': 'text', 'numeric': true},
        {'key': 'warrantyExpiry', 'label': 'Warranty expiry', 'type': 'date', 'nullable': true},
        {'key': 'insuranceExpiry', 'label': 'Insurance expiry', 'type': 'date', 'nullable': true},
        {'key': 'lastService', 'label': 'Last service', 'type': 'date', 'nullable': true},
        {
          'key': 'nextServiceHours',
          'label': 'Next service due (hours)',
          'type': 'text',
          'numeric': true,
        },
        {'key': 'maintenanceCost', 'label': 'Total maintenance cost', 'type': 'text', 'numeric': true},
      ];

    case _RecordKind.inventory:
      return [
        ..._commonFields(includeLocation: true),
        {'key': 'category', 'label': 'Category', 'type': 'text', 'required': true},
        {'key': 'unit', 'label': 'Unit (e.g. kg, bags)', 'type': 'text', 'required': true},
        {
          'key': 'quantity',
          'label': 'Quantity',
          'type': 'text',
          'numeric': true,
          'required': true,
        },
        {'key': 'minimumStock', 'label': 'Minimum stock', 'type': 'text', 'numeric': true},
        {'key': 'reorderLevel', 'label': 'Reorder level', 'type': 'text', 'numeric': true},
        {'key': 'unitCost', 'label': 'Unit cost', 'type': 'text', 'numeric': true},
        {'key': 'expiryDate', 'label': 'Expiry date', 'type': 'date', 'nullable': true},
        {'key': 'purchaseDate', 'label': 'Purchase date', 'type': 'date', 'nullable': true},
        {'key': 'batchNumber', 'label': 'Batch number', 'type': 'text'},
        {'key': 'supplier', 'label': 'Supplier', 'type': 'text'},
      ];
  }
}

// -------------------------------------------------------------------
// FarmRecord -> form data (for editing) and form data -> FarmRecord
// (on submit). This pair is the only place that needs updating if a
// field is ever added to/removed from the model.
// -------------------------------------------------------------------

Map<String, dynamic> _toFormData(FarmRecord r) {
  final data = <String, dynamic>{
    'name': r.name,
    'description': r.description ?? '',
    'isActive': r.isActive,
    'createdAt': r.createdAt,
  };
  if (r is! Folder) {
    data['location'] = r.location;
  }

  if (r is Animal) {
    data.addAll({
      'species': r.species,
      'breed': r.breed,
      'sex': r.sex,
      'dateOfBirth': r.dateOfBirth,
      'weight': r.weight?.toString() ?? '',
      'healthStatus': r.healthStatus,
      'lastVaccination': r.lastVaccination,
      'nextVaccination': r.nextVaccination,
      'lastVetCheck': r.lastVetCheck,
      'isPregnant': r.isPregnant,
      'expectedBirth': r.expectedBirth,
    });
  } else if (r is Equipment) {
    data.addAll({
      'equipmentType': r.equipmentType,
      'manufacturer': r.manufacturer,
      'model': r.model,
      'serialNumber': r.serialNumber,
      'purchaseDate': r.purchaseDate,
      'purchasePrice': r.purchasePrice.toString(),
      'currentValue': r.currentValue.toString(),
      'operatingHours': r.operatingHours.toString(),
      'warrantyExpiry': r.warrantyExpiry,
      'insuranceExpiry': r.insuranceExpiry,
      'lastService': r.lastService,
      'nextServiceHours': r.nextServiceHours?.toString() ?? '',
      'maintenanceCost': r.maintenanceCost.toString(),
    });
  } else if (r is Inventory) {
    data.addAll({
      'category': r.category,
      'unit': r.unit,
      'quantity': r.quantity.toString(),
      'minimumStock': r.minimumStock.toString(),
      'reorderLevel': r.reorderLevel.toString(),
      'unitCost': r.unitCost.toString(),
      'expiryDate': r.expiryDate,
      'purchaseDate': r.purchaseDate,
      'batchNumber': r.batchNumber ?? '',
      'supplier': r.supplier ?? '',
    });
  }

  return data;
}

FarmRecord _buildRecord(
  _RecordKind kind,
  Map<String, dynamic> formData, {
  FarmRecord? existing,
  required RecordsController controller,
}) {
  final now = DateTime.now();
  final id = existing?.id ?? controller.generateId();
  // 'createdAt' is a 'date' field, so GPWFormDialog stores it as a
  // DateTime directly (not a String) — see the 'date' case it added.
  final createdAt =
      formData['createdAt'] as DateTime? ?? existing?.createdAt ?? now;
  final name = ((formData['name'] as String?) ?? '').trim();
  final description = ((formData['description'] as String?) ?? '').trim();
  final isActive = formData['isActive'] as bool? ?? true;
  final location = kind == _RecordKind.folder
      ? 'System'
      : ((formData['location'] as String?) ?? 'TKS');

  // 'numeric' text fields are still Strings coming out of the form (a
  // GPWFormDialog TextFormField always saves a String) — parse here.
  // Nullable fields (weight, nextServiceHours) get null on empty/invalid
  // input; non-nullable ones fall back to a given default instead.
  double? num_(String key) =>
      double.tryParse((formData[key] as String?) ?? '');
  double numOr(String key, double fallback) => num_(key) ?? fallback;

  switch (kind) {
    case _RecordKind.folder:
      return Folder(
        id: id,
        name: name,
        description: description,
        location: location,
        createdAt: createdAt,
        updatedAt: now,
        isActive: isActive,
      );

    case _RecordKind.animal:
      return Animal(
        id: id,
        name: name,
        description: description,
        location: location,
        createdAt: createdAt,
        updatedAt: now,
        isActive: isActive,
        species: ((formData['species'] as String?) ?? '').trim(),
        breed: ((formData['breed'] as String?) ?? '').trim(),
        sex: (formData['sex'] as String?) ?? 'Female',
        // Required date field left untouched on a brand-new record falls
        // back to now() rather than blocking submission — GPWFormDialog's
        // 'date' fields don't hook into Form validation (see its comment).
        dateOfBirth: formData['dateOfBirth'] as DateTime? ?? now,
        weight: num_('weight'),
        healthStatus: (formData['healthStatus'] as String?) ?? 'Healthy',
        lastVaccination: formData['lastVaccination'] as DateTime?,
        nextVaccination: formData['nextVaccination'] as DateTime?,
        lastVetCheck: formData['lastVetCheck'] as DateTime?,
        isPregnant: formData['isPregnant'] as bool? ?? false,
        expectedBirth: formData['expectedBirth'] as DateTime?,
      );

    case _RecordKind.equipment:
      return Equipment(
        id: id,
        name: name,
        description: description,
        location: location,
        createdAt: createdAt,
        updatedAt: now,
        isActive: isActive,
        equipmentType: ((formData['equipmentType'] as String?) ?? '').trim(),
        manufacturer: ((formData['manufacturer'] as String?) ?? '').trim(),
        model: ((formData['model'] as String?) ?? '').trim(),
        serialNumber: ((formData['serialNumber'] as String?) ?? '').trim(),
        purchaseDate: formData['purchaseDate'] as DateTime? ?? now,
        purchasePrice: numOr('purchasePrice', 0),
        currentValue: numOr('currentValue', 0),
        operatingHours: numOr('operatingHours', 0),
        warrantyExpiry: formData['warrantyExpiry'] as DateTime?,
        insuranceExpiry: formData['insuranceExpiry'] as DateTime?,
        lastService: formData['lastService'] as DateTime?,
        nextServiceHours: num_('nextServiceHours'),
        maintenanceCost: numOr('maintenanceCost', 0),
      );

    case _RecordKind.inventory:
      final batch = ((formData['batchNumber'] as String?) ?? '').trim();
      final supplier = ((formData['supplier'] as String?) ?? '').trim();
      return Inventory(
        id: id,
        name: name,
        description: description,
        location: location,
        createdAt: createdAt,
        updatedAt: now,
        isActive: isActive,
        category: ((formData['category'] as String?) ?? '').trim(),
        unit: ((formData['unit'] as String?) ?? '').trim(),
        quantity: numOr('quantity', 0),
        minimumStock: numOr('minimumStock', 0),
        reorderLevel: numOr('reorderLevel', 0),
        unitCost: numOr('unitCost', 0),
        expiryDate: formData['expiryDate'] as DateTime?,
        purchaseDate: formData['purchaseDate'] as DateTime?,
        batchNumber: batch.isEmpty ? null : batch,
        supplier: supplier.isEmpty ? null : supplier,
      );
  }
}