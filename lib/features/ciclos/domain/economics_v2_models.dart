enum EconomicsV2Purpose {
  postura,
  carne,
  ornamental;

  String get code => name;

  static EconomicsV2Purpose fromCode(String value) => switch (value) {
    'postura' => EconomicsV2Purpose.postura,
    'carne' => EconomicsV2Purpose.carne,
    'ornamental' => EconomicsV2Purpose.ornamental,
    _ => throw ArgumentError.value(value, 'value', 'Unsupported V2 purpose'),
  };
}

class EconomicsV2Cycle {
  const EconomicsV2Cycle({
    required this.id,
    required this.farmId,
    required this.status,
  });

  final String id;
  final String farmId;
  final String status;

  factory EconomicsV2Cycle.fromJson(Map<String, dynamic> json) =>
      EconomicsV2Cycle(
        id: json['cycle_id'] as String,
        farmId: json['granja_id'] as String,
        status: json['status'] as String,
      );
}

sealed class EconomicsV2Result {
  const EconomicsV2Result({
    required this.cycleId,
    required this.purpose,
    required this.productionBasis,
  });

  final String cycleId;
  final EconomicsV2Purpose purpose;
  final String productionBasis;
}

class EconomicsV2Calculation extends EconomicsV2Result {
  const EconomicsV2Calculation({
    required super.cycleId,
    required super.purpose,
    required super.productionBasis,
    required this.totalCost,
    required this.revenue,
    required this.margin,
    this.breakEven,
  });

  final double totalCost;
  final double revenue;
  final double margin;
  final double? breakEven;

  factory EconomicsV2Calculation.fromJson(Map<String, dynamic> json) =>
      EconomicsV2Calculation(
        cycleId: json['cycle_id'] as String,
        purpose: EconomicsV2Purpose.fromCode(json['purpose_code'] as String),
        productionBasis: json['production_basis'] as String,
        totalCost: (json['total_cost'] as num).toDouble(),
        revenue: (json['revenue'] as num).toDouble(),
        margin: (json['margin'] as num).toDouble(),
        breakEven: (json['break_even'] as num?)?.toDouble(),
      );
}

class EconomicsV2Projection extends EconomicsV2Result {
  const EconomicsV2Projection({
    required super.cycleId,
    required super.purpose,
    required super.productionBasis,
    required this.projectedRevenue,
    required this.projectedTotalCost,
    required this.projectedMargin,
  });

  final double projectedRevenue;
  final double projectedTotalCost;
  final double projectedMargin;

  factory EconomicsV2Projection.fromJson(Map<String, dynamic> json) =>
      EconomicsV2Projection(
        cycleId: json['cycle_id'] as String,
        purpose: EconomicsV2Purpose.fromCode(json['purpose_code'] as String),
        productionBasis: json['production_basis'] as String,
        projectedRevenue: (json['projected_revenue'] as num).toDouble(),
        projectedTotalCost: (json['projected_total_cost'] as num).toDouble(),
        projectedMargin: (json['projected_margin'] as num).toDouble(),
      );
}

class EconomicsV2ProjectionInput {
  const EconomicsV2ProjectionInput({
    required this.expectedUnits,
    required this.unitPrice,
  });

  final double expectedUnits;
  final double unitPrice;

  Map<String, double> toJson() => {
    'expected_units': expectedUnits,
    'unit_price': unitPrice,
  };
}
