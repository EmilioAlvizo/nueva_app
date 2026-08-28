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

enum EconomicsV2CycleStatus {
  open,
  productionClosed,
  settled;

  static EconomicsV2CycleStatus fromCode(String value) => switch (value) {
    'open' => EconomicsV2CycleStatus.open,
    'closed' => EconomicsV2CycleStatus.productionClosed,
    'production_closed' => EconomicsV2CycleStatus.productionClosed,
    'settled' => EconomicsV2CycleStatus.settled,
    _ => throw ArgumentError.value(value, 'value', 'Unsupported cycle status'),
  };
}

enum EconomicsV2ReadinessReason {
  missingMembers,
  missingFeed,
  missingSaleableOutput,
  salesExceedOutput,
  openFeedIntervals,
  productionNotClosed;

  static EconomicsV2ReadinessReason fromCode(String value) => switch (value) {
    'missing_members' => EconomicsV2ReadinessReason.missingMembers,
    'missing_feed' => EconomicsV2ReadinessReason.missingFeed,
    'missing_saleable_output' =>
      EconomicsV2ReadinessReason.missingSaleableOutput,
    'sales_exceed_output' => EconomicsV2ReadinessReason.salesExceedOutput,
    'open_feed_intervals' => EconomicsV2ReadinessReason.openFeedIntervals,
    'production_not_closed' => EconomicsV2ReadinessReason.productionNotClosed,
    _ => throw ArgumentError.value(
      value,
      'value',
      'Unsupported readiness reason',
    ),
  };
}

final class EconomicsV2FarmAccess {
  const EconomicsV2FarmAccess({
    required this.farmId,
    required this.enabled,
    required this.role,
    required this.canEdit,
  });

  final String farmId;
  final bool enabled;
  final String role;
  final bool canEdit;

  @override
  bool operator ==(Object other) =>
      other is EconomicsV2FarmAccess &&
      other.farmId == farmId &&
      other.enabled == enabled &&
      other.role == role &&
      other.canEdit == canEdit;

  @override
  int get hashCode => Object.hash(farmId, enabled, role, canEdit);
}

final class EconomicsV2CycleSummary {
  const EconomicsV2CycleSummary({
    required this.cycleId,
    required this.farmId,
    required this.status,
    required this.startsOn,
    required this.purposeId,
    required this.purposeName,
    required this.activeAnimalCount,
    required this.exitedAnimalCount,
    required this.directExpenseTotal,
    required this.linkedMixtureCount,
    this.endsOn,
    this.latestLinkedGroupName,
  });

  final String cycleId;
  final String farmId;
  final String status;
  final DateTime startsOn;
  final DateTime? endsOn;
  final String purposeId;
  final String purposeName;
  final int activeAnimalCount;
  final int exitedAnimalCount;
  final double directExpenseTotal;
  final int linkedMixtureCount;
  final String? latestLinkedGroupName;

  bool get isOpen => status == 'open';
}

final class EconomicsV2CyclesDashboard {
  EconomicsV2CyclesDashboard(List<EconomicsV2CycleSummary> summaries)
    : summaries = List.unmodifiable(summaries),
      openCycleCount = summaries.where((cycle) => cycle.isOpen).length,
      activeAnimalCount = summaries.fold(
        0,
        (total, cycle) => total + cycle.activeAnimalCount,
      ),
      directExpenseTotal = summaries.fold(
        0,
        (total, cycle) => total + cycle.directExpenseTotal,
      );

  final List<EconomicsV2CycleSummary> summaries;
  final int openCycleCount;
  final int activeAnimalCount;
  final double directExpenseTotal;

  int get cycleCount => summaries.length;
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
        margin: (json['margin'] as num? ?? json['profit'] as num).toDouble(),
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

sealed class EconomicsV2ProjectionInput {
  const EconomicsV2ProjectionInput._();

