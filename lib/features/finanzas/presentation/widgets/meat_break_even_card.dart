import 'package:flutter/material.dart';

import '../../../../core/extensions/primitive_formatting_extensions.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/finance_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ciclos/domain/economics_v2_models.dart';

final class MeatBreakEvenCardViewData {
  const MeatBreakEvenCardViewData({
    required this.cycleId,
    required this.title,
    required this.subtitle,
    required this.breakEvenLabel,
    required this.resultValue,
    required this.resultUnit,
    required this.totalCostValue,
    required this.totalCostsLabel,
    required this.feedLabel,
    required this.feedValue,
    required this.extrasLabel,
    required this.extrasValue,
    required this.revenueValue,
    required this.revenueLabel,
    required this.metricsText,
    required this.footerText,
    required this.semanticsLabel,
  });

  final String cycleId;
  final String title;
  final String subtitle;
  final String breakEvenLabel;
  final String resultValue;
  final String resultUnit;
  final String totalCostValue;
  final String totalCostsLabel;
  final String feedLabel;
  final String feedValue;
  final String extrasLabel;
  final String extrasValue;
  final String revenueValue;
  final String revenueLabel;
  final String metricsText;
  final String footerText;
  final String semanticsLabel;
}

abstract final class MeatBreakEvenCardDataMapper {
  static MeatBreakEvenCardViewData map({
    required EconomicsV2CycleSummary summary,
    required EconomicsV2MeatCycleMetrics metrics,
    required DateTime today,
    required AppLocalizations l10n,
  }) {
    final groupName = summary.latestLinkedGroupName?.trim();
    final title = l10n.financeMeatBreakEvenTitle(
      groupName == null || groupName.isEmpty
          ? l10n.financeCycleAnimalsWithoutGroup
          : groupName,
    );
    final resultValue = switch (metrics.balancePerAnimal) {
      final value? => value.formatCompactCurrency(l10n),
      null => l10n.financeMeatBreakEvenUnavailable,
    };
    final totalCostValue = metrics.totalCost.formatCompactCurrency(l10n);
    final revenueValue = metrics.animalSaleRevenue.formatCompactCurrency(l10n);
    final metricsText = l10n.financeMeatBreakEvenMetrics(
      metrics.animalCount,
      metrics.saleCount,
      metrics.feedKgTotal.formatDecimal(l10n),
    );
    final end = summary.meatDisplayEndOn(today);
    final footerText = l10n.financeMeatBreakEvenPeriod(
      summary.startsOn.formatShortDate(l10n),
      end.formatShortDate(l10n),
      summary.meatDisplayDayCount(today),
    );

    return MeatBreakEvenCardViewData(
      cycleId: summary.cycleId,
      title: title,
      subtitle: l10n.financeMeatBreakEvenSubtitle,
      breakEvenLabel: l10n.financeMeatBreakEvenLabel,
      resultValue: resultValue,
      resultUnit: l10n.financeMeatBreakEvenPerAnimal,
      totalCostValue: totalCostValue,
      totalCostsLabel: l10n.financeMeatBreakEvenTotalCosts,
      feedLabel: l10n.financeMeatBreakEvenFeed,
      feedValue: metrics.feedCost.formatCompactCurrency(l10n),
      extrasLabel: l10n.financeMeatBreakEvenExtras,
      extrasValue: (summary.directExpenseTotal + metrics.acquisitionCost)
          .formatCompactCurrency(l10n),
      revenueValue: revenueValue,
      revenueLabel: l10n.financeMeatBreakEvenRevenue,
      metricsText: metricsText,
      footerText: footerText,
      semanticsLabel: l10n.financeMeatBreakEvenSemantics(
        title,
        resultValue,
        totalCostValue,
        revenueValue,
        metricsText,
        footerText,
      ),
    );
  }
}

class MeatBreakEvenCard extends StatelessWidget {
  const MeatBreakEvenCard({required this.data, super.key});

