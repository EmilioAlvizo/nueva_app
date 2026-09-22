import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_lifecycle_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_lifecycle_repository.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_repository.dart';
import 'package:rancho/features/ciclos/presentation/providers/cycle_providers.dart';

void main() {
  test(
    'suppresses duplicate atomic assignments while the first request is pending',
    () async {
      final lifecycle = _PendingLifecycleRepository();
      final economics = _EconomicsRepository();
      final container = ProviderContainer.test(
        overrides: [
          economicsV2LifecycleRepositoryProvider.overrideWithValue(lifecycle),
          economicsV2RepositoryProvider.overrideWithValue(economics),
        ],
      );
      addTearDown(container.dispose);
      final provider = financeCycleWorkspaceMutationsProvider(
        'farm-1',
        'cycle-1',
      );
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);

      final first = notifier.assignAnimals(
        animalIds: const ['animal-1', 'animal-2'],
        joinedOn: DateTime(2026, 8, 20),
      );
      final duplicate = await notifier.assignAnimals(
        animalIds: const ['animal-1', 'animal-2'],
        joinedOn: DateTime(2026, 8, 20),
      );

      expect(duplicate, isFalse);
      expect(lifecycle.requests, hasLength(1));
      expect(
        lifecycle.requests.single,
        isA<EconomicsV2AssignAnimalsRequest>()
            .having((request) => request.cycleId, 'cycle id', 'cycle-1')
            .having((request) => request.animalIds, 'animal ids', [
              'animal-1',
              'animal-2',
            ])
            .having(
              (request) => request.joinedOn,
              'joined date',
              DateTime(2026, 8, 20),
            ),
      );
      lifecycle.complete();
      expect(await first, isTrue);
      expect(economics.memberCalls, 1);
      expect(container.read(provider), const AsyncData<void>(null));
    },
  );

  test(
    'keeps assignment pending until members, detail, and summaries reconcile',
    () async {
      final lifecycle = _PendingLifecycleRepository();
      final economics = _ReconciliationEconomicsRepository();
      final container = ProviderContainer.test(
        overrides: [
          economicsV2LifecycleRepositoryProvider.overrideWithValue(lifecycle),
          economicsV2RepositoryProvider.overrideWithValue(economics),
        ],
      );
      addTearDown(container.dispose);
      final provider = financeCycleWorkspaceMutationsProvider(
        'farm-1',
        'cycle-1',
      );
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);
      var completed = false;

      final assignment = notifier
          .assignAnimals(
            animalIds: const ['animal-1', 'animal-2'],
            joinedOn: DateTime(2026, 8, 20),
          )
          .then((result) => completed = result);
      lifecycle.complete();
      await Future<void>.delayed(Duration.zero);

      expect(economics.memberCalls, 1);
      expect(economics.detailCalls, 1);
      expect(economics.summaryCalls, 1);
      economics.completeMembers();
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(container.read(provider), isA<AsyncLoading<void>>());

      economics.completeDetail();
      economics.completeSummaries();
      await assignment;

      expect(completed, isTrue);
      expect(container.read(provider), const AsyncData<void>(null));
    },
  );

  test('exposes assignment failure and permits a later retry', () async {
    final lifecycle = _FailOnceLifecycleRepository();
    final economics = _EconomicsRepository();
    final container = ProviderContainer.test(
      overrides: [
        economicsV2LifecycleRepositoryProvider.overrideWithValue(lifecycle),
        economicsV2RepositoryProvider.overrideWithValue(economics),
      ],
    );
    addTearDown(container.dispose);
    final provider = financeCycleWorkspaceMutationsProvider(
      'farm-1',
      'cycle-1',
    );
    await container.read(provider.future);
    final notifier = container.read(provider.notifier);

    final failed = await notifier.assignAnimals(
      animalIds: const ['animal-1', 'animal-2'],
      joinedOn: DateTime(2026, 8, 20),
    );

    expect(failed, isFalse);
    expect(container.read(provider), isA<AsyncError<void>>());
    expect(lifecycle.requests, hasLength(1));
    expect(economics.memberCalls, 1);

    final retried = await notifier.assignAnimals(
      animalIds: const ['animal-1', 'animal-2'],
      joinedOn: DateTime(2026, 8, 20),
    );

    expect(retried, isTrue);
    expect(lifecycle.requests, hasLength(2));
    expect(economics.memberCalls, 2);
    expect(container.read(provider), const AsyncData<void>(null));
  });

  test(
    'exposes reconciliation failure and retries from authoritative reads',
    () async {
      final lifecycle = _SuccessfulLifecycleRepository();
      final economics = _FailsFirstMemberRefreshRepository();
      final container = ProviderContainer.test(
        overrides: [
          economicsV2LifecycleRepositoryProvider.overrideWithValue(lifecycle),
          economicsV2RepositoryProvider.overrideWithValue(economics),
        ],
      );
      addTearDown(container.dispose);
      final provider = financeCycleWorkspaceMutationsProvider(
        'farm-1',
        'cycle-1',
      );
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);

      final failed = await notifier.assignAnimals(
        animalIds: const ['animal-1', 'animal-2'],
        joinedOn: DateTime(2026, 8, 20),
      );

      expect(failed, isFalse);
      expect(container.read(provider), isA<AsyncError<void>>());
      expect(lifecycle.requests, hasLength(1));
      expect(economics.memberCalls, 1);

      final retried = await notifier.assignAnimals(
        animalIds: const ['animal-2', 'animal-3'],
        joinedOn: DateTime(2026, 8, 21),
      );

      expect(retried, isTrue);
      expect(lifecycle.requests, hasLength(1));
      expect(economics.memberCalls, 2);
      expect(container.read(provider), const AsyncData<void>(null));
    },
  );
}

