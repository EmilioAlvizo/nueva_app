import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../comida_models.dart';
import '../../../shared/widgets/fechas.dart';

class MixtureCard extends StatelessWidget {
  const MixtureCard({
    super.key,
    required this.mixture,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final FoodMixture mixture;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final date = DateFormat('dd/MM/yyyy');
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: AppColors.bgCard,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mixture.groupName,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${mixture.ingredients.length} ${mixture.ingredients.length == 1 ? 'ingrediente' : 'ingredientes'}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canEdit) ...[
                            IconButton(
                              tooltip: 'Editar mezcla',
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit_outlined),
                              color: AppColors.textPrimary,
                            ),
                            IconButton(
                              tooltip: 'Eliminar mezcla',
                              onPressed: onDelete,
                              icon: const Icon(Icons.delete_outline_rounded),
                              color: AppColors.negative,
                            ),
                          ],
                        ],
                      ),
                    ),
                    for (final ingredient in mixture.ingredients)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 5,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                ingredient.categoryName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${_quantity(ingredient.quantityKg)} kg · ${currency.format(ingredient.totalCost)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 9, 16, 14),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${_quantity(mixture.totalKg)} kg · ${currency.format(mixture.totalCost)}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      color: isDark
                          ? AppColors.fecha
                          : AppColors.fechaLg,
                      child: Text(
                        mixture.endDate == null
                            ? 'Desde ${formatSpanishLongDate(mixture.startDate)}'
                            : '${formatSpanishLongDate(mixture.startDate)} → ${formatSpanishLongDate(mixture.endDate!)}',
                        style: TextStyle(
                          color: isDark
                          ? AppColors.textPrimary:AppColors.textPrimaryLg,
                          fontSize: 12,
                        ),
                        textAlign: .center,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                color: const Color(0xFF3178C6),
                alignment: Alignment.center,
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    mixture.isActive ? 'Activa' : 'Cerrada',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _quantity(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
