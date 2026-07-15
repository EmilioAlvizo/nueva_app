import 'cycle_models.dart';

abstract interface class CycleRepository {
  Future<CycleCatalogs> getCatalogs();
  Future<List<Cycle>> getCycles(String farmId);
  Future<CycleDetail> getCycleDetail(String cycleId);
  Future<CycleEconomics?> getEconomics(String cycleId);
  Future<List<CycleTimelineItem>> getTimeline(String cycleId);
  Future<List<CycleGroup>> getGroups(String farmId);
  Future<List<CycleMemberCandidate>> getMemberCandidates(String farmId);
  Future<CycleAccess> getAccess(String farmId);
  Future<Cycle> createCycle(CycleCreationInput input);
  Future<Cycle> editMembers(CycleMembershipEditInput input);
}