final class _PendingLifecycleRepository extends Fake
    implements EconomicsV2LifecycleRepository {
  final requests = <EconomicsV2AssignAnimalsRequest>[];
  final _completer = Completer<EconomicsV2AnimalsAssigned>();

  @override
  Future<EconomicsV2AnimalsAssigned> assignAnimals(
    EconomicsV2AssignAnimalsRequest request,
  ) {
    requests.add(request);
    return _completer.future;
  }

  void complete() {
    _completer.complete(
      const EconomicsV2AnimalsAssigned(
        cycleId: 'cycle-1',
        animalIds: ['animal-1', 'animal-2'],
      ),
    );
  }
}

final class _EconomicsRepository extends Fake implements EconomicsV2Repository {
  var memberCalls = 0;

  @override
  Future<EconomicsV2CycleMembers> getCycleMembers({
    required String farmId,
    required String cycleId,
  }) async {
    memberCalls++;
    return EconomicsV2CycleMembers(members: const [], candidates: const []);
  }

  @override
  Future<EconomicsV2CycleDetail> getCycleDetail({
    required String farmId,
    required String cycleId,
  }) async => _cycleDetail();

  @override
  Future<List<EconomicsV2CycleSummary>> getCycleSummaries(
    String farmId,
  ) async => const [];
}

final class _ReconciliationEconomicsRepository extends Fake
    implements EconomicsV2Repository {
  var memberCalls = 0;
  var detailCalls = 0;
  var summaryCalls = 0;
  final _members = Completer<EconomicsV2CycleMembers>();
  final _detail = Completer<EconomicsV2CycleDetail>();
  final _summaries = Completer<List<EconomicsV2CycleSummary>>();

  @override
  Future<EconomicsV2CycleMembers> getCycleMembers({
    required String farmId,
    required String cycleId,
  }) {
    memberCalls++;
    return _members.future;
  }

  @override
  Future<EconomicsV2CycleDetail> getCycleDetail({
    required String farmId,
    required String cycleId,
  }) {
    detailCalls++;
    return _detail.future;
  }

  @override
  Future<List<EconomicsV2CycleSummary>> getCycleSummaries(String farmId) {
    summaryCalls++;
    return _summaries.future;
  }

  void completeMembers() {
    _members.complete(
      EconomicsV2CycleMembers(members: const [], candidates: const []),
    );
  }

  void completeDetail() {
    _detail.complete(_cycleDetail());
  }

  void completeSummaries() {
    _summaries.complete(const []);
  }
}

EconomicsV2CycleDetail _cycleDetail() => EconomicsV2CycleDetail(
  cycleId: 'cycle-1',
  farmId: 'farm-1',
  name: null,
  status: EconomicsV2CycleStatus.open,
  startsOn: DateTime(2026, 8, 20),
  purposeId: 'purpose-1',
  purposeName: 'Purpose',
  purpose: EconomicsV2Purpose.postura,
  activeAnimalCount: 1,
  exitedAnimalCount: 0,
  feedCost: 0,
  directExpenseTotal: 0,
  revenue: 0,
  totalCost: 0,
  profit: 0,
  updatedAt: DateTime(2026, 8, 20),
);

final class _FailOnceLifecycleRepository extends Fake
    implements EconomicsV2LifecycleRepository {
  final requests = <EconomicsV2AssignAnimalsRequest>[];

  @override
  Future<EconomicsV2AnimalsAssigned> assignAnimals(
    EconomicsV2AssignAnimalsRequest request,
  ) async {
    requests.add(request);
    if (requests.length == 1) {
      throw StateError('Assignment rejected by the server.');
    }
    return const EconomicsV2AnimalsAssigned(
      cycleId: 'cycle-1',
      animalIds: ['animal-1', 'animal-2'],
    );
  }
}

final class _SuccessfulLifecycleRepository extends Fake
    implements EconomicsV2LifecycleRepository {
  final requests = <EconomicsV2AssignAnimalsRequest>[];

  @override
  Future<EconomicsV2AnimalsAssigned> assignAnimals(
    EconomicsV2AssignAnimalsRequest request,
  ) async {
    requests.add(request);
    return EconomicsV2AnimalsAssigned(
      cycleId: request.cycleId,
      animalIds: request.animalIds,
    );
  }
}

final class _FailsFirstMemberRefreshRepository extends Fake
    implements EconomicsV2Repository {
  var memberCalls = 0;

  @override
  Future<EconomicsV2CycleMembers> getCycleMembers({
    required String farmId,
    required String cycleId,
  }) async {
    memberCalls++;
    if (memberCalls == 1) {
      throw StateError('Members refresh failed.');
    }
    return EconomicsV2CycleMembers(members: const [], candidates: const []);
  }

  @override
  Future<EconomicsV2CycleDetail> getCycleDetail({
    required String farmId,
    required String cycleId,
  }) async => _cycleDetail();

  @override
  Future<List<EconomicsV2CycleSummary>> getCycleSummaries(
    String farmId,
  ) async => const [];
}
