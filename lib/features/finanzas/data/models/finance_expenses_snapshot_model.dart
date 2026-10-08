import '../../domain/entities/finance_expense.dart';

abstract final class FinanceExpensesSnapshotModel {
  static FinanceExpensesSnapshot fromJson(Map<String, dynamic> json) {
    final targets = List<FinanceExpenseTarget>.unmodifiable(
      _jsonList(json['targets']).map(_targetFromJson),
    );
    final expenses = List<FinanceExpense>.unmodifiable(
      _jsonList(json['expenses']).map(_expenseFromJson),
    );

    return FinanceExpensesSnapshot(
      farmId: json['granja_id'] as String,
      role: json['role'] as String,
      canEdit: json['can_edit'] as bool? ?? false,
      targets: targets,
      expenses: expenses,
    );
  }

  static FinanceExpenseTarget _targetFromJson(Map<String, dynamic> json) =>
      FinanceExpenseTarget(
        kind: FinanceExpenseTargetKind.fromWire(json['target_kind'] as String),
        id: json['target_id'] as String,
        label: json['target_label'] as String,
        startsOn: DateTime.parse(json['starts_on'] as String),
        endsOnExclusive: switch (json['ends_on_exclusive']) {
          final String value => DateTime.parse(value),
          _ => null,
        },
      );

  static FinanceExpense _expenseFromJson(Map<String, dynamic> json) =>
      FinanceExpense(
        id: json['expense_id'] as String,
        targetKind: FinanceExpenseTargetKind.fromWire(
          json['target_kind'] as String,
        ),
        targetId: json['target_id'] as String,
        targetLabel: json['target_label'] as String,
        occurredOn: DateTime.parse(json['occurred_on'] as String),
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        canMutate: json['can_mutate'] as bool? ?? false,
      );

  static Iterable<Map<String, dynamic>> _jsonList(Object? value) =>
      (value as List<Object?>? ?? const <Object?>[]).map(
        (item) => Map<String, dynamic>.from(item! as Map),
      );
}
