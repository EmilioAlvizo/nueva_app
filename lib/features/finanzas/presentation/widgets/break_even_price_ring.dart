import 'package:flutter/material.dart';

import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/finance_theme.dart';

class BreakEvenPriceRing extends StatelessWidget {
  const BreakEvenPriceRing({
    required this.mixtureId,
    required this.label,
    required this.value,
    required this.marginRole,
    super.key,
  });

  final String mixtureId;
  final String label;
  final String value;
  final FinanceMarginRole marginRole;

  @override
  Widget build(BuildContext context) {
    final financeTheme = FinanceTheme.of(context);
    final palette = financeTheme.marginPalette(marginRole);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final dimension =
        AppSizes.financePriceRing + (textScale - 1).clamp(0, 1) * AppSpacing.xl;
    final contentDimension = dimension - AppSpacing.sm * 2;

    return SizedBox.square(
      dimension: dimension,
      child: DecoratedBox(
        key: ValueKey(AppWidgetKeys.financeBreakEvenPriceIndicator(mixtureId)),
        decoration: BoxDecoration(
          color: financeTheme.neutralMetricSurface,
          shape: BoxShape.circle,
          border: Border.all(
            color: palette.accent,
            width: AppSizes.financePriceRingStroke,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: contentDimension,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: financeTheme.onCard,
                      fontSize: AppSizes.financeRingValueFont,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: financeTheme.onCardMuted,
                      fontSize: AppSizes.financeRingLabelFont,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
