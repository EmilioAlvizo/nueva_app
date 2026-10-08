import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/supabase_finances_repository.dart';
import '../../domain/entities/break_even_point.dart';
import '../../domain/entities/finance_expense.dart';
import '../../domain/repositories/finances_repository.dart';
import '../../../ciclos/presentation/providers/cycle_providers.dart';

part 'finances_providers.g.dart';

Duration? _noRetry(int _, Object _) => null;

@Riverpod(keepAlive: true)
FinancesRepository financesRepository(Ref ref) {
  return SupabaseFinancesRepository(Supabase.instance.client);
}

@Riverpod(retry: _noRetry)
Future<List<BreakEvenPoint>> breakEvenPoints(Ref ref, String farmId) {
  return ref.read(financesRepositoryProvider).getBreakEvenPoints(farmId);
}

@Riverpod(retry: _noRetry)
Future<FinanceExpensesSnapshot> financeExpenses(Ref ref, String farmId) =>
    ref.watch(financesRepositoryProvider).getExpenses(farmId);

@riverpod
class FinanceExpenseMutation extends _$FinanceExpenseMutation {
  @override
  Future<void> build(String farmId) async {}

  Future<void> create(FinanceExpenseDraft draft) => _run(
    () => ref.read(financesRepositoryProvider).createExpense(farmId, draft),
    targetKind: draft.targetKind,
    targetId: draft.targetId,
  );

  Future<void> updateExpense(
    FinanceExpense expense,
    FinanceExpenseDraft draft,
  ) => _run(
    () => ref
        .read(financesRepositoryProvider)
        .updateExpense(farmId, expense, draft),
    targetKind: expense.targetKind,
    targetId: expense.targetId,
  );

  Future<void> delete(FinanceExpense expense) => _run(
    () => ref.read(financesRepositoryProvider).deleteExpense(farmId, expense),
    targetKind: expense.targetKind,
    targetId: expense.targetId,
  );

  Future<void> _run(
    Future<void> Function() operation, {
    required FinanceExpenseTargetKind targetKind,
    required String targetId,
  }) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await operation();
      if (!ref.mounted) return;

      ref
        ..invalidate(financeExpensesProvider(farmId))
        ..invalidate(breakEvenPointsProvider(farmId));
      if (targetKind == FinanceExpenseTargetKind.cycle) {
        ref
          ..invalidate(economicsV2CycleExpensesProvider(farmId, targetId))
          ..invalidate(economicsV2CycleDetailProvider(farmId, targetId))
          ..invalidate(economicsV2CycleSummariesProvider(farmId));
      }

      await ref.read(financeExpensesProvider(farmId).future);
    });
    if (!ref.mounted) return;
    state = result;
    if (result case AsyncError(:final error, :final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