  const factory EconomicsV2ProjectionInput({
    required double expectedUnitPrice,
    required double productionPerDay,
    required double feedPerDay,
    required double otherCosts,
    required int horizonDays,
  }) = _EconomicsV2ScenarioProjectionInput;

  const factory EconomicsV2ProjectionInput.legacy({
    required double expectedUnits,
    required double unitPrice,
  }) = _EconomicsV2LegacyProjectionInput;

  double? get expectedUnitPrice;
  double? get productionPerDay;
  double? get feedPerDay;
  double? get otherCosts;
  int? get horizonDays;
  double? get expectedUnits;
  double? get unitPrice;

  Map<String, dynamic> toJson();
}

final class _EconomicsV2ScenarioProjectionInput
    extends EconomicsV2ProjectionInput {
  const _EconomicsV2ScenarioProjectionInput({
    required this.expectedUnitPrice,
    required this.productionPerDay,
    required this.feedPerDay,
    required this.otherCosts,
    required this.horizonDays,
  }) : super._();

  @override
  final double expectedUnitPrice;
  @override
  final double productionPerDay;
  @override
  final double feedPerDay;
  @override
  final double otherCosts;
  @override
  final int horizonDays;
  @override
  double? get expectedUnits => null;
  @override
  double? get unitPrice => null;

  @override
  Map<String, dynamic> toJson() => {
    'expected_unit_price': expectedUnitPrice,
    'production_per_day': productionPerDay,
    'feed_per_day': feedPerDay,
    'other_costs': otherCosts,
    'horizon_days': horizonDays,
  };
}

final class _EconomicsV2LegacyProjectionInput
    extends EconomicsV2ProjectionInput {
  const _EconomicsV2LegacyProjectionInput({
    required this.expectedUnits,
    required this.unitPrice,
  }) : super._();

  @override
  double? get expectedUnitPrice => null;
  @override
  double? get productionPerDay => null;
  @override
  double? get feedPerDay => null;
  @override
  double? get otherCosts => null;
  @override
  int? get horizonDays => null;
  @override
  final double expectedUnits;
  @override
  final double unitPrice;

  @override
  Map<String, dynamic> toJson() => {
    'expected_units': expectedUnits,
    'unit_price': unitPrice,
  };
}

final class EconomicsV2CycleDetail {
  const EconomicsV2CycleDetail({
    required this.cycleId,
    required this.farmId,
    required this.name,
    required this.status,
    required this.startsOn,
    required this.purposeId,
    required this.purposeName,
    required this.purpose,
    required this.activeAnimalCount,
    required this.exitedAnimalCount,
    required this.feedCost,
    required this.directExpenseTotal,
    required this.revenue,
    required this.totalCost,
    required this.profit,
    required this.updatedAt,
    this.isCompatibilityMode = false,
    this.plannedEndsOn,
    this.productionClosedOn,
    this.settledOn,
    this.marginPercentage,
    this.unitCost,
    this.breakEven,
    this.latestGroupNameSnapshot,
  });

  final String cycleId;
  final String farmId;
  final String? name;
  final EconomicsV2CycleStatus status;
  final DateTime startsOn;
  final DateTime? plannedEndsOn;
  final DateTime? productionClosedOn;
  final DateTime? settledOn;
  final String purposeId;
  final String purposeName;
  final EconomicsV2Purpose purpose;
  final int activeAnimalCount;
  final int exitedAnimalCount;
  final double feedCost;
  final double directExpenseTotal;
  final double revenue;
  final double totalCost;
  final double profit;
  final double? marginPercentage;
  final double? unitCost;
  final double? breakEven;
  final String? latestGroupNameSnapshot;
  final DateTime? updatedAt;
  final bool isCompatibilityMode;

