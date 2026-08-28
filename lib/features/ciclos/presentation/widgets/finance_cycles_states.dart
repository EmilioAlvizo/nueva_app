import 'package:flutter/material.dart';

import '../../../../core/extensions/localization_extension.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../../finanzas/presentation/widgets/finance_states.dart';

class FinanceCyclesLoadingState extends StatelessWidget {
  const FinanceCyclesLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: l10n.financeCyclesLoadingLabel,
      child: const Center(
        key: ValueKey(AppWidgetKeys.financeCyclesLoading),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class FinanceCyclesUnavailableState extends StatelessWidget {
  const FinanceCyclesUnavailableState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FinanceMessageState(
      key: const ValueKey(AppWidgetKeys.financeCyclesUnavailable),
      title: l10n.financeCyclesUnavailableTitle,
      message: l10n.financeCyclesUnavailableMessage,
      asset: 'assets/chicken.png',
    );
  }
}

class FinanceCyclesAccessMessage extends StatelessWidget {
  const FinanceCyclesAccessMessage({
    required this.stateKey,
    required this.title,
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String stateKey;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FinanceMessageState(
      key: ValueKey(stateKey),
      title: title,
      message: message,
      asset: 'assets/chicken.png',
      actionKey: AppWidgetKeys.financeCyclesRetry,
      actionLabel: l10n.financeRetry,
      onAction: onRetry,
    );
  }
}

class FinanceCyclesEmptyState extends StatelessWidget {
  const FinanceCyclesEmptyState({
    required this.canEdit,
    required this.onAdd,
    super.key,
  });

  final bool canEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FinanceMessageState(
      key: const ValueKey(AppWidgetKeys.financeCyclesEmpty),
      title: l10n.financeCyclesEmptyTitle,
      message: l10n.financeCyclesEmptyMessage,
      asset: 'assets/chicken.png',
      actionKey: canEdit ? AppWidgetKeys.financeCyclesAdd : null,
      actionLabel: canEdit ? l10n.financeCyclesAdd : null,
      onAction: canEdit ? onAdd : null,
      actionIcon: Icons.add_rounded,
    );
  }
}
