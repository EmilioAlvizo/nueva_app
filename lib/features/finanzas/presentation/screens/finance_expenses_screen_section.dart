import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/localization_extension.dart';
import '../../../../core/extensions/primitive_formatting_extensions.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../domain/entities/finance_expense.dart';
import '../providers/finances_providers.dart';
import '../widgets/finance_expenses_section.dart';
import '../widgets/finance_states.dart';

class FinanceExpensesScreenSection extends ConsumerWidget {
  const FinanceExpensesScreenSection({required this.farmId, super.key});

  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final snapshot = ref.watch(financeExpensesProvider(farmId));
    final mutation = ref.watch(financeExpenseMutationProvider(farmId));

    return switch (snapshot) {
      AsyncLoading() => const Center(
        key: ValueKey(AppWidgetKeys.financeExpensesLoading),
        child: CircularProgressIndicator(),
      ),
      AsyncError() => FinanceMessageState(
        key: const ValueKey(AppWidgetKeys.financeExpensesError),
        title: l10n.financeErrorTitle,
        message: l10n.financeErrorMessage,
        asset: 'assets/outcome.png',
        actionKey: AppWidgetKeys.financeExpensesRetry,
        actionLabel: l10n.financeRetry,
        onAction: () => ref.invalidate(financeExpensesProvider(farmId)),
      ),
      AsyncData(:final value) => ExpensesDashboard(
        snapshot: value,
        today: DateTimeFormatting.nowLocal(),
        busy: mutation.isLoading,
        onRefresh: () => _refresh(ref),
        onAdd: value.canEdit && value.targets.isNotEmpty
            ? () => _openForm(context, ref, value)
            : null,
        onEdit: (expense) => _openForm(context, ref, value, expense: expense),
        onDelete: (expense) => _confirmDelete(context, ref, expense),
      ),
    };
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(financeExpensesProvider(farmId));
    try {
      await ref.read(financeExpensesProvider(farmId).future);
    } on Object {
      // The provider exposes the refreshed error state.
    }
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    FinanceExpensesSnapshot snapshot, {
    FinanceExpense? expense,
  }) async {
    final draft = await showModalBottomSheet<FinanceExpenseDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FinanceExpenseForm(
        targets: snapshot.targets,
        expense: expense,
        today: DateTimeFormatting.nowLocal(),
      ),
    );
    if (draft == null || !context.mounted) return;

    try {
      final notifier = ref.read(
        financeExpenseMutationProvider(farmId).notifier,
      );
      if (expense == null) {
        await notifier.create(draft);
      } else {
        await notifier.updateExpense(expense, draft);
      }
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.financeExpenseMutationError)),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    FinanceExpense expense,
  ) async {
    final l10n = context.l10n;
    final categoryLabel = expense.category.trim().isEmpty
        ? l10n.financeCycleUncategorizedExpense
        : expense.category;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          FinanceExpenseDeleteDialog(categoryLabel: categoryLabel),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(financeExpenseMutationProvider(farmId).notifier)
          .delete(expense);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.financeExpenseMutationError)),
      );
    }
  }
}
