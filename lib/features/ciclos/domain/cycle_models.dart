enum CycleRole {
  owner,
  editor,
  viewer;

  static CycleRole fromDatabase(String? value) => switch (value) {
    'owner' => CycleRole.owner,
    'editor' => CycleRole.editor,
    _ => CycleRole.viewer,
  };

  String get label => switch (this) {
    CycleRole.owner => 'Owner',
    CycleRole.editor => 'Editor',
    CycleRole.viewer => 'Viewer',
  };
}

class CycleAccess {
  const CycleAccess(this.role);

  final CycleRole role;

  bool get canEdit => role != CycleRole.viewer;
}

class CycleProduct {
  const CycleProduct({
    required this.id,
    required this.code,
    required this.name,
    required this.defaultUnit,
  });

  final String id;
  final String code;
  final String name;
  final String defaultUnit;

  factory CycleProduct.fromJson(Map<String, dynamic> json) {
    final unit = json['cat_unidades'] as Map?;
    return CycleProduct(
      id: json['id'] as String,
      code: json['codigo'] as String,
      name: json['nombre'] as String,
      defaultUnit: unit?['nombre'] as String? ?? '',
    );
  }
}

class CycleMetric {
  const CycleMetric({
    required this.id,
    required this.productId,
    required this.code,
    required this.name,
    required this.role,
    required this.unit,
  });

  final String id;
  final String productId;
  final String code;
  final String name;
  final String role;
  final String unit;

  factory CycleMetric.fromJson(Map<String, dynamic> json) {
    final unit = json['cat_unidades'] as Map?;
    return CycleMetric(
      id: json['id'] as String,
      productId: json['producto_id'] as String,
      code: json['codigo'] as String,
      name: json['nombre'] as String,
      role: json['rol'] as String,
      unit: unit?['nombre'] as String? ?? '',
    );
  }
}

class CycleCatalogs {
  const CycleCatalogs({required this.products, required this.metrics});

  final List<CycleProduct> products;
  final List<CycleMetric> metrics;
}

class CycleGroup {
  const CycleGroup({
    required this.id,
    required this.animalTypeId,
    required this.name,
  });

  final String id;
  final String animalTypeId;
  final String name;

  factory CycleGroup.fromJson(Map<String, dynamic> json) => CycleGroup(
    id: json['id'] as String,
    animalTypeId: json['tipo_animal_id'] as String,
    name: json['nombre'] as String,
  );
}

class CycleMemberCandidate {
  const CycleMemberCandidate({
    required this.id,
    required this.animalTypeId,
    required this.animalTypeName,
    required this.label,
    this.groupId,
    this.groupName,
  });

  final String id;
  final String animalTypeId;
  final String animalTypeName;
  final String label;
  final String? groupId;
  final String? groupName;

  factory CycleMemberCandidate.fromJson(Map<String, dynamic> json) {
    final group = json['grupos'] as Map?;
    final animalType = json['tipo_animal'] as Map?;
    final bracelet = json['brazalete'];
    return CycleMemberCandidate(
      id: json['id'] as String,
      animalTypeId: json['tipo_animal_id'] as String,
      animalTypeName: animalType?['nombre'] as String? ?? 'Animal type',
      label: bracelet == null ? 'Animal ${json['id']}' : 'Bracelet $bracelet',
      groupId: json['grupo_id'] as String?,
      groupName: group?['nombre'] as String?,
    );
  }
}

class Cycle {
  const Cycle({
    required this.id,
    required this.farmId,
    required this.animalTypeId,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.animalTypeName,
    required this.startedAt,
    required this.isActive,
    required this.version,
    this.name,
    this.endedAt,
    this.notes,
  });

  final String id;
  final String farmId;
  final String animalTypeId;
  final String? productId;
  final String productCode;
  final String productName;
  final String animalTypeName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool isActive;
  final int version;
  final String? name;
  final String? notes;

  String get displayName =>
      name?.trim().isNotEmpty == true ? name! : productName;

