import '../entities/break_even_point.dart';
import '../entities/finance_expense.dart';

abstract interface class FinancesRepository {
  Future<List<BreakEvenPoint>> getBreakEvenPoints(String farmId);

  Future<FinanceExpensesSnapshot> getExpenses(String farmId);

  Future<void> createExpense(String farmId, FinanceExpenseDraft draft);

  Future<void> updateExpense(
    String farmId,
    FinanceExpense expense,
    FinanceExpenseDraft draft,
  );

  Future<void> deleteExpense(String farmId, FinanceExpense expense);
}
