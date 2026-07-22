import 'dart:math' as math;

enum EggPeriod {
  weekly('Semanal', 7),
  monthly('Mensual', 30),
  bimonthly('Bimestral', 60),
  fourMonthly('Cuatrimestral', 120),
  total('Total', null);

  const EggPeriod(this.label, this.days);

  final String label;
  final int? days;
}

class EggFilters {
  const EggFilters({this.groupId, this.period = EggPeriod.monthly});

  final String? groupId;
  final EggPeriod period;

  EggFilters copyWith({
    String? groupId,
    bool clearGroup = false,
    EggPeriod? period,
  }) {
    return EggFilters(
      groupId: clearGroup ? null : groupId ?? this.groupId,
      period: period ?? this.period,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EggFilters &&
        other.groupId == groupId &&
        other.period == period;
  }

  @override
  int get hashCode => Object.hash(groupId, period);
}

class EggGroupChoice {
  const EggGroupChoice({
    required this.id,
    required this.name,
    required this.animalTypeId,
    required this.animalTypeName,
  });

  final String id;
  final String name;
  final String animalTypeId;
  final String animalTypeName;

  String get displayName => '$name · $animalTypeName';
}

class EggCollection {
  const EggCollection({
    required this.id,
    required this.farmId,
    required this.groupId,
    required this.date,
    required this.goodEggs,
    required this.brokenEggs,
    required this.createdAt,
    required this.groupName,
    required this.animalTypeId,
    required this.animalTypeName,
    required this.authorName,
  });

  factory EggCollection.fromJson(Map<String, dynamic> json) {
    final group = _map(json['group'] ?? json['grupos']);
    final animalType = _map(group?['animal_type'] ?? group?['tipo_animal']);
    final author = _map(json['author'] ?? json['perfiles']);
    return EggCollection(
      id: json['id'] as String,
      farmId: json['granja_id'] as String,
      groupId: json['grupo_id'] as String,
      date: DateTime.parse(json['fecha_recoleccion'] as String),
      goodEggs: _integer(json['buenos']),
      brokenEggs: _integer(json['rotos']),
      createdAt: DateTime.parse(json['created_at'] as String),
      groupName: group?['nombre'] as String? ?? 'Grupo desconocido',
      animalTypeId: group?['tipo_animal_id'] as String? ?? '',
      animalTypeName: animalType?['nombre'] as String? ?? 'Tipo desconocido',
      authorName: author?['nombre'] as String? ?? 'Usuario desconocido',
    );
  }

  final String id;
  final String farmId;
  final String groupId;
  final DateTime date;
  final int goodEggs;
  final int brokenEggs;
  final DateTime createdAt;
  final String groupName;
  final String animalTypeId;
  final String animalTypeName;
  final String authorName;

  int get totalEggs => goodEggs + brokenEggs;
}

class EggSale {
  const EggSale({
    required this.id,
    required this.farmId,
    required this.groupId,
    required this.date,
    required this.quantity,
    required this.unitPrice,
    required this.createdAt,
    required this.groupName,
    required this.animalTypeId,
    required this.animalTypeName,
    required this.authorName,
  });

  factory EggSale.fromJson(Map<String, dynamic> json) {
    final group = _map(json['group'] ?? json['grupos']);
    final animalType = _map(group?['animal_type'] ?? group?['tipo_animal']);
    final author = _map(json['author'] ?? json['perfiles']);
    return EggSale(
      id: json['id'] as String,
      farmId: json['granja_id'] as String,
      groupId: json['grupo_id'] as String?,
      date: DateTime.parse(json['fecha_venta'] as String),
      quantity: _integer(json['cantidad']),
      unitPrice: _decimal(json['precio']),
      createdAt: DateTime.parse(json['created_at'] as String),
      groupName: group?['nombre'] as String? ?? 'Sin grupo histórico',
      animalTypeId: group?['tipo_animal_id'] as String? ?? '',
      animalTypeName: animalType?['nombre'] as String? ?? 'Tipo desconocido',
      authorName: author?['nombre'] as String? ?? 'Usuario desconocido',
    );
  }

  final String id;
  final String farmId;
  final String? groupId;
  final DateTime date;
  final int quantity;
  final double unitPrice;
  final DateTime createdAt;
  final String groupName;
  final String animalTypeId;
  final String animalTypeName;
  final String authorName;

