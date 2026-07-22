import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'huevo_models.dart';

class EggSummaryView extends StatelessWidget {
  const EggSummaryView({super.key, required this.summary});

  final EggSummary summary;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    return ListView(
      key: const Key('egg-summary-view'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final width = compact
                ? (constraints.maxWidth - 12) / 2
                : (constraints.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  width: compact ? constraints.maxWidth : width,
                  icon: Icons.egg_outlined,
                  label: 'Huevos',
                  value: '${summary.goodEggs}',
                ),
                _MetricCard(
                  width: width,
                  icon: Icons.payments_outlined,
                  label: 'Ingresos',
                  value: currency.format(summary.income),
                ),
                _MetricCard(
                  width: width,
                  icon: Icons.shopping_basket_outlined,
                  label: 'Vendidos',
                  value: '${summary.soldEggs}',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _DestinationCard(summary: summary),
        const SizedBox(height: 16),
        _DetailCard(summary: summary, currency: currency),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActivityCard(
                icon: Icons.inventory_2_outlined,
                label: 'Recolecciones',
                value: summary.collectionCount,
              ),
            ),
            const SizedBox(width: 12),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.headlineSmall),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.summary});

  final EggSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const consumptionColor = Color(0xFF14B8A6);
    const saleColor = Color(0xFFF59E0B);
    final brokenColor = colors.error;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Destino de los huevos', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Consumo representa huevos buenos no vendidos.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final chart = Semantics(
                label:
                    'Destino: consumo ${summary.consumedEggs}, venta ${summary.soldEggs}, rotos ${summary.brokenEggs}',
                child: SizedBox.square(
                  dimension: 160,
                  child: summary.destinationTotal == 0
                      ? _EmptyDonut(color: colors.outlineVariant)
                      : PieChart(
                          PieChartData(
                            centerSpaceRadius: 48,
                            sectionsSpace: 3,
                            sections: [
                              PieChartSectionData(
                                value: summary.consumedEggs.toDouble(),
                                color: consumptionColor,
                                radius: 28,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: summary.soldEggs.toDouble(),
                                color: saleColor,
                                radius: 28,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: summary.brokenEggs.toDouble(),
                                color: brokenColor,
                                radius: 28,
                                showTitle: false,
                              ),
                            ],
                          ),
                          duration: const Duration(milliseconds: 250),
                        ),
                ),
              );
              final legend = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Legend(
                    color: consumptionColor,
                    label: 'Consumo',
                    value: summary.consumedEggs,
                  ),
                  const SizedBox(height: 12),
                  _Legend(
                    color: saleColor,
                    label: 'Venta',
                    value: summary.soldEggs,
                  ),
                  const SizedBox(height: 12),
                  _Legend(
                    color: brokenColor,
                    label: 'Rotos',
                    value: summary.brokenEggs,
                  ),
                ],
              );
              if (constraints.maxWidth < 440) {
                return Column(
                  children: [chart, const SizedBox(height: 16), legend],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [chart, legend],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyDonut extends StatelessWidget {
  const _EmptyDonut({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 24),
      ),
      child: const Center(child: Text('Sin datos')),
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 8),
        Text('$value', style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.summary, required this.currency});

  final EggSummary summary;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detalle', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 18,
            children: [
              _Detail(label: 'Buenos', value: '${summary.goodEggs}'),
              _Detail(label: 'Rotos', value: '${summary.brokenEggs}'),
              _Detail(label: 'Vendidos', value: '${summary.soldEggs}'),
              _Detail(
                label: 'Ingresos',
                value: currency.format(summary.income),
              ),
              _Detail(
                label: 'Precio promedio',
                value: currency.format(summary.averageSalePrice),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value', style: Theme.of(context).textTheme.titleLarge),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
