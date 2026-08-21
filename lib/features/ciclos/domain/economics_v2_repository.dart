import 'economics_v2_models.dart';

abstract interface class EconomicsV2Repository {
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
  Future<void> finalize({required String farmId, required String cycleId});
}
