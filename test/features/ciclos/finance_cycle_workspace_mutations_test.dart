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
    'rejects a duplicate workspace mutation while the first is pending',
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

      final first = notifier.assignAnimal(
        animalId: 'animal-1',
        joinedOn: DateTime(2026, 8, 20),
      );
      final duplicate = await notifier.assignAnimal(
        animalId: 'animal-1',
        joinedOn: DateTime(2026, 8, 20),
      );

      expect(duplicate, isFalse);
      expect(lifecycle.requests, hasLength(1));
      lifecycle.complete();
      expect(await first, isTrue);
      expect(economics.memberCalls, 1);
      expect(container.read(provider), const AsyncData<void>(null));
    },
  );
}

final class _PendingLifecycleRepository extends Fake
    implements EconomicsV2LifecycleRepository {
  final requests = <EconomicsV2AssignAnimalRequest>[];
  final _completer = Completer<EconomicsV2AnimalAssigned>();

  @override
  Future<EconomicsV2AnimalAssigned> assignAnimal(
    EconomicsV2AssignAnimalRequest request,
  ) {
    requests.add(request);
    return _completer.future;
  }

  void complete() {
    _completer.complete(
      const EconomicsV2AnimalAssigned(cycleId: 'cycle-1', animalId: 'animal-1'),
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
}
