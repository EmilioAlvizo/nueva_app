import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_lifecycle_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_lifecycle_repository.dart';
import 'package:rancho/features/ciclos/presentation/providers/cycle_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('forwards typed requests and matching success states', () async {
    final repository = _LifecycleRepository();
    final container = _container(repository);
    await container.read(economicsV2LifecycleMutationsProvider.future);
    final notifier = container.read(
      economicsV2LifecycleMutationsProvider.notifier,
    );
    final day = DateTime(2026, 8, 21);
    final create = EconomicsV2CreateCycleRequest(
      farmId: 'farm-1',
      purposeId: 'purpose-1',
      startsOn: day,
    );
    final assign = EconomicsV2AssignAnimalRequest(
      farmId: 'farm-1',
      cycleId: 'cycle-1',
      animalId: 'animal-1',
      joinedOn: day,
    );
    final expense = EconomicsV2RecordExpenseRequest(
      farmId: 'farm-1',
      cycleId: 'cycle-1',
      occurredOn: day,
      amount: 12.5,
    );
    final feed = EconomicsV2LinkFeedRequest(
      farmId: 'farm-1',
      cycleId: 'cycle-1',
      mixtureId: 'mixture-1',
      startsOn: day,
    );

    await _expectOperation(
      container,
      () => notifier.create(create),
      repository.created,
    );
    await _expectOperation(
      container,
      () => notifier.assignAnimal(assign),
      repository.assigned,
    );
    await _expectOperation(
      container,
      () => notifier.recordExpense(expense),
      repository.recorded,
    );
    await _expectOperation(
      container,
      () => notifier.linkFeed(feed),
      repository.linked,
    );

    expect(repository.createCycleRequests, [same(create)]);
    expect(repository.assignAnimalRequests, [same(assign)]);
    expect(repository.recordExpenseRequests, [same(expense)]);
    expect(repository.linkFeedRequests, [same(feed)]);
  });

  test('preserves server error and stack without stale success', () async {
    final repository = _LifecycleRepository();
    final container = _container(repository);
    await container.read(economicsV2LifecycleMutationsProvider.future);
    final notifier = container.read(
      economicsV2LifecycleMutationsProvider.notifier,
    );
    await _expectOperation(
      container,
      () => notifier.create(
        EconomicsV2CreateCycleRequest(
          farmId: 'farm-1',
          purposeId: 'purpose-1',
          startsOn: DateTime(2026, 8, 21),
        ),
      ),
      repository.created,
    );
    final serverError = PostgrestException(
      message: 'Farm access denied',
      code: '42501',
      details: 'farm-2 is not owned by the current user',
    );
    final serverStack = StackTrace.fromString('server stack trace');
    repository.recordExpenseError = serverError;
    repository.recordExpenseStackTrace = serverStack;

    final recording = notifier.recordExpense(
      EconomicsV2RecordExpenseRequest(
        farmId: 'farm-2',
        cycleId: 'cycle-2',
        occurredOn: DateTime(2026, 8, 23),
        amount: 15,
      ),
    );
    _expectLoading(container);
    await expectLater(recording, throwsA(same(serverError)));
    final state = container.read(economicsV2LifecycleMutationsProvider);
    expect(state, isA<AsyncError<Object?>>());
    final errorState = state as AsyncError<Object?>;
    expect(errorState.error, same(serverError));
    expect(errorState.stackTrace, same(serverStack));
    expect(repository.recordExpenseRequests, hasLength(1));
  });
}

ProviderContainer _container(EconomicsV2LifecycleRepository repository) =>
    ProviderContainer.test(
      overrides: [
        economicsV2LifecycleRepositoryProvider.overrideWithValue(repository),
      ],
    );

Future<void> _expectOperation<T extends Object>(
  ProviderContainer container,
  Future<T> Function() operation,
  T expected,
) async {
  final future = operation();
  _expectLoading(container);
  expect(await future, same(expected));
  final state = container.read(economicsV2LifecycleMutationsProvider);
  expect(state, isA<AsyncData<Object?>>());
  expect(state.requireValue, same(expected));
}

void _expectLoading(ProviderContainer container) => expect(
  container.read(economicsV2LifecycleMutationsProvider),
  isA<AsyncLoading<Object?>>(),
);

final class _LifecycleRepository implements EconomicsV2LifecycleRepository {
  final createCycleRequests = <EconomicsV2CreateCycleRequest>[];
  final assignAnimalRequests = <EconomicsV2AssignAnimalRequest>[];
  final recordExpenseRequests = <EconomicsV2RecordExpenseRequest>[];
  final linkFeedRequests = <EconomicsV2LinkFeedRequest>[];
  final created = const EconomicsV2CycleCreated(cycleId: 'cycle-1');
  final assigned = const EconomicsV2AnimalAssigned(
    cycleId: 'cycle-1',
    animalId: 'animal-1',
  );
  final recorded = const EconomicsV2ExpenseRecorded(expenseId: 'expense-1');
  final linked = const EconomicsV2FeedLinked(feedId: 'feed-1');
  Object? recordExpenseError;
  StackTrace? recordExpenseStackTrace;

  @override
  Future<EconomicsV2CycleCreated> createCycle(
    EconomicsV2CreateCycleRequest request,
  ) {
    createCycleRequests.add(request);
    return Future.value(created);
  }

  @override
  Future<EconomicsV2AnimalAssigned> assignAnimal(
    EconomicsV2AssignAnimalRequest request,
  ) {
    assignAnimalRequests.add(request);
    return Future.value(assigned);
  }

  @override
  Future<EconomicsV2ExpenseRecorded> recordExpense(
    EconomicsV2RecordExpenseRequest request,
  ) {
    recordExpenseRequests.add(request);
    final error = recordExpenseError;
    return error == null
        ? Future.value(recorded)
        : Future.error(error, recordExpenseStackTrace);
  }

  @override
  Future<EconomicsV2FeedLinked> linkFeed(EconomicsV2LinkFeedRequest request) {
    linkFeedRequests.add(request);
    return Future.value(linked);
  }
}
