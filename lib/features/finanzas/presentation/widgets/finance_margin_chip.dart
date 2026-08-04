import 'package:flutter/material.dart';

import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/finance_theme.dart';

class FinanceMarginChip extends StatelessWidget {
  const FinanceMarginChip({
    required this.mixtureId,
    required this.label,
    required this.role,
    super.key,
  });

  final String mixtureId;
  final String label;
  final FinanceMarginRole role;

  @override
  Widget build(BuildContext context) {
    final palette = FinanceTheme.of(context).marginPalette(role);

    return DecoratedBox(
      key: ValueKey(AppWidgetKeys.financeMarginChip(mixtureId)),
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.financeChipHorizontal,
          vertical: AppSpacing.financeChipVertical,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: palette.onAccent,
            fontSize: AppSizes.financeMarginFont,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}