  double get total => quantity * unitPrice;
}

class EggData {
  const EggData({required this.collections, required this.sales});

  final List<EggCollection> collections;
  final List<EggSale> sales;

  EggData filtered({
    required String animalTypeId,
    required EggFilters filters,
    required DateTime now,
  }) {
    bool matches({
      required String itemAnimalTypeId,
      required String? itemGroupId,
      required DateTime date,
    }) {
      if (animalTypeId != 'all' && itemAnimalTypeId != animalTypeId) {
        return false;
      }
      if (filters.groupId != null && itemGroupId != filters.groupId) {
        return false;
      }
      return _isWithinPeriod(date, filters.period, now);
    }

    return EggData(
      collections: [
        for (final item in collections)
          if (matches(
            itemAnimalTypeId: item.animalTypeId,
            itemGroupId: item.groupId,
            date: item.date,
          ))
            item,
      ],
      sales: [
        for (final item in sales)
          if (matches(
            itemAnimalTypeId: item.animalTypeId,
            itemGroupId: item.groupId,
            date: item.date,
          ))
            item,
      ],
    );
  }
}

class EggSummary {
  const EggSummary({
    required this.goodEggs,
    required this.brokenEggs,
    required this.soldEggs,
    required this.consumedEggs,
    required this.income,
    required this.averageSalePrice,
    required this.collectionCount,
    required this.saleCount,
  });

  factory EggSummary.fromData(EggData data) {
    final goodEggs = data.collections.fold<int>(
      0,
      (sum, item) => sum + item.goodEggs,
    );
    final brokenEggs = data.collections.fold<int>(
      0,
      (sum, item) => sum + item.brokenEggs,
    );
    final soldEggs = data.sales.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final income = data.sales.fold<double>(0, (sum, item) => sum + item.total);
    return EggSummary(
      goodEggs: goodEggs,
      brokenEggs: brokenEggs,
      soldEggs: soldEggs,
      consumedEggs: math.max(goodEggs - soldEggs, 0),
      income: income,
      averageSalePrice: soldEggs == 0 ? 0 : income / soldEggs,
      collectionCount: data.collections.length,
      saleCount: data.sales.length,
    );
  }

  final int goodEggs;
  final int brokenEggs;
  final int soldEggs;
  final int consumedEggs;
  final double income;
  final double averageSalePrice;
  final int collectionCount;
  final int saleCount;

  int get destinationTotal => consumedEggs + soldEggs + brokenEggs;
}

class EggAccess {
  const EggAccess({required this.canEdit});

  final bool canEdit;
}

class EggCollectionInput {
  const EggCollectionInput({
    required this.farmId,
    required this.groupId,
    required this.goodEggs,
    required this.brokenEggs,
    required this.date,
  });

  final String farmId;
  final String groupId;
  final int goodEggs;
  final int brokenEggs;
  final DateTime date;

  String? validate() {
    if (groupId.isEmpty) return 'Selecciona un grupo.';
    if (goodEggs < 0 || brokenEggs < 0) {
      return 'Las cantidades no pueden ser negativas.';
    }
    if (goodEggs + brokenEggs == 0) {
      return 'Registra al menos un huevo recolectado.';
    }
    return null;
  }
}

class EggSaleInput {
  const EggSaleInput({
    required this.farmId,
    required this.groupId,
    required this.quantity,
    required this.unitPrice,
    required this.date,
  });

  final String farmId;
  final String groupId;
  final int quantity;
  final double unitPrice;
  final DateTime date;

  double get total => quantity * unitPrice;

  String? validate() {
    if (groupId.isEmpty) return 'Selecciona un grupo.';
    if (quantity <= 0) return 'La cantidad debe ser mayor que cero.';
    if (!unitPrice.isFinite || unitPrice <= 0) {
      return 'El precio unitario debe ser un número mayor que cero.';
    }
    return null;
  }
}

bool _isWithinPeriod(DateTime value, EggPeriod period, DateTime now) {
  final days = period.days;
  if (days == null) return true;
  final date = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  final firstDay = today.subtract(Duration(days: days - 1));
  return !date.isBefore(firstDay) && !date.isAfter(today);
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

int _integer(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.parse(text),
  _ => throw const FormatException('Expected an integer value.'),
};

double _decimal(Object? value) => switch (value) {
  num number => number.toDouble(),
  String text => double.parse(text),
  _ => throw const FormatException('Expected a decimal value.'),
};
