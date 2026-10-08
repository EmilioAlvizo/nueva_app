import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/extensions/localization_extension.dart';
import '../../../../core/extensions/primitive_formatting_extensions.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/finance_theme.dart';
import '../../domain/entities/finance_expense.dart';

class ExpensesDashboard extends StatelessWidget {
  const ExpensesDashboard({
    required this.snapshot,
    required this.today,
    required this.busy,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final FinanceExpensesSnapshot snapshot;
  final DateTime today;
  final bool busy;
  final Future<void> Function() onRefresh;
  final VoidCallback? onAdd;
  final ValueChanged<FinanceExpense> onEdit;
  final ValueChanged<FinanceExpense> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey(AppWidgetKeys.financeExpensesDashboard),
      builder: (context, constraints) {
        final contentWidth = math.min(
          constraints.maxWidth - AppSpacing.md * 2,
          AppSizes.maxContentWidth,
        );
        final columns = contentWidth >= AppSizes.expandedBreakpoint
            ? 3
            : contentWidth >= AppSizes.mediumBreakpoint
            ? 2
            : 1;
        final summaryWidth =
            (contentWidth - AppSpacing.sm * (columns - 1)) / columns;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: FinanceExpensesScrollView(
            contentWidth: contentWidth,
            child: FinanceExpensesContent(
              snapshot: snapshot,
              today: today,
              summaryWidth: summaryWidth,
              busy: busy,
              onAdd: onAdd,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        );
      },
    );
  }
}

class FinanceExpensesScrollView extends StatelessWidget {
  const FinanceExpensesScrollView({
    required this.contentWidth,
    required this.child,
    super.key,
  });

  final double contentWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.xl,
    ),
    child: Center(
      child: SizedBox(width: contentWidth, child: child),
    ),
  );
}

class FinanceExpensesContent extends StatelessWidget {
  const FinanceExpensesContent({
    required this.snapshot,
    required this.today,
    required this.summaryWidth,
    required this.busy,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final FinanceExpensesSnapshot snapshot;
  final DateTime today;
  final double summaryWidth;
  final bool busy;
  final VoidCallback? onAdd;
  final ValueChanged<FinanceExpense> onEdit;
  final ValueChanged<FinanceExpense> onDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FinanceExpensesHeader(onAdd: busy ? null : onAdd),
      const SizedBox(height: AppSpacing.lg),
      FinanceExpensesSummary(
        snapshot: snapshot,
        today: today,
        tileWidth: summaryWidth,
      ),
      const SizedBox(height: AppSpacing.lg),
      if (snapshot.expenses.isEmpty)
        FinanceExpensesEmptyState(hasTargets: snapshot.targets.isNotEmpty)
      else
        FinanceExpensesList(
          expenses: snapshot.expenses,
          busy: busy,
          onEdit: onEdit,
          onDelete: onDelete,
        ),
    ],
  );
}

class FinanceExpensesSummary extends StatelessWidget {
  const FinanceExpensesSummary({
    required this.snapshot,
    required this.today,
    required this.tileWidth,
    super.key,
  });

  final FinanceExpensesSnapshot snapshot;
  final DateTime today;
  final double tileWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        SizedBox(
          width: tileWidth,
          child: FinanceExpenseSummaryTile(
            data: (
              label: l10n.financeExpensesTotal,
              value: snapshot.totalAmount.formatCurrency(l10n),
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
        ),
        SizedBox(
          width: tileWidth,
          child: FinanceExpenseSummaryTile(
            data: (
              label: l10n.financeExpensesCurrentMonth,
              value: snapshot.currentMonthAmount(today).formatCurrency(l10n),
              icon: Icons.calendar_month_outlined,
            ),
          ),
        ),
        SizedBox(
          width: tileWidth,
          child: FinanceExpenseSummaryTile(
            data: (
              label: l10n.financeExpensesRecordCount,
              value: snapshot.expenses.length.formatInteger(l10n),
              icon: Icons.receipt_long_outlined,
            ),
          ),
        ),
      ],
    );
  }
}

class FinanceExpensesList extends StatelessWidget {
  const FinanceExpensesList({
    required this.expenses,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final List<FinanceExpense> expenses;
  final bool busy;
  final ValueChanged<FinanceExpense> onEdit;
  final ValueChanged<FinanceExpense> onDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final expense in expenses) ...[
        FinanceExpenseCard(
          expense: expense,
          onEdit: busy || !expense.canMutate ? null : () => onEdit(expense),
          onDelete: busy || !expense.canMutate ? null : () => onDelete(expense),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}

class FinanceExpensesHeader extends StatelessWidget {
  const FinanceExpensesHeader({required this.onAdd, super.key});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.financeExpensesHeading,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.financeExpensesSubtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (onAdd != null) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const ValueKey(AppWidgetKeys.financeExpensesAdd),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.financeExpenseAdd),
          ),
        ],
      ],
    );
  }
}

