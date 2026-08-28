import 'economics_v2_lifecycle_models.dart';
import 'economics_v2_models.dart';

abstract interface class EconomicsV2Repository {
  Future<EconomicsV2FarmAccess> getAccess(String farmId);
  Future<List<EconomicsV2CycleSummary>> getCycleSummaries(String farmId);
  Future<List<EconomicsV2Cycle>> getCycles(String farmId);
  Future<EconomicsV2Calculation> calculate({
    required String farmId,
    required String cycleId,
  });
  Future<EconomicsV2Projection> project({
    required String farmId,
    required String cycleId,
    required EconomicsV2ProjectionInput input,
  });
  Future<EconomicsV2CycleDetail> getCycleDetail({
    required String farmId,
    required String cycleId,
  });
  Future<EconomicsV2CycleMembers> getCycleMembers({
    required String farmId,
    required String cycleId,
  });
  Future<EconomicsV2CycleFeeds> getCycleFeeds({
    required String farmId,
    required String cycleId,
  });
  Future<List<EconomicsV2CycleExpense>> getCycleExpenses({
    required String farmId,
    required String cycleId,
  });
  Future<List<EconomicsV2SavedProjection>> getCycleProjections({
    required String farmId,
    required String cycleId,
  });
  Future<EconomicsV2CycleReadiness> getCycleReadiness({
    required String farmId,
    required String cycleId,
  });
  Future<EconomicsV2SavedProjection> saveProjection({
    required String farmId,
    required String cycleId,
    required EconomicsV2ProjectionInput input,
    String? note,
  });
  Future<EconomicsV2CycleDetail> closeProduction(
    EconomicsV2CloseProductionRequest request,
  );
  Future<EconomicsV2Finalization> finalize({
    required String farmId,
    required String cycleId,
  });
}
