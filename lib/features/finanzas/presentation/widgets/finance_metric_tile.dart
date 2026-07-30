import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/finance_theme.dart';

final class FinanceMetricViewData {
  const FinanceMetricViewData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class FinanceMetricTile extends StatelessWidget {
  const FinanceMetricTile({required this.metric, super.key});

  final FinanceMetricViewData metric;

  @override
  Widget build(BuildContext context) {
    final financeTheme = FinanceTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: financeTheme.metricSurface,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                metric.icon,
                color: financeTheme.onCardMuted,
                size: AppSizes.smallIcon,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              metric.value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: financeTheme.onCard,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              metric.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: financeTheme.onCardMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FinancePrimaryMetrics extends StatelessWidget {
  const FinancePrimaryMetrics({required this.metrics, super.key});

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
                child: FinanceMetricTile(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class FinanceOperationalMetric extends StatelessWidget {
  const FinanceOperationalMetric({required this.metric, super.key});

  final FinanceMetricViewData metric;

  @override
  Widget build(BuildContext context) {
    final financeTheme = FinanceTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              metric.icon,
              color: financeTheme.onCardMuted,
              size: AppSizes.smallIcon,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              metric.label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: financeTheme.onCardMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              metric.value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: financeTheme.onCard,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
