import 'package:flutter/material.dart';
import 'package:rancho/shared/widgets/fechas.dart';

import '../../core/theme/app_colors.dart';
import 'huevo_models.dart';
import 'huevo_pie_chart.dart';

enum _EggCardAction { edit, delete }

class EggCollectionCard extends StatelessWidget {
  const EggCollectionCard({
    super.key,
    required this.collection,
    required this.canEdit,
    required this.stripeColor,
    this.onEdit,
    this.onDelete,
  });

  final EggCollection collection;
  final bool canEdit;
  final Color stripeColor;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return _EggCollectionRecordCard(
      key: ValueKey('egg-collection-${collection.id}'),
      collection: collection,
      canEdit: canEdit,
      stripeColor: stripeColor,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _EggCollectionRecordCard extends StatelessWidget {
  const _EggCollectionRecordCard({
    super.key,
    required this.collection,
    required this.canEdit,
    required this.stripeColor,
    required this.onEdit,
    required this.onDelete,
  });

  final EggCollection collection;
  final bool canEdit;
  final Color stripeColor;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bodyColor = Color.alphaBlend(
      const Color(0xFF2A2D25).withValues(alpha: isDark ? 0.82 : 0.12),
      colors.surfaceContainerHigh,
    );
    final footerColor = Color.alphaBlend(
      const Color(0xFF485043).withValues(alpha: isDark ? 0.68 : 0.1),
      colors.surfaceContainerHighest,
    );
    return Semantics(
      container: true,
      label:
          'Recolección de ${collection.groupName}: '
          '${collection.goodEggs} buenos y ${collection.brokenEggs} rotos',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: DecoratedBox(
          key: const Key('egg-collection-surface'),
          decoration: BoxDecoration(color: bodyColor),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 13, 10, 12),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: .center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.egg_outlined,
                                    key: const Key('egg-collection-icon'),
                                    size: 20,
                                    color: eggConsumptionColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Recolección',
                                        key: const Key('egg-collection-title'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: colors.onSurface,
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        collection.groupName,
                                        key: const Key('egg-collection-group'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _CollectionStatistic(
                                  valueKey: const Key('egg-good-value'),
                                  labelKey: const Key('egg-good-label'),
                                  value: '${collection.goodEggs}',
                                  label: 'Buenos',
                                  color: colors.onSurface,
                                ),
                                const SizedBox(width: 9),
                                _CollectionStatistic(
                                  valueKey: const Key('egg-broken-value'),
                                  labelKey: const Key('egg-broken-label'),
                                  value: '${collection.brokenEggs}',
                                  label: 'Rotos',
                                  color: colors.error,
                                ),
                                if (canEdit) ...[
                                  const SizedBox(width: 2),
                                  _RecordMenu(
                                    onEdit: onEdit,
                                    onDelete: onDelete,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 11),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: colors.outlineVariant.withValues(
                                alpha: 0.1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                CircleAvatar(
                                  key: const Key('egg-collection-avatar'),
                                  radius: 12,
                                  backgroundColor: AppColors.naranjal,
                                  child: Text(
                                    _initials(collection.authorName),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text.rich(
                                    key: const Key('egg-collection-author'),
                                    TextSpan(
                                      text: 'Registrado por ',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                      children: [
                                        TextSpan(
                                          text: collection.authorName,
                                          style: TextStyle(
                                            color: colors.onSurface,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        key: const Key('egg-date-footer'),
                        width: double.infinity,
                        color: isDark
                          ? AppColors.fecha
                          : AppColors.fechaLg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          formatSpanishLongDate(collection.date),
                          key: const Key('egg-collection-date'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  key: const Key('egg-group-stripe'),
                  width: 36,
                  child: ColoredBox(
                    key: const Key('egg-animal-type-stripe'),
                    color: stripeColor,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Center(
                          child: Text(
                            collection.animalTypeName,
                            key: const Key('egg-animal-type-label'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: _onStripeColor(stripeColor),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionStatistic extends StatelessWidget {
  const _CollectionStatistic({
    required this.valueKey,
    required this.labelKey,
    required this.value,
    required this.label,
    required this.color,
  });

  final Key valueKey;
  final Key labelKey;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      //mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          value,
          key: valueKey,
          maxLines: 1,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          key: labelKey,
          maxLines: 1,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color.withValues(alpha: 0.78),
            fontSize: 9,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _RecordMenu extends StatelessWidget {
  const _RecordMenu({required this.onEdit, required this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: PopupMenuButton<_EggCardAction>(
        key: const Key('egg-record-menu'),
        padding: EdgeInsets.zero,
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
              leading: Icon(Icons.delete_outline, color: colors.error),
              title: const Text('Eliminar'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class EggSaleCard extends StatelessWidget {
  const EggSaleCard({
    super.key,
    required this.sale,
    required this.canEdit,
    required this.stripeColor,
    this.onEdit,
    this.onDelete,
  });

  final EggSale sale;
  final bool canEdit;
  final Color stripeColor;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bodyColor = isDark
        ? Color.alphaBlend(
            const Color(0xFF2A2D25).withValues(alpha: 0.84),
            colors.surfaceContainerHigh,
          )
        : Color.alphaBlend(
            colors.primary.withValues(alpha: 0.025),
            colors.surfaceContainerLowest,
          );
    final footerColor = isDark
        ? Color.alphaBlend(
            const Color(0xFF485043).withValues(alpha: 0.68),
            colors.surfaceContainerHighest,
          )
        : Color.alphaBlend(
            colors.primary.withValues(alpha: 0.055),
            colors.surfaceContainerLow,
          );
    final total = '${sale.total.toStringAsFixed(2)} \$';
    final detail = '${sale.quantity} × ${sale.unitPrice.toStringAsFixed(2)} \$';

    return Semantics(
      key: ValueKey('egg-sale-${sale.id}'),
      container: true,
      label:
          'Venta de ${sale.groupName}: ${sale.quantity} huevos por '
          '${sale.unitPrice.toStringAsFixed(2)} dólares, total $total',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: DecoratedBox(
          key: const Key('egg-sale-surface'),
          decoration: BoxDecoration(color: bodyColor),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 13, 4, 12),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.shopping_cart_outlined,
                                  key: Key('egg-sale-icon'),
                                  size: 20,
                                  color: AppColors.naranjal,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Venta',
                                        key: const Key('egg-sale-title'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: colors.onSurface,
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        sale.groupName,
                                        key: const Key('egg-sale-group'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 78,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          total,
                                          key: const Key('egg-sale-total'),
                                          maxLines: 1,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                color: colors.primary,
                                                fontWeight: FontWeight.w900,
                                                height: 1,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          detail,
                                          key: const Key('egg-sale-detail'),
                                          maxLines: 1,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: colors.onSurfaceVariant,
                                                fontSize: 9,
                                                height: 1,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (canEdit)
                                  _RecordMenu(
                                    onEdit: onEdit,
                                    onDelete: onDelete,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: colors.outlineVariant.withValues(
                                alpha: 0.1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                CircleAvatar(
                                  key: const Key('egg-sale-avatar'),
                                  radius: 12,
                                  backgroundColor: AppColors.naranjal,
                                  child: Text(
                                    _initials(sale.authorName),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text.rich(
                                    key: const Key('egg-sale-author'),
                                    TextSpan(
                                      text: 'Registrado por ',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                      children: [
                                        TextSpan(
                                          text: sale.authorName,
                                          style: TextStyle(
                                            color: colors.onSurface,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        key: const Key('egg-sale-date-footer'),
                        width: double.infinity,
                        color: isDark
                          ? AppColors.fecha
                          : AppColors.fechaLg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          formatSpanishLongDate(sale.date),
                          key: const Key('egg-sale-date'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  key: const Key('egg-sale-stripe'),
                  width: 36,
                  child: ColoredBox(
                    key: const Key('egg-sale-animal-type-stripe'),
                    color: stripeColor,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Center(
                          child: Text(
                            sale.animalTypeName,
                            key: const Key('egg-sale-animal-type-label'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: _onStripeColor(stripeColor),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

Color _onStripeColor(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.dark
    ? Colors.white
    : Colors.black;
