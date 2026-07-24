// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../settings/presentation/providers/theme_provider.dart'; // Tu provider de tema real
import '../../shared/widgets/setting_sheet.dart';
import '../granja/granja.dart';
import '../granja/granja_repository.dart';
import '../granja/granja_provider.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../granja/nueva_granja.dart';
// ⚠️ Ajusta esta ruta si la carpeta "animales" no es hermana directa de "home"
// en tu árbol de carpetas (debe apuntar a donde están animales_provider.dart
// y tipo_filtro.dart).
import '../animales/animales_provider.dart';
import '../animales/tipo_filtro.dart';
import '../model/grupo/grupo.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import '../huevos/huevo_filters.dart';
import '../huevos/huevo_models.dart';
import '../huevos/huevo_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  // Recibimos obligatoriamente el contenedor de navegación inyectado por GoRouter
  final StatefulNavigationShell navigationShell;

  const HomeScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bg : const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            _AppBar(
              isDark: isDark,
              onSettings: _openSettings,
              navigationShell: widget.navigationShell,
            ),
            // EL BODY AHORA ES EL CONTENEDOR DE LAS SUB-PANTALLAS DINÁMICAS
            Expanded(child: widget.navigationShell),
          ],
        ),
      ),
      // Le pasamos el shell a la barra inferior para que sepa qué índice está activo
      bottomNavigationBar: _BottomBar(
        isDark: isDark,
        navigationShell: widget.navigationShell,
      ),
    );
  }
}

class _AppBar extends ConsumerWidget {
  final bool isDark;
  final VoidCallback onSettings;
  final StatefulNavigationShell navigationShell;

  const _AppBar({
    required this.isDark,
    required this.onSettings,
    required this.navigationShell,
  });

  // Índice de la pestaña "Animales" en el bottom nav (ver _BottomBar._icons).
  // Si reordenas las pestañas, actualiza este valor.

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFarm = ref.watch(selectedFarmProvider);
    final branchIndex = navigationShell.currentIndex;
    final isAnimalBranch = branchIndex == 1 || branchIndex == 2;
    final isEggBranch = branchIndex == 2;
    final tiposAsync = selectedFarm != null
        ? ref.watch(tiposAnimalProvider(selectedFarm.id))
        : null;
    final gruposAsync = isAnimalBranch && selectedFarm != null
        ? ref.watch(gruposProvider(selectedFarm.id))
        : null;
    final tipos = tiposAsync?.value ?? const [];
    final grupos = gruposAsync?.value ?? const [];
    final tipoFiltro = ref.watch(tipoFiltroProvider);
    final filters = isEggBranch && selectedFarm != null
        ? ref.watch(huevoFiltersProvider(selectedFarm.id))
        : const EggFilters();
    final typeIsValid =
        tipoFiltro == 'all' || tipos.any((type) => type.id == tipoFiltro);
    final groupIsValid =
        resolveEggGroupForType(
          selectedGroupId: filters.groupId,
          groups: grupos,
          animalTypeId: typeIsValid ? tipoFiltro : 'all',
        ) ==
        filters.groupId;

