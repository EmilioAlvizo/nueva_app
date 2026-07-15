import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/cycle_supabase_repository.dart';
import '../../domain/cycle_models.dart';
import '../../domain/cycle_repository.dart';

part 'cycle_providers.g.dart';

@Riverpod(keepAlive: true)
CycleRepository cycleRepository(Ref ref) =>
    CycleSupabaseRepository(Supabase.instance.client);

@riverpod
Future<CycleCatalogs> cycleCatalogs(Ref ref) =>
    ref.watch(cycleRepositoryProvider).getCatalogs();

@riverpod
Future<List<Cycle>> cycles(Ref ref, String farmId) =>
    ref.watch(cycleRepositoryProvider).getCycles(farmId);

@riverpod
Future<CycleDetail> cycleDetail(Ref ref, String cycleId) =>
    ref.watch(cycleRepositoryProvider).getCycleDetail(cycleId);

@riverpod
Future<CycleEconomics?> cycleEconomics(Ref ref, String cycleId) =>
    ref.watch(cycleRepositoryProvider).getEconomics(cycleId);

@riverpod
Future<List<CycleTimelineItem>> cycleTimeline(Ref ref, String cycleId) =>
    ref.watch(cycleRepositoryProvider).getTimeline(cycleId);

@riverpod
Future<List<CycleGroup>> cycleGroups(Ref ref, String farmId) =>
    ref.watch(cycleRepositoryProvider).getGroups(farmId);

@riverpod
Future<List<CycleMemberCandidate>> eligibleCycleMembers(
  Ref ref,
  String farmId,
) => ref.watch(cycleRepositoryProvider).getMemberCandidates(farmId);

@riverpod
Future<CycleAccess> cycleAccess(Ref ref, String farmId) =>
    ref.watch(cycleRepositoryProvider).getAccess(farmId);

@riverpod
class CycleMutations extends _$CycleMutations {
  @override
  Future<void> build() async {}

  Future<Cycle> create(CycleCreationInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(cycleRepositoryProvider).createCycle(input),
    );
    return switch (result) {
      AsyncData(:final value) => _complete(value),
      AsyncError(:final error, :final stackTrace) => _fail(error, stackTrace),
      AsyncLoading() => throw StateError('Cycle creation did not complete.'),
    };
  }

  Cycle _complete(Cycle cycle) {
    if (ref.mounted) {
      state = const AsyncData(null);
    }
    return cycle;
  }

  Never _fail(Object error, StackTrace stackTrace) {
    if (ref.mounted) {
      state = AsyncError(error, stackTrace);
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}