  factory EconomicsV2CycleDetail.fromJson(Map<String, dynamic> json) =>
      EconomicsV2CycleDetail(
        cycleId: json['cycle_id'] as String,
        farmId: json['granja_id'] as String,
        name: json['name'] as String?,
        status: EconomicsV2CycleStatus.fromCode(json['status'] as String),
        startsOn: DateTime.parse(json['starts_on'] as String),
        plannedEndsOn: _optionalDate(json['planned_ends_on']),
        productionClosedOn: _optionalDate(json['production_closed_on']),
        settledOn: _optionalDate(json['settled_on']),
        purposeId: json['purpose_id'] as String,
        purposeName: json['purpose_name'] as String,
        purpose: EconomicsV2Purpose.fromCode(json['purpose_code'] as String),
        activeAnimalCount: (json['active_animal_count'] as num).toInt(),
        exitedAnimalCount: (json['exited_animal_count'] as num).toInt(),
        feedCost: (json['feed_cost'] as num).toDouble(),
        directExpenseTotal: (json['direct_expense_total'] as num).toDouble(),
        revenue: (json['revenue'] as num).toDouble(),
        totalCost: (json['total_cost'] as num).toDouble(),
        profit: (json['profit'] as num).toDouble(),
        marginPercentage: (json['margin_percentage'] as num?)?.toDouble(),
        unitCost: (json['unit_cost'] as num?)?.toDouble(),
        breakEven: (json['break_even'] as num?)?.toDouble(),
        latestGroupNameSnapshot: json['latest_group_name_snapshot'] as String?,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

final class EconomicsV2CycleMember {
  const EconomicsV2CycleMember({
    required this.animalId,
    required this.label,
    required this.joinedOn,
    required this.isActive,
    this.groupNameSnapshot,
    this.leftOn,
  });

  final String animalId;
  final String label;
  final String? groupNameSnapshot;
  final DateTime joinedOn;
  final DateTime? leftOn;
  final bool isActive;

  factory EconomicsV2CycleMember.fromJson(Map<String, dynamic> json) =>
      EconomicsV2CycleMember(
        animalId: json['animal_id'] as String,
        label: json['label'] as String,
        groupNameSnapshot: json['group_name_snapshot'] as String?,
        joinedOn: DateTime.parse(json['joined_on'] as String),
        leftOn: _optionalDate(json['left_on']),
        isActive: json['is_active'] as bool,
      );
}

final class EconomicsV2AnimalCandidate {
  const EconomicsV2AnimalCandidate({
    required this.animalId,
    required this.label,
    this.groupName,
  });

  final String animalId;
  final String label;
  final String? groupName;

  factory EconomicsV2AnimalCandidate.fromJson(Map<String, dynamic> json) =>
      EconomicsV2AnimalCandidate(
        animalId: json['animal_id'] as String,
        label: json['label'] as String,
        groupName: json['group_name'] as String?,
      );
}

final class EconomicsV2CycleMembers {
  EconomicsV2CycleMembers({
    required List<EconomicsV2CycleMember> members,
    required List<EconomicsV2AnimalCandidate> candidates,
  }) : members = List.unmodifiable(members),
       candidates = List.unmodifiable(candidates);

  final List<EconomicsV2CycleMember> members;
  final List<EconomicsV2AnimalCandidate> candidates;

  factory EconomicsV2CycleMembers.fromJson(Map<String, dynamic> json) =>
      EconomicsV2CycleMembers(
        members: [
          for (final row in _jsonRows(json['members']))
            EconomicsV2CycleMember.fromJson(row),
        ],
        candidates: [
          for (final row in _jsonRows(json['candidates']))
            EconomicsV2AnimalCandidate.fromJson(row),
        ],
      );
}

final class EconomicsV2FeedInterval {
  const EconomicsV2FeedInterval({
    required this.feedId,
    required this.mixtureId,
    required this.mixtureLabel,
    required this.startsOn,
    required this.cost,
    this.groupNameSnapshot,
    this.endsOn,
  });

  final String feedId;
  final String mixtureId;
  final String mixtureLabel;
  final String? groupNameSnapshot;
  final DateTime startsOn;
  final DateTime? endsOn;
  final double cost;

  bool get isActive => endsOn == null;

  factory EconomicsV2FeedInterval.fromJson(Map<String, dynamic> json) =>
      EconomicsV2FeedInterval(
        feedId: json['feed_id'] as String,
        mixtureId: json['mixture_id'] as String,
        mixtureLabel: json['mixture_label'] as String,
        groupNameSnapshot: json['group_name_snapshot'] as String?,
        startsOn: DateTime.parse(json['starts_on'] as String),
        endsOn: _optionalDate(json['ends_on']),
        cost: (json['cost'] as num).toDouble(),
      );
}

final class EconomicsV2FeedCandidate {
  const EconomicsV2FeedCandidate({
    required this.mixtureId,
    required this.mixtureLabel,
    this.groupName,
  });

  final String mixtureId;
  final String mixtureLabel;
  final String? groupName;

  factory EconomicsV2FeedCandidate.fromJson(Map<String, dynamic> json) =>
      EconomicsV2FeedCandidate(
        mixtureId: json['mixture_id'] as String,
        mixtureLabel: json['mixture_label'] as String,
        groupName: json['group_name'] as String?,
      );
}

final class EconomicsV2CycleFeeds {
  EconomicsV2CycleFeeds({
    required List<EconomicsV2FeedInterval> intervals,
    required List<EconomicsV2FeedCandidate> candidates,
  }) : intervals = List.unmodifiable(intervals),
       candidates = List.unmodifiable(candidates);

  final List<EconomicsV2FeedInterval> intervals;
  final List<EconomicsV2FeedCandidate> candidates;

  factory EconomicsV2CycleFeeds.fromJson(Map<String, dynamic> json) =>
      EconomicsV2CycleFeeds(
        intervals: [
          for (final row in _jsonRows(json['intervals']))
            EconomicsV2FeedInterval.fromJson(row),
        ],
        candidates: [
          for (final row in _jsonRows(json['candidates']))
            EconomicsV2FeedCandidate.fromJson(row),
        ],
      );
}

final class EconomicsV2CycleExpense {
  const EconomicsV2CycleExpense({
    required this.expenseId,
    required this.occurredOn,
    required this.amount,
    this.category,
    this.note,
  });

  final String expenseId;
  final DateTime occurredOn;
  final double amount;
  final String? category;
  final String? note;

  factory EconomicsV2CycleExpense.fromJson(Map<String, dynamic> json) =>
      EconomicsV2CycleExpense(
        expenseId: json['expense_id'] as String,
        occurredOn: DateTime.parse(json['occurred_on'] as String),
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String?,
        note: json['note'] as String?,
      );
}

final class EconomicsV2ProjectionResult {
  const EconomicsV2ProjectionResult({
    required this.expectedUnits,
    required this.projectedRevenue,
    required this.projectedTotalCost,
    required this.projectedBalance,
  });

  final double expectedUnits;
  final double projectedRevenue;
  final double projectedTotalCost;
  final double projectedBalance;

  factory EconomicsV2ProjectionResult.fromJson(Map<String, dynamic> json) =>
      EconomicsV2ProjectionResult(
        expectedUnits: (json['expected_units'] as num).toDouble(),
        projectedRevenue: (json['projected_revenue'] as num).toDouble(),
        projectedTotalCost: (json['projected_total_cost'] as num).toDouble(),
        projectedBalance: (json['projected_balance'] as num).toDouble(),
      );
}

final class EconomicsV2SavedProjection {
  const EconomicsV2SavedProjection({
    required this.projectionId,
    required this.createdAt,
    required this.calculationVersion,
    required this.input,
    required this.result,
    this.note,
  });

  final String projectionId;
  final DateTime createdAt;
  final String? note;
  final String calculationVersion;
  final EconomicsV2ProjectionInput input;
  final EconomicsV2ProjectionResult result;

  factory EconomicsV2SavedProjection.fromJson(Map<String, dynamic> json) =>
      EconomicsV2SavedProjection(
        projectionId: json['projection_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        note: json['note'] as String?,
        calculationVersion: json['calculation_version'] as String,
        input: _projectionInputFromJson(
          Map<String, dynamic>.from(json['assumptions'] as Map),
        ),
        result: EconomicsV2ProjectionResult.fromJson(
          Map<String, dynamic>.from(json['result'] as Map),
        ),
      );
}

final class EconomicsV2CycleReadiness {
  EconomicsV2CycleReadiness({
    required this.cycleId,
    required this.status,
    required this.canCloseProduction,
    required this.canSettle,
    required this.hasMembers,
    required this.hasFeed,
    required this.hasSaleableOutput,
    required this.salesWithinOutput,
    required this.openFeedCount,
    required List<EconomicsV2ReadinessReason> reasons,
  }) : reasons = List.unmodifiable(reasons);

  final String cycleId;
  final EconomicsV2CycleStatus status;
  final bool canCloseProduction;
  final bool canSettle;
  final bool hasMembers;
  final bool hasFeed;
  final bool hasSaleableOutput;
  final bool salesWithinOutput;
  final int openFeedCount;
  final List<EconomicsV2ReadinessReason> reasons;

  factory EconomicsV2CycleReadiness.fromJson(Map<String, dynamic> json) =>
      EconomicsV2CycleReadiness(
        cycleId: json['cycle_id'] as String,
        status: EconomicsV2CycleStatus.fromCode(json['status'] as String),
        canCloseProduction: json['can_close_production'] as bool,
        canSettle: json['can_settle'] as bool,
        hasMembers: json['has_members'] as bool,
        hasFeed: json['has_feed'] as bool,
        hasSaleableOutput: json['has_saleable_output'] as bool,
        salesWithinOutput: json['sales_within_output'] as bool,
        openFeedCount: (json['open_feed_count'] as num).toInt(),
        reasons: [
          for (final reason in json['reasons'] as List)
            EconomicsV2ReadinessReason.fromCode(reason as String),
        ],
      );
}

final class EconomicsV2Finalization {
  const EconomicsV2Finalization({
    required this.cycleId,
    required this.status,
    required this.calculationVersion,
    required this.settledOn,
    required this.result,
  });

  final String cycleId;
  final EconomicsV2CycleStatus status;
  final String calculationVersion;
  final DateTime settledOn;
  final EconomicsV2Calculation result;

  factory EconomicsV2Finalization.fromJson(Map<String, dynamic> json) =>
      EconomicsV2Finalization(
        cycleId: json['cycle_id'] as String,
        status: EconomicsV2CycleStatus.fromCode(json['status'] as String),
        calculationVersion: json['calculation_version'] as String,
        settledOn: DateTime.parse(json['settled_on'] as String),
        result: EconomicsV2Calculation.fromJson(
          Map<String, dynamic>.from(json['result'] as Map),
        ),
      );
}

DateTime? _optionalDate(Object? value) => switch (value) {
  final String date => DateTime.parse(date),
  _ => null,
};

List<Map<String, dynamic>> _jsonRows(Object? value) => [
  for (final row in value as List? ?? const [])
    Map<String, dynamic>.from(row as Map),
];

EconomicsV2ProjectionInput _projectionInputFromJson(
  Map<String, dynamic> json,
) => EconomicsV2ProjectionInput(
  expectedUnitPrice: (json['expected_unit_price'] as num).toDouble(),
  productionPerDay: (json['production_per_day'] as num).toDouble(),
  feedPerDay: (json['feed_per_day'] as num).toDouble(),
  otherCosts: (json['other_costs'] as num).toDouble(),
  horizonDays: (json['horizon_days'] as num).toInt(),
);
