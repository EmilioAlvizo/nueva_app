import 'package:flutter/material.dart';

import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/finance_theme.dart';
import 'break_even_price_ring.dart';
import 'finance_margin_chip.dart';
import 'finance_metric_tile.dart';

export 'finance_metric_tile.dart' show FinanceMetricViewData;

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
    required this.durationLabel,
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
  final String durationLabel;
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
        color: financeTheme.cardSurface,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
        child: Stack(
          children: [
            const FinanceCardDecoration(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BreakEvenHero(data: data),
                  const SizedBox(height: AppSpacing.md),
                  FinancePrimaryMetrics(metrics: data.primaryMetrics),
                  const SizedBox(height: AppSpacing.md),
                  FinanceCompactMetricText(text: data.secondaryMetricsText),
                  const SizedBox(height: AppSpacing.sm),
                  FinancePeriodStrip(data: data),
                ],
              ),
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
              const SizedBox(height: AppSpacing.md),
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
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: financeTheme.onCard,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          data.description,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: financeTheme.onCardMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
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
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: financeTheme.onCardMuted,
      fontWeight: FontWeight.w700,
    );
    final valueStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: financeTheme.onCard,
      fontWeight: FontWeight.w900,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: financeTheme.dateStrip,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.durationLabel, style: labelStyle),
                const SizedBox(height: AppSpacing.xxs),
                Text(data.durationValue, style: valueStyle),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.calendar_month_outlined,
                    color: financeTheme.onCardMuted,
                    size: AppSizes.smallIcon,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(child: Text(data.periodValue, style: valueStyle)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FinanceCardDecoration extends StatelessWidget {
  const FinanceCardDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    final financeTheme = FinanceTheme.of(context);
    return Positioned.fill(
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                right: -AppSizes.financeDecorationSmall / 2,
                top: -AppSizes.financeDecorationSmall / 2,
                child: Container(
                  width: AppSizes.financeDecorationLarge,
                  height: AppSizes.financeDecorationLarge,
                  decoration: BoxDecoration(
                    color: financeTheme.decoration.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -AppSizes.financeDecorationSmall / 2,
                bottom: -AppSizes.financeDecorationSmall / 2,
                child: Container(
                  width: AppSizes.financeDecorationSmall,
                  height: AppSizes.financeDecorationSmall,
                  decoration: BoxDecoration(
                    color: financeTheme.decoration.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
