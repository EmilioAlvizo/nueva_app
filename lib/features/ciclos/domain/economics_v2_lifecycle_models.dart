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

class EconomicsV2ExpenseRecorded {
  const EconomicsV2ExpenseRecorded({required this.expenseId});

  final String expenseId;
}

class EconomicsV2FeedLinked {
  const EconomicsV2FeedLinked({required this.feedId});

  final String feedId;
}
