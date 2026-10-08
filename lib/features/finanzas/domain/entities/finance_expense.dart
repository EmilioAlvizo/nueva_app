enum FinanceExpenseTargetKind {
  cycle('cycle'),
  legacyMixture('legacy_mixture');

  const FinanceExpenseTargetKind(this.wireValue);

  final String wireValue;

  static FinanceExpenseTargetKind fromWire(String value) => switch (value) {
    'cycle' => cycle,
    'legacy_mixture' => legacyMixture,
    _ => throw FormatException('Unknown finance expense target: $value'),
  };
}

final class FinanceExpenseTarget {
  const FinanceExpenseTarget({
    required this.kind,
    required this.id,
    required this.label,
    required this.startsOn,
    required this.endsOnExclusive,
  });

  final FinanceExpenseTargetKind kind;
  final String id;
  final String label;
  final DateTime startsOn;
  final DateTime? endsOnExclusive;
}

final class FinanceExpense {
  const FinanceExpense({
    required this.id,
    required this.targetKind,
    required this.targetId,
    required this.targetLabel,
    required this.occurredOn,
    required this.amount,
    required this.category,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.canMutate,
  });

  final String id;
  final FinanceExpenseTargetKind targetKind;
  final String targetId;
  final String targetLabel;
  final DateTime occurredOn;
  final double amount;
  final String category;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool canMutate;
}

final class FinanceExpensesSnapshot {
  const FinanceExpensesSnapshot({
    required this.farmId,
    required this.role,
    required this.canEdit,
    required this.targets,
    required this.expenses,
  });

  final String farmId;
  final String role;
  final bool canEdit;
  final List<FinanceExpenseTarget> targets;
  final List<FinanceExpense> expenses;

  double get totalAmount => expenses.fold(0, (sum, item) => sum + item.amount);

  double currentMonthAmount(DateTime today) => expenses
      .where(
        (item) =>
            item.occurredOn.year == today.year &&
            item.occurredOn.month == today.month,
      )
      .fold(0, (sum, item) => sum + item.amount);
}

final class FinanceExpenseDraft {
  const FinanceExpenseDraft({
    required this.targetKind,
    required this.targetId,
    required this.occurredOn,
    required this.amount,
    required this.category,
    this.note,
  });

  final FinanceExpenseTargetKind targetKind;
  final String targetId;
  final DateTime occurredOn;
  final double amount;
  final String category;
  final String? note;
}
