import '../../domain/entities/break_even_point.dart';

final class BreakEvenPointModel {
  const BreakEvenPointModel({
    required this.farmId,
    required this.groupId,
    required this.startedAt,
    required this.endedAt,
    required this.calculatedEndAt,
    required this.mixtureId,
    required this.groupName,
    required this.mixtureDays,
    required this.goodEggs,
    required this.brokenEggs,
    required this.totalFoodCost,
    required this.totalFeedConsumption,
    required this.weightedAverageBirds,
    required this.eggsPerDay,
    required this.eggsPerDayPerBird,
    required this.feedPerDay,
    required this.feedPerDayPerBird,
    required this.breakEvenPrice,
    required this.averageSalePrice,
    required this.marginPercentage,
  });

  factory BreakEvenPointModel.fromJson(Map<String, dynamic> json) {
    return BreakEvenPointModel(
      farmId: _requiredUuid(json, 'granja_id'),
      groupId: _requiredUuid(json, 'grupo_id'),
      startedAt: _requiredDate(json, 'fecha_inicio'),
      endedAt: _nullableDate(json, 'fecha_termino'),
      calculatedEndAt: _requiredDate(json, 'fecha_fin_calculada'),
      mixtureId: _requiredUuid(json, 'mezcla_id'),
      groupName: _requiredText(json, 'grupo_nombre'),
      mixtureDays: _requiredPositiveInt(json, 'dias_mezcla'),
      goodEggs: _requiredNonNegativeInt(json, 'buenos'),
      brokenEggs: _requiredNonNegativeInt(json, 'rotos'),
      totalFoodCost: _requiredNonNegativeDouble(json, 'total_costo_comidas'),
      totalFeedConsumption: _requiredNonNegativeDouble(json, 'consumo_total'),
      weightedAverageBirds: _requiredNonNegativeDouble(
        json,
        'aves_promedio_ponderado',
      ),
      eggsPerDay: _requiredNonNegativeDouble(json, 'huevos_por_dia'),
      eggsPerDayPerBird: _nullableNonNegativeDouble(json, 'huevos_por_dia_ave'),
      feedPerDay: _requiredNonNegativeDouble(json, 'consumo_por_dia'),
      feedPerDayPerBird: _nullableNonNegativeDouble(
        json,
        'consumo_por_dia_ave',
      ),
      breakEvenPrice: _nullableNonNegativeDouble(json, 'punto_de_equilibrio'),
      averageSalePrice: _nullableNonNegativeDouble(
        json,
        'precio_venta_promedio',
      ),
      marginPercentage: _nullableFiniteDouble(json, 'margen_porcentaje'),
    );
  }

  final String farmId;
  final String groupId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime calculatedEndAt;
  final String mixtureId;
  final String groupName;
  final int mixtureDays;
  final int goodEggs;
  final int brokenEggs;
  final double totalFoodCost;
  final double totalFeedConsumption;
  final double weightedAverageBirds;
  final double eggsPerDay;
  final double? eggsPerDayPerBird;
  final double feedPerDay;
  final double? feedPerDayPerBird;
  final double? breakEvenPrice;
  final double? averageSalePrice;
  final double? marginPercentage;

  BreakEvenPoint toEntity() => BreakEvenPoint(
    farmId: farmId,
    groupId: groupId,
    startedAt: startedAt,
    endedAt: endedAt,
    calculatedEndAt: calculatedEndAt,
    mixtureId: mixtureId,
    groupName: groupName,
    mixtureDays: mixtureDays,
    goodEggs: goodEggs,
    brokenEggs: brokenEggs,
    totalFoodCost: totalFoodCost,
    totalFeedConsumption: totalFeedConsumption,
    weightedAverageBirds: weightedAverageBirds,
    eggsPerDay: eggsPerDay,
    eggsPerDayPerBird: eggsPerDayPerBird,
    feedPerDay: feedPerDay,
    feedPerDayPerBird: feedPerDayPerBird,
    breakEvenPrice: breakEvenPrice,
    averageSalePrice: averageSalePrice,
    marginPercentage: marginPercentage,
  );

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static String _requiredUuid(Map<String, dynamic> json, String key) {
    final value = _requiredText(json, key);
    if (!_uuidPattern.hasMatch(value)) {
      throw FormatException('Expected $key to be a UUID.');
    }
    return value;
  }

  static String _requiredText(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Expected non-empty $key.');
    }
    return value.trim();
  }

  static DateTime _requiredDate(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw FormatException('Expected $key to be a date.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('Expected $key to be a date.');
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime? _nullableDate(Map<String, dynamic> json, String key) {
    if (json[key] == null) return null;
    return _requiredDate(json, key);
  }

  static int _requiredPositiveInt(Map<String, dynamic> json, String key) {
    final parsed = _requiredNonNegativeInt(json, key);
    if (parsed == 0) {
      throw FormatException('Expected $key to be a positive integer.');
    }
    return parsed;
  }

  static int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    final parsed = switch (value) {
      int number => number,
      num number when number.isFinite && number == number.roundToDouble() =>
        number.toInt(),
      String text => int.tryParse(text),
      _ => null,
    };
    if (parsed == null || parsed < 0) {
      throw FormatException('Expected $key to be a non-negative integer.');
    }
    return parsed;
  }

  static double _requiredNonNegativeDouble(
    Map<String, dynamic> json,
    String key,
  ) {
    final parsed = _finiteDouble(json[key]);
    if (parsed == null || parsed < 0) {
      throw FormatException('Expected $key to be a non-negative number.');
    }
    return parsed;
  }

  static double? _nullableNonNegativeDouble(
    Map<String, dynamic> json,
    String key,
  ) {
    if (json[key] == null) return null;
    return _requiredNonNegativeDouble(json, key);
  }

  static double? _nullableFiniteDouble(Map<String, dynamic> json, String key) {
    if (json[key] == null) return null;
    final parsed = _finiteDouble(json[key]);
    if (parsed == null) {
      throw FormatException('Expected $key to be a finite number.');
    }
    return parsed;
  }

  static double? _finiteDouble(Object? value) {
    final parsed = switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };
    return parsed?.isFinite ?? false ? parsed : null;
  }
}
