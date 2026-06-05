// lib/features/home/presentation/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../auth/data/auth_repository.dart';
import '../settings/presentation/providers/theme_provider.dart'; // Tu provider de tema real
import '../../shared/widgets/setting_sheet.dart';
import '../granja/granja.dart';
import '../granja/granja_repository.dart';
import '../granja/granja_provider.dart';
import 'nueva_granja.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedTab = 0;

  void _openSettings() {
    // Aquí puedes abrir tu SettingsSheet real cuando lo tengas implementado
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Leemos el estado real de tu themeProvider (AppThemeMode)
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            _AppBar(isDark: isDark, onSettings: _openSettings),
            Expanded(
              child: _Body(isDark: isDark, ref: ref),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        isDark: isDark,
        selected: _selectedTab,
        onTap: (index) => setState(() => _selectedTab = index),
      ),
    );
  }
}

class _AppBar extends ConsumerWidget {
  final bool isDark;
  final VoidCallback onSettings;

  const _AppBar({required this.isDark, required this.onSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 2. Extraemos dinámicamente el nombre del usuario desde Supabase authRepositoryProvider
    final user = ref.watch(authRepositoryProvider).currentUser;
    final userNombre = user?.userMetadata?['nombre'] ?? 'Granjero';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('🐔', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Granjas',
            style: TextStyle(
              color: isDark ? AppColors.textPrimary : const Color(0xFF1A1A2E),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onSettings,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgCard : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.border : const Color(0xFFD1D5DB),
                ),
              ),
              child: Icon(
                Icons.settings_outlined,
                color: isDark
                    ? AppColors.textSecondary
                    : const Color(0xFF6B7280),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final bool isDark;
  final WidgetRef ref;
  const _Body({required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    // Escuchamos el estado asíncrono de las granjas provenientes de Supabase
    final farmsAsync = ref.watch(farmsProvider);
    // Escuchamos cuál es la granja seleccionada actualmente
    final selectedFarm = ref.watch(selectedFarmProvider);

    return // Sección Dinámica de Granjas de la BD
    farmsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(
          'Error al cargar granjas: $err',
          style: const TextStyle(color: AppColors.negative),
        ),
      ),
      data: (farms) {
        if (farms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No tienes ninguna granja registrada',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                _NewFarmButton(isDark: isDark),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount:
              farms.length + 1, // +1 para incluir el botón de agregar al final
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == farms.length) {
              return _NewFarmButton(isDark: isDark);
            }

            final farm = farms[index];
            // Condición clave: ¿Es esta tarjeta la seleccionada actualmente?
            final isSelected = selectedFarm?.id == farm.id;

            return _FarmCard(
              farm: farm,
              isDark: isDark,
              isSelected: isSelected,
              hasImage: true,
              onTap: () {
                // Al hacer tap, guardamos/actualizamos el estado de la granja elegida
                ref.read(selectedFarmProvider.notifier).updateFarm(farm);
                print('granja: ${ref.watch(selectedFarmProvider)?.nombre}');
              },
            );
          },
        );
      },
    );
  }
}

