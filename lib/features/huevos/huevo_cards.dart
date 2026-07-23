import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import 'huevo_models.dart';
import 'huevo_pie_chart.dart';

enum _EggCardAction { edit, delete }

class EggCollectionCard extends StatelessWidget {
  const EggCollectionCard({
    super.key,
    required this.collection,
    required this.canEdit,
    this.onEdit,
    this.onDelete,
  });

  final EggCollection collection;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return _EggRecordCard(
      key: ValueKey('egg-collection-${collection.id}'),
      semanticsLabel:
          'Recolección de ${collection.groupName}: '
          '${collection.goodEggs} buenos y ${collection.brokenEggs} rotos',
      icon: Icons.egg_rounded,
      iconColor: eggConsumptionColor,
      title: collection.groupName,
      subtitle: collection.animalTypeName,
      firstLabel: 'Buenos',
      firstValue: '${collection.goodEggs}',
      secondLabel: 'Rotos',
      secondValue: '${collection.brokenEggs}',
      author: collection.authorName,
      date: collection.date,
      canEdit: canEdit,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class EggSaleCard extends StatelessWidget {
  const EggSaleCard({
    super.key,
    required this.sale,
    required this.canEdit,
    this.onEdit,
    this.onDelete,
  });

  final EggSale sale;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    return _EggRecordCard(
      key: ValueKey('egg-sale-${sale.id}'),
      semanticsLabel:
          'Venta de ${sale.groupName}: ${sale.quantity} huevos por '
          '${currency.format(sale.unitPrice)}, total '
          '${currency.format(sale.total)}',
      icon: Icons.point_of_sale_rounded,
      iconColor: AppColors.naranjal,
      title: sale.groupName,
      subtitle: sale.animalTypeName,
      firstLabel: 'Total',
      firstValue: currency.format(sale.total),
      firstValueColor: Theme.of(context).colorScheme.primary,
      secondLabel: 'Cantidad × precio',
      secondValue: '${sale.quantity} × ${currency.format(sale.unitPrice)}',
      author: sale.authorName,
      date: sale.date,
      canEdit: canEdit,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _EggRecordCard extends StatelessWidget {
  const _EggRecordCard({
    super.key,
    required this.semanticsLabel,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.firstLabel,
    required this.firstValue,
    required this.secondLabel,
    required this.secondValue,
    required this.author,
    required this.date,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    this.firstValueColor,
  });

  final String semanticsLabel;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String firstLabel;
  final String firstValue;
  final Color? firstValueColor;
  final String secondLabel;
  final String secondValue;
  final String author;
  final DateTime date;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(15, 14, 10, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  key: const Key('egg-record-icon'),
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, color: iconColor, size: 21),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (canEdit)
                                  PopupMenuButton<_EggCardAction>(
                                    key: const Key('egg-record-menu'),
                                    tooltip: 'Opciones del registro',
                                    onSelected: (action) => switch (action) {
                                      _EggCardAction.edit => onEdit?.call(),
                                      _EggCardAction.delete => onDelete?.call(),
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: _EggCardAction.edit,
                                        child: ListTile(
                                          leading: Icon(Icons.edit_outlined),
                                          title: Text('Editar'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: _EggCardAction.delete,
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.delete_outline,
                                            color: colors.error,
                                          ),
                                          title: const Text('Eliminar'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _RecordValue(
                                    label: firstLabel,
                                    value: firstValue,
                                    valueColor: firstValueColor,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _RecordValue(
                                    label: secondLabel,
                                    value: secondValue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: colors.secondary.withValues(
                                    alpha: 0.16,
                                  ),
                                  child: Text(
                                    _initials(author),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.secondary,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      key: const Key('egg-group-stripe'),
                      width: 7,
                      child: const ColoredBox(color: eggConsumptionColor),
                    ),
                  ],
                ),
              ),
              Container(
                key: const Key('egg-date-footer'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                color: Color.alphaBlend(
                  colors.primary.withValues(alpha: 0.07),
                  colors.surfaceContainerHighest,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd/MM/yyyy').format(date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordValue extends StatelessWidget {
  const _RecordValue({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

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
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}
