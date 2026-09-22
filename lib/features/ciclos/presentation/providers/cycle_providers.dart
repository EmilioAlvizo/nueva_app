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

Duration? doNotRetryProvider(int retryCount, Object error) => null;

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

@Riverpod(retry: doNotRetryProvider)
Future<EconomicsV2FarmAccess> economicsV2Access(Ref ref, String farmId) =>
    ref.watch(economicsV2RepositoryProvider).getAccess(farmId);

@Riverpod(retry: doNotRetryProvider)
Future<EconomicsV2CyclesDashboard> economicsV2CycleSummaries(
  Ref ref,
  String farmId,
) async {
  final summaries = await ref
      .watch(economicsV2RepositoryProvider)
      .getCycleSummaries(farmId);
  return EconomicsV2CyclesDashboard(summaries);
}

@Riverpod(retry: doNotRetryProvider)
Future<EconomicsV2CycleDetail> economicsV2CycleDetail(
  Ref ref,
  String farmId,
  String cycleId,
) => ref
    .watch(economicsV2RepositoryProvider)
    .getCycleDetail(farmId: farmId, cycleId: cycleId);

@Riverpod(retry: doNotRetryProvider)
Future<EconomicsV2CycleMembers> economicsV2CycleMembers(
  Ref ref,
  String farmId,
  String cycleId,
) => ref
    .watch(economicsV2RepositoryProvider)
    .getCycleMembers(farmId: farmId, cycleId: cycleId);

@Riverpod(retry: doNotRetryProvider)
Future<EconomicsV2CycleFeeds> economicsV2CycleFeeds(
  Ref ref,
  String farmId,
  String cycleId,
) => ref
    .watch(economicsV2RepositoryProvider)
    .getCycleFeeds(farmId: farmId, cycleId: cycleId);

@Riverpod(retry: doNotRetryProvider)
Future<List<EconomicsV2CycleExpense>> economicsV2CycleExpenses(
  Ref ref,
  String farmId,
  String cycleId,
) => ref
    .watch(economicsV2RepositoryProvider)
    .getCycleExpenses(farmId: farmId, cycleId: cycleId);

@Riverpod(retry: doNotRetryProvider)
Future<List<EconomicsV2SavedProjection>> economicsV2CycleProjections(
  Ref ref,
  String farmId,
  String cycleId,
) => ref
    .watch(economicsV2RepositoryProvider)
    .getCycleProjections(farmId: farmId, cycleId: cycleId);

