import 'package:flutter/material.dart';

import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/finance_theme.dart';

enum FinanceMetricRole { cost, eggs, consumption }

final class FinanceMetricViewData {
  const FinanceMetricViewData({
    required this.role,
    required this.label,
    required this.value,
    required this.icon,
  });

  final FinanceMetricRole role;
  final String label;
  final String value;
  final IconData icon;
}

class FinanceMetricTile extends StatelessWidget {
  const FinanceMetricTile({
    required this.mixtureId,
    required this.metric,
    super.key,
  });

  final String mixtureId;
  final FinanceMetricViewData metric;

  @override
  Widget build(BuildContext context) {
    final financeTheme = FinanceTheme.of(context);
    final (surface, foreground) = switch (metric.role) {
      FinanceMetricRole.cost || FinanceMetricRole.eggs => (
        financeTheme.neutralMetricSurface,
        financeTheme.onNeutralMetricSurface,
      ),
      FinanceMetricRole.consumption => (
        financeTheme.consumptionMetricSurface,
        financeTheme.onConsumptionMetricSurface,
      ),
    };

    return DecoratedBox(
      key: ValueKey(
        AppWidgetKeys.financeBreakEvenMetric(mixtureId, metric.role.name),
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSizes.financeMetricRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metric.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: foreground,
                fontSize: AppSizes.financeMetricValueFont,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontSize: AppSizes.financeMetricLabelFont,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FinancePrimaryMetrics extends StatelessWidget {
  const FinancePrimaryMetrics({
    required this.mixtureId,
    required this.metrics,
    super.key,
  });

  final String mixtureId;
  final List<FinanceMetricViewData> metrics;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumns =
            constraints.maxWidth >= AppSizes.financePrimaryMetricsBreakpoint &&
            textScale <= 1.2;
        final width = useColumns
            ? (constraints.maxWidth - AppSpacing.xs * (metrics.length - 1)) /
                  metrics.length
            : constraints.maxWidth;

        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: FinanceMetricTile(mixtureId: mixtureId, metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class FinanceCompactMetricText extends StatelessWidget {
  const FinanceCompactMetricText({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final financeTheme = FinanceTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: financeTheme.onCardMuted,
            fontSize: AppSizes.financeCompactLineFont,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
