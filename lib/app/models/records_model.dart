import 'dart:collection';
import 'dart:convert';

abstract class FarmRecord {
  final String id;
  String name;
  String? description;
  String location;
  DateTime createdAt;
  DateTime updatedAt;
  bool isActive;

  List<FarmRecord> children;

  FarmRecord({
    required this.id,
    required this.name,
    this.description,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    List<FarmRecord>? children,
  }) : children = children ?? [];

  String get recordType;

  bool get requiresAttention;

  bool validate();

  String getSummary();

  void updateTimestamp() {
    updatedAt = DateTime.now();
  }

  void addChild(FarmRecord child) {
    children.add(child);
    updateTimestamp();
  }

  bool removeChild(String childId) {
    final before = children.length;
    children.removeWhere((c) => c.id == childId);
    if (children.length != before) {
      updateTimestamp();
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------
  // Traversal (BFS). All operate on the subtree rooted at `this`.
  // ---------------------------------------------------------------------

  List<FarmRecord> bfs() {
    final result = <FarmRecord>[];
    final queue = Queue<FarmRecord>()..add(this);
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      result.add(current);
      queue.addAll(current.children);
    }
    return result;
  }

  /// Every node in this subtree, DFS pre-order — `this` first, then each
  /// child's full subtree before moving to the next sibling. Implemented
  /// with an explicit stack (not recursion) so a very deep tree can't
  /// blow the call stack.
  List<FarmRecord> dfs() {
    final result = <FarmRecord>[];
    final stack = <FarmRecord>[this];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      result.add(current);
      // Push in reverse so the first child is the next one popped.
      for (final child in current.children.reversed) {
        stack.add(child);
      }
    }
    return result;
  }

  /// DFS-filters this subtree down to nodes of type [T] — e.g.
  /// `folder.filterByType<Animal>()`. Returns a flat 1D list.
  List<T> filterByType<T extends FarmRecord>() {
    return dfs().whereType<T>().toList();
  }

  // findById/search/findParentOf below deliberately use DFS, not BFS: none
  // of them need BFS's one actual advantage (shortest path — that's what
  // findPath is for). They either visit every node anyway (search) or just
  // need *a* match with no ordering requirement, and DFS's stack peaks at
  // the current path's siblings rather than a whole tree level, which is
  // the cheaper traversal for a tree this wide and shallow.

  FarmRecord? findById(String targetId) {
    final stack = <FarmRecord>[this];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (current.id == targetId) return current;
      stack.addAll(current.children);
    }
    return null;
  }

  List<FarmRecord> search(bool Function(FarmRecord record) test) {
    return dfs().where(test).toList();
  }

  /// BFS for the path from `this` node down to [targetId] — shortest path,
  /// used for breadcrumbs. Null if not found in this subtree.
  List<FarmRecord>? findPath(String targetId) {
    final queue = Queue<List<FarmRecord>>()..add([this]);
    while (queue.isNotEmpty) {
      final path = queue.removeFirst();
      final current = path.last;
      if (current.id == targetId) return path;
      for (final child in current.children) {
        queue.add([...path, child]);
      }
    }
    return null;
  }

  /// DFS for the immediate parent of [targetId] in this subtree (early
  /// exit on match — no need to collect a full traversal first). Null if
  /// [targetId] is `this` node (no parent) or isn't found at all.
  FarmRecord? findParentOf(String targetId) {
    if (id == targetId) return null;
    final stack = <FarmRecord>[this];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      for (final child in current.children) {
        if (child.id == targetId) return current;
        stack.add(child);
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------

  Map<String, dynamic> toMap() {
    return {
      'type': recordType,
      'id': id,
      'name': name,
      'description': description,
      'location': location,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
      'children': children.map((child) => child.toMap()).toList(),
    };
  }

  String toJson() {
    return jsonEncode(toMap());
  }

  static FarmRecord fromMap(Map<String, dynamic> map) {
    switch (map['type']) {
      case 'Animal':
        return Animal.fromMap(map);
      case 'Equipment':
        return Equipment.fromMap(map);
      case 'Inventory':
        return Inventory.fromMap(map);
      case 'Folder':
        return Folder.fromMap(map);
      default:
        throw Exception('Unknown FarmRecord type: ${map['type']}');
    }
  }

  static FarmRecord fromJson(String json) {
    final Map<String, dynamic> map = jsonDecode(json);
    return fromMap(map);
  }

  static List<FarmRecord> _childrenFromMap(Map<String, dynamic> map) {
    final rawChildren = map['children'] as List?;
    if (rawChildren == null) return [];
    return rawChildren
        .map((child) => FarmRecord.fromMap(child as Map<String, dynamic>))
        .toList();
  }
}

/// A pure container node — groups other records (including other Folders).
class Folder extends FarmRecord {
  Folder({
    required super.id,
    required super.name,
    super.description,
    required super.location,
    required super.createdAt,
    required super.updatedAt,
    super.isActive,
    super.children,
  });

  @override
  String get recordType => 'Folder';

  @override
  bool get requiresAttention =>
      children.any((child) => child.requiresAttention);

  // A direct-children count would be misleading (it ignores nested
  // folders), and an accurate total needs a recursive/BFS walk that's
  // overkill just for a summary line — so this stays a simple boolean.
  @override
  String getSummary() => children.isEmpty ? 'Empty' : 'Filed';

  @override
  bool validate() => name.isNotEmpty;

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      location: map['location'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      isActive: map['isActive'] ?? true,
      children: FarmRecord._childrenFromMap(map),
    );
  }
}

