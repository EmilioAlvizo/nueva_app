// lib/shared/widgets/confirmation_dialog.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ConfirmationDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
    String confirmLabel = 'Eliminar',
    String cancelLabel = 'Cancelar',
    bool isDark = true,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.bgCard : Colors.white,
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? AppColors.textPrimary : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          content,
          style: TextStyle(
            color: isDark ? AppColors.textSecondary : Colors.black54,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              cancelLabel,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negative,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Cierra el modal
              onConfirm(); // Ejecuta la acción personalizada
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}