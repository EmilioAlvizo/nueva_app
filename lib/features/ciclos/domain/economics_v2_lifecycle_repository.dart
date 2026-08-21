import 'economics_v2_lifecycle_models.dart';

abstract interface class EconomicsV2LifecycleRepository {
  Future<EconomicsV2CycleCreated> createCycle(
    EconomicsV2CreateCycleRequest request,
  );

  Future<EconomicsV2AnimalAssigned> assignAnimal(
    EconomicsV2AssignAnimalRequest request,
  );

  Future<EconomicsV2ExpenseRecorded> recordExpense(
    EconomicsV2RecordExpenseRequest request,
  );

  Future<EconomicsV2FeedLinked> linkFeed(EconomicsV2LinkFeedRequest request);
}
