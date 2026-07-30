import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/localization_extension.dart';
import '../../../../core/extensions/primitive_formatting_extensions.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/finance_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/break_even_point.dart';
import '../providers/finances_providers.dart';
import '../widgets/break_even_card.dart';
import '../widgets/break_even_content.dart';
import '../widgets/finance_states.dart';
import '../widgets/finance_tab_bar.dart';

class FinancesScreen extends ConsumerStatefulWidget {
  const FinancesScreen({required this.farmId, super.key});

  final String farmId;

  @override
  ConsumerState<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends ConsumerState<FinancesScreen> {
  FinanceTab _selectedTab = FinanceTab.balance;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      FinanceTabItem(
        tab: FinanceTab.balance,
        role: FinanceTabRole.balance,
        label: l10n.financeTabBalance,
        asset: 'assets/goal.png',
        keyValue: AppWidgetKeys.financeBalanceTab,
      ),
      FinanceTabItem(
        tab: FinanceTab.income,
        role: FinanceTabRole.income,
        label: l10n.financeTabIncome,
        asset: 'assets/income.png',
        keyValue: AppWidgetKeys.financeIncomeTab,
      ),
      FinanceTabItem(
        tab: FinanceTab.expenses,
        role: FinanceTabRole.expenses,
        label: l10n.financeTabExpenses,
        asset: 'assets/outcome.png',
        keyValue: AppWidgetKeys.financeExpensesTab,
      ),
      FinanceTabItem(
        tab: FinanceTab.charts,
        role: FinanceTabRole.charts,
        label: l10n.financeTabCharts,
        asset: 'assets/chart.png',
        keyValue: AppWidgetKeys.financeChartsTab,
      ),
    ];
    final content = switch (_selectedTab) {
      FinanceTab.balance => FinanceBalanceSection(farmId: widget.farmId),
      FinanceTab.income => FinanceMessageState(
        key: const ValueKey(AppWidgetKeys.financeIncomeUnavailable),
        title: l10n.financeIncomeUnavailableTitle,
        message: l10n.financeIncomeUnavailableMessage,
        note: l10n.financeNoFabricatedData,
        asset: 'assets/income.png',
      ),
      FinanceTab.expenses => FinanceMessageState(
        key: const ValueKey(AppWidgetKeys.financeExpensesUnavailable),
        title: l10n.financeExpensesUnavailableTitle,
        message: l10n.financeExpensesUnavailableMessage,
        note: l10n.financeNoFabricatedData,
        asset: 'assets/outcome.png',
      ),
      FinanceTab.charts => FinanceMessageState(
        key: const ValueKey(AppWidgetKeys.financeChartsUnavailable),
        title: l10n.financeChartsUnavailableTitle,
        message: l10n.financeChartsUnavailableMessage,
        note: l10n.financeNoFabricatedData,
        asset: 'assets/chart_filled.png',
      ),
    };

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xs),
            FinanceTabBar(
              items: items,
              selected: _selectedTab,
              onSelected: (tab) => setState(() => _selectedTab = tab),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class FinanceBalanceSection extends ConsumerWidget {
  const FinanceBalanceSection({required this.farmId, super.key});

  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final points = ref.watch(breakEvenPointsProvider(farmId));
    return switch (points) {
      AsyncLoading() => const Center(
        key: ValueKey(AppWidgetKeys.financeLoading),
        child: CircularProgressIndicator(),
      ),
      AsyncError() => FinanceMessageState(
        key: const ValueKey(AppWidgetKeys.financeError),
        title: l10n.financeErrorTitle,
        message: l10n.financeErrorMessage,
        asset: 'assets/goal.png',
        actionKey: AppWidgetKeys.financeRetry,
        actionLabel: l10n.financeRetry,
        onAction: () => ref.invalidate(breakEvenPointsProvider(farmId)),
      ),
      AsyncData(:final value) when value.isEmpty => FinanceMessageState(
        key: const ValueKey(AppWidgetKeys.financeEmpty),
        title: l10n.financeBalanceEmptyTitle,
        message: l10n.financeBalanceEmptyMessage,
        asset: 'assets/goal.png',
      ),
      AsyncData(:final value) => BreakEvenContent(
        title: l10n.financeBalanceHeading,
        subtitle: l10n.financeBalanceSubtitle,
        cards: [
          for (final point in value) BreakEvenCardDataMapper.map(point, l10n),
        ],
        onRefresh: () async {
          ref.invalidate(breakEvenPointsProvider(farmId));
          await ref.read(breakEvenPointsProvider(farmId).future);
        },
      ),
    };
  }
}

