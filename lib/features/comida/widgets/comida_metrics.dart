import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../comida_models.dart';

class ComidaMetrics extends StatelessWidget {
  const ComidaMetrics({
    super.key,
    required this.stats,
    required this.countLabel,
  });

  final FoodStats stats;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _MetricCard(
            value: '${_number(stats.totalKg)} kg',
            label: 'Total',
            color: const Color(0xFFB8E6CF),
            foreground: const Color(0xFF14392A),
          ),
          _MetricCard(
            value: currency.format(stats.totalCost),
            label: 'Gasto total',
            color: AppColors.bgCard,
            foreground: AppColors.textPrimary,
          ),
          _MetricCard(
            value: '${stats.count}',
            label: countLabel,
            color: const Color(0xFF75422F),
            foreground: Colors.white,
          ),
        ];
        if (constraints.maxWidth >= 560) {
          return Row(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                Expanded(child: cards[index]),
                if (index != cards.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              Expanded(child: cards[index]),
              if (index != cards.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }

  static String _number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class ComidaMetricsLoading extends StatelessWidget {
  const ComidaMetricsLoading({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Expanded(child: _MetricPlaceholder(color: Color(0xFFB8E6CF))),
      SizedBox(width: 8),
      Expanded(child: _MetricPlaceholder(color: AppColors.bgCard)),
      SizedBox(width: 8),
      Expanded(child: _MetricPlaceholder(color: Color(0xFF75422F))),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
    required this.color,
    required this.foreground,
  });

  final String value;
  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: foreground,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MetricPlaceholder extends StatelessWidget {
  const _MetricPlaceholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 88,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Center(
      child: SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}
