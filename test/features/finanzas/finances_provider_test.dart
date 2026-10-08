import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_repository.dart';
import 'package:rancho/features/ciclos/presentation/providers/cycle_providers.dart';
import 'package:rancho/features/finanzas/domain/entities/break_even_point.dart';
import 'package:rancho/features/finanzas/domain/entities/finance_expense.dart';
import 'package:rancho/features/finanzas/domain/repositories/finances_repository.dart';
import 'package:rancho/features/finanzas/presentation/providers/finances_providers.dart';

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

  test(
    'legacy expense mutation refreshes dashboard and break-even data',
    () async {
      final repository = _ExpenseMutationRepository();
      final container = ProviderContainer.test(
        overrides: [financesRepositoryProvider.overrideWithValue(repository)],
      );
      final expensesSubscription = container.listen(
        financeExpensesProvider('farm-selected'),
        (_, _) {},
      );
      final breakEvenSubscription = container.listen(
        breakEvenPointsProvider('farm-selected'),
        (_, _) {},
      );
      addTearDown(expensesSubscription.close);
      addTearDown(breakEvenSubscription.close);
      await container.read(financeExpensesProvider('farm-selected').future);
      await container.read(breakEvenPointsProvider('farm-selected').future);
      await container.read(
        financeExpenseMutationProvider('farm-selected').future,
      );

      await container
          .read(financeExpenseMutationProvider('farm-selected').notifier)
          .create(
            FinanceExpenseDraft(
              targetKind: FinanceExpenseTargetKind.legacyMixture,
              targetId: 'mixture-1',
              occurredOn: DateTime(2026, 9, 25),
              amount: 10,
              category: 'Maintenance',
            ),
          );
      await container.read(breakEvenPointsProvider('farm-selected').future);

      expect(repository.createdFarmIds, ['farm-selected']);
      expect(repository.expenseReads, 2);
      expect(repository.breakEvenReads, 2);
    },
  );

  test(
    'cycle expense mutation refetches dashboard, expenses, detail, and summaries',
    () async {
      final finances = _ExpenseMutationRepository();
      final economics = _CycleRefreshRepository();
      final container = ProviderContainer.test(
        overrides: [
          financesRepositoryProvider.overrideWithValue(finances),
          economicsV2RepositoryProvider.overrideWithValue(economics),
        ],
      );
      final dashboardProvider = financeExpensesProvider('farm-selected');
      final cycleExpensesProvider = economicsV2CycleExpensesProvider(
        'farm-selected',
        'cycle-1',
      );
      final cycleDetailProvider = economicsV2CycleDetailProvider(
        'farm-selected',
        'cycle-1',
      );
      final cycleSummariesProvider = economicsV2CycleSummariesProvider(
        'farm-selected',
      );
      final dashboardSubscription = container.listen(
        dashboardProvider,
        (_, _) {},
      );
      final expensesSubscription = container.listen(
        cycleExpensesProvider,
        (_, _) {},
      );
      final detailSubscription = container.listen(
        cycleDetailProvider,
        (_, _) {},
      );
      final summariesSubscription = container.listen(
        cycleSummariesProvider,
        (_, _) {},
      );
      addTearDown(dashboardSubscription.close);
      addTearDown(expensesSubscription.close);
      addTearDown(detailSubscription.close);
      addTearDown(summariesSubscription.close);

      await container.read(dashboardProvider.future);
      await container.read(cycleExpensesProvider.future);
      await container.read(cycleDetailProvider.future);
      await container.read(cycleSummariesProvider.future);
      await container.read(
        financeExpenseMutationProvider('farm-selected').future,
      );

      await container
          .read(financeExpenseMutationProvider('farm-selected').notifier)
          .create(
            FinanceExpenseDraft(
              targetKind: FinanceExpenseTargetKind.cycle,
              targetId: 'cycle-1',
              occurredOn: DateTime(2026, 9, 25),
              amount: 15,
              category: 'Veterinary',
            ),
          );
      await container.read(cycleExpensesProvider.future);
      await container.read(cycleDetailProvider.future);
      await container.read(cycleSummariesProvider.future);

      expect(finances.expenseReads, 2);
      expect(economics.expenseRequests, [
        ('farm-selected', 'cycle-1'),
        ('farm-selected', 'cycle-1'),
      ]);
      expect(economics.detailRequests, [
        ('farm-selected', 'cycle-1'),
        ('farm-selected', 'cycle-1'),
      ]);
      expect(economics.summaryFarmIds, ['farm-selected', 'farm-selected']);
    },
  );
}