class _NewFarmButton extends StatelessWidget {
  final bool isDark;
  const _NewFarmButton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // ABRIR EL MODAL MODERNO AQUÍ
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true, // Permite ajustar el tamaño con el teclado
            builder: (_) => NuevaGranja(isDark: isDark),
          );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.border : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
          color: isDark
              ? AppColors.bgCard.withOpacity(0.5)
              : Colors.white.withOpacity(0.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppColors.textSecondary, size: 18),
            SizedBox(width: 8),
            Text(
              'Nueva granja',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom bar ───────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final bool isDark;
  final int selected;
  final ValueChanged<int> onTap;

  const _BottomBar({
    required this.isDark,
    required this.selected,
    required this.onTap,
  });

  static const _icons = [
    Icons.home_rounded,
    Icons.egg_outlined,
    Icons.circle_outlined,
    Icons.grass_outlined,
    Icons.show_chart_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.border : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_icons.length, (i) {
          final sel = i == selected;
          return GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: sel
                  ? const BoxDecoration(
                      color: AppColors.bgCardLight,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Icon(
                _icons[i],
                size: 22,
                color: sel
                    ? AppColors.green
                    : (isDark
                          ? AppColors.textSecondary
                          : const Color(0xFF9CA3AF)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Farm card ────────────────────────────────────────────────────────────────
class _FarmCard extends StatelessWidget {
  final Granja farm;
  final bool isDark, isSelected, hasImage;
  final VoidCallback onTap;

  const _FarmCard({
    required this.farm,
    required this.isDark,
    required this.isSelected,
    required this.hasImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final balance = 100;
    final balanceColor = balance >= 0 ? AppColors.positive : AppColors.negative;
    final balanceStr = balance >= 0 ? '+$balance \$' : '$balance \$';
    final ownerName = farm.ownerProfile?.nombre ?? 'Desconocido';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          // Cambiamos el borde dinámicamente si está seleccionado para dar el feedback visual
          border: Border.all(
            color: isSelected
                ? AppColors
                      .green // Borde verde si está seleccionado
                : AppColors.border, // Borde por defecto si no lo está
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.green.withOpacity(0.15),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child:
            // Icono o Avatar identificador de la granja
            /* Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.green.withOpacity(0.15)
                    : AppColors.bgCardLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.gite_rounded,
                color: isSelected ? AppColors.green : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14), */
            // Datos de la base de datos
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImage)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          height: 110,
                          width: double.infinity,
                          color: const Color(0xFF2D4A1E),
                          child: const Center(
                            child: Text(
                              '🌿🌾🌿',
                              style: TextStyle(fontSize: 40),
                            ),
                          ),
                        ),
                        Container(
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.5),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 14,
                          right: 14,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                farm.nombre,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              _InviteChip(isDark: isDark),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 14,
                          child: Text(
                            ownerName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: EdgeInsets.fromLTRB(14, hasImage ? 10 : 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!hasImage) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              farm.nombre,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textPrimary
                                    : const Color(0xFF1A1A2E),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            _InviteChip(isDark: isDark),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          farm.ownerId,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          _Stat(
                            value: '$balance',
                            label: 'Aves',
                            isDark: isDark,
                          ),
                          const SizedBox(width: 16),
                          _Stat(
                            value: '$balance',
                            label: 'Huevos',
                            isDark: isDark,
                          ),
                          const SizedBox(width: 16),
                          _Stat(
                            value: balanceStr,
                            label: 'Balance',
                            isDark: isDark,
                            valueColor: balanceColor,
                          ),
                          const Spacer(),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.bgCardLight
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(
                              Icons.home_outlined,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

        // Radio indicator visual a la derecha
        /* Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.green : AppColors.textMuted,
              size: 20,
            ), */
      ),
    );
  }
}

/* class _FarmCard2 extends StatelessWidget {
  final String nombre, owner;
  final int aves, huevos, balance;
  final bool hasImage, isDark;

  const _FarmCard2({
    required this.nombre,
    required this.owner,
    required this.aves,
    required this.huevos,
    required this.balance,
    required this.hasImage,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final balanceColor = balance >= 0 ? AppColors.positive : AppColors.negative;
    final balanceStr = balance >= 0 ? '+$balance \$' : '$balance \$';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          if (hasImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  Container(
                    height: 110,
                    width: double.infinity,
                    color: const Color(0xFF2D4A1E),
                    child: const Center(
                      child: Text('🌿🌾🌿', style: TextStyle(fontSize: 40)),
                    ),
                  ),
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 14,
                    right: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                        ),
                        _InviteChip(),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 14,
                    child: Text(
                      owner,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, hasImage ? 10 : 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasImage) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        nombre,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textPrimary
                              : const Color(0xFF1A1A2E),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      _InviteChip(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    owner,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    _Stat(value: '$aves', label: 'Aves', isDark: isDark),
                    const SizedBox(width: 16),
                    _Stat(value: '$huevos', label: 'Huevos', isDark: isDark),
                    const SizedBox(width: 16),
                    _Stat(
                      value: balanceStr,
                      label: 'Balance',
                      isDark: isDark,
                      valueColor: balanceColor,
                    ),
                    const Spacer(),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.bgCardLight
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.home_outlined,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
 */

class _InviteChip extends StatelessWidget {
  final bool isDark;
  const _InviteChip({required this.isDark});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {},
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_add_outlined, color: Colors.white, size: 12),
          SizedBox(width: 4),
          Text(
            'Invitar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  /* Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.35),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white24),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person_add_outlined, color: Colors.white, size: 12),
        SizedBox(width: 4),
        Text(
          'Invitar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  ); */
}

class _Stat extends StatelessWidget {
  final String value, label;
  final Color? valueColor;
  final bool isDark;

  const _Stat({
    required this.value,
    required this.label,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: TextStyle(
          color:
              valueColor ??
              (isDark ? AppColors.textPrimary : const Color(0xFF1A1A2E)),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
    ],
  );
}
