import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/localization_extension.dart';
import '../../../../core/extensions/primitive_formatting_extensions.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/finance_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/economics_v2_models.dart';
import '../providers/cycle_providers.dart';
import '../widgets/finance_cycle_visuals.dart';
import '../widgets/finance_cycles_states.dart';

class FinanceCycleWorkspaceSection extends ConsumerWidget {
  const FinanceCycleWorkspaceSection({
    required this.farmId,
    required this.cycleId,
    required this.view,
    this.now,
    super.key,
  });

  final String farmId;
  final String cycleId;
  final FinanceCyclesView view;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(economicsV2CycleDetailProvider(farmId, cycleId));
    final mutation = ref.watch(
      financeCycleWorkspaceMutationsProvider(farmId, cycleId),
    );
    return switch (detail) {
      AsyncLoading() => const FinanceCyclesLoadingState(),
      AsyncError() => FinanceCycleWorkspaceReadError(
        onRetry: () =>
            ref.invalidate(economicsV2CycleDetailProvider(farmId, cycleId)),
      ),
      AsyncData(:final value) => FinanceCycleWorkspaceView(
        detail: value,
        selectedView: view,
        onBack: () =>
            ref.read(financeCyclesWorkflowProvider(farmId).notifier).showList(),
        onSelectView: (destination) => ref
            .read(financeCyclesWorkflowProvider(farmId).notifier)
            .showCycleView(destination),
        mutationFailed: mutation.hasError,
        isCompatibilityMode: value.isCompatibilityMode,
        body: FinanceCycleWorkspaceBody(
          farmId: farmId,
          cycleId: cycleId,
          view: view,
          detail: value,
          isPending: mutation.isLoading,
          now: now,
        ),
      ),
    };
  }
}

class FinanceCycleWorkspaceBody extends ConsumerWidget {
  const FinanceCycleWorkspaceBody({
    required this.farmId,
    required this.cycleId,
    required this.view,
    required this.detail,
    required this.isPending,
    this.now,
    super.key,
  });

  final String farmId;
  final String cycleId;
  final FinanceCyclesView view;
  final EconomicsV2CycleDetail detail;
  final bool isPending;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (view) {
    FinanceCyclesView.overview => FinanceCycleOverviewView(
      detail: detail,
      isCompatibilityMode: detail.isCompatibilityMode,
      onSelectView: (destination) => ref
          .read(financeCyclesWorkflowProvider(farmId).notifier)
          .showCycleView(destination),
    ),
    FinanceCyclesView.animals => FinanceCycleWorkspaceAsyncBody(
      viewKey: AppWidgetKeys.financeCycleAnimals,
      value: ref.watch(economicsV2CycleMembersProvider(farmId, cycleId)),
      onRetry: () =>
          ref.invalidate(economicsV2CycleMembersProvider(farmId, cycleId)),
      builder: (members) => FinanceCycleAnimalsView(
        members: members,
        isPending: isPending,
        onAssign: (animalId) => ref
            .read(
              financeCycleWorkspaceMutationsProvider(farmId, cycleId).notifier,
            )
            .assignAnimal(
              animalId: animalId,
              joinedOn: _actionDate(detail.startsOn),
            ),
      ),
    ),
    FinanceCyclesView.feeds => FinanceCycleWorkspaceAsyncBody(
      viewKey: AppWidgetKeys.financeCycleFeeds,
      value: ref.watch(economicsV2CycleFeedsProvider(farmId, cycleId)),
      onRetry: () =>
          ref.invalidate(economicsV2CycleFeedsProvider(farmId, cycleId)),
      builder: (feeds) => FinanceCycleFeedsView(
        feeds: feeds,
        isPending: isPending,
        onLink: (mixtureId) => ref
            .read(
              financeCycleWorkspaceMutationsProvider(farmId, cycleId).notifier,
            )
            .linkFeed(
              mixtureId: mixtureId,
              startsOn: _actionDate(detail.startsOn),
            ),
      ),
    ),
    FinanceCyclesView.expenses => FinanceCycleWorkspaceAsyncBody(
      viewKey: AppWidgetKeys.financeCycleExpenses,
      value: ref.watch(economicsV2CycleExpensesProvider(farmId, cycleId)),
      onRetry: () =>
          ref.invalidate(economicsV2CycleExpensesProvider(farmId, cycleId)),
      builder: (expenses) => FinanceCycleExpensesView(
        expenses: expenses,
        isPending: isPending,
        onAdd: () => _recordExpense(context, ref, detail.startsOn),
      ),
    ),
    FinanceCyclesView.projections => FinanceCycleWorkspaceAsyncBody(
      viewKey: AppWidgetKeys.financeCycleProjections,
      value: ref.watch(economicsV2CycleProjectionsProvider(farmId, cycleId)),
      onRetry: () =>
          ref.invalidate(economicsV2CycleProjectionsProvider(farmId, cycleId)),
      builder: (projections) => FinanceCycleProjectionsView(
        projections: projections,
        isPending: isPending,
        onAdd: () => _saveProjection(context, ref),
      ),
    ),
    FinanceCyclesView.close => FinanceCycleWorkspaceAsyncBody(
      viewKey: AppWidgetKeys.financeCycleClose,
      value: ref.watch(economicsV2CycleReadinessProvider(farmId, cycleId)),
      onRetry: () =>
          ref.invalidate(economicsV2CycleReadinessProvider(farmId, cycleId)),
      builder: (readiness) => FinanceCycleCloseView(
        detail: detail,
        readiness: readiness,
        isPending: isPending,
        onCloseProduction: () => ref
            .read(
              financeCycleWorkspaceMutationsProvider(farmId, cycleId).notifier,
            )
            .closeProduction(_actionDate(detail.startsOn)),
        onFinalize: () => ref
            .read(
              financeCycleWorkspaceMutationsProvider(farmId, cycleId).notifier,
            )
            .finalize(),
      ),
    ),
    FinanceCyclesView.list || FinanceCyclesView.create => throw StateError(
      'A workspace requires a cycle destination.',
    ),
  };

