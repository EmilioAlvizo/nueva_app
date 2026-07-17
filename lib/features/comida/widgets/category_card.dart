import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../comida_models.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final FoodCategory category;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 76),
    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF3178C6).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.sell_outlined, color: Color(0xFF72A9E8)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            category.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (canEdit) ...[
          IconButton(
            tooltip: 'Editar categoría',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            color: AppColors.textPrimary,
          ),
          IconButton(
            tooltip: 'Eliminar categoría',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.negative,
          ),
        ],
      ],
    ),
  );
}