class FinanceExpenseSummaryTile extends StatelessWidget {
  const FinanceExpenseSummaryTile({required this.data, super.key});

  final ({String label, String value, IconData icon}) data;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: finance.expenses.container,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(data.icon, color: finance.expenses.accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.label, maxLines: 2),
                  const SizedBox(height: AppSpacing.xxs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      data.value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FinanceExpensesEmptyState extends StatelessWidget {
  const FinanceExpensesEmptyState({required this.hasTargets, super.key});

  final bool hasTargets;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      key: const ValueKey(AppWidgetKeys.financeExpensesEmpty),
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            const Icon(Icons.receipt_long_outlined, size: AppSizes.stateImage),
            const SizedBox(height: AppSpacing.md),
            Text(
              hasTargets
                  ? l10n.financeExpensesEmptyTitle
                  : l10n.financeExpensesNoTargetsTitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasTargets
                  ? l10n.financeExpensesEmptyMessage
                  : l10n.financeExpensesNoTargetsMessage,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class FinanceExpenseDeleteDialog extends StatelessWidget {
  const FinanceExpenseDeleteDialog({required this.categoryLabel, super.key});

  final String categoryLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const ValueKey(AppWidgetKeys.financeExpenseDeleteDialog),
      title: Text(l10n.financeExpenseDeleteTitle),
      content: Text(l10n.financeExpenseDeleteMessage(categoryLabel)),
      actions: [
        TextButton(
          key: const ValueKey(AppWidgetKeys.financeExpenseDeleteCancel),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.financeExpenseCancel),
        ),
        FilledButton(
          key: const ValueKey(AppWidgetKeys.financeExpenseDeleteConfirm),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.financeExpenseDelete),
        ),
      ],
    );
  }
}

class FinanceExpenseCard extends StatelessWidget {
  const FinanceExpenseCard({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final FinanceExpense expense;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final amount = expense.amount.formatCurrency(l10n);
    final date = expense.occurredOn.formatShortDate(l10n);
    final categoryLabel = expense.category.trim().isEmpty
        ? l10n.financeCycleUncategorizedExpense
        : expense.category;
    final targetType = switch (expense.targetKind) {
      FinanceExpenseTargetKind.cycle => l10n.financeExpenseCycleTarget,
      FinanceExpenseTargetKind.legacyMixture => l10n.financeExpenseLegacyTarget,
    };
    return FinanceExpenseCardSurface(
      expenseId: expense.id,
      semanticLabel: l10n.financeExpenseCardSemantics(
        amount,
        categoryLabel,
        expense.targetLabel,
        date,
      ),
      category: categoryLabel,
      amount: amount,
      target: '$targetType · ${expense.targetLabel}',
      date: date,
      note: expense.note,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class FinanceExpenseCardSurface extends StatelessWidget {
  const FinanceExpenseCardSurface({
    required this.expenseId,
    required this.semanticLabel,
    required this.category,
    required this.amount,
    required this.target,
    required this.date,
    required this.note,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final String expenseId;
  final String semanticLabel;
  final String category;
  final String amount;
  final String target;
  final String date;
  final String? note;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return Semantics(
      container: true,
      button: onEdit != null,
      label: semanticLabel,
      child: Card.filled(
        key: ValueKey(AppWidgetKeys.financeExpenseCard(expenseId)),
        color: finance.cycleSurface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          side: BorderSide(color: finance.expenses.accent, width: 2),
        ),
        child: InkWell(
          onTap: onEdit,
          onLongPress: onDelete,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FinanceExpenseCardContent(
              category: category,
              amount: amount,
              target: target,
              date: date,
              note: note,
            ),
          ),
        ),
      ),
    );
  }
}

class FinanceExpenseCardContent extends StatelessWidget {
  const FinanceExpenseCardContent({
    required this.category,
    required this.amount,
    required this.target,
    required this.date,
    required this.note,
    super.key,
  });

  final String category;
  final String amount;
  final String target;
  final String date;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceExpenseCardHeader(category: category, amount: amount),
        const SizedBox(height: AppSpacing.xs),
        Text(target, style: TextStyle(color: finance.cycleOnSurfaceMuted)),
        const SizedBox(height: AppSpacing.xxs),
        Text(date, style: TextStyle(color: finance.cycleOnSurfaceMuted)),
        if (note case final note? when note.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(note, style: TextStyle(color: finance.cycleOnSurface)),
        ],
      ],
    );
  }
}