@Riverpod(retry: doNotRetryProvider)
Future<EconomicsV2CycleReadiness> economicsV2CycleReadiness(
  Ref ref,
  String farmId,
  String cycleId,
) => ref
    .watch(economicsV2RepositoryProvider)
    .getCycleReadiness(farmId: farmId, cycleId: cycleId);

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
      _run(() async {
        await ref
            .read(economicsV2RepositoryProvider)
            .finalize(farmId: farmId, cycleId: cycleId);
      });

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

  Future<EconomicsV2AnimalsAssigned> assignAnimals(
    EconomicsV2AssignAnimalsRequest request,
  ) => _run(
    () =>
        ref.read(economicsV2LifecycleRepositoryProvider).assignAnimals(request),
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

enum FinanceCyclesView {
  list,
  create,
  overview,
  animals,
  feeds,
  expenses,
  projections,
  close,
}

enum FinanceCycleAnimalsStep { members, selection, confirmation }

enum FinanceCycleAnimalFilter { all, grouped, ungrouped }

final class FinanceCyclesWorkflowState {
  FinanceCyclesWorkflowState({
    this.view = FinanceCyclesView.list,
    this.cycleId,
    this.animalsStep = FinanceCycleAnimalsStep.members,
    List<String> selectedAnimalIds = const [],
    this.animalSearchQuery = '',
    this.animalFilter = FinanceCycleAnimalFilter.all,
    this.joinedOn,
  }) : selectedAnimalIds = List.unmodifiable(selectedAnimalIds);

  final FinanceCyclesView view;
  final String? cycleId;
  final FinanceCycleAnimalsStep animalsStep;
  final List<String> selectedAnimalIds;
  final String animalSearchQuery;
  final FinanceCycleAnimalFilter animalFilter;
  final DateTime? joinedOn;

  FinanceCyclesWorkflowState copyWith({
    FinanceCyclesView? view,
    String? cycleId,
    FinanceCycleAnimalsStep? animalsStep,
    List<String>? selectedAnimalIds,
    String? animalSearchQuery,
    FinanceCycleAnimalFilter? animalFilter,
    DateTime? joinedOn,
    bool clearJoinedOn = false,
  }) => FinanceCyclesWorkflowState(
    view: view ?? this.view,
    cycleId: cycleId ?? this.cycleId,
    animalsStep: animalsStep ?? this.animalsStep,
    selectedAnimalIds: selectedAnimalIds ?? this.selectedAnimalIds,
    animalSearchQuery: animalSearchQuery ?? this.animalSearchQuery,
    animalFilter: animalFilter ?? this.animalFilter,
    joinedOn: clearJoinedOn ? null : joinedOn ?? this.joinedOn,
  );
}

@riverpod
class FinanceCyclesWorkflow extends _$FinanceCyclesWorkflow {
  @override
  FinanceCyclesWorkflowState build(String farmId) =>
      FinanceCyclesWorkflowState();

  void showCreate() =>
      state = FinanceCyclesWorkflowState(view: FinanceCyclesView.create);

  void openCycle(String cycleId) => state = FinanceCyclesWorkflowState(
    view: FinanceCyclesView.overview,
    cycleId: cycleId,
  );

  void showCycleView(FinanceCyclesView view) {
    if (view == FinanceCyclesView.list || view == FinanceCyclesView.create) {
      throw ArgumentError.value(
        view,
        'view',
        'Expected a cycle workspace view.',
      );
    }
    final cycleId = state.cycleId;
    if (cycleId == null) return;
    state = FinanceCyclesWorkflowState(view: view, cycleId: cycleId);
  }

  void startAnimalSelection() {
    if (state.view != FinanceCyclesView.animals) return;
    state = state.copyWith(
      animalsStep: FinanceCycleAnimalsStep.selection,
      selectedAnimalIds: const [],
      animalSearchQuery: '',
      animalFilter: FinanceCycleAnimalFilter.all,
      clearJoinedOn: true,
    );
  }

  void setAnimalSearchQuery(String query) {
    if (state.animalsStep != FinanceCycleAnimalsStep.selection) return;
    state = state.copyWith(animalSearchQuery: query);
  }

  void setAnimalFilter(FinanceCycleAnimalFilter filter) {
    if (state.animalsStep != FinanceCycleAnimalsStep.selection) return;
    state = state.copyWith(animalFilter: filter);
  }

  void toggleAnimal(String animalId) {
    if (state.animalsStep != FinanceCycleAnimalsStep.selection) return;
    final selected = [...state.selectedAnimalIds];
    selected.contains(animalId)
        ? selected.remove(animalId)
        : selected.add(animalId);
    state = state.copyWith(selectedAnimalIds: selected);
  }

  void clearSelectedAnimals() {
    if (state.animalsStep != FinanceCycleAnimalsStep.selection) return;
    state = state.copyWith(selectedAnimalIds: const []);
  }

  void continueAnimalSelection(DateTime joinedOn) {
    if (state.animalsStep != FinanceCycleAnimalsStep.selection ||
        state.selectedAnimalIds.isEmpty) {
      return;
    }
    state = state.copyWith(
      animalsStep: FinanceCycleAnimalsStep.confirmation,
      joinedOn: joinedOn,
    );
  }

  void setAnimalJoinedOn(DateTime joinedOn) {
    if (state.animalsStep != FinanceCycleAnimalsStep.confirmation) return;
    state = state.copyWith(joinedOn: joinedOn);
  }

  void backAnimalAssignment() {
    state = switch (state.animalsStep) {
      FinanceCycleAnimalsStep.confirmation => state.copyWith(
        animalsStep: FinanceCycleAnimalsStep.selection,
        clearJoinedOn: true,
      ),
      FinanceCycleAnimalsStep.selection => _resetAnimalAssignmentState(),
      FinanceCycleAnimalsStep.members => state,
    };
  }

  void resetAnimalAssignment() => state = _resetAnimalAssignmentState();

  FinanceCyclesWorkflowState _resetAnimalAssignmentState() => state.copyWith(
    animalsStep: FinanceCycleAnimalsStep.members,
    selectedAnimalIds: const [],
    animalSearchQuery: '',
    animalFilter: FinanceCycleAnimalFilter.all,
    clearJoinedOn: true,
  );

  void showList() => state = FinanceCyclesWorkflowState();
}

@riverpod
class FinanceCycleWorkspaceMutations extends _$FinanceCycleWorkspaceMutations {
  var _assignmentNeedsReconciliation = false;

  @override
  Future<void> build(String farmId, String cycleId) async {}

  Future<bool> assignAnimal({
    required String animalId,
    required DateTime joinedOn,
  }) => _run(
    () => ref
        .read(economicsV2LifecycleRepositoryProvider)
        .assignAnimal(
          EconomicsV2AssignAnimalRequest(
            farmId: farmId,
            cycleId: cycleId,
            animalId: animalId,
            joinedOn: joinedOn,
          ),
        ),
    refresh: _refreshMembers,
  );

  Future<bool> assignAnimals({
    required List<String> animalIds,
    required DateTime joinedOn,
  }) async {
    if (animalIds.isEmpty) return false;
    if (state.isLoading) return false;
    state = const AsyncLoading();
    if (_assignmentNeedsReconciliation) {
      return _reconcileAssignedAnimals();
    }
    try {
      await ref
          .read(economicsV2LifecycleRepositoryProvider)
          .assignAnimals(
            EconomicsV2AssignAnimalsRequest(
              cycleId: cycleId,
              animalIds: animalIds,
              joinedOn: joinedOn,
            ),
          );
      if (!ref.mounted) return false;
      _assignmentNeedsReconciliation = true;
      return _reconcileAssignedAnimals();
    } catch (error, stackTrace) {
      if (!ref.mounted) return false;
      try {
        await _refreshMembers();
      } on Object {
        // Preserve the mutation failure as the actionable error.
      }
      if (!ref.mounted) return false;
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> _reconcileAssignedAnimals() async {
    try {
      await _refreshMembers();
      if (!ref.mounted) return false;
      _assignmentNeedsReconciliation = false;
      state = const AsyncData(null);
      ref
          .read(financeCyclesWorkflowProvider(farmId).notifier)
          .resetAnimalAssignment();
      return true;
    } catch (error, stackTrace) {
      if (!ref.mounted) return false;
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> linkFeed({
    required String mixtureId,
    required DateTime startsOn,
  }) => _run(
    () => ref
        .read(economicsV2LifecycleRepositoryProvider)
        .linkFeed(
          EconomicsV2LinkFeedRequest(
            farmId: farmId,
            cycleId: cycleId,
            mixtureId: mixtureId,
            startsOn: startsOn,
          ),
        ),
    refresh: _refreshFeeds,
  );

  Future<bool> recordExpense({
    required DateTime occurredOn,
    required double amount,
    String? category,
    String? note,
  }) => _run(
    () => ref
        .read(economicsV2LifecycleRepositoryProvider)
        .recordExpense(
          EconomicsV2RecordExpenseRequest(
            farmId: farmId,
            cycleId: cycleId,
            occurredOn: occurredOn,
            amount: amount,
            category: category,
            note: note,
          ),
        ),
    refresh: _refreshExpenses,
  );

  Future<bool> saveProjection({
    required EconomicsV2ProjectionInput input,
    String? note,
  }) => _run(
    () => ref
        .read(economicsV2RepositoryProvider)
        .saveProjection(
          farmId: farmId,
          cycleId: cycleId,
          input: input,
          note: note,
        ),
    refresh: _refreshProjections,
  );

  Future<bool> closeProduction(DateTime closedOn) => _run(
    () => ref
        .read(economicsV2RepositoryProvider)
        .closeProduction(
          EconomicsV2CloseProductionRequest(
            farmId: farmId,
            cycleId: cycleId,
            closedOn: closedOn,
          ),
        ),
    refresh: _refreshReadiness,
  );

  Future<bool> finalize() => _run(
    () => ref
        .read(economicsV2RepositoryProvider)
        .finalize(farmId: farmId, cycleId: cycleId),
    refresh: _refreshReadiness,
  );

  Future<bool> _run(
    Future<Object> Function() operation, {
    required Future<void> Function() refresh,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await operation();
      if (!ref.mounted) return false;
      await refresh();
      if (!ref.mounted) return false;
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<void> _refreshMembers() async {
    _invalidateCommon();
    ref.invalidate(economicsV2CycleMembersProvider(farmId, cycleId));
    await Future.wait([
      ref.read(economicsV2CycleMembersProvider(farmId, cycleId).future),
      ref.read(economicsV2CycleDetailProvider(farmId, cycleId).future),
      ref.read(economicsV2CycleSummariesProvider(farmId).future),
    ]);
    if (!ref.mounted) return;
  }

  Future<void> _refreshFeeds() async {
    _invalidateCommon();
    ref.invalidate(economicsV2CycleFeedsProvider(farmId, cycleId));
    await ref.read(economicsV2CycleFeedsProvider(farmId, cycleId).future);
  }

  Future<void> _refreshExpenses() async {
    _invalidateCommon();
    ref.invalidate(economicsV2CycleExpensesProvider(farmId, cycleId));
    await ref.read(economicsV2CycleExpensesProvider(farmId, cycleId).future);
  }

  Future<void> _refreshProjections() async {
    _invalidateCommon();
    ref.invalidate(economicsV2CycleProjectionsProvider(farmId, cycleId));
    await ref.read(economicsV2CycleProjectionsProvider(farmId, cycleId).future);
  }

  Future<void> _refreshReadiness() async {
    _invalidateCommon();
    ref.invalidate(economicsV2CycleReadinessProvider(farmId, cycleId));
    await ref.read(economicsV2CycleReadinessProvider(farmId, cycleId).future);
  }

  void _invalidateCommon() {
    ref.invalidate(economicsV2CycleDetailProvider(farmId, cycleId));
    ref.invalidate(economicsV2CycleSummariesProvider(farmId));
  }
}

@riverpod
class FinanceCycleCreation extends _$FinanceCycleCreation {
  @override
  Future<EconomicsV2CycleCreated?> build(String farmId) async => null;

  Future<bool> create({
    required String purposeId,
    required DateTime startsOn,
    DateTime? endsOn,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      final request = EconomicsV2CreateCycleRequest(
        farmId: farmId,
        purposeId: purposeId,
        startsOn: startsOn,
        endsOn: endsOn,
      );
      final created = await ref
          .read(economicsV2LifecycleRepositoryProvider)
          .createCycle(request);
      if (!ref.mounted) return false;
      ref.invalidate(economicsV2CycleSummariesProvider(request.farmId));
      await ref.read(economicsV2CycleSummariesProvider(request.farmId).future);
      if (!ref.mounted) return false;
      state = AsyncData(created);
      ref.read(financeCyclesWorkflowProvider(farmId).notifier).showList();
      return true;
    } catch (error, stackTrace) {
      if (!ref.mounted) return false;
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