abstract final class BreakEvenCardDataMapper {
  static BreakEvenCardViewData map(
    BreakEvenPoint point,
    AppLocalizations l10n,
  ) {
    final price = switch (point.breakEvenPrice) {
      final value? => value.formatCurrency(l10n),
      null => l10n.notAvailableLabel,
    };
    final (:marginLabel, :marginRole) = switch (point.marginPercentage) {
      double value when value >= 0 => (
        marginLabel: l10n.financeMarginValue(value.formatSignedDecimal(l10n)),
        marginRole: FinanceMarginRole.positive,
      ),
      double value => (
        marginLabel: l10n.financeMarginValue(value.formatSignedDecimal(l10n)),
        marginRole: FinanceMarginRole.negative,
      ),
      null => (
        marginLabel: l10n.financeMarginUnavailable,
        marginRole: FinanceMarginRole.unavailable,
      ),
    };
    final secondaryMetrics = <FinanceMetricViewData>[
      FinanceMetricViewData(
        label: l10n.weightedAverageBirdsLabel,
        value: point.weightedAverageBirds.formatDecimal(l10n),
        icon: Icons.pets_outlined,
      ),
      FinanceMetricViewData(
        label: l10n.eggsPerDayLabel,
        value: point.eggsPerDay.formatDecimal(l10n),
        icon: Icons.calendar_today_outlined,
      ),
      FinanceMetricViewData(
        label: l10n.eggsPerDayPerBirdLabel,
        value: point.eggsPerDayPerBird.formatDecimal(l10n),
        icon: Icons.egg_outlined,
      ),
      FinanceMetricViewData(
        label: l10n.feedPerDayLabel,
        value: l10n.financeKilograms(point.feedPerDay.formatDecimal(l10n)),
        icon: Icons.scale_outlined,
      ),
      FinanceMetricViewData(
        label: l10n.feedPerDayPerBirdLabel,
        value: l10n.financeKilograms(
          point.feedPerDayPerBird.formatDecimal(l10n),
        ),
        icon: Icons.monitor_weight_outlined,
      ),
      if (point.averageSalePrice case final salePrice?)
        FinanceMetricViewData(
          label: l10n.averageSalePriceLabel,
          value: salePrice.formatCurrency(l10n),
          icon: Icons.sell_outlined,
        ),
    ];

    return BreakEvenCardViewData(
      mixtureId: point.mixtureId,
      groupName: point.groupName,
      description: l10n.breakEvenCardDescription,
      priceLabel: l10n.breakEvenPricePerEggLabel,
      priceValue: price,
      marginLabel: marginLabel,
      marginRole: marginRole,
      primaryMetrics: [
        FinanceMetricViewData(
          label: l10n.totalCostLabel,
          value: point.totalFoodCost.formatCurrency(l10n),
          icon: Icons.payments_outlined,
        ),
        FinanceMetricViewData(
          label: l10n.goodEggsLabel,
          value: point.goodEggs.formatInteger(l10n),
          icon: Icons.egg_alt_outlined,
        ),
        FinanceMetricViewData(
          label: l10n.totalFeedConsumptionLabel,
          value: l10n.financeKilograms(
            point.totalFeedConsumption.formatDecimal(l10n),
          ),
          icon: Icons.grass_outlined,
        ),
      ],
      secondaryMetrics: secondaryMetrics,
      durationLabel: l10n.mixtureDurationLabel,
      durationValue: l10n.financeDurationDays(point.mixtureDays),
      periodValue: l10n.financeDateRange(
        point.startedAt.formatShortDate(l10n),
        point.calculatedEndAt.formatShortDate(l10n),
      ),
      semanticsLabel: l10n.breakEvenCardSemantics(
        point.groupName,
        price,
        marginLabel,
      ),
    );
  }
}
