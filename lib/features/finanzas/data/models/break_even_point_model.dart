import '../../domain/entities/break_even_point.dart';

final class BreakEvenPointModel {
  const BreakEvenPointModel({
    required this.startedAt,
    required this.endedAt,
    required this.mixtureId,
    required this.groupName,
    required this.goodEggs,
    required this.brokenEggs,
    required this.totalFoodCost,
    required this.breakEvenPrice,
  });

  factory BreakEvenPointModel.fromJson(Map<String, dynamic> json) {
    return BreakEvenPointModel(
      startedAt: _requiredDate(json, 'fecha_inicio'),
      endedAt: _nullableDate(json, 'fecha_termino'),
      mixtureId: _requiredUuid(json, 'mezcla_id'),
      groupName: _requiredText(json, 'grupo_nombre'),
      goodEggs: _requiredNonNegativeInt(json, 'buenos'),
      brokenEggs: _requiredNonNegativeInt(json, 'rotos'),
      totalFoodCost: _requiredNonNegativeDouble(json, 'total_costo_comidas'),
      breakEvenPrice: _nullableNonNegativeDouble(json, 'punto_de_equilibrio'),
    );
  }

  final DateTime startedAt;
  final DateTime? endedAt;
  final String mixtureId;
  final String groupName;
  final int goodEggs;
  final int brokenEggs;
  final double totalFoodCost;
  final double? breakEvenPrice;

  BreakEvenPoint toEntity() => BreakEvenPoint(
    startedAt: startedAt,
    endedAt: endedAt,
    mixtureId: mixtureId,
    groupName: groupName,
    goodEggs: goodEggs,
    brokenEggs: brokenEggs,
    totalFoodCost: totalFoodCost,
    breakEvenPrice: breakEvenPrice,
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
    final value = json[key];
    final parsed = switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };
    if (parsed == null || !parsed.isFinite || parsed < 0) {
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
}