    if (tiposAsync?.hasValue == true && !typeIsValid ||
        gruposAsync?.hasValue == true && isEggBranch && !groupIsValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (!typeIsValid && ref.read(tipoFiltroProvider) != 'all') {
          ref.read(tipoFiltroProvider.notifier).clear();
        }
        if (selectedFarm != null && !groupIsValid) {
          final provider = huevoFiltersProvider(selectedFarm.id);
          if (ref.read(provider).groupId != null) {
            ref.read(provider.notifier).setGroup(null);
          }
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          return Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.bgCard3,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40 * 0.2),
                    child: Image.asset(
                      'assets/icon/app.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _branchTitle(branchIndex),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimary
                        : const Color(0xFF1A1A2E),
                    fontSize: compact ? 18 : 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              if (selectedFarm != null)
                HomeFilterControls(
                  branchIndex: branchIndex,
                  isDark: isDark,
                  compact: compact,
                  animalTypes: tipos,
                  groups: grupos,
                  selectedAnimalTypeId: typeIsValid ? tipoFiltro : 'all',
                  filters: groupIsValid
                      ? filters
                      : filters.copyWith(clearGroup: true),
                  onAnimalTypeChanged: (value) {
                    ref.read(tipoFiltroProvider.notifier).set(value);
                    if (!isEggBranch) return;
                    final resolvedGroupId = resolveEggGroupForType(
                      selectedGroupId: filters.groupId,
                      groups: grupos,
                      animalTypeId: value,
                    );
                    if (resolvedGroupId != filters.groupId) {
                      ref
                          .read(huevoFiltersProvider(selectedFarm.id).notifier)
                          .setGroup(resolvedGroupId);
                    }
                  },
                  onGroupChanged: (value) => ref
                      .read(huevoFiltersProvider(selectedFarm.id).notifier)
                      .setGroup(value),
                  onPeriodChanged: (value) => ref
                      .read(huevoFiltersProvider(selectedFarm.id).notifier)
                      .setPeriod(value),
                ),
              const SizedBox(width: 7),
              Tooltip(
                message: 'Ajustes',
                child: InkWell(
                  onTap: onSettings,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.bgCard : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.border
                            : const Color(0xFFD1D5DB),
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
              ),
            ],
          );
        },
      ),
    );
  }
}

String _branchTitle(int index) => switch (index) {
  0 => 'Granjas',
  1 => 'Animales',
  2 => 'Huevos',
  3 => 'Comida',
  4 => 'Gráficas',
  _ => 'Granjas',
};

class HomeFilterControls extends StatelessWidget {
  const HomeFilterControls({
    super.key,
    required this.branchIndex,
    required this.isDark,
    required this.compact,
    required this.animalTypes,
    required this.groups,
    required this.selectedAnimalTypeId,
    required this.filters,
    required this.onAnimalTypeChanged,
    required this.onGroupChanged,
    required this.onPeriodChanged,
  });

  final int branchIndex;
  final bool isDark;
  final bool compact;
  final List<TipoAnimal> animalTypes;
  final List<Grupo> groups;
  final String selectedAnimalTypeId;
  final EggFilters filters;
  final ValueChanged<String> onAnimalTypeChanged;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<EggPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final showAnimalType = branchIndex == 1 || branchIndex == 2;
    final showEggFilters = branchIndex == 2;
    final constrainedGroups = eggGroupsForType(
      groups: groups,
      animalTypeId: selectedAnimalTypeId,
    );
    return Row(
      key: const Key('home-filter-controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showAnimalType && animalTypes.isNotEmpty) ...[
          TipoFiltroBadgeButton(
            isDark: isDark,
            tipos: animalTypes,
            grupos: groups,
            tipoFiltro: selectedAnimalTypeId,
            compact: compact,
            onChanged: onAnimalTypeChanged,
          ),
          const SizedBox(width: 6),
        ],
        if (showEggFilters) ...[
          EggGroupFilterBadgeButton(
            isDark: isDark,
            groups: constrainedGroups,
            selectedGroupId: filters.groupId,
            compact: compact,
            onChanged: onGroupChanged,
          ),
          const SizedBox(width: 6),
          EggPeriodFilterBadgeButton(
            isDark: isDark,
            period: filters.period,
            compact: compact,
            onChanged: onPeriodChanged,
          ),
        ],
      ],
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────
class GranjasTab extends ConsumerWidget {
  const GranjasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    final farmsAsync = ref.watch(farmsProvider);
    final selectedFarm = ref.watch(selectedFarmProvider);

    return farmsAsync.when(
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
          itemCount: farms.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == farms.length) {
              return _NewFarmButton(isDark: isDark);
            }

            final farm = farms[index];
            final isSelected = selectedFarm?.id == farm.id;

