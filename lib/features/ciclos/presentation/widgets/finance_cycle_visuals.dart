import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/finance_theme.dart';

enum FinanceCycleActionVariant { primary, secondary, destructive }

enum FinanceCyclePanelVariant { info, warning, result }

class FinanceCycleCanvas extends StatelessWidget {
  const FinanceCycleCanvas({
    required this.child,
    this.maxWidth = AppSizes.financeCycleContentMaxWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return ColoredBox(
      color: finance.cycleCanvas,
      child: Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

class FinanceCycleSectionHeader extends StatelessWidget {
  const FinanceCycleSectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  color: finance.cycleOnSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: finance.cycleOnSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
        if (trailing case final trailing?) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing,
        ],
      ],
    );
  }
}

class FinanceCycleSurfaceCard extends StatelessWidget {
  const FinanceCycleSurfaceCard({
    required this.child,
    this.elevated = false,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  });

  final Widget child;
  final bool elevated;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return Material(
      color: elevated ? finance.cycleSurfaceElevated : finance.cycleSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(color: finance.cycleOutline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class FinanceCycleMetricTile extends StatelessWidget {
  const FinanceCycleMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: finance.cycleSurfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: AppSizes.smallIcon,
              color: finance.cyclePrimaryAction,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: textTheme.titleMedium?.copyWith(
                color: finance.cycleOnSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: finance.cycleOnSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FinanceCycleMetricGroup extends StatelessWidget {
  const FinanceCycleMetricGroup({
    required this.metrics,
    this.expandedColumns = 2,
    super.key,
  });

  final List<Widget> metrics;
  final int expandedColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= AppSizes.financeCycleMetricBreakpoint
          ? expandedColumns
          : 1;
      final gaps = AppSpacing.xs * (columns - 1);
      final itemWidth = (constraints.maxWidth - gaps) / columns;
      return Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final metric in metrics)
            SizedBox(width: itemWidth, child: metric),
        ],
      );
    },
  );
}

class FinanceCycleContentSection extends StatelessWidget {
  const FinanceCycleContentSection({
    required this.title,
    required this.children,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    return FinanceCycleSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              color: finance.cycleOnSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle case final subtitle?) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: finance.cycleOnSurfaceMuted,
              ),
            ),
          ],
          if (children.isNotEmpty) const SizedBox(height: AppSpacing.sm),
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.xs),
            child,
          ],
        ],
      ),
    );
  }
}

class FinanceCycleRecordTile extends StatelessWidget {
  const FinanceCycleRecordTile({
    required this.icon,
    required this.title,
    this.details = const [],
    this.value,
    this.badge,
    super.key,
  });

  final IconData icon;
  final String title;
  final List<String> details;
  final String? value;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: finance.cycleSurfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: finance.cycleInputSurface,
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: SizedBox.square(
                    dimension: AppSizes.minTapTarget,
                    child: Icon(icon, color: finance.cyclePrimaryAction),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          color: finance.cycleOnSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (value case final value?) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          value,
                          style: textTheme.titleSmall?.copyWith(
                            color: finance.cyclePrimaryAction,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      for (final detail in details) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          detail,
                          style: textTheme.bodySmall?.copyWith(
                            color: finance.cycleOnSurfaceMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (badge case final badge?) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(alignment: AlignmentDirectional.centerStart, child: badge),
            ],
          ],
        ),
      ),
    );
  }
}

class FinanceCycleStatusPill extends StatelessWidget {
  const FinanceCycleStatusPill({
    required this.label,
    required this.isActive,
    this.keyValue,
    super.key,
  });

