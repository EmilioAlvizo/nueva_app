import 'package:flutter/material.dart';

import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';

final class BreakEvenCardViewData {
  const BreakEvenCardViewData({
    required this.mixtureId,
    required this.groupName,
    required this.period,
    required this.breakEvenLabel,
    required this.breakEvenValue,
    required this.breakEvenSupportingText,
    required this.goodEggsLabel,
    required this.goodEggsValue,
    required this.brokenEggsLabel,
    required this.brokenEggsValue,
    required this.foodCostLabel,
    required this.foodCostValue,
    required this.semanticsLabel,
  });

  final String mixtureId;
  final String groupName;
  final String period;
  final String breakEvenLabel;
  final String breakEvenValue;
  final String? breakEvenSupportingText;
  final String goodEggsLabel;
  final String goodEggsValue;
  final String brokenEggsLabel;
  final String brokenEggsValue;
  final String foodCostLabel;
  final String foodCostValue;
  final String semanticsLabel;
}

class BreakEvenCard extends StatelessWidget {
  const BreakEvenCard({required this.data, super.key});

  final BreakEvenCardViewData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: data.semanticsLabel,
      child: Card.filled(
        key: ValueKey(AppWidgetKeys.financeBreakEvenCard(data.mixtureId)),
        color: colors.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: AppSizes.cardIcon,
                    height: AppSizes.cardIcon,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.tertiaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: Image.asset(
                      'assets/goal.png',
                      color: colors.onTertiaryContainer,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.groupName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          data.period,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.breakEvenLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      data.breakEvenValue,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (data.breakEvenSupportingText
                        case final supporting?) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        supporting,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FinanceMetricRow(
                icon: Icons.egg_alt_outlined,
                label: data.goodEggsLabel,
                value: data.goodEggsValue,
              ),
              FinanceMetricRow(
                icon: Icons.egg_outlined,
                label: data.brokenEggsLabel,
                value: data.brokenEggsValue,
              ),
              FinanceMetricRow(
                icon: Icons.grass_outlined,
                label: data.foodCostLabel,
                value: data.foodCostValue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FinanceMetricRow extends StatelessWidget {
  const FinanceMetricRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant);
    final valueStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800);
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: AppSizes.smallIcon,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            if (constraints.maxWidth < AppSizes.compactMetricBreakpoint)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: labelStyle),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(value, style: valueStyle),
                  ],
                ),
              )
            else ...[
              Expanded(child: Text(label, style: labelStyle)),
              const SizedBox(width: AppSpacing.xs),
              Text(value, style: valueStyle),
            ],
          ],
        ),
      ),
    );
  }
}
