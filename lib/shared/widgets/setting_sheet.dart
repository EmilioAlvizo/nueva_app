// lib/shared/widgets/settings_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '/features/auth/data/auth_repository.dart';
import '/features/settings/presentation/providers/theme_provider.dart';
import '../../../../features/granja/granja_provider.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Adaptación al enum AppThemeMode de tu themeProvider
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    // 2. Adaptación a tu repositorio real de Supabase
    final authRepository = ref.watch(authRepositoryProvider);
    final user = authRepository.currentUser;

    final nombre =
        user?.userMetadata?['nombre'] as String? ??
        user?.email?.split('@').first ??
        'Usuario';
    final email = user?.email ?? '';
    final initials = nombre
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.bg : AppColors.bgLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle superior para deslizar hacia abajo
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            'Ajustes',
            style: TextStyle(
              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLg,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tu cuenta y preferencias',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLg,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          // Tarjeta de usuario
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgCard3 : AppColors.bgCard3Lg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLg,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            nombre,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.textPrimaryLg,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.mail_outline,
                            color: isDark
                                ? AppColors.textMuted
                                : AppColors.textMutedLg,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              email,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.textSecondaryLg,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'APARIENCIA',
            style: TextStyle(
              color: isDark ? AppColors.textMuted : AppColors.textMutedLg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),

          // Selector de Tema (Claro / Oscuro) usando tus métodos setDark/setLight
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgCard3 : AppColors.bgCard3Lg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _ThemeOption(
                  label: 'Oscuro',
                  icon: Icons.dark_mode_outlined,
                  selected: isDark,
                  onTap: () => ref.read(themeProvider.notifier).setDark(),
                ),
                _ThemeOption(
                  label: 'Claro',
                  icon: Icons.light_mode_outlined,
                  selected: !isDark,
                  onTap: () => ref.read(themeProvider.notifier).setLight(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'CUENTA',
            style: TextStyle(
              color: isDark ? AppColors.textMuted : AppColors.textMutedLg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),

          _SettingsItem(
            icon: Icons.person_outline,
            label: 'Editar perfil',
            isDark: isDark,
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _SettingsItem(
            icon: Icons.logout_rounded,
            label: 'Cerrar sesión',
            isDestructive: true,
            isDark: isDark,
            onTap: () async {
              // Cerramos el BottomSheet primero
              Navigator.of(context).pop();
              // 2. Limpiamos la granja seleccionada para que el próximo usuario
              //    no vea datos residuales del anterior.
              ref.read(selectedFarmProvider.notifier).clear();
              // Deslogueamos de Supabase; go_router hará el resto mágicamente
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.amber : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : AppColors.textSecondary,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive, isDark;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.negative : isDark ? AppColors.textPrimary : AppColors.textPrimaryLg;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgCard3:AppColors.bgCard3Lg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!isDestructive)
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.textMuted : AppColors.textMutedLg,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