class FinanceExpenseCardHeader extends StatelessWidget {
  const FinanceExpenseCardHeader({
    required this.category,
    required this.amount,
    super.key,
  });

  final String category;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    final categoryText = Text(
      category,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: finance.cycleOnSurface,
        fontWeight: FontWeight.w800,
      ),
    );
    final amountText = Text(
      amount,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: finance.expenses.accent,
        fontWeight: FontWeight.w900,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < AppSizes.mediumBreakpoint ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              categoryText,
              const SizedBox(height: AppSpacing.xxs),
              amountText,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: categoryText),
            const SizedBox(width: AppSpacing.sm),
            amountText,
          ],
        );
      },
    );
  }
}

class FinanceExpenseForm extends StatefulWidget {
  const FinanceExpenseForm({
    required this.targets,
    required this.today,
    this.expense,
    super.key,
  });

  final List<FinanceExpenseTarget> targets;
  final DateTime today;
  final FinanceExpense? expense;

  @override
  State<FinanceExpenseForm> createState() => _FinanceExpenseFormState();
}

class _FinanceExpenseFormState extends State<FinanceExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _categoryController;
  late final TextEditingController _noteController;
  late FinanceExpenseTarget _target;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _target = widget.targets.firstWhere(
      (target) =>
          target.kind == expense?.targetKind && target.id == expense?.targetId,
      orElse: () => widget.targets.first,
    );
    _date = expense?.occurredOn ?? _clampDate(widget.today, _target);
    _amountController = TextEditingController(
      text: expense == null ? '' : expense.amount.toStringAsFixed(2),
    );
    _categoryController = TextEditingController(text: expense?.category ?? '');
    _noteController = TextEditingController(text: expense?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FinanceExpenseFormViewport(
      formKey: _formKey,
      child: FinanceExpenseFormFields(
        editing: widget.expense != null,
        targets: widget.targets,
        target: _target,
        date: _date,
        amountController: _amountController,
        categoryController: _categoryController,
        noteController: _noteController,
        onTargetChanged: widget.expense != null
            ? null
            : (target) {
                setState(() {
                  _target = target;
                  _date = _clampDate(_date, target);
                });
              },
        onDatePressed: _pickDate,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _pickDate() async {
    final firstDate = _target.startsOn;
    final targetLast = _target.endsOnExclusive?.subtract(
      const Duration(days: 1),
    );
    final lastDate = targetLast == null || targetLast.isAfter(widget.today)
        ? widget.today
        : targetLast;
    final selected = await showDatePicker(
      context: context,
      initialDate: _clampDate(_date, _target),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  DateTime _clampDate(DateTime value, FinanceExpenseTarget target) {
    final targetLast = target.endsOnExclusive?.subtract(
      const Duration(days: 1),
    );
    final last = targetLast == null || targetLast.isAfter(widget.today)
        ? widget.today
        : targetLast;
    if (value.isBefore(target.startsOn)) return target.startsOn;
    if (value.isAfter(last)) return last;
    return value;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final note = _noteController.text.trim();
    Navigator.pop(
      context,
      FinanceExpenseDraft(
        targetKind: _target.kind,
        targetId: _target.id,
        occurredOn: _date,
        amount: double.parse(
          _amountController.text.trim().replaceAll(',', '.'),
        ),
        category: _categoryController.text.trim(),
        note: note.isEmpty ? null : note,
      ),
    );
  }
}

class FinanceExpenseFormViewport extends StatelessWidget {
  const FinanceExpenseFormViewport({
    required this.formKey,
    required this.child,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey(AppWidgetKeys.financeExpenseForm),
    padding: EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSizes.financeFormMaxWidth,
        ),
        child: Form(key: formKey, child: child),
      ),
    ),
  );
}

class FinanceExpenseFormFields extends StatelessWidget {
  const FinanceExpenseFormFields({
    required this.editing,
    required this.targets,
    required this.target,
    required this.date,
    required this.amountController,
    required this.categoryController,
    required this.noteController,
    required this.onTargetChanged,
    required this.onDatePressed,
    required this.onSubmit,
    super.key,
  });

  final bool editing;
  final List<FinanceExpenseTarget> targets;
  final FinanceExpenseTarget target;
  final DateTime date;
  final TextEditingController amountController;
  final TextEditingController categoryController;
  final TextEditingController noteController;
  final ValueChanged<FinanceExpenseTarget>? onTargetChanged;
  final VoidCallback onDatePressed;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FinanceExpenseFormHeader(editing: editing),
      const SizedBox(height: AppSpacing.lg),
      FinanceExpenseTargetField(
        targets: targets,
        target: target,
        onChanged: onTargetChanged,
      ),
      const SizedBox(height: AppSpacing.md),
      FinanceExpenseDateField(date: date, onPressed: onDatePressed),
      const SizedBox(height: AppSpacing.md),
      FinanceExpenseAmountField(controller: amountController),
      const SizedBox(height: AppSpacing.md),
      FinanceExpenseCategoryField(controller: categoryController),
      const SizedBox(height: AppSpacing.md),
      FinanceExpenseNoteField(controller: noteController),
      const SizedBox(height: AppSpacing.lg),
      FinanceExpenseSubmitButton(onPressed: onSubmit),
    ],
  );
}