  DateTime _actionDate(DateTime cycleStart) {
    final today = DateUtils.dateOnly(now?.call() ?? DateTime.now());
    final start = DateUtils.dateOnly(cycleStart);
    return today.isBefore(start) ? start : today;
  }

  Future<void> _recordExpense(
    BuildContext context,
    WidgetRef ref,
    DateTime cycleStart,
  ) async {
    final draft = await showFinanceCycleExpenseDialog(context);
    if (draft == null || !context.mounted) return;
    await ref
        .read(financeCycleWorkspaceMutationsProvider(farmId, cycleId).notifier)
        .recordExpense(
          occurredOn: _actionDate(cycleStart),
          amount: draft.amount,
          category: draft.category,
          note: draft.note,
        );
  }

  Future<void> _saveProjection(BuildContext context, WidgetRef ref) async {
    final draft = await showFinanceCycleProjectionDialog(context);
    if (draft == null || !context.mounted) return;
    await ref
        .read(financeCycleWorkspaceMutationsProvider(farmId, cycleId).notifier)
        .saveProjection(input: draft.input, note: draft.note);
  }
}

class FinanceCycleWorkspaceView extends StatelessWidget {
  const FinanceCycleWorkspaceView({
    required this.detail,
    required this.selectedView,
    required this.body,
    required this.onBack,
    required this.onSelectView,
    required this.isCompatibilityMode,
    this.mutationFailed = false,
    super.key,
  });

  final EconomicsV2CycleDetail detail;
  final FinanceCyclesView selectedView;
  final Widget body;
  final VoidCallback onBack;
  final ValueChanged<FinanceCyclesView> onSelectView;
  final bool isCompatibilityMode;
  final bool mutationFailed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = switch (detail.latestGroupNameSnapshot) {
      final groupName? => l10n.financeCycleWorkspaceTitle(
        detail.purposeName,
        groupName,
      ),
      null => detail.name ?? detail.purposeName,
    };
    final status = FinanceCycleStatusLabelMapper.map(detail.status, l10n);
    final end = switch (detail) {
      EconomicsV2CycleDetail(:final settledOn?) => settledOn,
      EconomicsV2CycleDetail(:final productionClosedOn?) => productionClosedOn,
      _ => null,
    };
    final endLabel = detail.status == EconomicsV2CycleStatus.open
        ? l10n.financeCycleWorkspaceOngoing
        : end?.formatShortDate(l10n) ?? l10n.notAvailableLabel;
    final period = l10n.financeCycleWorkspacePeriod(
      detail.startsOn.formatShortDate(l10n),
      endLabel,
    );
    return FinanceCycleCanvas(
      child: ListView(
        key: const ValueKey(AppWidgetKeys.financeCycleWorkspace),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          FinanceCycleContextSelector(
            allCyclesLabel: l10n.financeCycleWorkspaceAllCycles,
            detailLabel: l10n.financeCycleWorkspaceDetail,
            onBack: onBack,
          ),
          const SizedBox(height: AppSpacing.lg),
          FinanceCycleWorkspaceHeader(
            title: title,
            period: period,
            status: FinanceCycleStatusPill(
              key: const ValueKey(AppWidgetKeys.financeCycleStatus),
              label: status,
              isActive: detail.status == EconomicsV2CycleStatus.open,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isCompatibilityMode) ...[
            FinanceCycleCompatibilityNotice(
              message: l10n.financeCycleCompatibilityMessage,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          /* if (selectedView != FinanceCyclesView.overview) ...[
            FinanceCycleWorkspaceNavigation(
              selectedView: selectedView,
              onSelectView: onSelectView,
              isCompatibilityMode: isCompatibilityMode,
            ),
            const SizedBox(height: AppSpacing.md),
          ], */
          if (mutationFailed) ...[
            FinanceCyclePanel(
              message: l10n.financeCycleMutationError,
              variant: FinanceCyclePanelVariant.warning,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          body,
        ],
      ),
    );
  }
}

abstract final class FinanceCycleStatusLabelMapper {
  static String map(EconomicsV2CycleStatus status, AppLocalizations l10n) =>
      switch (status) {
        EconomicsV2CycleStatus.open => l10n.financeCycleStatusOpen,
        EconomicsV2CycleStatus.productionClosed =>
          l10n.financeCycleStatusProductionClosed,
        EconomicsV2CycleStatus.settled => l10n.financeCycleStatusSettled,
      };
}

class FinanceCycleCompatibilityNotice extends StatelessWidget {
  const FinanceCycleCompatibilityNotice({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: FinanceCyclePanel(
      key: const ValueKey(AppWidgetKeys.financeCycleCompatibilityNotice),
      message: message,
      variant: FinanceCyclePanelVariant.warning,
    ),
  );
}

class FinanceCycleWorkspaceNavigation extends StatelessWidget {
  const FinanceCycleWorkspaceNavigation({
    required this.selectedView,
    required this.onSelectView,
    required this.isCompatibilityMode,
    super.key,
  });

  final FinanceCyclesView selectedView;
  final ValueChanged<FinanceCyclesView> onSelectView;
  final bool isCompatibilityMode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destinations = [
      (
        view: FinanceCyclesView.overview,
        key: AppWidgetKeys.financeCycleOverviewTab,
        icon: Icons.dashboard_outlined,
        label: l10n.financeCycleWorkspaceOverview,
      ),
      (
        view: FinanceCyclesView.animals,
        key: AppWidgetKeys.financeCycleAnimalsTab,
        icon: Icons.pets_outlined,
        label: l10n.financeCycleWorkspaceAnimals,
      ),
      (
        view: FinanceCyclesView.feeds,
        key: AppWidgetKeys.financeCycleFeedsTab,
        icon: Icons.grass_outlined,
        label: l10n.financeCycleWorkspaceFeeds,
      ),
      (
        view: FinanceCyclesView.expenses,
        key: AppWidgetKeys.financeCycleExpensesTab,
        icon: Icons.receipt_long_outlined,
        label: l10n.financeCycleWorkspaceExpenses,
      ),
      (
        view: FinanceCyclesView.projections,
        key: AppWidgetKeys.financeCycleProjectionsTab,
        icon: Icons.trending_up_rounded,
        label: l10n.financeCycleWorkspaceProjections,
      ),
      (
        view: FinanceCyclesView.close,
        key: AppWidgetKeys.financeCycleCloseTab,
        icon: Icons.task_alt_rounded,
        label: l10n.financeCycleWorkspaceClose,
      ),
    ];
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final destination in destinations)
          IconButton.filledTonal(
            key: ValueKey(destination.key),
            tooltip:
                isCompatibilityMode &&
                    destination.view != FinanceCyclesView.overview
                ? l10n.financeCycleCompatibilityMessage
                : destination.label,
            isSelected: selectedView == destination.view,
            onPressed:
                isCompatibilityMode &&
                    destination.view != FinanceCyclesView.overview
                ? null
                : () => onSelectView(destination.view),
            icon: Icon(destination.icon),
          ),
      ],
    );
  }
}

