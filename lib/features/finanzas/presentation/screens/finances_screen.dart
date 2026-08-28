import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/localization_extension.dart';
import '../../../../core/extensions/primitive_formatting_extensions.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/finance_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ciclos/presentation/screens/finance_cycles_section.dart';
import '../../domain/entities/break_even_point.dart';
import '../providers/finances_providers.dart';
import '../widgets/break_even_card.dart';
import '../widgets/break_even_content.dart';
import '../widgets/finance_states.dart';
import '../widgets/finance_tab_bar.dart';

class FinancesScreen extends ConsumerStatefulWidget {
  const FinancesScreen({
    required this.farmId,
    this.initialTab = FinanceTab.balance,
    super.key,
  });

  final String farmId;
  final FinanceTab initialTab;

  @override
  ConsumerState<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends ConsumerState<FinancesScreen> {
  late final PageController _pageController;
  late FinanceTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _pageController = PageController(initialPage: widget.initialTab.index);
  }

  @override
  void didUpdateWidget(covariant FinancesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab == widget.initialTab ||
        _selectedTab == widget.initialTab) {
      return;
    }
    _selectedTab = widget.initialTab;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(widget.initialTab.index);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finance = FinanceTheme.of(context);
    final usesCyclePalette = _selectedTab == FinanceTab.cycles;
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
      FinanceTabItem(
        tab: FinanceTab.cycles,
        role: FinanceTabRole.cycles,
        label: l10n.financeTabCycles,
        asset: 'assets/chicken.png',
        keyValue: AppWidgetKeys.financeCyclesTab,
      ),
    ];
    final pages = [
      FinanceBalanceSection(farmId: widget.farmId),
      FinanceMessageState(
        key: const ValueKey(AppWidgetKeys.financeIncomeUnavailable),
        title: l10n.financeIncomeUnavailableTitle,
        message: l10n.financeIncomeUnavailableMessage,
        note: l10n.financeNoFabricatedData,
        asset: 'assets/income.png',
      ),
      FinanceMessageState(
        key: const ValueKey(AppWidgetKeys.financeExpensesUnavailable),
        title: l10n.financeExpensesUnavailableTitle,
        message: l10n.financeExpensesUnavailableMessage,
        note: l10n.financeNoFabricatedData,
        asset: 'assets/outcome.png',
      ),
      FinanceMessageState(
        key: const ValueKey(AppWidgetKeys.financeChartsUnavailable),
        title: l10n.financeChartsUnavailableTitle,
        message: l10n.financeChartsUnavailableMessage,
        note: l10n.financeNoFabricatedData,
        asset: 'assets/chart_filled.png',
      ),
      FinanceCyclesSection(farmId: widget.farmId),
    ];

    return Scaffold(
      backgroundColor: usesCyclePalette ? finance.cycleCanvas : null,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.financesTitle,
                  key: const ValueKey(AppWidgetKeys.financeHeader),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: usesCyclePalette
                        ? finance.cycleOnSurface
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            FinanceTabBar(
              items: items,
              selected: _selectedTab,
              onSelected: _selectTab,
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: PageView(
                key: const ValueKey(AppWidgetKeys.financePages),
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: pages,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectTab(FinanceTab tab) {
    if (_pageController.hasClients) {
      unawaited(
        _pageController.animateToPage(
          tab.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }

    if (_selectedTab == tab) return;
    setState(() => _selectedTab = tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients || _selectedTab != tab) {
        return;
      }
      _pageController.jumpToPage(tab.index);
    });
  }

  void _onPageChanged(int index) {
    final tab = FinanceTab.values[index];
    if (_selectedTab == tab) return;
    setState(() => _selectedTab = tab);
  }
}

class FinanceBalanceSection extends ConsumerWidget {
  const FinanceBalanceSection({required this.farmId, super.key});

  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final points = ref.watch(breakEvenPointsProvider(farmId));
    final content = switch (points) {
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
    return content;
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
    final secondaryMetricsText = l10n.financeCompactMetrics(
      point.weightedAverageBirds.formatFixedTwoDecimals(l10n),
      _formatPerBirdMetric(point.eggsPerDayPerBird, l10n),
      _formatPerBirdMetric(point.feedPerDayPerBird, l10n),
    );

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
          role: FinanceMetricRole.cost,
          label: l10n.totalCostLabel,
          value: point.totalFoodCost.formatCurrency(l10n),
          icon: Icons.payments_outlined,
        ),
        FinanceMetricViewData(
          role: FinanceMetricRole.eggs,
          label: l10n.goodEggsLabel,
          value: point.goodEggs.formatInteger(l10n),
          icon: Icons.egg_alt_outlined,
        ),
        FinanceMetricViewData(
          role: FinanceMetricRole.consumption,
          label: l10n.totalFeedConsumptionLabel,
          value: l10n.financeKilograms(
            point.totalFeedConsumption.formatDecimal(l10n),
          ),
          icon: Icons.grass_outlined,
        ),
      ],
      secondaryMetricsText: secondaryMetricsText,
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

  static String _formatPerBirdMetric(double? value, AppLocalizations l10n) =>
      switch (value) {
        final value? => value.formatFixedTwoDecimals(l10n),
        null => '-',
      };
}
