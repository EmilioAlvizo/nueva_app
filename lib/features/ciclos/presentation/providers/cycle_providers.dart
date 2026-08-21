import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/cycle_supabase_repository.dart';
import '../../data/economics_v2_supabase_repository.dart';
import '../../domain/cycle_models.dart';
import '../../domain/cycle_repository.dart';
import '../../domain/economics_v2_lifecycle_models.dart';
import '../../domain/economics_v2_lifecycle_repository.dart';
import '../../domain/economics_v2_models.dart';
import '../../domain/economics_v2_repository.dart';

part 'cycle_providers.g.dart';

@Riverpod(keepAlive: true)
CycleRepository cycleRepository(Ref ref) =>
    CycleSupabaseRepository(Supabase.instance.client);

@Riverpod(keepAlive: true)
EconomicsV2Repository economicsV2Repository(Ref ref) =>
    EconomicsV2SupabaseRepository(Supabase.instance.client);

@Riverpod(keepAlive: true)
EconomicsV2LifecycleRepository economicsV2LifecycleRepository(Ref ref) =>
    EconomicsV2SupabaseRepository(Supabase.instance.client);

@riverpod
Future<List<EconomicsV2Cycle>> economicsV2Cycles(Ref ref, String farmId) =>
    ref.watch(economicsV2RepositoryProvider).getCycles(farmId);

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

@riverpod
class EconomicsV2Mutations extends _$EconomicsV2Mutations {
  @override
  Future<EconomicsV2Result?> build() async => null;

  Future<EconomicsV2Calculation> calculate({
    required String farmId,
    required String cycleId,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(economicsV2RepositoryProvider)
          .calculate(farmId: farmId, cycleId: cycleId),
    );
    return switch (result) {
      AsyncData(:final value) => _complete(value),
      AsyncError(:final error, :final stackTrace) => _fail(error, stackTrace),
      AsyncLoading() => throw StateError('V2 calculation did not complete.'),
    };
  }

  Future<EconomicsV2Projection> project({
    required String farmId,
    required String cycleId,
    required EconomicsV2ProjectionInput input,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(economicsV2RepositoryProvider)
          .project(farmId: farmId, cycleId: cycleId, input: input),
    );
    return switch (result) {
      AsyncData(:final value) => _complete(value),
      AsyncError(:final error, :final stackTrace) => _fail(error, stackTrace),
      AsyncLoading() => throw StateError('V2 projection did not complete.'),
    };
  }

  Future<void> finalize({required String farmId, required String cycleId}) =>
      _run(
        () => ref
            .read(economicsV2RepositoryProvider)
            .finalize(farmId: farmId, cycleId: cycleId),
      );

  T _complete<T extends EconomicsV2Result>(T result) {
    if (ref.mounted) {
      state = AsyncData(result);
    }
    return result;
  }

  Future<void> _run(Future<void> Function() operation) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(operation);
    if (!ref.mounted) return;
    if (result case AsyncError(:final error, :final stackTrace)) {
      state = AsyncError(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
    state = const AsyncData(null);
  }

  Never _fail(Object error, StackTrace stackTrace) {
    if (ref.mounted) {
      state = AsyncError(error, stackTrace);
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

@riverpod
class EconomicsV2LifecycleMutations extends _$EconomicsV2LifecycleMutations {
  @override
  Future<Object?> build() async => null;

  Future<EconomicsV2CycleCreated> create(
    EconomicsV2CreateCycleRequest request,
  ) => _run(
    () => ref.read(economicsV2LifecycleRepositoryProvider).createCycle(request),
  );

  Future<EconomicsV2AnimalAssigned> assignAnimal(
    EconomicsV2AssignAnimalRequest request,
  ) => _run(
    () =>
        ref.read(economicsV2LifecycleRepositoryProvider).assignAnimal(request),
  );

  Future<EconomicsV2ExpenseRecorded> recordExpense(
    EconomicsV2RecordExpenseRequest request,
  ) => _run(
    () =>
        ref.read(economicsV2LifecycleRepositoryProvider).recordExpense(request),
  );

  Future<EconomicsV2FeedLinked> linkFeed(EconomicsV2LinkFeedRequest request) =>
      _run(
        () =>
            ref.read(economicsV2LifecycleRepositoryProvider).linkFeed(request),
      );

  Future<T> _run<T extends Object>(Future<T> Function() operation) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(operation);
    return switch (result) {
      AsyncData(:final value) => _complete(value),
      AsyncError(:final error, :final stackTrace) => _fail(error, stackTrace),
      AsyncLoading() => throw StateError(
        'Lifecycle mutation did not complete.',
      ),
    };
  }

  T _complete<T extends Object>(T result) {
    if (ref.mounted) {
      state = AsyncData(result);
    }
    return result;
  }

  Never _fail(Object error, StackTrace stackTrace) {
    if (ref.mounted) {
      state = AsyncError(error, stackTrace);
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}