class FinanceExpenseFormHeader extends StatelessWidget {
  const FinanceExpenseFormHeader({required this.editing, super.key});

  final bool editing;

  @override
  Widget build(BuildContext context) => Text(
    editing
        ? context.l10n.financeExpenseEditTitle
        : context.l10n.financeExpenseCreateTitle,
    style: Theme.of(
      context,
    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
  );
}

class FinanceExpenseTargetField extends StatelessWidget {
  const FinanceExpenseTargetField({
    required this.targets,
    required this.target,
    required this.onChanged,
    super.key,
  });

  final List<FinanceExpenseTarget> targets;
  final FinanceExpenseTarget target;
  final ValueChanged<FinanceExpenseTarget>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DropdownButtonFormField<FinanceExpenseTarget>(
      key: const ValueKey(AppWidgetKeys.financeExpenseTarget),
      initialValue: target,
      decoration: InputDecoration(labelText: l10n.financeExpenseTargetLabel),
      items: [
        for (final target in targets)
          DropdownMenuItem(
            value: target,
            child: Text(switch (target.kind) {
              FinanceExpenseTargetKind.cycle =>
                '${l10n.financeExpenseCycleTarget} · ${target.label}',
              FinanceExpenseTargetKind.legacyMixture =>
                '${l10n.financeExpenseLegacyTarget} · ${target.label}',
            }, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged == null
          ? null
          : (target) {
              if (target != null) onChanged!(target);
            },
    );
  }
}

class FinanceExpenseDateField extends StatelessWidget {
  const FinanceExpenseDateField({
    required this.date,
    required this.onPressed,
    super.key,
  });

  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OutlinedButton.icon(
      key: const ValueKey(AppWidgetKeys.financeExpenseDate),
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text(
        '${l10n.financeExpenseDateLabel}: ${date.formatShortDate(l10n)}',
      ),
    );
  }
}

class FinanceExpenseAmountField extends StatelessWidget {
  const FinanceExpenseAmountField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      key: const ValueKey(AppWidgetKeys.financeExpenseAmount),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: l10n.financeExpenseAmountLabel),
      validator: (value) {
        final amount = double.tryParse(
          (value ?? '').trim().replaceAll(',', '.'),
        );
        return amount == null || !amount.isFinite || amount <= 0
            ? l10n.financeExpenseInvalidAmount
            : null;
      },
    );
  }
}

class FinanceExpenseCategoryField extends StatelessWidget {
  const FinanceExpenseCategoryField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      key: const ValueKey(AppWidgetKeys.financeExpenseCategory),
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: l10n.financeExpenseCategoryLabel),
      validator: (value) => (value ?? '').trim().isEmpty
          ? l10n.financeExpenseInvalidCategory
          : null,
    );
  }
}

class FinanceExpenseNoteField extends StatelessWidget {
  const FinanceExpenseNoteField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: const ValueKey(AppWidgetKeys.financeExpenseNote),
    controller: controller,
    textCapitalization: TextCapitalization.sentences,
    maxLines: 3,
    decoration: InputDecoration(
      labelText: context.l10n.financeExpenseNoteLabel,
    ),
  );
}

class FinanceExpenseSubmitButton extends StatelessWidget {
  const FinanceExpenseSubmitButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    key: const ValueKey(AppWidgetKeys.financeExpenseSubmit),
    onPressed: onPressed,
    child: Text(context.l10n.financeExpenseSave),
  );
}