  factory Cycle.fromJson(Map<String, dynamic> json) {
    final product = json['cat_productos'] as Map?;
    final animalType = json['tipo_animal'] as Map?;
    return Cycle(
      id: json['id'] as String,
      farmId: json['granja_id'] as String,
      animalTypeId: json['tipo_animal_id'] as String,
      productId: json['producto_id'] as String?,
      productCode:
          product?['codigo'] as String? ?? json['tipo_produccion'] as String,
      productName:
          product?['nombre'] as String? ?? json['tipo_produccion'] as String,
      animalTypeName: animalType?['nombre'] as String? ?? '',
      startedAt: DateTime.parse(json['fecha_inicio'] as String),
      endedAt: json['fecha_fin'] == null
          ? null
          : DateTime.parse(json['fecha_fin'] as String),
      isActive: json['activo'] as bool? ?? false,
      version: (json['version'] as num?)?.toInt() ?? 1,
      name: json['nombre'] as String?,
      notes: json['notas'] as String?,
    );
  }
}

class CycleMember {
  const CycleMember({
    required this.id,
    required this.animalId,
    required this.label,
    required this.joinedAt,
    this.leftAt,
    this.groupName,
  });

  final String id;
  final String animalId;
  final String label;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final String? groupName;

  bool get isActive => leftAt == null;

  factory CycleMember.fromJson(Map<String, dynamic> json) {
    final animal = json['animales'] as Map?;
    final bracelet = animal?['brazalete'];
    final group = animal?['grupos'] as Map?;
    return CycleMember(
      id: json['id'] as String,
      animalId: json['animal_id'] as String,
      label: bracelet == null
          ? 'Animal ${json['animal_id']}'
          : 'Bracelet $bracelet',
      joinedAt: DateTime.parse(json['joined_at'] as String),
      leftAt: json['left_at'] == null
          ? null
          : DateTime.parse(json['left_at'] as String),
      groupName: group?['nombre'] as String?,
    );
  }
}

class CycleDetail {
  const CycleDetail({required this.cycle, required this.members});

  final Cycle cycle;
  final List<CycleMember> members;
}

class CycleEconomics {
  const CycleEconomics({
    required this.feedCost,
    required this.acquisitionCost,
    required this.extraExpense,
    required this.eventRevenue,
    required this.extraRevenue,
    required this.producedUnits,
    required this.totalCost,
    required this.totalRevenue,
    required this.profit,
    this.roiPercent,
    this.unitCost,
  });

  final double feedCost;
  final double acquisitionCost;
  final double extraExpense;
  final double eventRevenue;
  final double extraRevenue;
  final double producedUnits;
  final double totalCost;
  final double totalRevenue;
  final double profit;
  final double? roiPercent;
  final double? unitCost;

  factory CycleEconomics.fromJson(Map<String, dynamic> json) => CycleEconomics(
    feedCost: (json['costo_alimento'] as num?)?.toDouble() ?? 0,
    acquisitionCost: (json['costo_adquisicion'] as num?)?.toDouble() ?? 0,
    extraExpense: (json['gastos_extra'] as num?)?.toDouble() ?? 0,
    eventRevenue: (json['ingresos_eventos'] as num?)?.toDouble() ?? 0,
    extraRevenue: (json['ingresos_extra'] as num?)?.toDouble() ?? 0,
    producedUnits: (json['unidades_producidas'] as num?)?.toDouble() ?? 0,
    totalCost: (json['costo_total'] as num?)?.toDouble() ?? 0,
    totalRevenue: (json['ingreso_total'] as num?)?.toDouble() ?? 0,
    profit: (json['ganancia'] as num?)?.toDouble() ?? 0,
    roiPercent: (json['roi_porcentaje'] as num?)?.toDouble(),
    unitCost: (json['costo_unitario'] as num?)?.toDouble(),
  );
}

enum CycleTimelineKind { started, memberJoined, memberLeft, production }

class CycleTimelineItem {
  const CycleTimelineItem({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.title,
    this.detail,
  });

  final String id;
  final CycleTimelineKind kind;
  final DateTime occurredAt;
  final String title;
  final String? detail;
}

class CycleCreationInput {
  const CycleCreationInput({
    required this.farmId,
    required this.productCode,
    required this.animalTypeId,
    required this.animalIds,
    required this.startedAt,
    this.name,
    this.notes,
  });

  final String farmId;
  final String productCode;
  final String animalTypeId;
  final List<String> animalIds;
  final DateTime startedAt;
  final String? name;
  final String? notes;
}
