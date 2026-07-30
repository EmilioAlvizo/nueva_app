import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/localization_extension.dart';
import '../../../../core/extensions/primitive_formatting_extensions.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';
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
        label: l10n.financeTabBalance,
        asset: 'assets/goal.png',
        keyValue: AppWidgetKeys.financeBalanceTab,
      ),
      FinanceTabItem(
        tab: FinanceTab.income,
        label: l10n.financeTabIncome,
        asset: 'assets/income.png',
        keyValue: AppWidgetKeys.financeIncomeTab,
      ),
      FinanceTabItem(
        tab: FinanceTab.expenses,
        label: l10n.financeTabExpenses,
        asset: 'assets/outcome.png',
        keyValue: AppWidgetKeys.financeExpensesTab,
      ),
      FinanceTabItem(
        tab: FinanceTab.charts,
        label: l10n.financeTabCharts,
        asset: 'assets/chart.png',
        keyValue: AppWidgetKeys.financeChartsTab,
      ),
    ];

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
            Expanded(child: _selectedContent()),
          ],
        ),
      ),
    );
  }

  Widget _selectedContent() {
    final l10n = context.l10n;
    return switch (_selectedTab) {
      FinanceTab.balance => _balanceContent(),
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
  }

  Widget _balanceContent() {
    final l10n = context.l10n;
    final points = ref.watch(breakEvenPointsProvider(widget.farmId));
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
        onAction: _retry,
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
        cards: value.map(_toCardViewData).toList(growable: false),
        onRefresh: _refresh,
      ),
    };
  }

  BreakEvenCardViewData _toCardViewData(BreakEvenPoint point) {
    final l10n = context.l10n;
    final breakEvenValue =
        point.breakEvenPrice?.formatCurrency(l10n) ?? l10n.notAvailableLabel;
    final end = point.endedAt?.formatShortDate(l10n) ?? l10n.ongoingLabel;
    return BreakEvenCardViewData(
      mixtureId: point.mixtureId,
      groupName: point.groupName,
      period: l10n.financeDateRange(point.startedAt.formatShortDate(l10n), end),
      breakEvenLabel: l10n.breakEvenPriceLabel,
      breakEvenValue: breakEvenValue,
      breakEvenSupportingText: point.breakEvenPrice == null
          ? l10n.breakEvenUnavailableReason
          : null,
      goodEggsLabel: l10n.goodEggsLabel,
      goodEggsValue: point.goodEggs.formatInteger(l10n),
      brokenEggsLabel: l10n.brokenEggsLabel,
      brokenEggsValue: point.brokenEggs.formatInteger(l10n),
      foodCostLabel: l10n.foodCostLabel,
      foodCostValue: point.totalFoodCost.formatCurrency(l10n),
      semanticsLabel: l10n.breakEvenCardSemantics(
        point.groupName,
        breakEvenValue,
      ),
    );
  }

  void _retry() {
    ref.invalidate(breakEvenPointsProvider(widget.farmId));
  }

  Future<void> _refresh() async {
    ref.invalidate(breakEvenPointsProvider(widget.farmId));
    await ref.read(breakEvenPointsProvider(widget.farmId).future);
  }
}