            return _FarmCard(
              farm: farm,
              isDark: isDark,
              isSelected: isSelected,
              hasImage: true,
              onTap: () {
                ref.read(selectedFarmProvider.notifier).updateFarm(farm);
                print('granja seleccionada: ${farm.nombre}');

                // OPCIONAL: Podrías hacer que al seleccionar una granja
                // salte automáticamente a la pestaña de animales (índice 1):
                // GoRouterState.of(context).... o simplemente:
                // (widget.navigationShell).goBranch(1);
              },
              onLongPress: () {
                ConfirmationDialog.show(
                  context: context,
                  isDark: isDark,
                  title: 'Eliminar Granja',
                  content:
                      '¿Estás seguro de que deseas eliminar la granja "${farm.nombre}"? Esta acción no se puede deshacer.',
                  onConfirm: () async {
                    try {
                      await ref
                          .read(farmRepositoryProvider)
                          .deleteFarm(farmId: farm.id);
                      if (isSelected) {
                        ref.read(selectedFarmProvider.notifier).clear();
                      }
                      ref.invalidate(farmsProvider);
                    } catch (e) {
                      print('Error al eliminar granja: $e');
                    }
                  },
                );
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
              ? AppColors.bgCard.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.5),
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
  final StatefulNavigationShell navigationShell;

  const _BottomBar({required this.isDark, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    // 1. Definimos una función que genera el icono correcto según su color dinámico
    Widget getIcon(int index, Color color) {
      switch (index) {
        case 0:
          return Icon(Icons.home_rounded, size: 22, color: color);
        // 2. Aquí reemplazamos Icons.circle_outlined por tu asset personalizado
        case 1:
          return Image.asset(
            'assets/chicken.png',
            width: 22,
            height: 22,
            color: color,
          );
        case 2:
          return Image.asset(
            'assets/eggs.png',
            width: 22,
            height: 22,
            color: color,
          );
        case 3:
          return Image.asset(
            'assets/grain.png',
            width: 22,
            height: 22,
            color: color,
          );
        case 4:
          return Icon(Icons.show_chart_rounded, size: 22, color: color);
        default:
          return const SizedBox.shrink();
      }
    }

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: isDark ? AppColors.bg : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.border : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(5, (index) {
          // 5 es el número total de pestañas
          final isSelected = currentIndex == index;

          // 3. Calculamos el color una sola vez para pasarlo al Icon o al Image.asset
          final iconColor = isSelected
              ? AppColors.green
              : (isDark ? AppColors.textSecondary : const Color(0xFF9CA3AF));

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => navigationShell.goBranch(
              index,
              initialLocation: index == currentIndex,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.bgCard3 : Colors.transparent,
                shape: BoxShape.circle,
              ),
              // 4. Renderizamos el widget dinámico pasando el color calculado
              child: getIcon(index, iconColor),
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
  final VoidCallback onTap, onLongPress;

  const _FarmCard({
    required this.farm,
    required this.isDark,
    required this.isSelected,
    required this.hasImage,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    const List<String> kFarmCardImages = [
      'assets/icon/card1.jpeg',
      'assets/icon/card2.jpeg',
      'assets/icon/card3.jpeg',
      'assets/icon/card4.jpeg',
    ];

    final balance = 100;
    final balanceColor = balance >= 0 ? AppColors.positive : AppColors.negative;
    final balanceStr = balance >= 0 ? '+$balance \$' : '$balance \$';
    final ownerName = farm.ownerProfile?.nombre ?? 'Desconocido';

    String _imageForFarm(String farmId) {
      final index = farmId.hashCode.abs() % kFarmCardImages.length;
      return kFarmCardImages[index];
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bg : Colors.white,
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
                    color: AppColors.green.withValues(alpha: 0.15),
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
                        Image.asset(
                          _imageForFarm(farm.id),
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.5),
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
                              _InviteChip(
                                farmId: farm.id,
                                farmName: farm.nombre,
                                isDark: isDark,
                              ),
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
                            _InviteChip(
                              farmId: farm.id,
                              farmName: farm.nombre,
                              isDark: isDark,
                            ),
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
                                  ? AppColors.bgCard3
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
  final String farmId, farmName;
  const _InviteChip({
    required this.farmId,
    required this.farmName,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      context.push('/collaborators/$farmId', extra: farmName);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
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
