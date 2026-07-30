import 'package:flutter/material.dart';

import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';

enum FinanceTab { balance, income, expenses, charts }

final class FinanceTabItem {
  const FinanceTabItem({
    required this.tab,
    required this.label,
    required this.asset,
    required this.keyValue,
  });

  final FinanceTab tab;
  final String label;
  final String asset;
  final String keyValue;
}

class FinanceTabBar extends StatelessWidget {
  const FinanceTabBar({
    required this.items,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<FinanceTabItem> items;
  final FinanceTab selected;
  final ValueChanged<FinanceTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      key: const ValueKey(AppWidgetKeys.financeTabs),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: Row(
            children: [
              for (final item in items) ...[
                FinanceTabButton(
                  item: item,
                  selected: selected == item.tab,
                  onPressed: () => onSelected(item.tab),
                ),
                if (item != items.last) const SizedBox(width: AppSpacing.xxs),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FinanceTabButton extends StatelessWidget {
  const FinanceTabButton({
    required this.item,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final FinanceTabItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      foregroundColor: WidgetStatePropertyAll(foreground),
      backgroundColor: WidgetStatePropertyAll(
        selected ? colors.primaryContainer : Colors.transparent,
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
      ),
    );
    final asset = selected && item.tab == FinanceTab.charts
        ? 'assets/chart_filled.png'
        : item.asset;

    return Semantics(
      button: true,
      selected: selected,
      child: TextButton.icon(
        key: ValueKey(item.keyValue),
        onPressed: onPressed,
        style: style,
        icon: Image.asset(
          asset,
          width: AppSizes.smallIcon,
          height: AppSizes.smallIcon,
          color: foreground,
          excludeFromSemantics: true,
        ),
        label: Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