  final String label;
  final bool isActive;
  final String? keyValue;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    final background = isActive
        ? finance.cycleAbierto
        : finance.cycleSurfaceElevated;
    final foreground = isActive
        ? finance.cycleOnAbierto
        : finance.cycleOnSurfaceMuted;
    return DecoratedBox(
      key: keyValue == null ? null : ValueKey(keyValue),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class FinanceCycleNavigationRow extends StatelessWidget {
  const FinanceCycleNavigationRow({
    required this.keyValue,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.value,
    super.key,
  });

  final String keyValue;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final enabled = onPressed != null;
    final foreground = enabled
        ? finance.cycleOnSurface
        : finance.cycleOnSurfaceMuted;
    return Material(
      key: ValueKey(keyValue),
      color: finance.cycleSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(color: finance.cycleOutline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: finance.cycleInputSurface,
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: SizedBox.square(
                    dimension: AppSizes.minTapTarget,
                    child: Icon(
                      icon,
                      color: enabled
                          ? finance.cyclePrimaryAction
                          : finance.cycleOnSurfaceMuted,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: finance.cycleOnSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (value case final value?) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: finance.cycleInputSurface,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          value,
                          textAlign: TextAlign.center,
                          style: textTheme.labelMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  color: finance.cycleOnSurfaceMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FinanceCycleFieldSurface extends StatelessWidget {
  const FinanceCycleFieldSurface({
    required this.keyValue,
    required this.label,
    required this.value,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String keyValue;
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Material(
      key: ValueKey(keyValue),
      color: finance.cycleInputSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(color: finance.cycleOutline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(icon, color: finance.cyclePrimaryAction),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: textTheme.labelMedium?.copyWith(
                          color: finance.cycleOnSurfaceMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        value,
                        style: textTheme.bodyLarge?.copyWith(
                          color: finance.cycleOnSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: finance.cycleOnSurfaceMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FinanceCycleDropdownSurface<T> extends StatelessWidget {
  const FinanceCycleDropdownSurface({
    required this.keyValue,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final String keyValue;
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return Material(
      key: ValueKey(keyValue),
      color: finance.cycleInputSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(color: finance.cycleOutline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              hint: Text(label),
              dropdownColor: finance.cycleSurfaceElevated,
              iconEnabledColor: finance.cyclePrimaryAction,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: finance.cycleOnSurface,
                fontWeight: FontWeight.w700,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class FinanceCycleActionButton extends StatelessWidget {
  const FinanceCycleActionButton({
    required this.keyValue,
    required this.label,
    required this.variant,
    required this.onPressed,
    this.icon,
    this.semanticLabel,
    this.child,
    super.key,
  });

  final String keyValue;
  final String label;
  final FinanceCycleActionVariant variant;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? semanticLabel;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    final (background, foreground) = switch (variant) {
      FinanceCycleActionVariant.primary => (
        finance.cyclePrimaryAction,
        finance.cycleOnPrimaryAction,
      ),
      FinanceCycleActionVariant.secondary => (
        finance.cycleSurfaceElevated,
        finance.cycleOnSurface,
      ),
      FinanceCycleActionVariant.destructive => (
        finance.cycleDestructiveAction,
        finance.cycleOnDestructiveAction,
      ),
    };
    final content =
        child ??
        (icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(child: Text(label)),
                ],
              ));
    return Semantics(
      key: ValueKey(keyValue),
      container: true,
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: finance.cycleInputSurface,
            disabledForegroundColor: finance.cycleOnSurfaceMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
          ),
          onPressed: onPressed,
          child: content,
        ),
      ),
    );
  }
}

class FinanceCyclePanel extends StatelessWidget {
  const FinanceCyclePanel({
    required this.message,
    required this.variant,
    super.key,
  });

  final String message;
  final FinanceCyclePanelVariant variant;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    final accent = switch (variant) {
      FinanceCyclePanelVariant.info => finance.cyclePositiveAction,
      FinanceCyclePanelVariant.warning => finance.cycleDestructiveAction,
      FinanceCyclePanelVariant.result => finance.cyclePrimaryAction,
    };
    final icon = switch (variant) {
      FinanceCyclePanelVariant.info => Icons.info_outline_rounded,
      FinanceCyclePanelVariant.warning => Icons.warning_amber_rounded,
      FinanceCyclePanelVariant.result => Icons.insights_rounded,
    };
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: finance.cycleAbierto,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          //border: Border.all(color: accent),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: finance.cycleOnSurface,
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