class FinanceCycleOverviewView extends StatelessWidget {
  const FinanceCycleOverviewView({
    required this.detail,
    required this.onSelectView,
    required this.isCompatibilityMode,
    super.key,
  });

  final EconomicsV2CycleDetail detail;
  final ValueChanged<FinanceCyclesView> onSelectView;
  final bool isCompatibilityMode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destination = isCompatibilityMode
        ? null
        : (FinanceCyclesView view) => onSelectView(view);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceCycleOverviewSummary(
          key: const ValueKey(AppWidgetKeys.financeCycleOverview),
          metrics: [
            FinanceCycleOverviewMetric(
              key: const ValueKey(
                AppWidgetKeys.financeCycleOverviewAnimalsMetric,
              ),
              label: l10n.financeCycleOverviewAnimalsMetric,
              value: detail.activeAnimalCount.formatInteger(l10n),
            ),
            FinanceCycleOverviewMetric(
              key: const ValueKey(
                AppWidgetKeys.financeCycleOverviewExpensesMetric,
              ),
              label: l10n.financeCycleOverviewExpensesMetric,
              value: detail.directExpenseTotal.formatCurrency(l10n),
            ),
            FinanceCycleOverviewMetric(
              key: const ValueKey(AppWidgetKeys.financeCycleOverviewFeedMetric),
              label: l10n.financeCycleOverviewFeedMetric,
              value: detail.feedCost.formatCurrency(l10n),
            ),
            FinanceCycleOverviewMetric(
              key: const ValueKey(
                AppWidgetKeys.financeCycleOverviewProjectionMetric,
              ),
              label: l10n.financeCycleOverviewProjectionMetric,
              value: detail.profit.formatCurrency(l10n),
            ),
          ],
          lastUpdated: l10n.financeCycleOverviewLastUpdated(
            detail.updatedAt?.formatShortDate(l10n) ?? l10n.notAvailableLabel,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FinanceCycleNavigationRow(
          keyValue: AppWidgetKeys.financeCycleAnimalsTab,
          icon: Icons.pets_outlined,
          title: l10n.financeCycleWorkspaceAnimals,
          subtitle: l10n.financeCycleAnimalsNavigationSubtitle,
          value: l10n.financeCycleActiveValue(detail.activeAnimalCount),
          onPressed: destination == null
              ? null
              : () => destination(FinanceCyclesView.animals),
        ),
        const SizedBox(height: AppSpacing.sm),
        FinanceCycleNavigationRow(
          keyValue: AppWidgetKeys.financeCycleFeedsTab,
          icon: Icons.grass_outlined,
          title: l10n.financeCycleWorkspaceFeeds,
          subtitle: l10n.financeCycleFeedsNavigationSubtitle,
          value: detail.feedCost.formatCurrency(l10n),
          onPressed: destination == null
              ? null
              : () => destination(FinanceCyclesView.feeds),
        ),
        const SizedBox(height: AppSpacing.sm),
        FinanceCycleNavigationRow(
          keyValue: AppWidgetKeys.financeCycleExpensesTab,
          icon: Icons.receipt_long_outlined,
          title: l10n.financeCycleExpensesNavigationTitle,
          subtitle: l10n.financeCycleExpensesNavigationSubtitle,
          value: detail.directExpenseTotal.formatCurrency(l10n),
          onPressed: destination == null
              ? null
              : () => destination(FinanceCyclesView.expenses),
        ),
        const SizedBox(height: AppSpacing.sm),
        FinanceCycleNavigationRow(
          keyValue: AppWidgetKeys.financeCycleProjectionsTab,
          icon: Icons.trending_up_rounded,
          title: l10n.financeCycleProjectionNavigationTitle,
          subtitle: l10n.financeCycleProjectionsNavigationSubtitle,
          value: detail.profit.formatCurrency(l10n),
          onPressed: destination == null
              ? null
              : () => destination(FinanceCyclesView.projections),
        ),
        const SizedBox(height: AppSpacing.sm),
        FinanceCycleNavigationRow(
          keyValue: AppWidgetKeys.financeCycleCloseTab,
          icon: Icons.task_alt_rounded,
          title: l10n.financeCycleResultNavigationTitle,
          subtitle: l10n.financeCycleResultNavigationSubtitle,
          value: detail.profit.formatCurrency(l10n),
          onPressed: destination == null
              ? null
              : () => destination(FinanceCyclesView.close),
        ),
        const SizedBox(height: AppSpacing.md),
        FinanceCycleActionButton(
          keyValue: AppWidgetKeys.financeCycleCloseAction,
          label: l10n.financeCycleCloseAction,
          variant: FinanceCycleActionVariant.destructive,
          onPressed: destination == null
              ? null
              : () => destination(FinanceCyclesView.close),
          icon: Icons.lock_outline_rounded,
        ),
      ],
    );
  }
}

