import 'economics_v2_models.dart';

class EconomicsV2CreateCycleRequest {
  const EconomicsV2CreateCycleRequest({
    required this.farmId,
    required this.purposeId,
    required this.startsOn,
    this.endsOn,
  });

  final String farmId, purposeId;
  final DateTime startsOn;
  final DateTime? endsOn;
}

class EconomicsV2AssignAnimalRequest {
  const EconomicsV2AssignAnimalRequest({
    required this.farmId,
    required this.cycleId,
    required this.animalId,
    required this.joinedOn,
  });

  final String farmId, cycleId, animalId;
  final DateTime joinedOn;
}

class EconomicsV2AssignAnimalsRequest {
  const EconomicsV2AssignAnimalsRequest({
    required this.cycleId,
    required this.animalIds,
    required this.joinedOn,
  });

  final String cycleId;
  final List<String> animalIds;
  final DateTime joinedOn;
}

class EconomicsV2RecordExpenseRequest {
  const EconomicsV2RecordExpenseRequest({
    required this.farmId,
    required this.cycleId,
    required this.occurredOn,
    required this.amount,
    this.category,
    this.note,
  });

  final String farmId, cycleId;
  final DateTime occurredOn;
  final double amount;
  final String? category;
  final String? note;
}

class EconomicsV2CloseProductionRequest {
  const EconomicsV2CloseProductionRequest({
    required this.farmId,
    required this.cycleId,
    required this.closedOn,
  });

  final String farmId, cycleId;
  final DateTime closedOn;
}

class EconomicsV2CycleSaleRequest {
  const EconomicsV2CycleSaleRequest({
    required this.farmId,
    required this.cycleId,
    required this.animalIds,
    required this.soldOn,
    required this.totalAmount,
    required this.totalWeightKg,
    this.note,
  });

  final String farmId, cycleId;
  final List<String> animalIds;
  final DateTime soldOn;
  final double totalAmount, totalWeightKg;
  final String? note;
}

class EconomicsV2LinkFeedRequest {
  const EconomicsV2LinkFeedRequest({
    required this.farmId,
    required this.cycleId,
    required this.mixtureId,
    required this.startsOn,
    this.endsOn,
  });

  final String farmId, cycleId, mixtureId;
  final DateTime startsOn;
  final DateTime? endsOn;
}

class EconomicsV2CycleCreated {
  const EconomicsV2CycleCreated({required this.cycleId});
  final String cycleId;
}

class EconomicsV2AnimalAssigned {
  const EconomicsV2AnimalAssigned({
    required this.cycleId,
    required this.animalId,
  });

  final String cycleId, animalId;
}

class EconomicsV2AnimalsAssigned {
  const EconomicsV2AnimalsAssigned({
    required this.cycleId,
    required this.animalIds,
  });

  final String cycleId;
  final List<String> animalIds;
}

class EconomicsV2ExpenseRecorded {
  const EconomicsV2ExpenseRecorded({required this.expenseId});

  final String expenseId;
}

class EconomicsV2FeedLinked {
  const EconomicsV2FeedLinked({required this.feedId});

  final String feedId;
}

class EconomicsV2CycleSaleRecorded {
  const EconomicsV2CycleSaleRecorded({
    required this.saleId,
    required this.cycleId,
    required this.soldCount,
    required this.status,
  });

  factory EconomicsV2CycleSaleRecorded.fromJson(Map<String, dynamic> json) =>
      EconomicsV2CycleSaleRecorded(
        saleId: json['sale_id'] as String,
        cycleId: json['cycle_id'] as String,
        soldCount: (json['sold_count'] as num).toInt(),
        status: EconomicsV2CycleStatus.fromCode(json['status'] as String),
      );

  final String saleId, cycleId;
  final int soldCount;
  final EconomicsV2CycleStatus status;
}
