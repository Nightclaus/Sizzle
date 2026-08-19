import 'package:flutter/material.dart';
import '../controllers/records_controller.dart';
import '../models/records_model.dart';

/// Shows a create/edit form for a FarmRecord. Pass [existing] to edit (its
/// runtime type is kept and reused); omit it to create, in which case the
/// user picks a type first. Returns the built FarmRecord on save, or null
/// if cancelled — the caller still has to call
/// `RecordsController.createRecord` / `updateRecord` with the result.
Future<FarmRecord?> showRecordFormDialog(
  BuildContext context, {
  required RecordsController controller,
  FarmRecord? existing,
}) {
  return showDialog<FarmRecord>(
    context: context,
    builder: (_) =>
        _RecordFormDialog(controller: controller, existing: existing),
  );
}

enum _RecordKind { folder, animal, equipment, inventory }

class _RecordFormDialog extends StatefulWidget {
  final RecordsController controller;
  final FarmRecord? existing;

  const _RecordFormDialog({required this.controller, this.existing});

  @override
  State<_RecordFormDialog> createState() => _RecordFormDialogState();
}

class _RecordFormDialogState extends State<_RecordFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late _RecordKind _kind;

  static const _folderLocation = 'System';
  static const _locationOptions = ['TKS', 'Tutor'];

  late final TextEditingController _name;
  late final TextEditingController _description;
  // Not free text: constrained to _locationOptions for every non-Folder
  // kind. Folders don't use this at all — their location is always
  // _folderLocation, set at submit time, not user-editable.
  String _location = _locationOptions.first;
  bool _isActive = true;

  late final TextEditingController _species;
  late final TextEditingController _breed;
  String _sex = 'Female';
  DateTime _dateOfBirth = DateTime.now();
  late final TextEditingController _weight;
  String _healthStatus = 'Healthy';

  late final TextEditingController _equipmentType;
  late final TextEditingController _manufacturer;
  late final TextEditingController _model;
  late final TextEditingController _serialNumber;
  DateTime _purchaseDate = DateTime.now();
  late final TextEditingController _purchasePrice;
  late final TextEditingController _currentValue;

  late final TextEditingController _category;
  late final TextEditingController _unit;
  late final TextEditingController _quantity;
  late final TextEditingController _unitCost;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _kind = _kindOf(e);

    _name = TextEditingController(text: e?.name ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    // Legacy/unexpected values fall back to the first option rather than
    // crashing the dropdown on an unrecognized value.
    _location = (e != null && e is! Folder && _locationOptions.contains(e.location))
        ? e.location
        : _locationOptions.first;
    _isActive = e?.isActive ?? true;

    _species = TextEditingController(text: e is Animal ? e.species : '');
    _breed = TextEditingController(text: e is Animal ? e.breed : '');
    _sex = e is Animal ? e.sex : 'Female';
    _dateOfBirth = e is Animal ? e.dateOfBirth : DateTime.now();
    _weight = TextEditingController(
        text: e is Animal && e.weight != null ? e.weight.toString() : '');
    _healthStatus = e is Animal ? e.healthStatus : 'Healthy';

    _equipmentType =
        TextEditingController(text: e is Equipment ? e.equipmentType : '');
    _manufacturer =
        TextEditingController(text: e is Equipment ? e.manufacturer : '');
    _model = TextEditingController(text: e is Equipment ? e.model : '');
    _serialNumber =
        TextEditingController(text: e is Equipment ? e.serialNumber : '');
    _purchaseDate = e is Equipment ? e.purchaseDate : DateTime.now();
    _purchasePrice = TextEditingController(
        text: e is Equipment ? e.purchasePrice.toString() : '0');
    _currentValue = TextEditingController(
        text: e is Equipment ? e.currentValue.toString() : '0');

    _category = TextEditingController(text: e is Inventory ? e.category : '');
    _unit = TextEditingController(text: e is Inventory ? e.unit : '');
    _quantity = TextEditingController(
        text: e is Inventory ? e.quantity.toString() : '0');
    _unitCost = TextEditingController(
        text: e is Inventory ? e.unitCost.toString() : '0');
  }

  _RecordKind _kindOf(FarmRecord? r) {
    if (r is Animal) return _RecordKind.animal;
    if (r is Equipment) return _RecordKind.equipment;
    if (r is Inventory) return _RecordKind.inventory;
    return _RecordKind.folder;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit record' : 'New record'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isEditing) ...[
                  DropdownButtonFormField<_RecordKind>(
                    value: _kind,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: _RecordKind.values
                        .map((k) => DropdownMenuItem(
                              value: k,
                              child: Text(k.name.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (k) => setState(() => _kind = k!),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                if (_kind == _RecordKind.folder)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _location,
                    decoration: const InputDecoration(labelText: 'Location'),
                    items: _locationOptions
                        .map((loc) =>
                            DropdownMenuItem(value: loc, child: Text(loc)))
                        .toList(),
                    onChanged: (v) => setState(() => _location = v!),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const Divider(),
                ..._typeSpecificFields(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  List<Widget> _typeSpecificFields() {
    switch (_kind) {
      case _RecordKind.folder:
        return const [
          Text('Folders are used to group other records.',
              style: TextStyle(fontStyle: FontStyle.italic)),
        ];
      case _RecordKind.animal:
        return [
          TextFormField(
            controller: _species,
            decoration: const InputDecoration(labelText: 'Species'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          TextFormField(
            controller: _breed,
            decoration: const InputDecoration(labelText: 'Breed'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          DropdownButtonFormField<String>(
            value: _sex,
            decoration: const InputDecoration(labelText: 'Sex'),
            items: const [
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Male', child: Text('Male')),
            ],
            onChanged: (v) => setState(() => _sex = v!),
          ),
          _DatePickerField(
            label: 'Date of birth',
            value: _dateOfBirth,
            onChanged: (d) => setState(() => _dateOfBirth = d),
          ),
          TextFormField(
            controller: _weight,
            decoration:
                const InputDecoration(labelText: 'Weight (kg, optional)'),
            keyboardType: TextInputType.number,
          ),
          DropdownButtonFormField<String>(
            value: _healthStatus,
            decoration: const InputDecoration(labelText: 'Health status'),
            items: const [
              DropdownMenuItem(value: 'Healthy', child: Text('Healthy')),
              DropdownMenuItem(value: 'Sick', child: Text('Sick')),
              DropdownMenuItem(value: 'Injured', child: Text('Injured')),
              DropdownMenuItem(
                  value: 'Under observation',
                  child: Text('Under observation')),
            ],
            onChanged: (v) => setState(() => _healthStatus = v!),
          ),
        ];
      case _RecordKind.equipment:
        return [
          TextFormField(
            controller: _equipmentType,
            decoration: const InputDecoration(labelText: 'Equipment type'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          TextFormField(
            controller: _manufacturer,
            decoration: const InputDecoration(labelText: 'Manufacturer'),
          ),
          TextFormField(
            controller: _model,
            decoration: const InputDecoration(labelText: 'Model'),
          ),
          TextFormField(
            controller: _serialNumber,
            decoration: const InputDecoration(labelText: 'Serial number'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          _DatePickerField(
            label: 'Purchase date',
            value: _purchaseDate,
            onChanged: (d) => setState(() => _purchaseDate = d),
          ),
          TextFormField(
            controller: _purchasePrice,
            decoration: const InputDecoration(labelText: 'Purchase price'),
            keyboardType: TextInputType.number,
          ),
          TextFormField(
            controller: _currentValue,
            decoration: const InputDecoration(labelText: 'Current value'),
            keyboardType: TextInputType.number,
          ),
        ];
      case _RecordKind.inventory:
        return [
          TextFormField(
            controller: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          TextFormField(
            controller: _unit,
            decoration:
                const InputDecoration(labelText: 'Unit (e.g. kg, bags)'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          TextFormField(
            controller: _quantity,
            decoration: const InputDecoration(labelText: 'Quantity'),
            keyboardType: TextInputType.number,
            validator: (v) => (v == null || double.tryParse(v) == null)
                ? 'Number required'
                : null,
          ),
          TextFormField(
            controller: _unitCost,
            decoration: const InputDecoration(labelText: 'Unit cost'),
            keyboardType: TextInputType.number,
          ),
        ];
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final id = widget.existing?.id ?? widget.controller.generateId();
    final createdAt = widget.existing?.createdAt ?? now;
    final location = _kind == _RecordKind.folder ? _folderLocation : _location;

    FarmRecord result;
    switch (_kind) {
      case _RecordKind.folder:
        result = Folder(
          id: id,
          name: _name.text.trim(),
          description: _description.text.trim(),
          location: location,
          createdAt: createdAt,
          updatedAt: now,
          isActive: _isActive,
        );
        break;
      case _RecordKind.animal:
        result = Animal(
          id: id,
          name: _name.text.trim(),
          description: _description.text.trim(),
          location: location,
          createdAt: createdAt,
          updatedAt: now,
          isActive: _isActive,
          species: _species.text.trim(),
          breed: _breed.text.trim(),
          sex: _sex,
          dateOfBirth: _dateOfBirth,
          weight: double.tryParse(_weight.text),
          healthStatus: _healthStatus,
        );
        break;
      case _RecordKind.equipment:
        result = Equipment(
          id: id,
          name: _name.text.trim(),
          description: _description.text.trim(),
          location: location,
          createdAt: createdAt,
          updatedAt: now,
          isActive: _isActive,
          equipmentType: _equipmentType.text.trim(),
          manufacturer: _manufacturer.text.trim(),
          model: _model.text.trim(),
          serialNumber: _serialNumber.text.trim(),
          purchaseDate: _purchaseDate,
          purchasePrice: double.tryParse(_purchasePrice.text) ?? 0,
          currentValue: double.tryParse(_currentValue.text) ?? 0,
        );
        break;
      case _RecordKind.inventory:
        result = Inventory(
          id: id,
          name: _name.text.trim(),
          description: _description.text.trim(),
          location: location,
          createdAt: createdAt,
          updatedAt: now,
          isActive: _isActive,
          category: _category.text.trim(),
          unit: _unit.text.trim(),
          quantity: double.tryParse(_quantity.text) ?? 0,
          unitCost: double.tryParse(_unitCost.text) ?? 0,
        );
        break;
    }

    Navigator.pop(context, result);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _species.dispose();
    _breed.dispose();
    _weight.dispose();
    _equipmentType.dispose();
    _manufacturer.dispose();
    _model.dispose();
    _serialNumber.dispose();
    _purchasePrice.dispose();
    _currentValue.dispose();
    _category.dispose();
    _unit.dispose();
    _quantity.dispose();
    _unitCost.dispose();
    super.dispose();
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(1990),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
}