class FinanceCycleAnimalsView extends StatelessWidget {
  const FinanceCycleAnimalsView({
    required this.members,
    required this.isPending,
    required this.onAssign,
    super.key,
  });

  final EconomicsV2CycleMembers members;
  final bool isPending;
  final ValueChanged<String> onAssign;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeMemberCount = members.members
        .where((member) => member.isActive)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceCycleSurfaceCard(
          key: const ValueKey(AppWidgetKeys.financeCycleAnimalsSummary),
          child: FinanceCycleMetricGroup(
            metrics: [
              FinanceCycleMetricTile(
                label: l10n.financeCycleAssignedAnimalsMetric,
                value: activeMemberCount.formatInteger(l10n),
                icon: Icons.pets_outlined,
              ),
              FinanceCycleMetricTile(
                label: l10n.financeCycleAvailableAnimalsMetric,
                value: members.candidates.length.formatInteger(l10n),
                icon: Icons.add_circle_outline_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FinanceCycleContentSection(
          key: const ValueKey(AppWidgetKeys.financeCycleAnimalsAssigned),
          title: l10n.financeCycleAnimalsAssignedTitle,
          subtitle: l10n.financeCycleAnimalsAssignedCount(
            members.members.length,
          ),
          children: [
            if (members.members.isEmpty)
              FinanceCyclePanel(
                message: l10n.financeCycleAnimalsAssignedEmpty,
                variant: FinanceCyclePanelVariant.info,
              ),
            for (final member in members.members)
              FinanceCycleRecordTile(
                icon: Icons.pets_outlined,
                title: member.label,
                details: [
                  l10n.financeCycleMemberSince(
                    member.joinedOn.formatShortDate(l10n),
                  ),
                  ?member.groupNameSnapshot,
                ],
                badge: FinanceCycleStatusPill(
                  label: member.isActive
                      ? l10n.financeCycleAssignmentActive
                      : l10n.financeCycleAssignmentFinished,
                  isActive: member.isActive,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        FinanceCycleContentSection(
          key: const ValueKey(AppWidgetKeys.financeCycleAnimalsAvailable),
          title: l10n.financeCycleAnimalsAvailableTitle,
          subtitle: l10n.financeCycleAnimalsAvailableCount(
            members.candidates.length,
          ),
          children: [
            if (members.candidates.isEmpty)
              FinanceCyclePanel(
                message: l10n.financeCycleAnimalsAvailableEmpty,
                variant: FinanceCyclePanelVariant.info,
              ),
            for (final candidate in members.candidates) ...[
              FinanceCycleRecordTile(
                icon: Icons.pets_outlined,
                title: candidate.label,
                details: [?candidate.groupName],
              ),
              FinanceCycleActionButton(
                keyValue: AppWidgetKeys.financeCycleAssignAnimal(
                  candidate.animalId,
                ),
                label: l10n.financeCycleAssignAnimal(candidate.label),
                variant: FinanceCycleActionVariant.primary,
                onPressed: isPending
                    ? null
                    : () => onAssign(candidate.animalId),
                icon: Icons.add_rounded,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class FinanceCycleFeedsView extends StatelessWidget {
  const FinanceCycleFeedsView({
    required this.feeds,
    required this.isPending,
    required this.onLink,
    super.key,
  });

  final EconomicsV2CycleFeeds feeds;
  final bool isPending;
  final ValueChanged<String> onLink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeFeedCount = feeds.intervals
        .where((feed) => feed.isActive)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceCycleSurfaceCard(
          key: const ValueKey(AppWidgetKeys.financeCycleFeedsSummary),
          child: FinanceCycleMetricGroup(
            metrics: [
              FinanceCycleMetricTile(
                label: l10n.financeCycleLinkedFeedsMetric,
                value: activeFeedCount.formatInteger(l10n),
                icon: Icons.grass_outlined,
              ),
              FinanceCycleMetricTile(
                label: l10n.financeCycleAvailableFeedsMetric,
                value: feeds.candidates.length.formatInteger(l10n),
                icon: Icons.add_circle_outline_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FinanceCycleContentSection(
          key: const ValueKey(AppWidgetKeys.financeCycleFeedsLinked),
          title: l10n.financeCycleFeedsLinkedTitle,
          subtitle: l10n.financeCycleFeedsLinkedCount(feeds.intervals.length),
          children: [
            if (feeds.intervals.isEmpty)
              FinanceCyclePanel(
                message: l10n.financeCycleFeedsLinkedEmpty,
                variant: FinanceCyclePanelVariant.info,
              ),
            for (final feed in feeds.intervals)
              FinanceCycleRecordTile(
                icon: Icons.grass_outlined,
                title: feed.mixtureLabel,
                value: feed.cost.formatCurrency(l10n),
                details: [
                  l10n.financeCycleFeedPeriod(
                    feed.startsOn.formatShortDate(l10n),
                    feed.endsOn?.formatShortDate(l10n) ?? l10n.ongoingLabel,
                  ),
                  ?feed.groupNameSnapshot,
                ],
                badge: FinanceCycleStatusPill(
                  label: feed.isActive
                      ? l10n.financeCycleFeedActive
                      : l10n.financeCycleFeedFinished,
                  isActive: feed.isActive,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        FinanceCycleContentSection(
          key: const ValueKey(AppWidgetKeys.financeCycleFeedsAvailable),
          title: l10n.financeCycleFeedsAvailableTitle,
          subtitle: l10n.financeCycleFeedsAvailableCount(
            feeds.candidates.length,
          ),
          children: [
            if (feeds.candidates.isEmpty)
              FinanceCyclePanel(
                message: l10n.financeCycleFeedsAvailableEmpty,
                variant: FinanceCyclePanelVariant.info,
              ),
            for (final candidate in feeds.candidates) ...[
              FinanceCycleRecordTile(
                icon: Icons.grass_outlined,
                title: candidate.mixtureLabel,
                details: [?candidate.groupName],
              ),
              FinanceCycleActionButton(
                keyValue: AppWidgetKeys.financeCycleLinkFeed(
                  candidate.mixtureId,
                ),
                label: l10n.financeCycleLinkFeed(candidate.mixtureLabel),
                variant: FinanceCycleActionVariant.primary,
                onPressed: isPending ? null : () => onLink(candidate.mixtureId),
                icon: Icons.add_rounded,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class FinanceCycleExpensesView extends StatelessWidget {
  const FinanceCycleExpensesView({
    required this.expenses,
    required this.isPending,
    required this.onAdd,
    super.key,
  });

  final List<EconomicsV2CycleExpense> expenses;
  final bool isPending;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceCycleSurfaceCard(
          key: const ValueKey(AppWidgetKeys.financeCycleExpensesSummary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FinanceCycleMetricGroup(
                metrics: [
                  FinanceCycleMetricTile(
                    label: l10n.financeCycleExpensesTotalMetric,
                    value: total.formatCurrency(l10n),
                    icon: Icons.receipt_long_outlined,
                  ),
                  FinanceCycleMetricTile(
                    label: l10n.financeCycleExpensesCountMetric,
                    value: expenses.length.formatInteger(l10n),
                    icon: Icons.format_list_numbered_rounded,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FinanceCycleActionButton(
                keyValue: AppWidgetKeys.financeCycleExpenseAdd,
                label: l10n.financeCycleAddExpense,
                variant: FinanceCycleActionVariant.primary,
                onPressed: isPending ? null : onAdd,
                icon: Icons.add_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FinanceCycleContentSection(
          key: const ValueKey(AppWidgetKeys.financeCycleExpensesList),
          title: l10n.financeCycleExpensesHistoryTitle,
          subtitle: l10n.financeCycleExpensesRecordedCount(expenses.length),
          children: [
            if (expenses.isEmpty)
              FinanceCyclePanel(
                message: l10n.financeCycleExpensesEmpty,
                variant: FinanceCyclePanelVariant.info,
              ),
            for (final expense in expenses)
              FinanceCycleRecordTile(
                icon: Icons.receipt_long_outlined,
                title:
                    expense.category ?? l10n.financeCycleUncategorizedExpense,
                value: expense.amount.formatCurrency(l10n),
                details: [
                  l10n.financeCycleExpenseDate(
                    expense.occurredOn.formatShortDate(l10n),
                  ),
                  ?expense.note,
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class FinanceCycleProjectionsView extends StatelessWidget {
  const FinanceCycleProjectionsView({
    required this.projections,
    required this.isPending,
    required this.onAdd,
    super.key,
  });

  final List<EconomicsV2SavedProjection> projections;
  final bool isPending;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finance = FinanceTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceCycleActionButton(
          keyValue: AppWidgetKeys.financeCycleProjectionAdd,
          label: l10n.financeCycleAddProjection,
          variant: FinanceCycleActionVariant.primary,
          onPressed: isPending ? null : onAdd,
          icon: Icons.add_rounded,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (projections.isEmpty)
          FinanceCyclePanel(
            message: l10n.financeCycleProjectionsEmpty,
            variant: FinanceCyclePanelVariant.info,
          ),
        for (final projection in projections) ...[
          FinanceCycleSurfaceCard(
            key: ValueKey(
              AppWidgetKeys.financeCycleProjectionCard(projection.projectionId),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.financeCycleProjectionCreatedOn(
                    projection.createdAt.formatShortDate(l10n),
                  ),
                  style: textTheme.titleMedium?.copyWith(
                    color: finance.cycleOnSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (projection.note case final note?) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    note,
                    style: textTheme.bodySmall?.copyWith(
                      color: finance.cycleOnSurfaceMuted,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                FinanceCycleMetricGroup(
                  metrics: [
                    FinanceCycleMetricTile(
                      label: l10n.financeCycleProjectedRevenueMetric,
                      value: projection.result.projectedRevenue.formatCurrency(
                        l10n,
                      ),
                      icon: Icons.arrow_upward_rounded,
                    ),
                    FinanceCycleMetricTile(
                      label: l10n.financeCycleProjectedCostMetric,
                      value: projection.result.projectedTotalCost
                          .formatCurrency(l10n),
                      icon: Icons.arrow_downward_rounded,
                    ),
                    FinanceCycleMetricTile(
                      label: l10n.financeCycleProjectedBalanceMetric,
                      value: projection.result.projectedBalance.formatCurrency(
                        l10n,
                      ),
                      icon: Icons.insights_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.financeCycleProjectionAssumptionsTitle,
                  style: textTheme.titleSmall?.copyWith(
                    color: finance.cycleOnSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                FinanceCycleMetricGroup(
                  metrics: [
                    FinanceCycleMetricTile(
                      label: l10n.financeCycleProjectionUnitPriceLabel,
                      value:
                          projection.input.expectedUnitPrice?.formatCurrency(
                            l10n,
                          ) ??
                          l10n.notAvailableLabel,
                      icon: Icons.sell_outlined,
                    ),
                    FinanceCycleMetricTile(
                      label: l10n.financeCycleProjectionProductionPerDayLabel,
                      value:
                          projection.input.productionPerDay?.formatDecimal(
                            l10n,
                          ) ??
                          l10n.notAvailableLabel,
                      icon: Icons.inventory_2_outlined,
                    ),
                    FinanceCycleMetricTile(
                      label: l10n.financeCycleProjectionFeedPerDayLabel,
                      value:
                          projection.input.feedPerDay?.formatCurrency(l10n) ??
                          l10n.notAvailableLabel,
                      icon: Icons.grass_outlined,
                    ),
                    FinanceCycleMetricTile(
                      label: l10n.financeCycleProjectionHorizonLabel,
                      value: switch (projection.input.horizonDays) {
                        final days? => l10n.financeCycleProjectionDays(days),
                        null => l10n.notAvailableLabel,
                      },
                      icon: Icons.calendar_today_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class FinanceCycleCloseView extends StatelessWidget {
  const FinanceCycleCloseView({
    required this.detail,
    required this.readiness,
    required this.isPending,
    required this.onCloseProduction,
    required this.onFinalize,
    super.key,
  });

  final EconomicsV2CycleDetail detail;
  final EconomicsV2CycleReadiness readiness;
  final bool isPending;
  final VoidCallback onCloseProduction;
  final VoidCallback onFinalize;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finance = FinanceTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    if (detail.status == EconomicsV2CycleStatus.settled) {
      return FinanceCycleSurfaceCard(
        key: const ValueKey(AppWidgetKeys.financeCycleFinalResult),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.financeCycleFinalResultTitle,
              style: textTheme.titleLarge?.copyWith(
                color: finance.cycleOnSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FinanceCyclePanel(
              message: l10n.financeCycleSettledOn(
                detail.settledOn?.formatShortDate(l10n) ??
                    l10n.notAvailableLabel,
              ),
              variant: FinanceCyclePanelVariant.result,
            ),
            const SizedBox(height: AppSpacing.sm),
            FinanceCycleMetricGroup(
              metrics: [
                FinanceCycleMetricTile(
                  label: l10n.financeCycleFinalRevenueMetric,
                  value: detail.revenue.formatCurrency(l10n),
                  icon: Icons.arrow_upward_rounded,
                ),
                FinanceCycleMetricTile(
                  label: l10n.financeCycleFinalCostMetric,
                  value: detail.totalCost.formatCurrency(l10n),
                  icon: Icons.arrow_downward_rounded,
                ),
                FinanceCycleMetricTile(
                  label: l10n.financeCycleFinalProfitMetric,
                  value: detail.profit.formatCurrency(l10n),
                  icon: Icons.insights_rounded,
                ),
              ],
            ),
          ],
        ),
      );
    }
    return FinanceCycleSurfaceCard(
      key: const ValueKey(AppWidgetKeys.financeCycleCloseReadiness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.financeCycleCloseRequirementsTitle,
            style: textTheme.titleLarge?.copyWith(
              color: finance.cycleOnSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FinanceCyclePanel(
            message: readiness.canCloseProduction
                ? l10n.financeCycleReadyToClose
                : readiness.canSettle
                ? l10n.financeCycleReadyToSettle
                : l10n.financeCycleNotReadyToClose,
            variant: readiness.canCloseProduction || readiness.canSettle
                ? FinanceCyclePanelVariant.info
                : FinanceCyclePanelVariant.warning,
          ),
          const SizedBox(height: AppSpacing.sm),
          FinanceCycleRecordTile(
            icon: readiness.hasMembers
                ? Icons.check_circle_outline_rounded
                : Icons.pending_outlined,
            title: l10n.financeCycleCloseMembersCriterion,
            badge: FinanceCycleStatusPill(
              label: readiness.hasMembers
                  ? l10n.financeCycleCriterionComplete
                  : l10n.financeCycleCriterionPending,
              isActive: readiness.hasMembers,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FinanceCycleRecordTile(
            icon: readiness.hasFeed
                ? Icons.check_circle_outline_rounded
                : Icons.pending_outlined,
            title: l10n.financeCycleCloseFeedCriterion,
            badge: FinanceCycleStatusPill(
              label: readiness.hasFeed
                  ? l10n.financeCycleCriterionComplete
                  : l10n.financeCycleCriterionPending,
              isActive: readiness.hasFeed,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FinanceCycleRecordTile(
            icon: readiness.hasSaleableOutput
                ? Icons.check_circle_outline_rounded
                : Icons.pending_outlined,
            title: l10n.financeCycleCloseOutputCriterion,
            badge: FinanceCycleStatusPill(
              label: readiness.hasSaleableOutput
                  ? l10n.financeCycleCriterionComplete
                  : l10n.financeCycleCriterionPending,
              isActive: readiness.hasSaleableOutput,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FinanceCycleRecordTile(
            icon: readiness.salesWithinOutput
                ? Icons.check_circle_outline_rounded
                : Icons.pending_outlined,
            title: l10n.financeCycleCloseSalesCriterion,
            badge: FinanceCycleStatusPill(
              label: readiness.salesWithinOutput
                  ? l10n.financeCycleCriterionComplete
                  : l10n.financeCycleCriterionPending,
              isActive: readiness.salesWithinOutput,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FinanceCycleRecordTile(
            icon: readiness.openFeedCount == 0
                ? Icons.check_circle_outline_rounded
                : Icons.pending_outlined,
            title: l10n.financeCycleCloseOpenFeedsCriterion(
              readiness.openFeedCount,
            ),
            badge: FinanceCycleStatusPill(
              label: readiness.openFeedCount == 0
                  ? l10n.financeCycleCriterionComplete
                  : l10n.financeCycleCriterionPending,
              isActive: readiness.openFeedCount == 0,
            ),
          ),
          for (final reason in readiness.reasons) ...[
            const SizedBox(height: AppSpacing.xs),
            FinanceCycleReadinessReasonLabel(reason: reason),
          ],
          if (readiness.canCloseProduction) ...[
            const SizedBox(height: AppSpacing.sm),
            FinanceCycleActionButton(
              keyValue: AppWidgetKeys.financeCycleCloseProduction,
              label: l10n.financeCycleCloseProductionAction,
              variant: FinanceCycleActionVariant.destructive,
              onPressed: isPending ? null : onCloseProduction,
              icon: Icons.task_alt_rounded,
            ),
          ],
          if (readiness.canSettle) ...[
            const SizedBox(height: AppSpacing.sm),
            FinanceCycleActionButton(
              keyValue: AppWidgetKeys.financeCycleFinalize,
              label: l10n.financeCycleFinalizeAction,
              variant: FinanceCycleActionVariant.destructive,
              onPressed: isPending ? null : onFinalize,
              icon: Icons.lock_outline_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class FinanceCycleReadinessReasonLabel extends StatelessWidget {
  const FinanceCycleReadinessReasonLabel({required this.reason, super.key});

  final EconomicsV2ReadinessReason reason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (reason) {
      EconomicsV2ReadinessReason.missingMembers =>
        l10n.financeCycleReadinessMissingMembers,
      EconomicsV2ReadinessReason.missingFeed =>
        l10n.financeCycleReadinessMissingFeed,
      EconomicsV2ReadinessReason.missingSaleableOutput =>
        l10n.financeCycleReadinessMissingSaleableOutput,
      EconomicsV2ReadinessReason.salesExceedOutput =>
        l10n.financeCycleReadinessSalesExceedOutput,
      EconomicsV2ReadinessReason.openFeedIntervals =>
        l10n.financeCycleReadinessOpenFeedIntervals,
      EconomicsV2ReadinessReason.productionNotClosed =>
        l10n.financeCycleReadinessProductionNotClosed,
    };
    return Text(
      l10n.financeCycleReadinessReason(label),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: FinanceTheme.of(context).cycleOnSurfaceMuted,
      ),
    );
  }
}

class FinanceCycleWorkspaceAsyncBody<T> extends StatelessWidget {
  const FinanceCycleWorkspaceAsyncBody({
    required this.viewKey,
    required this.value,
    required this.onRetry,
    required this.builder,
    super.key,
  });

  final String viewKey;
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: ValueKey(viewKey),
    child: switch (value) {
      AsyncLoading() => const FinanceCyclesLoadingState(),
      AsyncError() => FinanceCycleWorkspaceReadError(onRetry: onRetry),
      AsyncData(:final value) => builder(value),
    },
  );
}

class FinanceCycleWorkspaceReadError extends StatelessWidget {
  const FinanceCycleWorkspaceReadError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n.financeCycleWorkspaceLoadError),
        const SizedBox(height: AppSpacing.xs),
        FilledButton.tonal(
          onPressed: onRetry,
          child: Text(context.l10n.financeRetry),
        ),
      ],
    ),
  );
}

final class FinanceCycleExpenseDraft {
  const FinanceCycleExpenseDraft({
    required this.amount,
    this.category,
    this.note,
  });

  final double amount;
  final String? category;
  final String? note;
}

final class FinanceCycleProjectionDraft {
  const FinanceCycleProjectionDraft({required this.input, this.note});

  final EconomicsV2ProjectionInput input;
  final String? note;
}

Future<FinanceCycleExpenseDraft?> showFinanceCycleExpenseDialog(
  BuildContext context,
) => showDialog<FinanceCycleExpenseDraft>(
  context: context,
  builder: (_) => const FinanceCycleExpenseDialog(),
);

Future<FinanceCycleProjectionDraft?> showFinanceCycleProjectionDialog(
  BuildContext context,
) => showDialog<FinanceCycleProjectionDraft>(
  context: context,
  builder: (_) => const FinanceCycleProjectionDialog(),
);

class FinanceCycleExpenseDialog extends StatefulWidget {
  const FinanceCycleExpenseDialog({super.key});

  @override
  State<FinanceCycleExpenseDialog> createState() =>
      _FinanceCycleExpenseDialogState();
}

class _FinanceCycleExpenseDialogState extends State<FinanceCycleExpenseDialog> {
  final _category = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  var _showValidation = false;

  @override
  void dispose() {
    _category.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.financeCycleAddExpense),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey(AppWidgetKeys.financeCycleExpenseCategory),
            controller: _category,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.financeCycleExpenseCategoryLabel,
            ),
          ),
          TextField(
            key: const ValueKey(AppWidgetKeys.financeCycleExpenseAmount),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.financeCycleExpenseAmountLabel,
            ),
          ),
          TextField(
            key: const ValueKey(AppWidgetKeys.financeCycleExpenseNote),
            controller: _note,
            decoration: InputDecoration(labelText: l10n.financeCycleNoteLabel),
          ),
          if (_showValidation)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                l10n.financeCycleInvalidForm,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.financeCycleCancel),
        ),
        FilledButton(
          key: const ValueKey(AppWidgetKeys.financeCycleExpenseConfirm),
          onPressed: _submit,
          child: Text(l10n.financeCycleSave),
        ),
      ],
    );
  }

  void _submit() {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _showValidation = true);
      return;
    }
    Navigator.of(context).pop(
      FinanceCycleExpenseDraft(
        amount: amount,
        category: _optionalText(_category.text),
        note: _optionalText(_note.text),
      ),
    );
  }
}

class FinanceCycleProjectionDialog extends StatefulWidget {
  const FinanceCycleProjectionDialog({super.key});

  @override
  State<FinanceCycleProjectionDialog> createState() =>
      _FinanceCycleProjectionDialogState();
}

class _FinanceCycleProjectionDialogState
    extends State<FinanceCycleProjectionDialog> {
  final _unitPrice = TextEditingController();
  final _productionPerDay = TextEditingController();
  final _feedPerDay = TextEditingController();
  final _otherCosts = TextEditingController();
  final _horizonDays = TextEditingController();
  final _note = TextEditingController();
  var _showValidation = false;

  @override
  void dispose() {
    _unitPrice.dispose();
    _productionPerDay.dispose();
    _feedPerDay.dispose();
    _otherCosts.dispose();
    _horizonDays.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.financeCycleAddProjection),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FinanceCycleNumberField(
            keyValue: AppWidgetKeys.financeCycleProjectionUnitPrice,
            controller: _unitPrice,
            label: l10n.financeCycleProjectionUnitPriceLabel,
          ),
          FinanceCycleNumberField(
            keyValue: AppWidgetKeys.financeCycleProjectionProductionPerDay,
            controller: _productionPerDay,
            label: l10n.financeCycleProjectionProductionPerDayLabel,
          ),
          FinanceCycleNumberField(
            keyValue: AppWidgetKeys.financeCycleProjectionFeedPerDay,
            controller: _feedPerDay,
            label: l10n.financeCycleProjectionFeedPerDayLabel,
          ),
          FinanceCycleNumberField(
            keyValue: AppWidgetKeys.financeCycleProjectionOtherCosts,
            controller: _otherCosts,
            label: l10n.financeCycleProjectionOtherCostsLabel,
          ),
          TextField(
            key: const ValueKey(
              AppWidgetKeys.financeCycleProjectionHorizonDays,
            ),
            controller: _horizonDays,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.financeCycleProjectionHorizonLabel,
            ),
          ),
          TextField(
            key: const ValueKey(AppWidgetKeys.financeCycleProjectionNote),
            controller: _note,
            decoration: InputDecoration(labelText: l10n.financeCycleNoteLabel),
          ),
          if (_showValidation)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                l10n.financeCycleInvalidForm,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.financeCycleCancel),
        ),
        FilledButton(
          key: const ValueKey(AppWidgetKeys.financeCycleProjectionConfirm),
          onPressed: _submit,
          child: Text(l10n.financeCycleSave),
        ),
      ],
    );
  }

  void _submit() {
    final unitPrice = _positiveDouble(_unitPrice.text);
    final productionPerDay = _positiveDouble(_productionPerDay.text);
    final feedPerDay = _positiveDouble(_feedPerDay.text);
    final otherCosts = double.tryParse(_otherCosts.text.trim());
    final horizonDays = int.tryParse(_horizonDays.text.trim());
    if (unitPrice == null ||
        productionPerDay == null ||
        feedPerDay == null ||
        otherCosts == null ||
        !otherCosts.isFinite ||
        otherCosts < 0 ||
        horizonDays == null ||
        horizonDays <= 0) {
      setState(() => _showValidation = true);
      return;
    }
    Navigator.of(context).pop(
      FinanceCycleProjectionDraft(
        input: EconomicsV2ProjectionInput(
          expectedUnitPrice: unitPrice,
          productionPerDay: productionPerDay,
          feedPerDay: feedPerDay,
          otherCosts: otherCosts,
          horizonDays: horizonDays,
        ),
        note: _optionalText(_note.text),
      ),
    );
  }
}

class FinanceCycleNumberField extends StatelessWidget {
  const FinanceCycleNumberField({
    required this.keyValue,
    required this.controller,
    required this.label,
    super.key,
  });

  final String keyValue;
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
    key: ValueKey(keyValue),
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(labelText: label),
  );
}

double? _positiveDouble(String value) {
  final parsed = double.tryParse(value.trim());
  return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
}

String? _optionalText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
