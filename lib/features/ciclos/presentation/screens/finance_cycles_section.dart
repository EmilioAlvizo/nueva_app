import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/extensions/localization_extension.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../../finanzas/presentation/widgets/finance_states.dart';
import '../providers/cycle_providers.dart';
import '../widgets/finance_cycles_dashboard.dart';
import '../widgets/finance_cycles_states.dart';
import 'finance_cycle_form_section.dart';
import 'finance_cycle_workspace_section.dart';

class FinanceCyclesSection extends ConsumerWidget {
  const FinanceCyclesSection({
    required this.farmId,
    this.isFeatureEnabled = economicsV2Enabled,
    this.now,
    super.key,
  });

  final String farmId;
  final bool isFeatureEnabled;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isFeatureEnabled) return const FinanceCyclesUnavailableState();

    final localAccess = ref.watch(cycleAccessProvider(farmId));
    return switch (localAccess) {
      AsyncData(:final value) when value.canEdit =>
        FinanceAuthorizedCyclesSection(farmId: farmId, now: now),
      AsyncData() || AsyncError() => const FinanceCyclesUnavailableState(),
      AsyncLoading() => const FinanceCyclesLoadingState(),
    };
  }
}

class FinanceAuthorizedCyclesSection extends ConsumerWidget {
  const FinanceAuthorizedCyclesSection({
    required this.farmId,
    this.now,
    super.key,
  });

  final String farmId;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final access = ref.watch(economicsV2AccessProvider(farmId));
    return switch (access) {
      AsyncLoading() => const FinanceCyclesLoadingState(),
      AsyncError() => FinanceCyclesAccessMessage(
        stateKey: AppWidgetKeys.financeCyclesError,
        title: l10n.financeCyclesErrorTitle,
        message: l10n.financeCyclesErrorMessage,
        onRetry: () => ref.invalidate(economicsV2AccessProvider(farmId)),
      ),
      AsyncData(:final value) when !value.enabled => FinanceCyclesAccessMessage(
        stateKey: AppWidgetKeys.financeCyclesDisabled,
        title: l10n.financeCyclesDisabledTitle,
        message: l10n.financeCyclesDisabledMessage,
        onRetry: () => ref.invalidate(economicsV2AccessProvider(farmId)),
      ),
      AsyncData(:final value) => FinanceCyclesContentSection(
        farmId: farmId,
        canEdit: value.canEdit,
        now: now,
      ),
    };
  }
}

class FinanceCyclesContentSection extends ConsumerWidget {
  const FinanceCyclesContentSection({
    required this.farmId,
    required this.canEdit,
    this.now,
    super.key,
  });

  final String farmId;
  final bool canEdit;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.watch(financeCycleCreationProvider(farmId));
    final dashboard = ref.watch(economicsV2CycleSummariesProvider(farmId));
    final workflow = ref.watch(financeCyclesWorkflowProvider(farmId));
    if (workflow.view == FinanceCyclesView.create && canEdit) {
      return FinanceCycleFormSection(farmId: farmId, now: now);
    }
    if (workflow case FinanceCyclesWorkflowState(
      :final view,
      cycleId: final cycleId?,
    ) when view != FinanceCyclesView.list && view != FinanceCyclesView.create) {
      return FinanceCycleWorkspaceSection(
        farmId: farmId,
        cycleId: cycleId,
        view: view,
        now: now,
      );
    }

    return switch (dashboard) {
      AsyncLoading() => const FinanceCyclesLoadingState(),
      AsyncError() => FinanceMessageState(
        key: const ValueKey(AppWidgetKeys.financeCyclesError),
        title: l10n.financeCyclesErrorTitle,
        message: l10n.financeCyclesErrorMessage,
        asset: 'assets/chicken.png',
        actionKey: AppWidgetKeys.financeCyclesRetry,
        actionLabel: l10n.financeRetry,
        onAction: () =>
            ref.invalidate(economicsV2CycleSummariesProvider(farmId)),
      ),
      AsyncData(:final value) when value.summaries.isEmpty =>
        FinanceCyclesEmptyState(
          canEdit: canEdit,
          onAdd: () => ref
              .read(financeCyclesWorkflowProvider(farmId).notifier)
              .showCreate(),
        ),
      AsyncData(:final value) => FinanceCyclesDashboardView(
        dashboard: value,
        canEdit: canEdit,
        onAdd: () => ref
            .read(financeCyclesWorkflowProvider(farmId).notifier)
            .showCreate(),
        onOpen: (cycleId) => ref
            .read(financeCyclesWorkflowProvider(farmId).notifier)
            .openCycle(cycleId),
        onRefresh: () async {
          ref.invalidate(economicsV2CycleSummariesProvider(farmId));
          await ref.read(economicsV2CycleSummariesProvider(farmId).future);
        },
      ),
    };
  }
}
