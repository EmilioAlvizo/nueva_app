import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'huevo_models.dart';

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
    return _EggCard(
      key: ValueKey('egg-collection-${collection.id}'),
      accent: _groupAccent(collection.groupId, isSale: false),
      title: collection.groupName,
      subtitle: collection.animalTypeName,
      primaryLabel: 'Buenos',
      primaryValue: '${collection.goodEggs}',
      secondaryLabel: 'Rotos',
      secondaryValue: '${collection.brokenEggs}',
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
    return _EggCard(
      key: ValueKey('egg-sale-${sale.id}'),
      accent: _groupAccent(sale.groupId ?? sale.id, isSale: true),
      title: sale.groupName,
      subtitle: sale.animalTypeName,
      primaryLabel: 'Total',
      primaryValue: currency.format(sale.total),
      secondaryLabel: 'Detalle',
      secondaryValue: '${sale.quantity} × ${currency.format(sale.unitPrice)}',
      author: sale.authorName,
      date: sale.date,
      canEdit: canEdit,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _EggCard extends StatelessWidget {
  const _EggCard({
    super.key,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.primaryValue,
    required this.secondaryLabel,
    required this.secondaryValue,
    required this.author,
    required this.date,
    required this.canEdit,
    this.onEdit,
    this.onDelete,
  });

  final Color accent;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final String primaryValue;
  final String secondaryLabel;
  final String secondaryValue;
  final String author;
  final DateTime date;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 6, child: ColoredBox(color: accent)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: theme.textTheme.titleMedium),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canEdit) ...[
                          IconButton(
                            tooltip: 'Editar',
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: onDelete,
                            icon: Icon(
                              Icons.delete_outline,
                              color: colors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 24,
                      runSpacing: 10,
                      children: [
                        _Value(label: primaryLabel, value: primaryValue),
                        _Value(label: secondaryLabel, value: secondaryValue),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: colors.outlineVariant, height: 1),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 18,
                      runSpacing: 6,
                      children: [
                        _Meta(icon: Icons.person_outline, text: author),
                        _Meta(
                          icon: Icons.calendar_today_outlined,
                          text: DateFormat('dd/MM/yyyy').format(date),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value});

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
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

Color _groupAccent(String seed, {required bool isSale}) {
  final palette = isSale
      ? const [Color(0xFFF59E0B), Color(0xFF22C55E)]
      : const [Color(0xFF14B8A6), Color(0xFF0891B2)];
  return palette[seed.hashCode.abs() % palette.length];
}
