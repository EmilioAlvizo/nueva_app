// ─── lib/features/animales/animales_screen.dart ──────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import '../model/grupo/grupo.dart';
import '../model/altaAnimales/altaAnimales.dart';
import '../model/altaAnimales/animal_registration_sheet.dart';
import '../model/grupo/nuevo_grupo.dart';
import '../model/tipoAnimal/nuevo_tipoAnimal.dart';
import '../model/animal/animal.dart';
import '../model/animal/nuevo_ejemplar.dart';
import '../model/bajaAnimal/baja_animal.dart';
import 'animales_provider.dart';
import 'animales_repository.dart' show NoGroupOverview, NoGroupTypeOverview;
import 'tipo_filtro.dart';
import '/features/settings/presentation/providers/theme_provider.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import 'editar_baja_sheet.dart';
import 'registrar_baja_sheet.dart';

// ─── Helpers de color ────────────────────────────────────────────────────────
Color _colorParaTipo(String tipoId, List<TipoAnimal> tipos) {
  final idx = tipos.indexWhere((t) => t.id == tipoId);
  return AppColors.tipoColor[(idx < 0 ? 0 : idx) % AppColors.tipoColor.length];
}

Future<void> _showAltaEditor({
  required BuildContext context,
  required String granjaId,
  required bool isDark,
  required AltaAnimales alta,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => AnimalRegistrationSheet(
      granjaId: granjaId,
      isDark: isDark,
      initialQuantity: alta.cantidadAnimales,
      tipoAnimalIdInicial: alta.tipoAnimalId,
      initialAlta: alta,
    ),
  );
}

Future<void> _showAltaDeleteConfirmation({
  required BuildContext context,
  required WidgetRef ref,
  required String granjaId,
  required AltaAnimales alta,
}) async {
  final hasBajasOrMuertos =
      alta.muertosCount > 0 ||
      alta.brazaletesDetalleSafe.any((item) => !item.activo);
  final deleted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        hasBajasOrMuertos ? 'Eliminar alta con bajas/muertos' : 'Eliminar alta',
      ),
      content: Text(
        hasBajasOrMuertos
            ? 'Esta alta incluye animales muertos o en baja. Para eliminarla de forma segura también se deben borrar esas bajas/muertos asociados. ¿Deseas continuar?'
            : 'Se eliminará esta alta y sus animales asociados. Esta acción no se puede deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: hasBajasOrMuertos
                ? const Color(0xFFC94F6D)
                : AppColors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            hasBajasOrMuertos
                ? 'Eliminar alta y bajas/muertos'
                : 'Eliminar alta',
          ),
        ),
      ],
    ),
  );

  if (deleted != true || !context.mounted) {
    return;
  }

  try {
    await ref
        .read(animalesRepositoryProvider)
        .eliminarAltaAnimales(alta.id, deleteBajas: hasBajasOrMuertos);
    invalidateAnimalesInventoryMutationProviders(ref, granjaId);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasBajasOrMuertos
              ? 'Alta, animales y bajas/muertos eliminados'
              : 'Alta eliminada',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo eliminar el alta: $error')),
    );
  }
}

// ─── Definición de tabs ──────────────────────────────────────────────────────
enum _Tab { grupos, animales, altas, bajas, tipos }

const _tabLabel = {
  _Tab.grupos: 'Grupos',
  _Tab.animales: 'Animales',
  _Tab.altas: 'Altas',
  _Tab.bajas: 'Bajas',
  _Tab.tipos: 'Tipos',
};

const _tabIcon = {
  _Tab.grupos: Icons.create_new_folder_outlined,
  _Tab.animales: Icons.tag,
  _Tab.altas: Icons.inventory_2_outlined,
  _Tab.bajas: Icons.remove_circle_outline,
  _Tab.tipos: Icons.layers_outlined,
};

// ─────────────────────────────────────────────────────────────────────────────
class AnimalesScreen extends ConsumerStatefulWidget {
  final String granjaId;
  const AnimalesScreen({super.key, required this.granjaId});

  @override
  ConsumerState<AnimalesScreen> createState() => _AnimalesScreenState();
}

class _AnimalesScreenState extends ConsumerState<AnimalesScreen> {
  // ── Tab / Page ──────────────────────────────────────────────────────────────
  late final PageController _pageCtrl;
  _Tab _activeTab = _Tab.grupos;