class Animal extends FarmRecord {
  final String species;
  final String breed;
  final String sex;
  final DateTime dateOfBirth;

  double? weight;
  String healthStatus;

  DateTime? lastVaccination;
  DateTime? nextVaccination;

  DateTime? lastVetCheck;

  bool isPregnant;
  DateTime? expectedBirth;

  Animal({
    required super.id,
    required super.name,
    super.description,
    required super.location,
    required super.createdAt,
    required super.updatedAt,
    super.isActive,
    super.children,
    required this.species,
    required this.breed,
    required this.sex,
    required this.dateOfBirth,
    this.weight,
    this.healthStatus = 'Healthy',
    this.lastVaccination,
    this.nextVaccination,
    this.lastVetCheck,
    this.isPregnant = false,
    this.expectedBirth,
  });

  @override
  String get recordType => 'Animal';

  @override
  bool get requiresAttention {
    if (healthStatus != 'Healthy') return true;
    if (nextVaccination != null && nextVaccination!.isBefore(DateTime.now())) {
      return true;
    }
    return false;
  }

  @override
  String getSummary() => '$species • $breed • $healthStatus';

  @override
  bool validate() {
    return name.isNotEmpty &&
        species.isNotEmpty &&
        breed.isNotEmpty &&
        dateOfBirth.isBefore(DateTime.now());
  }

  void recordVaccination(DateTime date, DateTime nextDue) {
    lastVaccination = date;
    nextVaccination = nextDue;
    updateTimestamp();
  }

  void updateWeight(double newWeight) {
    weight = newWeight;
    updateTimestamp();
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'species': species,
      'breed': breed,
      'sex': sex,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'weight': weight,
      'healthStatus': healthStatus,
      'lastVaccination': lastVaccination?.toIso8601String(),
      'nextVaccination': nextVaccination?.toIso8601String(),
      'lastVetCheck': lastVetCheck?.toIso8601String(),
      'isPregnant': isPregnant,
      'expectedBirth': expectedBirth?.toIso8601String(),
    });
    return map;
  }

  factory Animal.fromMap(Map<String, dynamic> map) {
    return Animal(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      location: map['location'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      isActive: map['isActive'] ?? true,
      children: FarmRecord._childrenFromMap(map),
      species: map['species'],
      breed: map['breed'],
      sex: map['sex'],
      dateOfBirth: DateTime.parse(map['dateOfBirth']),
      weight: map['weight']?.toDouble(),
      healthStatus: map['healthStatus'] ?? 'Healthy',
      lastVaccination: map['lastVaccination'] != null
          ? DateTime.parse(map['lastVaccination'])
          : null,
      nextVaccination: map['nextVaccination'] != null
          ? DateTime.parse(map['nextVaccination'])
          : null,
      lastVetCheck: map['lastVetCheck'] != null
          ? DateTime.parse(map['lastVetCheck'])
          : null,
      isPregnant: map['isPregnant'] ?? false,
      expectedBirth: map['expectedBirth'] != null
          ? DateTime.parse(map['expectedBirth'])
          : null,
    );
  }
}

class Equipment extends FarmRecord {
  final String equipmentType;
  final String manufacturer;
  final String model;
  final String serialNumber;

  DateTime purchaseDate;
  double purchasePrice;

  double currentValue;

  double operatingHours;

  DateTime? warrantyExpiry;
  DateTime? insuranceExpiry;

  DateTime? lastService;
  double? nextServiceHours;

  double maintenanceCost;

  Equipment({
    required super.id,
    required super.name,
    super.description,
    required super.location,
    required super.createdAt,
    required super.updatedAt,
    super.isActive,
    super.children,
    required this.equipmentType,
    required this.manufacturer,
    required this.model,
    required this.serialNumber,
    required this.purchaseDate,
    required this.purchasePrice,
    required this.currentValue,
    this.operatingHours = 0,
    this.warrantyExpiry,
    this.insuranceExpiry,
    this.lastService,
    this.nextServiceHours,
    this.maintenanceCost = 0,
  });

  @override
  String get recordType => 'Equipment';

  @override
  bool get requiresAttention {
    final now = DateTime.now();
    if (insuranceExpiry != null && insuranceExpiry!.isBefore(now)) return true;
    if (warrantyExpiry != null && warrantyExpiry!.isBefore(now)) return true;
    if (nextServiceHours != null && operatingHours >= nextServiceHours!) {
      return true;
    }
    return false;
  }

  @override
  String getSummary() => '$manufacturer $model • ${operatingHours}h';

