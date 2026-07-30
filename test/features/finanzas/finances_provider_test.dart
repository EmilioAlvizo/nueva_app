import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/features/finanzas/domain/entities/break_even_point.dart';
import 'package:nueva_app/features/finanzas/domain/repositories/finances_repository.dart';
import 'package:nueva_app/features/finanzas/presentation/providers/finances_providers.dart';

void main() {
  test('query provider propagates the selected farm id', () async {
    final repository = _RecordingRepository();
    final container = ProviderContainer.test(
      overrides: [financesRepositoryProvider.overrideWithValue(repository)],
    );

    final result = await container.read(
      breakEvenPointsProvider('farm-selected').future,
    );

    expect(result, isEmpty);
    expect(repository.requestedFarmIds, ['farm-selected']);
  });
}

final class _RecordingRepository implements FinancesRepository {
  final requestedFarmIds = <String>[];

  @override
  Future<List<BreakEvenPoint>> getBreakEvenPoints(String farmId) async {
    requestedFarmIds.add(farmId);
    return const [];
  }
}