  final MeatBreakEvenCardViewData data;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return Semantics(
      key: ValueKey(AppWidgetKeys.financeMeatBreakEvenCard(data.cycleId)),
      container: true,
      label: data.semanticsLabel,
      child: Card.filled(
        color: finance.cycleSurface,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.financeCardRadius),
        ),
        child: Stack(
          children: [
            MeatBreakEvenDecoration(cycleId: data.cycleId),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MeatBreakEvenHero(data: data),
                      const SizedBox(height: AppSpacing.lg),
                      MeatBreakEvenEconomicPanels(data: data),
                      const SizedBox(height: AppSpacing.md),
                      MeatBreakEvenMetricBand(data: data),
                    ],
                  ),
                ),
                MeatBreakEvenFooter(data: data),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MeatBreakEvenHero extends StatelessWidget {
  const MeatBreakEvenHero({required this.data, super.key});

  final MeatBreakEvenCardViewData data;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth <
            AppSizes.financeMeatCardBreakpoint * textScale;
        final ring = MeatBreakEvenRing(data: data);
        final header = MeatBreakEvenHeader(data: data);
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ring,
              const SizedBox(height: AppSpacing.md),
              header,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ring,
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: header),
          ],
        );
      },
    );
  }
}

class MeatBreakEvenRing extends StatelessWidget {
  const MeatBreakEvenRing({required this.data, super.key});

  final MeatBreakEvenCardViewData data;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final dimension = textScale > 1
        ? AppSizes.financeMeatRingMaxExtent
        : AppSizes.financeMeatRingMinExtent;
    return SizedBox.square(
      dimension: dimension,
      child: DecoratedBox(
        key: ValueKey(AppWidgetKeys.financeMeatBreakEvenRing(data.cycleId)),
        decoration: BoxDecoration(
          color: finance.cycleSurface,
          shape: BoxShape.circle,
          border: Border.all(
            color: finance.cyclePositiveAction,
            width: AppSizes.financeMeatRingStroke,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.resultValue,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: finance.cycleOnSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  data.resultUnit,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: finance.cycleOnSurfaceMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MeatBreakEvenHeader extends StatelessWidget {
  const MeatBreakEvenHeader({required this.data, super.key});

  final MeatBreakEvenCardViewData data;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: finance.cycleOnSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          data.subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: finance.cycleOnSurfaceMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        DecoratedBox(
          key: ValueKey(AppWidgetKeys.financeMeatBreakEvenChip(data.cycleId)),
          decoration: BoxDecoration(
            color: finance.cyclePositiveAction,
            borderRadius: BorderRadius.circular(AppRadii.full),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              data.breakEvenLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: finance.cycleOnPositiveAction,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MeatBreakEvenEconomicPanels extends StatelessWidget {
  const MeatBreakEvenEconomicPanels({required this.data, super.key});

  final MeatBreakEvenCardViewData data;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth <
            AppSizes.financeMeatCardBreakpoint * textScale;
        final costs = MeatBreakEvenCostsPanel(data: data);
        final revenue = MeatBreakEvenRevenuePanel(data: data);
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              costs,
              const SizedBox(height: AppSpacing.sm),
              revenue,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: costs),
            const SizedBox(width: AppSpacing.sm),
            Expanded(flex: 2, child: revenue),
          ],
        );
      },
    );
  }
}

class MeatBreakEvenCostsPanel extends StatelessWidget {
  const MeatBreakEvenCostsPanel({required this.data, super.key});

  final MeatBreakEvenCardViewData data;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppSizes.financeMeatPanelMinHeight,
      ),
      child: DecoratedBox(
        key: ValueKey(AppWidgetKeys.financeMeatBreakEvenCosts(data.cycleId)),
        decoration: BoxDecoration(
          color: finance.cycleSurfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        data.totalCostValue,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: finance.cycleOnSurface,
                              fontWeight: FontWeight.w900,
                              fontSize: AppSizes.financeMetricValueFont,
                            ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      data.totalCostsLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: finance.cycleOnSurfaceMuted,
                        fontSize: AppSizes.financeMetricLabelFont,
                      ),
                    ),
                  ],
                ),
                VerticalDivider(
                  width: AppSpacing.lg,
                  color: finance.cycleOnSurfaceMuted,
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MeatBreakEvenCostLine(
                        color: finance.cyclePositiveAction,
                        label: data.feedLabel,
                        value: data.feedValue,
                      ),
                      //const SizedBox(height: AppSpacing.xs),
                      MeatBreakEvenCostLine(
                        color: finance.cyclePrimaryAction,
                        label: data.extrasLabel,
                        value: data.extrasValue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MeatBreakEvenCostLine extends StatelessWidget {
  const MeatBreakEvenCostLine({
    required this.color,
    required this.label,
    required this.value,
    super.key,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final label = Text(
      this.label,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: finance.cycleOnSurfaceMuted,
      fontSize: AppSizes.financeMetricLabelFont,),
      
    );
    final value = Text(
      this.value,
      textAlign: TextAlign.end,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: finance.cycleOnSurface,
        fontWeight: FontWeight.w800,
        fontSize: AppSizes.financeMetricValueFont,
      ),
    );
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: SizedBox.square(
            dimension: AppSpacing.xs,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: textScale > 1.5
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label,
                    const SizedBox(height: AppSpacing.xxs),
                    value,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: label),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(child: value),
                  ],
                ),
        ),
      ],
    );
  }
}