  @override
  bool validate() {
    return name.isNotEmpty &&
        serialNumber.isNotEmpty &&
        purchasePrice >= 0 &&
        currentValue >= 0;
  }

  void recordService(double cost) {
    lastService = DateTime.now();
    maintenanceCost += cost;
    updateTimestamp();
  }

  void addOperatingHours(double hours) {
    if (hours < 0) return;
    operatingHours += hours;
    updateTimestamp();
  }

  double get depreciation => purchasePrice - currentValue;

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'equipmentType': equipmentType,
      'manufacturer': manufacturer,
      'model': model,
      'serialNumber': serialNumber,
      'purchaseDate': purchaseDate.toIso8601String(),
      'purchasePrice': purchasePrice,
      'currentValue': currentValue,
      'operatingHours': operatingHours,
      'warrantyExpiry': warrantyExpiry?.toIso8601String(),
      'insuranceExpiry': insuranceExpiry?.toIso8601String(),
      'lastService': lastService?.toIso8601String(),
      'nextServiceHours': nextServiceHours,
      'maintenanceCost': maintenanceCost,
    });
    return map;
  }

  factory Equipment.fromMap(Map<String, dynamic> map) {
    return Equipment(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      location: map['location'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      isActive: map['isActive'] ?? true,
      children: FarmRecord._childrenFromMap(map),
      equipmentType: map['equipmentType'],
      manufacturer: map['manufacturer'],
      model: map['model'],
      serialNumber: map['serialNumber'],
      purchaseDate: DateTime.parse(map['purchaseDate']),
      purchasePrice: (map['purchasePrice'] as num).toDouble(),
      currentValue: (map['currentValue'] as num).toDouble(),
      operatingHours: (map['operatingHours'] as num?)?.toDouble() ?? 0,
      warrantyExpiry: map['warrantyExpiry'] != null
          ? DateTime.parse(map['warrantyExpiry'])
          : null,
      insuranceExpiry: map['insuranceExpiry'] != null
          ? DateTime.parse(map['insuranceExpiry'])
          : null,
      lastService: map['lastService'] != null
          ? DateTime.parse(map['lastService'])
          : null,
      nextServiceHours: map['nextServiceHours']?.toDouble(),
      maintenanceCost: (map['maintenanceCost'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Inventory extends FarmRecord {
  final String category;
  final String unit;

  double quantity;
  double minimumStock;

  double reorderLevel;

  double unitCost;

  DateTime? expiryDate;
  DateTime? purchaseDate;

  String? batchNumber;
  String? supplier;

  Inventory({
    required super.id,
    required super.name,
    super.description,
    required super.location,
    required super.createdAt,
    required super.updatedAt,
    super.isActive,
    super.children,
    required this.category,
    required this.unit,
    required this.quantity,
    this.minimumStock = 0,
    this.reorderLevel = 0,
    this.unitCost = 0,
    this.expiryDate,
    this.purchaseDate,
    this.batchNumber,
    this.supplier,
  });

  @override
  String get recordType => 'Inventory';

  @override
  bool get requiresAttention {
    if (quantity <= minimumStock) return true;
    if (expiryDate != null && expiryDate!.isBefore(DateTime.now())) {
      return true;
    }
    return false;
  }

  @override
  String getSummary() => '$quantity $unit remaining';

  @override
  bool validate() => name.isNotEmpty && quantity >= 0 && unitCost >= 0;

  void consume(double amount) {
    if (amount <= 0 || amount > quantity) {
      throw ArgumentError('Invalid quantity.');
    }
    quantity -= amount;
    updateTimestamp();
  }

  void restock(double amount) {
    if (amount <= 0) {
      throw ArgumentError('Amount must be positive.');
    }
    quantity += amount;
    updateTimestamp();
  }

  double get totalValue => quantity * unitCost;

  bool get needsReordering => quantity <= reorderLevel;

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'category': category,
      'unit': unit,
      'quantity': quantity,
      'minimumStock': minimumStock,
      'reorderLevel': reorderLevel,
      'unitCost': unitCost,
      'expiryDate': expiryDate?.toIso8601String(),
      'purchaseDate': purchaseDate?.toIso8601String(),
      'batchNumber': batchNumber,
      'supplier': supplier,
    });
    return map;
  }

  factory Inventory.fromMap(Map<String, dynamic> map) {
    return Inventory(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      location: map['location'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      isActive: map['isActive'] ?? true,
      children: FarmRecord._childrenFromMap(map),
      category: map['category'],
      unit: map['unit'],
      quantity: (map['quantity'] as num).toDouble(),
      minimumStock: (map['minimumStock'] as num?)?.toDouble() ?? 0,
      reorderLevel: (map['reorderLevel'] as num?)?.toDouble() ?? 0,
      unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0,
      expiryDate:
          map['expiryDate'] != null ? DateTime.parse(map['expiryDate']) : null,
      purchaseDate: map['purchaseDate'] != null
          ? DateTime.parse(map['purchaseDate'])
          : null,
      batchNumber: map['batchNumber'],
      supplier: map['supplier'],
    );
  }
}