final class _ExpenseMutationRepository implements FinancesRepository {
  var expenseReads = 0;
  var breakEvenReads = 0;
  final createdFarmIds = <String>[];

  @override
  Future<List<BreakEvenPoint>> getBreakEvenPoints(String farmId) async {
    breakEvenReads++;
    return const [];
  }

  @override
  Future<FinanceExpensesSnapshot> getExpenses(String farmId) async {
    expenseReads++;
    return FinanceExpensesSnapshot(
      farmId: farmId,
      role: 'editor',
      canEdit: true,
      targets: const [],
      expenses: const [],
    );
  }

  @override
  Future<void> createExpense(String farmId, FinanceExpenseDraft draft) async {
    createdFarmIds.add(farmId);
  }

  @override
  Future<void> deleteExpense(String farmId, FinanceExpense expense) async {}

  @override
  Future<void> updateExpense(
    String farmId,
    FinanceExpense expense,
    FinanceExpenseDraft draft,
  ) async {}
}

final class _CycleRefreshRepository extends Fake
    implements EconomicsV2Repository {
  final expenseRequests = <(String, String)>[];
  final detailRequests = <(String, String)>[];
  final summaryFarmIds = <String>[];

  @override
  Future<List<EconomicsV2CycleExpense>> getCycleExpenses({
    required String farmId,
    required String cycleId,
  }) async {
    expenseRequests.add((farmId, cycleId));
    return const [];
  }

  @override
  Future<EconomicsV2CycleDetail> getCycleDetail({
    required String farmId,
    required String cycleId,
  }) async {
    detailRequests.add((farmId, cycleId));
    return _cycleDetail;
  }

  @override
  Future<List<EconomicsV2CycleSummary>> getCycleSummaries(String farmId) async {
    summaryFarmIds.add(farmId);
    return [_cycleSummary];
  }
}

final class _RecordingRepository
    with _UnsupportedExpenses
    implements FinancesRepository {
  final requestedFarmIds = <String>[];

  @override
  Future<List<BreakEvenPoint>> getBreakEvenPoints(String farmId) async {
    requestedFarmIds.add(farmId);
    return const [];
  }
}

mixin _UnsupportedExpenses {
  Future<FinanceExpensesSnapshot> getExpenses(String farmId) async =>
      FinanceExpensesSnapshot(
        farmId: farmId,
        role: 'viewer',
        canEdit: false,
        targets: const [],
        expenses: const [],
      );

  Future<void> createExpense(String farmId, FinanceExpenseDraft draft) =>
      throw UnimplementedError();

  Future<void> updateExpense(
    String farmId,
    FinanceExpense expense,
    FinanceExpenseDraft draft,
  ) => throw UnimplementedError();

  Future<void> deleteExpense(String farmId, FinanceExpense expense) =>
      throw UnimplementedError();
}

final _cycleDetail = EconomicsV2CycleDetail(
  cycleId: 'cycle-1',
  farmId: 'farm-selected',
  name: 'North grow-out',
  status: EconomicsV2CycleStatus.open,
  startsOn: DateTime(2026, 9),
  purposeId: 'purpose-1',
  purposeName: 'Meat',
  purpose: EconomicsV2Purpose.carne,
  activeAnimalCount: 4,
  exitedAnimalCount: 0,
  feedCost: 100,
  directExpenseTotal: 15,
  revenue: 0,
  totalCost: 115,
  profit: -115,
  updatedAt: DateTime(2026, 9, 25),
);

final _cycleSummary = EconomicsV2CycleSummary(
  cycleId: 'cycle-1',
  farmId: 'farm-selected',
  status: 'open',
  startsOn: DateTime(2026, 9),
  purposeId: 'purpose-1',
  purposeName: 'Meat',
  purpose: EconomicsV2Purpose.carne,
  activeAnimalCount: 4,
  exitedAnimalCount: 0,
  directExpenseTotal: 15,
  linkedMixtureCount: 1,
);
