import 'package:flutter/material.dart';

import '../../../../core/extensions/localization_extension.dart';
import '../../../../core/extensions/primitive_formatting_extensions.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/finance_theme.dart';
import '../../domain/economics_v2_models.dart';
import 'finance_cycle_visuals.dart';

class FinanceCyclesDashboardView extends StatelessWidget {
  const FinanceCyclesDashboardView({
    required this.dashboard,
    required this.canEdit,
    required this.onAdd,
    required this.onOpen,
    required this.onRefresh,
    super.key,
  });

  final EconomicsV2CyclesDashboard dashboard;
  final bool canEdit;
  final VoidCallback onAdd;
  final ValueChanged<String> onOpen;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finance = FinanceTheme.of(context);
    return FinanceCycleCanvas(
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSizes.financeCycleFabClearance,
              ),
              children: [
                FinanceCycleSectionHeader(
                  title: l10n.financeCyclesTitle,
                  subtitle: l10n.financeCyclesSubtitle,
                ),
                const SizedBox(height: AppSpacing.md),
                FinanceCycleSurfaceCard(
                  key: const ValueKey(AppWidgetKeys.financeCyclesAggregate),
                  elevated: true,
                  child: FinanceCycleMetricGroup(
                    expandedColumns: 4,
                    metrics: [
                      FinanceCycleMetricTile(
                        label: l10n.financeCyclesAggregateTotalLabel,
                        value: l10n.financeCyclesCount(dashboard.cycleCount),
                        icon: Icons.loop_rounded,
                      ),
                      FinanceCycleMetricTile(
                        label: l10n.financeCyclesAggregateOpenLabel,
                        value: l10n.financeCyclesOpenCount(
                          dashboard.openCycleCount,
                        ),
                        icon: Icons.play_circle_outline_rounded,
                      ),
                      FinanceCycleMetricTile(
                        label: l10n.financeCyclesAggregateAnimalsLabel,
                        value: dashboard.activeAnimalCount.formatInteger(l10n),
                        icon: Icons.pets_outlined,
                      ),
                      FinanceCycleMetricTile(
                        label: l10n.financeCyclesAggregateExpensesLabel,
                        value: dashboard.directExpenseTotal.formatCurrency(
                          l10n,
                        ),
                        icon: Icons.receipt_long_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final cycle in dashboard.summaries) ...[
                  FinanceCycleSummaryCard(
                    cycle: cycle,
                    onOpen: () => onOpen(cycle.cycleId),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
          if (canEdit)
            PositionedDirectional(
              end: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Tooltip(
                message: l10n.financeCyclesAdd,
                child: Semantics(
                  button: true,
                  label: l10n.financeCyclesAdd,
                  excludeSemantics: true,
                  child: FloatingActionButton(
                    key: const ValueKey(AppWidgetKeys.financeCyclesAdd),
                    onPressed: onAdd,
                    backgroundColor: finance.cyclePositiveAction,
                    foregroundColor: finance.cycleOnPositiveAction,
                    child: const Icon(Icons.add_rounded),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FinanceCycleSummaryCard extends StatelessWidget {
  const FinanceCycleSummaryCard({
    required this.cycle,
    required this.onOpen,
    super.key,
  });

  final EconomicsV2CycleSummary cycle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finance = FinanceTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final end = cycle.endsOn?.formatShortDate(l10n) ?? l10n.ongoingLabel;
    return FinanceCycleSurfaceCard(
      key: ValueKey(AppWidgetKeys.financeCycleSummary(cycle.cycleId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  cycle.purposeName,
                  style: textTheme.titleLarge?.copyWith(
                    color: finance.cycleOnSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FinanceCycleStatusPill(
                keyValue: AppWidgetKeys.financeCycleStatusPill(cycle.cycleId),
                label: cycle.isOpen
                    ? l10n.financeCycleStatusOpen
                    : l10n.financeCycleStatusClosed,
                isActive: cycle.isOpen,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.financeCyclePeriod(cycle.startsOn.formatShortDate(l10n), end),
            style: textTheme.bodyMedium?.copyWith(
              color: finance.cycleOnSurfaceMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FinanceCycleMetricGroup(
            expandedColumns: 3,
            metrics: [
              FinanceCycleMetricTile(
                label: l10n.financeCycleSummaryAnimalsLabel,
                value: cycle.activeAnimalCount.formatInteger(l10n),
                icon: Icons.pets_outlined,
              ),
              FinanceCycleMetricTile(
                label: l10n.financeCycleSummaryExpensesLabel,
                value: cycle.directExpenseTotal.formatCurrency(l10n),
                icon: Icons.receipt_long_outlined,
              ),
              FinanceCycleMetricTile(
                label: l10n.financeCycleSummaryFeedsLabel,
                value: cycle.linkedMixtureCount.formatInteger(l10n),
                icon: Icons.grass_outlined,
              ),
            ],
          ),
          if (cycle.latestLinkedGroupName case final groupName?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.financeCycleLatestLinkedGroup(groupName),
              style: textTheme.bodySmall?.copyWith(
                color: finance.cycleOnSurfaceMuted,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FinanceCycleActionButton(
            keyValue: AppWidgetKeys.financeCycleOpen(cycle.cycleId),
            label: l10n.financeCycleViewDetail,
            semanticLabel: l10n.financeCycleOpenSemantics(cycle.purposeName),
            variant: FinanceCycleActionVariant.primary,
            onPressed: onOpen,
            icon: Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }
}
