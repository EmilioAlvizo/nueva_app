import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'huevo_models.dart';
import 'huevo_pie_chart.dart';
import '../../shared/widgets/metric_card.dart';
import '../../core/theme/app_colors.dart';

class EggSummaryView extends StatelessWidget {
  const EggSummaryView({super.key, required this.summary});

  final EggSummary summary;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    return ListView(
      key: const Key('egg-summary-view'),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 112),
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCard(
                //key: const Key('egg-metric-eggs'),
                label: 'Huevos',
                value: '${summary.goodEggs}',
                color: const Color(0xFFB8E6CF),
            foreground: const Color(0xFF14392A),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(
                //key: const Key('egg-metric-income'),
                label: 'Ingresos',
                value: currency.format(summary.income),
                color: AppColors.bgCard,
            foreground: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(
                //key: const Key('egg-metric-sold'),
                label: 'Vendidos',
                value: '${summary.soldEggs}',
                color: const Color(0xFF75422F),
            foreground: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _DestinationCard(summary: summary),
        const SizedBox(height: 14),
        _StatisticsCard(summary: summary, currency: currency),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ActivityCard(
                icon: Icons.inventory_2_outlined,
                label: 'Recolecciones',
                value: summary.collectionCount,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActivityCard(
                icon: Icons.receipt_long_outlined,
                label: 'Ventas',
                value: summary.saleCount,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/* class _MetricCard extends StatelessWidget {
  const _MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      height: 96,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: colors.secondary),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
 */

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.summary});

  final EggSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final chart = HuevoPieChart(
      consumption: summary.consumedEggs.toDouble(),
      sale: summary.soldEggs.toDouble(),
      broken: summary.brokenEggs.toDouble(),
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Legend(
          color: eggConsumptionColor,
          label: 'Consumo',
          value: summary.consumedEggs,
        ),
        const SizedBox(height: 11),
        _Legend(color: eggSaleColor, label: 'Venta', value: summary.soldEggs),
        const SizedBox(height: 11),
        _Legend(color: colors.error, label: 'Rotos', value: summary.brokenEggs),
      ],
    );
    return Container(
      key: const Key('egg-destination-card'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Destino de los Huevos',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Distribución de huevos recolectados y vendidos',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 320) {
                return Column(
                  children: [chart, const SizedBox(height: 8), legend],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Flexible(child: chart),
                  legend,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 58,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(
          '$value',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({required this.summary, required this.currency});

  final EggSummary summary;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Precio promedio de venta',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currency.format(summary.averageSalePrice),
                    key: const Key('egg-average-sale-price'),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _Statistic(
                          label: 'Buenos',
                          value: '${summary.goodEggs}',
                        ),
                      ),
                      Expanded(
                        child: _Statistic(
                          label: 'Rotos',
                          value: '${summary.brokenEggs}',
                        ),
                      ),
                      Expanded(
                        child: _Statistic(
                          label: 'Vendidos',
                          value: '${summary.soldEggs}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _Statistic(
                          label: 'Consumo',
                          value: '${summary.consumedEggs}',
                        ),
                      ),
                      Expanded(
                        child: _Statistic(
                          label: 'Ingresos',
                          value: currency.format(summary.income),
                        ),
                      ),
                      Expanded(
                        child: _Statistic(
                          label: 'Registros',
                          value:
                              '${summary.collectionCount + summary.saleCount}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              key: const Key('egg-break-even-strip'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              color: Color.alphaBlend(
                colors.primary.withValues(alpha: 0.08),
                colors.surfaceContainerHighest,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.balance_outlined,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Punto de equilibrio',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Sin costos registrados',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Statistic extends StatelessWidget {
  const _Statistic({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
