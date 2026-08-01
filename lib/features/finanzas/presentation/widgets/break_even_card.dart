import 'package:flutter/material.dart';

import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/finance_theme.dart';
import 'break_even_price_ring.dart';
import 'finance_margin_chip.dart';
import 'finance_metric_tile.dart';

export 'finance_metric_tile.dart' show FinanceMetricRole, FinanceMetricViewData;

final class BreakEvenCardViewData {
  const BreakEvenCardViewData({
    required this.mixtureId,
    required this.groupName,
    required this.description,
    required this.priceLabel,
    required this.priceValue,
    required this.marginLabel,
    required this.marginRole,
    required this.primaryMetrics,
    required this.secondaryMetricsText,
    required this.durationValue,
    required this.periodValue,
    required this.semanticsLabel,
  });

  final String mixtureId;
  final String groupName;
  final String description;
  final String priceLabel;
  final String priceValue;
  final String marginLabel;
  final FinanceMarginRole marginRole;
  final List<FinanceMetricViewData> primaryMetrics;
  final String secondaryMetricsText;
  final String durationValue;
  final String periodValue;
  final String semanticsLabel;
}

class BreakEvenCard extends StatelessWidget {
  const BreakEvenCard({required this.data, super.key});

  final BreakEvenCardViewData data;

  @override
  Widget build(BuildContext context) {
    final financeTheme = FinanceTheme.of(context);
    return Semantics(
      key: ValueKey(AppWidgetKeys.financeBreakEvenCard(data.mixtureId)),
      container: true,
      label: data.semanticsLabel,
      child: Card.filled(
        color: financeTheme.breakEvenCardSurface(data.marginRole),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.financeCardRadius),
        ),
        child: Stack(
          children: [
            FinanceCardDecoration(
              mixtureId: data.mixtureId,
              marginRole: data.marginRole,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      BreakEvenHero(data: data),
                      const SizedBox(height: AppSpacing.md),
                      FinancePrimaryMetrics(
                        mixtureId: data.mixtureId,
                        metrics: data.primaryMetrics,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FinanceCompactMetricText(text: data.secondaryMetricsText),
                    ],
                  ),
                ),
                FinancePeriodStrip(data: data),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BreakEvenHero extends StatelessWidget {
  const BreakEvenHero({required this.data, super.key});

  final BreakEvenCardViewData data;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < AppSizes.financeHeaderBreakpoint ||
            textScale > 1.2;
        final ring = BreakEvenPriceRing(
          mixtureId: data.mixtureId,
          label: data.priceLabel,
          value: data.priceValue,
          marginRole: data.marginRole,
        );
        final details = BreakEvenHeroDetails(data: data);

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: ring),
              const SizedBox(height: AppSpacing.sm),
              details,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ring,
            const SizedBox(width: AppSpacing.md),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}

class BreakEvenHeroDetails extends StatelessWidget {
  const BreakEvenHeroDetails({required this.data, super.key});

  final BreakEvenCardViewData data;

  @override
  Widget build(BuildContext context) {
    final financeTheme = FinanceTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.groupName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: financeTheme.onCard,
            fontSize: AppSizes.financeTitleFont,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          data.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: financeTheme.onCardMuted,
            fontSize: AppSizes.financeSubtitleFont,
            height: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        FinanceMarginChip(
          mixtureId: data.mixtureId,
          label: data.marginLabel,
          role: data.marginRole,
        ),
      ],
    );
  }
}

class FinancePeriodStrip extends StatelessWidget {
  const FinancePeriodStrip({required this.data, super.key});

  final BreakEvenCardViewData data;

  @override
  Widget build(BuildContext context) {
    final financeTheme = FinanceTheme.of(context);
    return DecoratedBox(
      key: ValueKey(AppWidgetKeys.financeBreakEvenPeriod(data.mixtureId)),
      decoration: BoxDecoration(
        color: financeTheme.periodSurface,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppSizes.financeCardRadius),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSizes.financePeriodMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.financePeriodVertical,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${data.periodValue} · ${data.durationValue}',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: financeTheme.onPeriodSurface,
                fontSize: AppSizes.financePeriodFont,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FinanceCardDecoration extends StatelessWidget {
  const FinanceCardDecoration({
    required this.mixtureId,
    required this.marginRole,
    super.key,
  });

  final String mixtureId;
  final FinanceMarginRole marginRole;

  @override
  Widget build(BuildContext context) {
    final financeTheme = FinanceTheme.of(context);
    return Positioned(
      right: -AppSizes.financeDecorationLarge / 2,
      top: -AppSizes.financeDecorationLarge / 2,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: SizedBox.square(
            dimension: AppSizes.financeDecorationLarge,
            child: DecoratedBox(
              key: ValueKey(
                AppWidgetKeys.financeBreakEvenDecoration(mixtureId),
              ),
              decoration: BoxDecoration(
                color: financeTheme.breakEvenDecoration(marginRole),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