class MeatBreakEvenRevenuePanel extends StatelessWidget {
  const MeatBreakEvenRevenuePanel({required this.data, super.key});

  final MeatBreakEvenCardViewData data;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppSizes.financeMeatPanelMinHeight,
      ),
      child: DecoratedBox(
        key: ValueKey(AppWidgetKeys.financeMeatBreakEvenRevenue(data.cycleId)),
        decoration: BoxDecoration(
          color: finance.cyclePositiveAction,
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    data.revenueValue,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: finance.cycleOnPositiveAction,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  data.revenueLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: finance.cycleOnPositiveAction,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MeatBreakEvenMetricBand extends StatelessWidget {
  const MeatBreakEvenMetricBand({required this.data, super.key});

  final MeatBreakEvenCardViewData data;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return Text(
      data.metricsText,
      key: ValueKey(AppWidgetKeys.financeMeatBreakEvenMetrics(data.cycleId)),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: finance.cycleOnSurfaceMuted,
        fontWeight: FontWeight.w700,
        fontSize: AppSizes.financeCompactLineFont,
      ),
    );
  }
}

class MeatBreakEvenFooter extends StatelessWidget {
  const MeatBreakEvenFooter({required this.data, super.key});

  final MeatBreakEvenCardViewData data;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return DecoratedBox(
      key: ValueKey(AppWidgetKeys.financeMeatBreakEvenFooter(data.cycleId)),
      decoration: BoxDecoration(
        color: finance.periodSurface,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppSizes.financeCardRadius),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Text(
          data.footerText,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: finance.onPeriodSurface,
            fontWeight: FontWeight.w800,
            fontSize: AppSizes.financePeriodFont,
          ),
        ),
      ),
    );
  }
}

class MeatBreakEvenDecoration extends StatelessWidget {
  const MeatBreakEvenDecoration({required this.cycleId, super.key});

  final String cycleId;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return Positioned(
      top: -AppSizes.financeDecorationLarge / 2,
      right: -AppSizes.financeDecorationLarge / 2,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: SizedBox.square(
            dimension: AppSizes.financeDecorationLarge,
            child: DecoratedBox(
              key: ValueKey(
                AppWidgetKeys.financeMeatBreakEvenDecoration(cycleId),
              ),
              decoration: BoxDecoration(
                color: finance.cycleSurfaceElevated,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
