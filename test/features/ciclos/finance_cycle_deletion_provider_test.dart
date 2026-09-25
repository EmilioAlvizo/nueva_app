import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_repository.dart';
import 'package:rancho/features/ciclos/presentation/providers/cycle_providers.dart';

void main() {
  test(
    'suppresses duplicate deletion and awaits source-of-truth refresh',
    () async {
      final repository = _PendingDeleteRepository();
      final container = ProviderContainer.test(
        overrides: [
          economicsV2RepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final summariesProvider = economicsV2CycleSummariesProvider('farm-1');
      final mutationProvider = financeCycleDeletionProvider('farm-1');
      final subscription = container.listen(mutationProvider, (_, _) {});
      addTearDown(subscription.close);

      expect((await container.read(summariesProvider.future)).cycleCount, 1);
      await container.read(mutationProvider.future);
      final notifier = container.read(mutationProvider.notifier);

      final first = notifier.delete('cycle-1');
      final duplicate = await notifier.delete('cycle-1');

      expect(duplicate, isFalse);
      expect(repository.deleteCalls, [('farm-1', 'cycle-1')]);
      repository.completeDelete();
      expect(await first, isTrue);

      expect(repository.summaryCalls, 2);
      expect(
        (await container.read(summariesProvider.future)).summaries,
        isEmpty,
      );
      expect(
        container.read(mutationProvider),
        const AsyncData<String?>('cycle-1'),
      );
    },
  );

  test('preserves AsyncError when deletion fails', () async {
    final repository = _PendingDeleteRepository(
      deleteError: Exception('delete failed'),
    );
    final container = ProviderContainer.test(
      overrides: [economicsV2RepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final mutationProvider = financeCycleDeletionProvider('farm-1');
    await container.read(mutationProvider.future);

    final deleted = await container
        .read(mutationProvider.notifier)
        .delete('cycle-1');

    expect(deleted, isFalse);
    expect(container.read(mutationProvider), isA<AsyncError<String?>>());
    expect(repository.summaryCalls, 0);
  });
}

final class _PendingDeleteRepository extends Fake
    implements EconomicsV2Repository {
  _PendingDeleteRepository({this.deleteError});

  final Object? deleteError;
  final _deleteCompleter = Completer<String>();
  final deleteCalls = <(String, String)>[];
  var summaryCalls = 0;
  var summaries = <EconomicsV2CycleSummary>[_summary];

  @override
  Future<List<EconomicsV2CycleSummary>> getCycleSummaries(String farmId) async {
    summaryCalls++;
    return List.unmodifiable(summaries);
  }

  @override
  Future<String> deleteCycle({
    required String farmId,
    required String cycleId,
  }) {
    deleteCalls.add((farmId, cycleId));
    final error = deleteError;
    if (error != null) return Future.error(error);
    return _deleteCompleter.future;
  }

  void completeDelete() {
    summaries = [];
    _deleteCompleter.complete('cycle-1');
  }
}

final _summary = EconomicsV2CycleSummary(
  cycleId: 'cycle-1',
  farmId: 'farm-1',
  status: 'open',
  startsOn: DateTime(2026, 8, 20),
  purposeId: 'purpose-1',
  purposeName: 'Postura',
  purpose: EconomicsV2Purpose.postura,
  activeAnimalCount: 4,
  exitedAnimalCount: 1,
  directExpenseTotal: 42.5,
  linkedMixtureCount: 2,
  latestLinkedGroupName: 'Gallinero norte',
);