  // ── Estado de grupos ────────────────────────────────────────────────────────
  final Set<String> _expandidos = {};
  final Set<String> _colapsados = {};

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: _Tab.values.indexOf(_Tab.grupos));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goToTab(_Tab tab) {
    setState(() => _activeTab = tab);
    _pageCtrl.animateToPage(
      _Tab.values.indexOf(tab),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _toggleExpand(String id) => setState(
    () =>
        _expandidos.contains(id) ? _expandidos.remove(id) : _expandidos.add(id),
  );

  void _toggleColapso(String id) => setState(
    () =>
        _colapsados.contains(id) ? _colapsados.remove(id) : _colapsados.add(id),
  );

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    final tiposAsync = ref.watch(tiposAnimalProvider(widget.granjaId));
    final gruposAsync = ref.watch(gruposProvider(widget.granjaId));
    final conteosAsync = ref.watch(conteosGruposProvider(widget.granjaId));
    final noGroupOverviewAsync = ref.watch(
      noGroupOverviewProvider(widget.granjaId),
    );

    final tipos = tiposAsync.value ?? [];
    final grupos = gruposAsync.value ?? [];
    final tipoFiltro = ref.watch(tipoFiltroProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bg : AppColors.bgCard3Lg,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar personalizado ───────────────────────────────────
            _AppBarSection(
              isDark: isDark,
              activeTab: _activeTab,
              onTabSelected: _goToTab,
            ),

            // ── PageView de secciones ──────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) =>
                    setState(() => _activeTab = _Tab.values[i]),
                // Mantiene el estado de cada página al deslizar
                children: [
                  // ── Grupos ──────────────────────────────────────────
                  _GruposTab(
                    granjaId: widget.granjaId,
                    tipoFiltro: tipoFiltro,
                    tiposAsync: tiposAsync,
                    gruposAsync: gruposAsync,
                    conteosAsync: conteosAsync,
                    noGroupOverviewAsync: noGroupOverviewAsync,
                    tipos: tipos,
                    expandidos: _expandidos,
                    colapsados: _colapsados,
                    onToggleExpand: _toggleExpand,
                    onToggleColapso: _toggleColapso,
                    isDark: isDark,
                  ),
                  // ── Animales ──────────────────────────────────────
                  _EjemplaresTab(
                    granjaId: widget.granjaId,
                    tipoFiltro: tipoFiltro,
                    tipos: tipos,
                    isDark: isDark,
                  ),
                  // ── Altas ───────────────────────────────────────────
                  _LotesTab(
                    granjaId: widget.granjaId,
                    tipoFiltro: tipoFiltro,
                    tipos: tipos,
                    grupos: grupos,
                    isDark: isDark,
                  ),
                  // ── Bajas ────────────────────────────────────────────
                  _BajasTab(
                    granjaId: widget.granjaId,
                    tipoFiltro: tipoFiltro,
                    tipos: tipos,
                    isDark: isDark,
                  ),
                  // ── Tipos ───────────────────────────────────────────
                  _TiposTab(
                    granjaId: widget.granjaId,
                    tipos: tipos,
                    grupos: grupos,
                    conteos: conteosAsync.value ?? {},
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(context, isDark),
    );
  }

  Widget _buildFab(BuildContext context, bool isDark) {
    final filteredTypeId = ref.read(tipoFiltroProvider) == 'all'
        ? null
        : ref.read(tipoFiltroProvider);

    final action = switch (_activeTab) {
      _Tab.grupos => _ContextualFabAction(
        key: 'grupos',
        icon: Icons.create_new_folder_outlined,
        label: 'Nuevo grupo',
        backgroundColor: AppColors.green,
        foregroundColor: isDark ? AppColors.bg : AppColors.bgInputLg,
        onPressed: () => _openSheet(context, NuevoGrupo(isDark: isDark)),
      ),
      _Tab.animales => _ContextualFabAction(
        key: 'animales',
        icon: Icons.add,
        label: 'Nuevo animal',
        backgroundColor: AppColors.green,
        foregroundColor: isDark ? AppColors.bg : AppColors.bgInputLg,
        onPressed: () => _openSheet(
          context,
          AnimalRegistrationSheet(
            granjaId: widget.granjaId,
            isDark: isDark,
            initialQuantity: 1,
            tipoAnimalIdInicial: filteredTypeId,
          ),
        ),
      ),
      _Tab.altas => _ContextualFabAction(
        key: 'altas',
        icon: Icons.inventory_2_outlined,
        label: 'Nueva alta',
        backgroundColor: AppColors.naranjao,
        foregroundColor: AppColors.bg,
        onPressed: () => _openSheet(
          context,
          AnimalRegistrationSheet(
            granjaId: widget.granjaId,
            isDark: isDark,
            initialQuantity: 2,
            tipoAnimalIdInicial: filteredTypeId,
          ),
        ),
      ),
      _Tab.bajas => _ContextualFabAction(
        key: 'bajas',
        icon: Icons.remove_circle,
        label: 'Nueva baja',
        backgroundColor: const Color(0xFFC94F6D),
        foregroundColor: Colors.white,
        onPressed: () => _openSheet(
          context,
          RegistrarBajaSheet(
            granjaId: widget.granjaId,
            isDark: isDark,
            tipoAnimalIdInicial: filteredTypeId,
          ),
        ),
      ),
      _Tab.tipos => _ContextualFabAction(
        key: 'tipos',
        icon: Icons.label_outline,
        label: 'Nuevo tipo',
        backgroundColor: const Color(0xFF5865F2),
        foregroundColor: Colors.white,
        onPressed: () => _openSheet(context, NuevoAnimal(isDark: isDark)),
      ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: FloatingActionButton.extended(
        key: ValueKey(action.key),
        heroTag: 'animales-fab-${action.key}',
        backgroundColor: action.backgroundColor,
        foregroundColor: action.foregroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onPressed: action.onPressed,
        icon: Icon(action.icon),
        label: Text(action.label),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, Widget child) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR: título + botón filtro + ajustes + choice chips de tabs
// ─────────────────────────────────────────────────────────────────────────────
class _AppBarSection extends StatelessWidget {
  final bool isDark;
  final _Tab activeTab;
  final ValueChanged<_Tab> onTabSelected;

  const _AppBarSection({
    required this.isDark,
    required this.activeTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Fila título ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
          child: Row(
            children: [
              // Logo placeholder (igual al HomeScreen)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.egg_alt_outlined,
                  size: 20,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Aves',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.textPrimaryLg,
                ),
              ),
              // El botón de filtro por tipo y el de ajustes viven ahora en la
              // barra superior del HomeScreen (junto al título "Granjas"),
              // para no duplicar controles entre las dos barras.
            ],
          ),
        ),

        // ── Choice chips de tabs ─────────────────────────────────────
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _Tab.values.map((tab) {
              final sel = tab == activeTab;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onTabSelected(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 0,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? (isDark ? AppColors.naranjao : AppColors.naranjal)
                          : (isDark ? AppColors.bgCard : AppColors.bgLight),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _tabIcon[tab]!,
                          size: 14,
                          color: sel
                              ? (isDark
                                    ? AppColors.textPrimaryLg
                                    : AppColors.textPrimary)
                              : (isDark
                                    ? AppColors.textSecondary
                                    : AppColors.textSecondaryLg),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _tabLabel[tab]!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel
                                ? (isDark
                                      ? AppColors.textPrimaryLg
                                      : AppColors.textPrimary)
                                : (isDark
                                      ? AppColors.textSecondary
                                      : AppColors.textSecondaryLg),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: GRUPOS
// ─────────────────────────────────────────────────────────────────────────────
class _GruposTab extends ConsumerWidget {
  final String granjaId;
  final String tipoFiltro;
  final AsyncValue<List<TipoAnimal>> tiposAsync;
  final AsyncValue<List<Grupo>> gruposAsync;
  final AsyncValue<Map<String, GrupoConteo>> conteosAsync;
  final AsyncValue<NoGroupOverview> noGroupOverviewAsync;
  final List<TipoAnimal> tipos;
  final Set<String> expandidos;
  final Set<String> colapsados;
  final ValueChanged<String> onToggleExpand;
  final ValueChanged<String> onToggleColapso;
  final bool isDark;

  const _GruposTab({
    required this.granjaId,
    required this.tipoFiltro,
    required this.tiposAsync,
    required this.gruposAsync,
    required this.conteosAsync,
    required this.noGroupOverviewAsync,
    required this.tipos,
    required this.expandidos,
    required this.colapsados,
    required this.onToggleExpand,
    required this.onToggleColapso,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return tiposAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error 1: $e')),
      data: (tipos) => gruposAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error 2: $e')),
        data: (grupos) => conteosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error 3: $e')),
          data: (conteos) => noGroupOverviewAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error 4: $e')),
            data: (noGroupOverview) {
              final gruposFiltrados = tipoFiltro == 'all'
                  ? grupos
                  : grupos.where((g) => g.tipoAnimalId == tipoFiltro).toList();
              final noGroupSummaries = noGroupOverview.typeSummaries
                  .where((summary) {
                    return tipoFiltro == 'all' ||
                        summary.tipoAnimalId == tipoFiltro;
                  })
                  .toList(growable: false);

              final totalVivos =
                  gruposFiltrados.fold<int>(
                    0,
                    (s, g) => s + (conteos[g.id]?.vivos ?? 0),
                  ) +
                  noGroupSummaries.fold<int>(
                    0,
                    (sum, summary) => sum + summary.activeCount,
                  );
              final totalMuertes =
                  gruposFiltrados.fold<int>(
                    0,
                    (s, g) => s + (conteos[g.id]?.muertes ?? 0),
                  ) +
                  noGroupSummaries.fold<int>(
                    0,
                    (sum, summary) => sum + summary.deadCount,
                  );

              final hasNoGroupCard = noGroupSummaries.isNotEmpty;

              return CustomScrollView(
                slivers: [
                  // Stats
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          _StatTile(
                            value: '$totalVivos',
                            label: 'Aves vivas',
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 10),
                          _StatTile(
                            value: '${gruposFiltrados.length}',
                            label: 'Grupos',
                            color: const Color(0xFF4B5563),
                          ),
                          const SizedBox(width: 10),
                          _StatTile(
                            value: '$totalMuertes',
                            label: 'Muertes',
                            color: const Color(0xFF7C3F2B),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (hasNoGroupCard)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _NoGroupCard(
                          overview: noGroupOverview,
                          tipos: tipos,
                          granjaId: granjaId,
                          tipoFiltro: tipoFiltro,
                          expandidos: expandidos,
                          colapsados: colapsados,
                          onToggleExpand: onToggleExpand,
                          onToggleColapso: onToggleColapso,
                          isDark: isDark,
                        ),
                      ),
                    ),

                  if (gruposFiltrados.isEmpty && !hasNoGroupCard)
                    SliverToBoxAdapter(child: _EmptyState(tipos: tipos))
                  else if (gruposFiltrados.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final grupo = gruposFiltrados[i];
                          final conteo =
                              conteos[grupo.id] ??
                              const GrupoConteo(vivos: 0, muertes: 0, total: 0);
                          final color = _colorParaTipo(
                            grupo.tipoAnimalId,
                            tipos,
                          );
                          final tipo = tipos.firstWhere(
                            (t) => t.id == grupo.tipoAnimalId,
                            orElse: () => TipoAnimal(
                              id: '',
                              granjaId: '',
                              nombre: '',
                              createdBy: '',
                            ),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _GrupoCard(
                              onTap: () => showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => NuevoGrupo(
                                  isDark: isDark,
                                  tipoAnimalIdInicial: grupo.tipoAnimalId,
                                  initialGroup: grupo,
                                ),
                              ),
                              onLongPress: () {
                                ConfirmationDialog.show(
                                  context: context,
                                  isDark: isDark,
                                  title: 'Eliminar Grupo',
                                  content:
                                      '¿Estás seguro de que deseas eliminar el grupo "${grupo.nombre}"? Esta acción no se puede deshacer.',
                                  onConfirm: () async {
                                    try {
                                      await ref
                                          .read(animalesRepositoryProvider)
                                          .deleteGrupo(
                                            farmId: granjaId,
                                            grupoId: grupo.id,
                                          );

                                      ref.invalidate(gruposProvider(granjaId));
                                      invalidateAnimalesInventoryMutationProviders(
                                        ref,
                                        granjaId,
                                      );
                                    } catch (e) {
                                      print('Error al eliminar granja: $e');
                                    }
                                  },
                                );
                              },

                              grupo: grupo,
                              tipo: tipo,
                              conteo: conteo,
                              stripColor: color,
                              expandido: expandidos.contains(grupo.id),
                              colapsado: colapsados.contains(grupo.id),
                              onToggleExpand: () => onToggleExpand(grupo.id),
                              onToggleColapso: () => onToggleColapso(grupo.id),
                              granjaId: granjaId,
                              isDark: isDark,
                            ),
                          );
                        }, childCount: gruposFiltrados.length),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: EJEMPLARES
// ─────────────────────────────────────────────────────────────────────────────
class _EjemplaresTab extends ConsumerStatefulWidget {
  final String granjaId;
  final String tipoFiltro;
  final List<TipoAnimal> tipos;
  final bool isDark;

  const _EjemplaresTab({
    required this.granjaId,
    required this.tipoFiltro,
    required this.tipos,
    required this.isDark,
  });

  @override
  ConsumerState<_EjemplaresTab> createState() => _EjemplaresTabState();
}

class _EjemplaresTabState extends ConsumerState<_EjemplaresTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _soloActivos = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _abrirFormulario({Animal? ejemplar}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => NuevoEjemplar(
        granjaId: widget.granjaId,
        isDark: widget.isDark,
        ejemplar: ejemplar,
        tipoAnimalIdInicial: widget.tipoFiltro == 'all'
            ? null
            : widget.tipoFiltro,
      ),
    );
  }

  void _confirmarEliminar(Animal ejemplar) {
    ConfirmationDialog.show(
      context: context,
      isDark: widget.isDark,
      title: 'Eliminar ejemplar',
      content:
          '¿Seguro que deseas eliminar el ejemplar #${ejemplar.brazalete} '
          '(${ejemplar.tipoNombre})? Esta acción no se puede deshacer.',
      onConfirm: () async {
        try {
          await ref
              .read(animalesRepositoryProvider)
              .deleteEjemplar(ejemplar.id);
          ref.invalidate(animalesProvider(widget.granjaId));
          ref.invalidate(conteosGruposProvider(widget.granjaId));
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ejemplaresAsync = ref.watch(animalesProvider(widget.granjaId));

    return ejemplaresAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (ejemplares) {
        var lista = widget.tipoFiltro == 'all'
            ? ejemplares
            : ejemplares
                  .where((e) => e.tipoAnimalId == widget.tipoFiltro)
                  .toList();

        if (_soloActivos) {
          lista = lista.where((e) => e.activo).toList();
        }

        if (_query.trim().isNotEmpty) {
          final q = _query.trim().toLowerCase();
          lista = lista.where((e) {
            return e.brazalete.toString().contains(q) ||
                e.tipoNombre.toLowerCase().contains(q) ||
                e.grupoNombre.toLowerCase().contains(q);
          }).toList();
        }

        return CustomScrollView(
          slivers: [
            // Buscador
            /* SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SearchField(
                  controller: _searchCtrl,
                  hint: 'Buscar brazalete, tipo o grupo…',
                  isDark: widget.isDark,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ), */

            // Toggle Activos / Todos
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: _SegmentedToggle(
                  isDark: widget.isDark,
                  options: const ['Activos', 'Todos'],
                  selectedIndex: _soloActivos ? 0 : 1,
                  onSelected: (i) => setState(() => _soloActivos = i == 0),
                ),
              ),
            ),

            if (lista.isEmpty)
              SliverToBoxAdapter(
                child: _TabPlaceholder(
                  icon: Icons.tag,
                  titulo: 'Sin animales',
                  subtitulo: ejemplares.isEmpty
                      ? 'Registra un animal o un alta para verlos aquí'
                      : 'Ningún animal coincide con la búsqueda',
                  isDark: widget.isDark,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final ej = lista[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EjemplarCard(
                        ejemplar: ej,
                        isDark: widget.isDark,
                        onTap: () => _abrirFormulario(ejemplar: ej),
                        onLongPress: () => _confirmarEliminar(ej),
                      ),
                    );
                  }, childCount: lista.length),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Card individual de un ejemplar (brazalete + tipo + grupo + fecha + estado)
class _EjemplarCard extends StatelessWidget {
  final Animal ejemplar;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _EjemplarCard({
    required this.ejemplar,
    required this.isDark,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMMM yyyy");
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.bgCard : AppColors.bgLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.border1lg : AppColors.border1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tag, size: 16, color: AppColors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${ejemplar.brazalete} · ${ejemplar.tipoNombre}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.textPrimaryLg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ejemplar.grupoNombre} · ${fmt.format(ejemplar.fechaAdquisicion)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLg,
                      ),
                    ),
                  ],
                ),
              ),
              _EstadoBadge(activo: ejemplar.activo),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final bool activo;
  const _EstadoBadge({required this.activo});

  @override
  Widget build(BuildContext context) {
    final color = activo ? AppColors.green : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        activo ? 'Activo' : 'Baja',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3: LOTES
// ─────────────────────────────────────────────────────────────────────────────
class _LotesTab extends ConsumerWidget {
  final String granjaId;
  final String tipoFiltro;
  final List<TipoAnimal> tipos;
  final List<Grupo> grupos;
  final bool isDark;

  const _LotesTab({
    required this.granjaId,
    required this.tipoFiltro,
    required this.tipos,
    required this.grupos,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filtra grupos por tipo activo
    final gruposFiltrados = tipoFiltro == 'all'
        ? grupos
        : grupos.where((g) => g.tipoAnimalId == tipoFiltro).toList();

    if (grupos.isEmpty) {
      return _TabPlaceholder(
        icon: Icons.inventory_2_outlined,
        titulo: 'Sin altas',
        subtitulo: 'Crea un grupo primero',
        isDark: isDark,
      );
    }

    return CustomScrollView(
      slivers: [
        // Barra de búsqueda (visual — implementa lógica si la necesitas)
        /* SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgCard : AppColors.bgLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.border1lg : AppColors.border1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 18,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLg,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Buscar por tipo, grupo o proveedor…',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ), */

        // Un bloque de lotes por grupo
        ...gruposFiltrados.map((grupo) {
          final tipo = tipos.firstWhere(
            (t) => t.id == grupo.tipoAnimalId,
            orElse: () =>
                TipoAnimal(id: '', granjaId: '', nombre: '', createdBy: ''),
          );
          return _LotesDeGrupoSliver(grupo: grupo, tipo: tipo, isDark: isDark);
        }),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

/// Sliver que carga lazy los lotes de un grupo
class _LotesDeGrupoSliver extends ConsumerWidget {
  final Grupo grupo;
  final TipoAnimal tipo;
  final bool isDark;

  const _LotesDeGrupoSliver({
    required this.grupo,
    required this.tipo,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotesAsync = ref.watch(lotesDeGrupoProvider(grupo.id));

    return SliverToBoxAdapter(
      child: lotesAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (lotes) {
          if (lotes.isEmpty) return const SizedBox.shrink();
          return Column(
            children: lotes
                .map(
                  (l) => _LoteTabCard(
                    lote: l,
                    tipoNombre: tipo.nombre,
                    grupoNombre: grupo.nombre,
                    isDark: isDark,
                    onTap: () => _showAltaEditor(
                      context: context,
                      granjaId: grupo.granjaId,
                      isDark: isDark,
                      alta: l,
                    ),
                    onLongPress: () => _showAltaDeleteConfirmation(
                      context: context,
                      ref: ref,
                      granjaId: grupo.granjaId,
                      alta: l,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

/// Card de lote en la tab de Lotes (diseño compacto de lista)
class _LoteTabCard extends StatelessWidget {
  final AltaAnimales lote;
  final String tipoNombre;
  final String grupoNombre;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _LoteTabCard({
    required this.lote,
    required this.tipoNombre,
    required this.grupoNombre,
    required this.isDark,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMMM yyyy");
    final vivos = lote.vivosCount;
    final muertos = lote.muertosCount;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgCard : AppColors.bgLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.border1lg : AppColors.border1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: AppColors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$tipoNombre · $grupoNombre',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.textPrimaryLg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fmt.format(lote.fechaAlta),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLg,
                    ),
                  ),
                  if (lote.proveedor != null || lote.costoTotal != null)
                    Text(
                      [
                        lote.tipoAdquisicionId,
                        if (lote.proveedor != null) lote.proveedor!,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.green,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _animalCountText(vivos, singular: 'vivo', plural: 'vivos'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLg,
                  ),
                ),
                Text(
                  _animalCountText(
                    muertos,
                    singular: 'muerto',
                    plural: 'muertos',
                  ),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLg,
                  ),
                ),
              ],
            ),
            /* _CardMenu(
              size: 16,
              isDark: isDark,
              onEdit: onTap ?? () {},
              onDelete: onLongPress ?? () {},
            ), */
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4: TIPOS
// ─────────────────────────────────────────────────────────────────────────────
class _TiposTab extends ConsumerWidget {
  final String granjaId;
  final List<TipoAnimal> tipos;
  final List<Grupo> grupos;
  final Map<String, GrupoConteo> conteos;
  final bool isDark;

  const _TiposTab({
    required this.granjaId,
    required this.tipos,
    required this.grupos,
    required this.conteos,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tipos.isEmpty) {
      return _TabPlaceholder(
        icon: Icons.layers_outlined,
        titulo: 'Sin tipos',
        subtitulo: 'Crea el primer tipo de animal con el botón +',
        isDark: isDark,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: tipos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final tipo = tipos[i];
        final gruposDeTipo = grupos
            .where((g) => g.tipoAnimalId == tipo.id)
            .toList();
        final vivos = gruposDeTipo.fold<int>(
          0,
          (s, g) => s + (conteos[g.id]?.vivos ?? 0),
        );
        final color = _colorParaTipo(tipo.id, tipos);

        return GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => NuevoAnimal(isDark: isDark, initialTipo: tipo),
          ),
          onLongPress: () {
            ConfirmationDialog.show(
              context: context,
              isDark: isDark,
              title: 'Eliminar Tipo',
              content:
                  '¿Estás seguro de que deseas eliminar el Tipo "${tipo.nombre}"? Esta acción no se puede deshacer.',
              onConfirm: () async {
                try {
                  await ref
                      .read(animalesRepositoryProvider)
                      .deleteTipoAnimal(farmId: granjaId, tipoId: tipo.id);

                  ref.invalidate(tiposAnimalProvider(granjaId));
                  ref.invalidate(gruposProvider(granjaId));
                  invalidateAnimalesInventoryMutationProviders(ref, granjaId);
                } catch (e) {
                  print('Error al eliminar Tipo: $e');
                }
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgCard : AppColors.bgLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.border1lg : AppColors.border1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tipo.nombre,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.textPrimaryLg,
                        ),
                      ),
                      Text(
                        '${gruposDeTipo.length} grupos · $vivos vivos',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLg,
                        ),
                      ),
                      if (tipo.descripcion != null)
                        Text(
                          tipo.descripcion!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLg,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                /* _CardMenu(
                  isDark: isDark,
                  onEdit: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) =>
                        NuevoAnimal(isDark: isDark, initialTipo: tipo),
                  ),
                  onDelete: () {
                    ConfirmationDialog.show(
                      context: context,
                      isDark: isDark,
                      title: 'Eliminar Tipo',
                      content:
                          '¿Estás seguro de que deseas eliminar el Tipo "${tipo.nombre}"? Esta acción no se puede deshacer.',
                      onConfirm: () async {
                        try {
                          await ref
                              .read(animalesRepositoryProvider)
                              .deleteTipoAnimal(
                                farmId: granjaId,
                                tipoId: tipo.id,
                              );
                          ref.invalidate(tiposAnimalProvider(granjaId));
                          ref.invalidate(gruposProvider(granjaId));
                          invalidateAnimalesInventoryMutationProviders(
                            ref,
                            granjaId,
                          );
                        } catch (e) {
                          print('Error al eliminar Tipo: $e');
                        }
                      },
                    );
                  },
                ), */
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 5: BAJAS
// ─────────────────────────────────────────────────────────────────────────────
class _BajasTab extends ConsumerStatefulWidget {
  final String granjaId;
  final String tipoFiltro;
  final List<TipoAnimal> tipos;
  final bool isDark;

  const _BajasTab({
    required this.granjaId,
    required this.tipoFiltro,
    required this.tipos,
    required this.isDark,
  });

  @override
  ConsumerState<_BajasTab> createState() => _BajasTabState();
}

class _BajasTabState extends ConsumerState<_BajasTab> {
  @override
  Widget build(BuildContext context) {
    final bajasAsync = ref.watch(bajasAnimalesProvider(widget.granjaId));

    return bajasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (todasLasBajas) {
        final bajas = widget.tipoFiltro == 'all'
            ? todasLasBajas
            : todasLasBajas
                  .where((b) => b.tipoAnimalId == widget.tipoFiltro)
                  .toList();

        final totalAves = bajas.fold<int>(
          0,
          (sum, b) => sum + b.cantidadAnimales,
        );
        final totalEventos = bajas.length;

        return CustomScrollView(
          slivers: [
            // ── Stat card de resumen ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: _BajasResumenCard(
                  totalAves: totalAves,
                  eventos: totalEventos,
                  isDark: widget.isDark,
                ),
              ),
            ),

            if (bajas.isEmpty)
              SliverToBoxAdapter(
                child: _TabPlaceholder(
                  icon: Icons.remove_circle_outline,
                  titulo: 'Sin bajas',
                  subtitulo: 'El historial de bajas aparecerá aquí',
                  isDark: widget.isDark,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BajaEventoCard(
                        baja: bajas[i],
                        isDark: widget.isDark,
                        onTap: () => _editarBaja(bajas[i]),
                        onLongPress: () => _confirmarBorrado(bajas[i]),
                      ),
                    ),
                    childCount: bajas.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        );
      },
    );
  }

  void _editarBaja(BajaAnimal baja) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditarBajaSheet(baja: baja, isDark: widget.isDark),
    );
  }

  Future<void> _confirmarBorrado(BajaAnimal baja) async {
    ConfirmationDialog.show(
      context: context,
      isDark: widget.isDark,
      title: 'Eliminar baja',
      content: baja.esLote
          ? '¿Deseas eliminar esta baja de ${baja.cantidadAnimales} animales? Los animales afectados volverán a estar activos.'
          : '¿Deseas eliminar esta baja? El animal afectado volverá a estar activo.',
      onConfirm: () async {
        try {
          await ref.read(animalesRepositoryProvider).eliminarBaja(baja.id);
          invalidateAnimalesInventoryMutationProviders(ref, widget.granjaId);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Baja eliminada')));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
          }
        }
      },
    );
  }
}

/// Card de resumen con el total de aves dadas de baja y el número de eventos.
class _BajasResumenCard extends StatelessWidget {
  final int totalAves;
  final int eventos;
  final bool isDark;
  const _BajasResumenCard({
    required this.totalAves,
    required this.eventos,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.heart_broken_outlined,
              size: 20,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$totalAves',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLg,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'aves dadas de baja',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$eventos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.textPrimaryLg,
                ),
              ),
              Text(
                'eventos',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondaryLg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card de un evento de baja. Funciona tanto para bajas de 1 animal como
/// para bajas masivas (`cantidadAnimales > 1`); el diseño es el mismo,
/// solo cambia el badge y el texto de brazaletes.
class _BajaEventoCard extends StatelessWidget {
  final BajaAnimal baja;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BajaEventoCard({
    required this.baja,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMMM yyyy");
    final color = baja.esMuerte ? Colors.redAccent : Colors.orangeAccent;
    final helperColor = isDark
        ? AppColors.textSecondary
        : AppColors.textSecondaryLg;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgCard : AppColors.bgLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.border1lg : AppColors.border1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _RazonTag(label: baja.razonNombre, color: color),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.calendar_today,
                        size: 11,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLg,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        fmt.format(baja.fechaBaja),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLg,
                        ),
                      ),
                      if (baja.esLote) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isDark ? AppColors.bgCard2 : AppColors.border1)
                                    .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'LOTE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondaryLg,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    baja.grupoNombre != null
                        ? '${baja.tipoNombre} · ${baja.grupoNombre}'
                        : baja.tipoNombre,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.textPrimaryLg,
                    ),
                  ),
                  if (baja.brazaletes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      baja.brazaletes.map((b) => '#$b').join(', '),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLg,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (baja.notas != null && baja.notas!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      baja.notas!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLg,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${baja.cantidadAnimales}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLg,
                  ),
                ),
                Text(
                  baja.cantidadAnimales == 1 ? 'ave' : 'aves',
                  style: TextStyle(fontSize: 10, color: helperColor),
                ),
                if (baja.importeTotal != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '\$${baja.importeTotal!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ],
                /* const SizedBox(height: 10),
                _BajaCardActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Editar',
                  isDark: isDark,
                  onTap: onTap,
                ),
                const SizedBox(height: 6),
                _BajaCardActionButton(
                  icon: Icons.delete_outline,
                  label: 'Mantén para eliminar',
                  isDark: isDark,
                  color: Colors.redAccent,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Mantén presionada la card para confirmar la eliminación.',
                      ),
                    ),
                  ),
                  onLongPress: onLongPress,
                ), */
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pequeña etiqueta de razón de baja (Muerte / Sacrificio / etc.)
class _RazonTag extends StatelessWidget {
  final String label;
  final Color color;
  const _RazonTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.isEmpty ? 'Baja' : label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES COMPARTIDOS: buscador y toggle segmentado
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentedToggle extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isDark;

  const _SegmentedToggle({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard2 : AppColors.bgLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(options.length, (i) {
          final sel = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? AppColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  options[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel
                        ? Colors.white
                        : (isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLg),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER GENÉRICO DE TAB VACÍA
// ─────────────────────────────────────────────────────────────────────────────
class _TabPlaceholder extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final bool isDark;

  const _TabPlaceholder({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AppColors.green),
          ),
          const SizedBox(height: 16),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLg,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitulo,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE GRUPO (igual a antes, se mantiene en tab Grupos)
// ─────────────────────────────────────────────────────────────────────────────
class _NoGroupCard extends StatelessWidget {
  const _NoGroupCard({
    required this.overview,
    required this.tipos,
    required this.granjaId,
    required this.tipoFiltro,
    required this.expandidos,
    required this.colapsados,
    required this.onToggleExpand,
    required this.onToggleColapso,
    required this.isDark,
  });

  final NoGroupOverview overview;
  final List<TipoAnimal> tipos;
  final String granjaId;
  final String tipoFiltro;
  final Set<String> expandidos;
  final Set<String> colapsados;
  final ValueChanged<String> onToggleExpand;
  final ValueChanged<String> onToggleColapso;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final summariesByType = {
      for (final summary in overview.typeSummaries)
        summary.tipoAnimalId: summary,
    };

    final visibleSummaries = [
      for (final tipo in tipos)
        if ((tipoFiltro == 'all' || tipo.id == tipoFiltro) &&
            summariesByType.containsKey(tipo.id))
          (tipo: tipo, summary: summariesByType[tipo.id]!),
    ];

    return Column(
      children: [
        for (final item in visibleSummaries) ...[
          _NoGroupTypeCard(
            granjaId: granjaId,
            tipo: item.tipo,
            summary: item.summary,
            stripColor: _colorParaTipo(item.tipo.id, tipos),
            expandido: expandidos.contains('no-group-altas-${item.tipo.id}'),
            colapsado: colapsados.contains('no-group-${item.tipo.id}'),
            onToggleExpand: () =>
                onToggleExpand('no-group-altas-${item.tipo.id}'),
            onToggleColapso: () => onToggleColapso('no-group-${item.tipo.id}'),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _NoGroupTypeCard extends StatelessWidget {
  const _NoGroupTypeCard({
    required this.granjaId,
    required this.tipo,
    required this.summary,
    required this.stripColor,
    required this.expandido,
    required this.colapsado,
    required this.onToggleExpand,
    required this.onToggleColapso,
    required this.isDark,
  });

  final String granjaId;
  final TipoAnimal tipo;
  final NoGroupTypeOverview summary;
  final Color stripColor;
  final bool expandido;
  final bool colapsado;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleColapso;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final total = summary.activeCount + summary.deadCount;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgCard : AppColors.bgLight,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.only(
              top: 16,
              left: 16,
              right: 48,
              bottom: 16,
            ),
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
                          Text(
                            'Sin grupo',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.textPrimaryLg,
                            ),
                          ),
                          if (!colapsado)
                            Text(
                              total == 1
                                  ? '1 animal sin asignar a un grupo'
                                  : '$total animales sin asignar a un grupo',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.textSecondaryLg,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.egg_outlined,
                          size: 22,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.textPrimaryLg,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${summary.activeCount}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimary
                                : AppColors.textPrimaryLg,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            colapsado ? Icons.expand_more : Icons.expand_less,
                            color: isDark
                                ? AppColors.textPrimary
                                : AppColors.textPrimaryLg,
                          ),
                          onPressed: onToggleColapso,
                        ),
                      ],
                    ),
                  ],
                ),
                if (!colapsado) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.egg_outlined,
                          value: '${summary.activeCount}',
                          label: 'Vivos',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.tag,
                          value: '$total',
                          label: 'Aves',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.one_x_mobiledata_rounded,
                          value: '${summary.deadCount}',
                          label: 'Muertes',
                          danger: true,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _NoGroupAltasSection(
                    granjaId: granjaId,
                    altas: summary.latestAltas,
                    expandido: expandido,
                    onToggle: onToggleExpand,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.add,
                          label: 'Animal',
                          isDark: isDark,
                          onTap: () => showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => AnimalRegistrationSheet(
                              granjaId: granjaId,
                              isDark: isDark,
                              initialQuantity: 1,
                              tipoAnimalIdInicial: tipo.id,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.inventory_2_outlined,
                          label: 'Alta',
                          isDark: isDark,
                          onTap: () => showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => AnimalRegistrationSheet(
                              granjaId: granjaId,
                              isDark: isDark,
                              initialQuantity: 2,
                              tipoAnimalIdInicial: tipo.id,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.one_x_mobiledata_rounded,
                          label: 'Baja',
                          danger: true,
                          isDark: isDark,
                          onTap: () => showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => RegistrarBajaSheet(
                              granjaId: granjaId,
                              isDark: isDark,
                              tipoAnimalIdInicial: tipo.id,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 32,
              color: stripColor,
              alignment: Alignment.center,
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  tipo.nombre,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoGroupAltasSection extends ConsumerWidget {
  const _NoGroupAltasSection({
    required this.granjaId,
    required this.altas,
    required this.expandido,
    required this.onToggle,
    required this.isDark,
  });

  final String granjaId;
  final List<AltaAnimales> altas;
  final bool expandido;
  final VoidCallback onToggle;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgCard2 : AppColors.bgCardLg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.border1lg : AppColors.border1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  expandido ? Icons.expand_less : Icons.chevron_right,
                  size: 16,
                  color: isDark ? AppColors.bgInputLg : AppColors.bg,
                ),
                const SizedBox(width: 6),
                Text(
                  expandido
                      ? 'Ocultar últimas 3 altas'
                      : 'Ver últimas 3 altas sin grupo',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.bgInputLg : AppColors.bg,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expandido)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: altas.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Aún no hay altas sin grupo.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLg,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    children: altas
                        .map(
                          (alta) => _LoteCard(
                            lote: alta,
                            isDark: isDark,
                            onTap: () => _showAltaEditor(
                              context: context,
                              granjaId: granjaId,
                              isDark: isDark,
                              alta: alta,
                            ),
                            onLongPress: () => _showAltaDeleteConfirmation(
                              context: context,
                              ref: ref,
                              granjaId: granjaId,
                              alta: alta,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
      ],
    );
  }
}

class _GrupoCard extends ConsumerWidget {
  final Grupo grupo;
  final TipoAnimal tipo;
  final GrupoConteo conteo;
  final Color stripColor;
  final bool expandido, colapsado, isDark;
  final VoidCallback onTap, onToggleExpand, onToggleColapso, onLongPress;
  final String granjaId;

  const _GrupoCard({
    required this.grupo,
    required this.tipo,
    required this.conteo,
    required this.onTap,
    required this.stripColor,
    required this.expandido,
    required this.colapsado,
    required this.onToggleExpand,
    required this.onToggleColapso,
    required this.granjaId,
    required this.isDark,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgCard : AppColors.bgLight,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.only(
                top: 16,
                left: 16,
                right: 48,
                bottom: 16,
              ),
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
                            Text(
                              grupo.nombre,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textPrimary
                                    : AppColors.textPrimaryLg,
                              ),
                            ),
                            if (grupo.descripcion != null && !colapsado)
                              Text(
                                grupo.descripcion!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.textSecondaryLg,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.egg_outlined,
                            size: 22,
                            color: isDark
                                ? AppColors.textPrimary
                                : AppColors.textPrimaryLg,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${conteo.vivos}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.textPrimaryLg,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              colapsado ? Icons.expand_more : Icons.expand_less,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.textPrimaryLg,
                            ),
                            onPressed: onToggleColapso,
                          ),
                          /* _CardMenu(
                            size: 18,
                            isDark: isDark,
                            onEdit: onTap,
                            onDelete: onLongPress,
                          ), */
                        ],
                      ),
                    ],
                  ),
                  if (!colapsado) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.egg_outlined,
                            value: '${conteo.vivos}',
                            label: 'Vivos',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.tag,
                            value: '${conteo.total}',
                            label: 'Brazaletes',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.one_x_mobiledata_rounded,
                            value: '${conteo.muertes}',
                            label: 'Muertes',
                            danger: true,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _LotesSection(
                      grupoId: grupo.id,
                      expandido: expandido,
                      onToggle: onToggleExpand,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.add,
                            label: 'Animal',
                            isDark: isDark,
                            onTap: () => showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (_) => AnimalRegistrationSheet(
                                granjaId: granjaId,
                                isDark: isDark,
                                initialQuantity: 1,
                                tipoAnimalIdInicial: grupo.tipoAnimalId,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.inventory_2_outlined,
                            label: 'Alta',
                            isDark: isDark,
                            onTap: () => showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (_) => AnimalRegistrationSheet(
                                granjaId: granjaId,
                                isDark: isDark,
                                initialQuantity: 2,
                                tipoAnimalIdInicial: grupo.tipoAnimalId,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.one_x_mobiledata_rounded,
                            label: 'Baja',
                            danger: true,
                            isDark: isDark,
                            onTap: () =>
                                context.push('/bajas/nueva?grupo=${grupo.id}'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Franja de color lateral
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 32,
                color: stripColor,
                alignment: Alignment.center,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    tipo.nombre,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECCIÓN DE LOTES dentro de la card de grupo
// ─────────────────────────────────────────────────────────────────────────────
class _LotesSection extends ConsumerWidget {
  final String grupoId;
  final bool expandido, isDark;
  final VoidCallback onToggle;

  const _LotesSection({
    required this.grupoId,
    required this.expandido,
    required this.onToggle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotesAsync = expandido
        ? ref.watch(lotesDeGrupoProvider(grupoId))
        : null;

    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgCard2 : AppColors.bgCardLg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.border1lg : AppColors.border1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  expandido ? Icons.expand_less : Icons.chevron_right,
                  size: 16,
                  color: isDark ? AppColors.bgInputLg : AppColors.bg,
                ),
                const SizedBox(width: 6),
                Text(
                  expandido ? 'Ocultar altas' : 'Ver altas de animales',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.bgInputLg : AppColors.bg,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expandido && lotesAsync != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: lotesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (e, stackTrace) {
                debugPrint('❌ ERROR EN LOTES: $e');
                debugPrint('📌 STACKTRACE:\n$stackTrace');
                return Text(
                  '$lotesAsync Error: $e',
                  style: const TextStyle(color: Colors.red),
                );
              },
              data: (lotes) {
                debugPrint('Contenido de los lotes: $lotes');
                return lotes.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Aún no hay altas.',
                          style: TextStyle(fontSize: 12, color: Colors.white38),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Column(
                        children: lotes
                            .map(
                              (l) => _LoteCard(
                                lote: l,
                                isDark: isDark,
                                onTap: () => _showAltaEditor(
                                  context: context,
                                  granjaId: l.granjaId,
                                  isDark: isDark,
                                  alta: l,
                                ),
                                onLongPress: () => _showAltaDeleteConfirmation(
                                  context: context,
                                  ref: ref,
                                  granjaId: l.granjaId,
                                  alta: l,
                                ),
                              ),
                            )
                            .toList(),
                      );
              },
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE LOTE (dentro de grupo expandido)
// ─────────────────────────────────────────────────────────────────────────────
class _LoteCard extends StatelessWidget {
  final AltaAnimales lote;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const _LoteCard({
    required this.lote,
    this.isDark = true,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMMM yyyy");
    final vivos = lote.vivosCount;
    final muertos = lote.muertosCount;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgCard2 : AppColors.bgCardLg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: Colors.white54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fmt.format(lote.fechaAlta),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.bgLight : AppColors.bg,
                        ),
                      ),
                      Text(
                        [
                          lote.tipoAdquisicionId,
                          if (lote.proveedor != null) lote.proveedor!,
                          if (lote.costoTotal != null)
                            '\$${lote.costoTotal!.toStringAsFixed(0)}',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.textMutedLg
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    '${_animalCountText(vivos, singular: 'vivo', plural: 'vivos')} · '
                    '${_animalCountText(muertos, singular: 'muerto', plural: 'muertos')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                /* _CardMenu(
                  size: 18,
                  isDark: isDark,
                  onEdit: onTap ?? () {},
                  onDelete: onLongPress ?? () {},
                ), */
              ],
            ),
            if (lote.brazaletesDetalleSafe.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: lote.brazaletesDetalleSafe
                    .map(
                      (b) => _BrazaleteBadge(
                        numero: b.numero,
                        activo: b.activo,
                        isDark: isDark,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BrazaleteBadge extends StatelessWidget {
  final int numero;
  final bool activo;
  final bool isDark;
  const _BrazaleteBadge({
    required this.numero,
    required this.activo,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch ((activo, isDark)) {
      (true, true) => AppColors.bgCard,
      (true, false) => AppColors.bgLight,
      (false, _) => const Color(0x33FF5A5F),
    };
    final borderColor = switch ((activo, isDark)) {
      (true, true) => AppColors.border,
      (true, false) => AppColors.border1,
      (false, _) => const Color(0x99FF5A5F),
    };
    final textColor = activo
        ? (isDark ? AppColors.textPrimary : AppColors.textMuted)
        : const Color(0xFFFF8A8E);

    return Tooltip(
      message: activo ? 'Ejemplar vivo' : 'Ejemplar muerto',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '#$numero',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            /* if (!activo) ...[
              const SizedBox(width: 3),
              Icon(Icons.close_rounded, size: 10, color: textColor),
              const SizedBox(width: 2),
              Text(
                'baja',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ], */
          ],
        ),
      ),
    );
  }
}

String _animalCountText(
  int count, {
  required String singular,
  required String plural,
}) {
  return '$count ${count == 1 ? singular : plural}';
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS PEQUEÑOS REUTILIZABLES
// ─────────────────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final bool danger, isDark;
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    this.danger = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: isDark ? AppColors.bgCard2 : AppColors.bgCardLg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Icon(
          icon,
          size: 16,
          color: danger
              ? Colors.redAccent
              : isDark
              ? AppColors.bgLight
              : AppColors.bg,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.bgLight : AppColors.bg,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.bgLight : AppColors.bg,
          ),
        ),
      ],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger, isDark;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: danger ? Colors.red.withValues(alpha: 0.3) : AppColors.border1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 14,
            color: danger
                ? Colors.redAccent
                : isDark
                ? AppColors.bgCardLg
                : AppColors.bgCard,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: danger
                  ? Colors.redAccent
                  : isDark
                  ? AppColors.textMutedLg
                  : AppColors.textMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

/* class _CardMenu extends StatelessWidget {
  final VoidCallback onEdit, onDelete;
  final double size;
  final bool isDark;
  const _CardMenu({
    required this.onEdit,
    required this.onDelete,
    this.size = 20,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    icon: Icon(
      Icons.more_vert,
      size: size,
      color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLg,
    ),
    color: AppColors.bgCard,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
    itemBuilder: (_) => [
      const PopupMenuItem(
        value: 'edit',
        child: Text('Editar', style: TextStyle(color: Colors.white)),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
      ),
    ],
  );
} */

class _ContextualFabAction {
  const _ContextualFabAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String key;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;
}

class _EmptyState extends StatelessWidget {
  final List<TipoAnimal> tipos;
  const _EmptyState({required this.tipos});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        const Text(
          'No hay grupos todavía',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          tipos.isEmpty
              ? 'Empieza creando un tipo de animal.'
              : 'Crea un grupo para empezar a registrar ejemplares.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.add, size: 16),
          label: Text(tipos.isEmpty ? 'Crear tipo de animal' : 'Crear grupo'),
          onPressed: () =>
              context.push(tipos.isEmpty ? '/tipos/nuevo' : '/grupos/nuevo'),
        ),
      ],
    ),
  );
}
