// ─── lib/features/animales/animales_screen.dart ──────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import '../model/grupo/grupo.dart';
import '../model/loteEntrada/loteEntrada.dart';
import '../model/loteEntrada/nuevo_loteEntrada.dart';
import '../model/grupo/nuevo_grupo.dart';
import '../model/tipoAnimal/nuevo_tipoAnimal.dart';
import '../model/ejemplar/ejemplar.dart';
import '../model/bajaEjemplar/baja_ejemplar.dart';
import 'animales_provider.dart';
import 'tipo_filtro.dart';
import '/features/settings/presentation/providers/theme_provider.dart';

// ─── Helpers de color ────────────────────────────────────────────────────────
Color _colorParaTipo(String tipoId, List<TipoAnimal> tipos) {
  final idx = tipos.indexWhere((t) => t.id == tipoId);
  return AppColors.tipoColor[(idx < 0 ? 0 : idx) % AppColors.tipoColor.length];
}

// ─── Definición de tabs ──────────────────────────────────────────────────────
enum _Tab { grupos, ejemplares, lotes, tipos, bajas }

const _tabLabel = {
  _Tab.grupos: 'Grupos',
  _Tab.ejemplares: 'Ejemplares',
  _Tab.lotes: 'Lotes',
  _Tab.tipos: 'Tipos',
  _Tab.bajas: 'Bajas',
};

const _tabIcon = {
  _Tab.grupos: Icons.create_new_folder_outlined,
  _Tab.ejemplares: Icons.tag,
  _Tab.lotes: Icons.inventory_2_outlined,
  _Tab.tipos: Icons.layers_outlined,
  _Tab.bajas: Icons.remove_circle_outline,
};

// ─────────────────────────────────────────────────────────────────────────────
class AnimalesScreen extends ConsumerStatefulWidget {
  final String granjaId;
  const AnimalesScreen({super.key, required this.granjaId});

  @override
  ConsumerState<AnimalesScreen> createState() => _AnimalesScreenState();
}

class _AnimalesScreenState extends ConsumerState<AnimalesScreen>
    with SingleTickerProviderStateMixin {
  // ── Tab / Page ──────────────────────────────────────────────────────────────
  late final PageController _pageCtrl;
  _Tab _activeTab = _Tab.grupos;

  // ── Estado de grupos ────────────────────────────────────────────────────────
  final Set<String> _expandidos = {};
  final Set<String> _colapsados = {};

  // ── FAB ─────────────────────────────────────────────────────────────────────
  bool _fabOpen = false;

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
                    expandidos: _expandidos,
                    colapsados: _colapsados,
                    onToggleExpand: _toggleExpand,
                    onToggleColapso: _toggleColapso,
                    isDark: isDark,
                  ),
                  // ── Ejemplares ──────────────────────────────────────
                  _EjemplaresTab(
                    granjaId: widget.granjaId,
                    tipoFiltro: tipoFiltro,
                    tipos: tipos,
                    isDark: isDark,
                  ),
                  // ── Lotes ───────────────────────────────────────────
                  _LotesTab(
                    granjaId: widget.granjaId,
                    tipoFiltro: tipoFiltro,
                    tipos: tipos,
                    grupos: grupos,
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
                  // ── Bajas ────────────────────────────────────────────
                  _BajasTab(
                    granjaId: widget.granjaId,
                    tipoFiltro: tipoFiltro,
                    tipos: tipos,
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
    final actions = [
      (
        Icons.add,
        'Nuevo ejemplar',
        'Un animal con su brazalete',
        NuevoAnimal(isDark: isDark),
      ),
      (
        Icons.inventory_2_outlined,
        'Nuevo lote de entrada',
        'Varios ejemplares juntos',
        NuevoLoteEntrada(isDark: isDark),
      ),
      (
        Icons.create_new_folder_outlined,
        'Nuevo grupo',
        'Corral o agrupación',
        NuevoGrupo(isDark: isDark),
      ),
      (
        Icons.label_outline,
        'Nuevo tipo de animal',
        'Categoría base (Gallina…)',
        NuevoAnimal(isDark: isDark),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabOpen) ...[
          ...actions.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FabMenuItem(
                icon: a.$1,
                label: a.$2,
                desc: a.$3,
                onTap: () {
                  setState(() => _fabOpen = false);
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => a.$4,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        FloatingActionButton(
          backgroundColor: AppColors.green,
          foregroundColor: isDark ? AppColors.bg : AppColors.bgInputLg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onPressed: () => setState(() => _fabOpen = !_fabOpen),
          child: AnimatedRotation(
            turns: _fabOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(_fabOpen ? Icons.close : Icons.add, size: 28),
          ),
        ),
      ],
    );
  }
}

// Extensión para iterar enum en orden
extension _TabValues on _Tab {
  static List<_Tab> get valores => _Tab.values;
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
                  color: AppColors.green.withOpacity(0.15),
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
class _GruposTab extends StatelessWidget {
  final String granjaId;
  final String tipoFiltro;
  final AsyncValue<List<TipoAnimal>> tiposAsync;
  final AsyncValue<List<Grupo>> gruposAsync;
  final AsyncValue<Map<String, GrupoConteo>> conteosAsync;
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
    required this.expandidos,
    required this.colapsados,
    required this.onToggleExpand,
    required this.onToggleColapso,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return tiposAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tipos) => gruposAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (grupos) => conteosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (conteos) {
            final gruposFiltrados = tipoFiltro == 'all'
                ? grupos
                : grupos.where((g) => g.tipoAnimalId == tipoFiltro).toList();
            final totalVivos = grupos.fold<int>(
              0,
              (s, g) => s + (conteos[g.id]?.vivos ?? 0),
            );
            final totalMuertes = grupos.fold<int>(
              0,
              (s, g) => s + (conteos[g.id]?.muertes ?? 0),
            );

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

                if (gruposFiltrados.isEmpty)
                  SliverToBoxAdapter(child: _EmptyState(tipos: tipos))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, i) {
                        final grupo = gruposFiltrados[i];
                        final conteo =
                            conteos[grupo.id] ??
                            const GrupoConteo(vivos: 0, muertes: 0, total: 0);
                        final color = _colorParaTipo(grupo.tipoAnimalId, tipos);
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

  @override
  Widget build(BuildContext context) {
    final ejemplaresAsync = ref.watch(ejemplaresProvider(widget.granjaId));

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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SearchField(
                  controller: _searchCtrl,
                  hint: 'Buscar brazalete, tipo o grupo…',
                  isDark: widget.isDark,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),

            // Toggle Activos / Todos
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: _SegmentedToggle(
                  isDark: widget.isDark,
                  options: const ['Activos', 'Todos'],
                  selectedIndex: _soloActivos ? 0 : 1,
                  onSelected: (i) =>
                      setState(() => _soloActivos = i == 0),
                ),
              ),
            ),

            if (lista.isEmpty)
              SliverToBoxAdapter(
                child: _TabPlaceholder(
                  icon: Icons.tag,
                  titulo: 'Sin ejemplares',
                  subtitulo: ejemplares.isEmpty
                      ? 'Registra un ejemplar o lote de entrada para verlos aquí'
                      : 'Ningún ejemplar coincide con la búsqueda',
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
                      child: _EjemplarCard(ejemplar: ej, isDark: widget.isDark),
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
  final Ejemplar ejemplar;
  final bool isDark;
  const _EjemplarCard({required this.ejemplar, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMMM yyyy");
    return Container(
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
              color: AppColors.green.withOpacity(0.12),
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
        color: color.withOpacity(0.15),
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
        titulo: 'Sin lotes',
        subtitulo: 'Crea un grupo primero',
        isDark: isDark,
      );
    }

    return CustomScrollView(
      slivers: [
        // Barra de búsqueda (visual — implementa lógica si la necesitas)
        SliverToBoxAdapter(
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
        ),

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
  final LoteEntrada lote;
  final String tipoNombre;
  final String grupoNombre;
  final bool isDark;

  const _LoteTabCard({
    required this.lote,
    required this.tipoNombre,
    required this.grupoNombre,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMMM yyyy");
    final vivos = lote.brazaletes.length;

    return Container(
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
              color: AppColors.green.withOpacity(0.12),
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
                  fmt.format(lote.fechaAdquisicion),
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
                      lote.tipoAdquisicionNombre,
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
                '$vivos/${lote.totalEjemplares}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.textPrimaryLg,
                ),
              ),
              Text(
                'vivos',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondaryLg,
                ),
              ),
            ],
          ),
          _CardMenu(
            size: 16,
            isDark: isDark,
            onEdit: () => context.push('/lotes-entrada/${lote.id}/editar'),
            onDelete: () {},
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4: TIPOS
// ─────────────────────────────────────────────────────────────────────────────
class _TiposTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
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

        return Container(
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
                  color: color.withOpacity(0.2),
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
              _CardMenu(
                isDark: isDark,
                onEdit: () => context.push('/tipos/${tipo.id}/editar'),
                onDelete: () => _confirmarEliminar(context, tipo),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmarEliminar(BuildContext context, TipoAnimal tipo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar tipo'),
        content: Text(
          '¿Eliminar "${tipo.nombre}"? Se quitarán sus grupos y ejemplares.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context), // TODO: repo.deleteTipo
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _porLote = true; // true = "Por lote", false = "Por ejemplar"

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bajasAsync = ref.watch(bajasEjemplaresProvider(widget.granjaId));

    return bajasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (todasLasBajas) {
        final bajasFiltradasPorTipo = widget.tipoFiltro == 'all'
            ? todasLasBajas
            : todasLasBajas
                  .where((b) => b.tipoAnimalId == widget.tipoFiltro)
                  .toList();

        final totalAves = bajasFiltradasPorTipo.length;
        final lotesUnicos = bajasFiltradasPorTipo
            .map((b) => b.lotesBajaId)
            .whereType<String>()
            .toSet()
            .length;

        final q = _query.trim().toLowerCase();

        return CustomScrollView(
          slivers: [
            // ── Stat card de resumen ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: _BajasResumenCard(
                  totalAves: totalAves,
                  lotes: lotesUnicos,
                  isDark: widget.isDark,
                ),
              ),
            ),

            // ── Toggle Por lote / Por ejemplar ────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: _SegmentedToggle(
                  isDark: widget.isDark,
                  options: const ['Por lote', 'Por ejemplar'],
                  selectedIndex: _porLote ? 0 : 1,
                  onSelected: (i) => setState(() => _porLote = i == 0),
                ),
              ),
            ),

            // ── Buscador ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SearchField(
                  controller: _searchCtrl,
                  hint: 'Buscar por tipo, grupo o razón…',
                  isDark: widget.isDark,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),

            if (_porLote)
              ..._buildPorLote(bajasFiltradasPorTipo, q)
            else
              ..._buildPorEjemplar(bajasFiltradasPorTipo, q),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        );
      },
    );
  }

  List<Widget> _buildPorLote(List<BajaEjemplar> bajas, String q) {
    var lotes = BajaLote.agruparDesde(bajas);

    if (q.isNotEmpty) {
      lotes = lotes.where((l) {
        return l.tipoNombre.toLowerCase().contains(q) ||
            l.grupoNombre.toLowerCase().contains(q) ||
            l.razonNombre.toLowerCase().contains(q);
      }).toList();
    }

    if (lotes.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _TabPlaceholder(
            icon: Icons.remove_circle_outline,
            titulo: 'Sin bajas por lote',
            subtitulo: 'Las bajas registradas en conjunto aparecerán aquí',
            isDark: widget.isDark,
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BajaLoteCard(lote: lotes[i], isDark: widget.isDark),
                ),
            childCount: lotes.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildPorEjemplar(List<BajaEjemplar> bajas, String q) {
    var lista = bajas;
    if (q.isNotEmpty) {
      lista = lista.where((b) {
        return b.brazalete.toString().contains(q) ||
            b.tipoNombre.toLowerCase().contains(q) ||
            b.grupoNombre.toLowerCase().contains(q) ||
            b.razonNombre.toLowerCase().contains(q);
      }).toList();
    }

    if (lista.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _TabPlaceholder(
            icon: Icons.remove_circle_outline,
            titulo: 'Sin bajas',
            subtitulo: 'El historial de bajas aparecerá aquí',
            isDark: widget.isDark,
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BajaEjemplarRow(baja: lista[i], isDark: widget.isDark),
            ),
            childCount: lista.length,
          ),
        ),
      ),
    ];
  }
}

/// Card de resumen con el total de aves dadas de baja y el número de lotes.
class _BajasResumenCard extends StatelessWidget {
  final int totalAves;
  final int lotes;
  final bool isDark;
  const _BajasResumenCard({
    required this.totalAves,
    required this.lotes,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.18),
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
                '$lotes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.textPrimaryLg,
                ),
              ),
              Text(
                'lotes',
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

/// Card de una baja agrupada por lote ("Por lote")
class _BajaLoteCard extends StatelessWidget {
  final BajaLote lote;
  final bool isDark;
  const _BajaLoteCard({required this.lote, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMMM yyyy");
    final color = lote.esMuerte ? Colors.redAccent : Colors.orangeAccent;

    return Container(
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
                    _RazonTag(label: lote.razonNombre, color: color),
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
                      fmt.format(lote.fechaBaja),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLg,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.bgCard2 : AppColors.border1)
                            .withOpacity(0.6),
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
                ),
                const SizedBox(height: 8),
                Text(
                  '${lote.tipoNombre} · ${lote.grupoNombre}',
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
                  lote.brazaletes.map((b) => '#$b').join(', '),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLg,
                  ),
                ),
                if (lote.notas != null && lote.notas!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    lote.notas!,
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
                '${lote.cantidad}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.textPrimaryLg,
                ),
              ),
              Text(
                'aves',
                style: TextStyle(
                  fontSize: 10,
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

/// Fila de una baja individual ("Por ejemplar")
class _BajaEjemplarRow extends StatelessWidget {
  final BajaEjemplar baja;
  final bool isDark;
  const _BajaEjemplarRow({required this.baja, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMMM yyyy");
    final color = baja.esMuerte ? Colors.redAccent : Colors.orangeAccent;

    return Container(
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
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '#${baja.brazalete} · ${baja.tipoNombre} · ${baja.grupoNombre}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLg,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '-1 ave',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
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
        color: color.withOpacity(0.18),
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
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLg,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondaryLg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
              color: AppColors.green.withOpacity(0.10),
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
class _GrupoCard extends ConsumerWidget {
  final Grupo grupo;
  final TipoAnimal tipo;
  final GrupoConteo conteo;
  final Color stripColor;
  final bool expandido, colapsado, isDark;
  final VoidCallback onToggleExpand, onToggleColapso;
  final String granjaId;

  const _GrupoCard({
    required this.grupo,
    required this.tipo,
    required this.conteo,
    required this.stripColor,
    required this.expandido,
    required this.colapsado,
    required this.onToggleExpand,
    required this.onToggleColapso,
    required this.granjaId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      child: GestureDetector(
                        onTap: () => _mostrarDetalle(context),
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
                        _CardMenu(
                          onEdit: () =>
                              context.push('/grupos/${grupo.id}/editar'),
                          onDelete: () => _confirmarEliminar(context),
                          isDark: isDark,
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
                          label: 'Ejemplar',
                          isDark: isDark,
                          onTap: () => context.push(
                            '/aves/nuevo?tipo=${grupo.tipoAnimalId}&grupo=${grupo.id}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.inventory_2_outlined,
                          label: 'Lote',
                          isDark: isDark,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NuevoLoteEntrada(
                                  isDark: isDark,
                                ), // Ya no pasa isDark
                              ),
                            );
                          },
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
    );
  }

  void _mostrarDetalle(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _DetalleGrupoSheet(grupo: grupo, tipo: tipo, conteo: conteo),
    );
  }

  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: const Text(
          '¿Eliminar este grupo? Se quitarán también sus ejemplares.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
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
                  expandido ? 'Ocultar lotes' : 'Ver lotes de entrada',
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
              error: (e, _) =>
                  Text('Error: $e', style: const TextStyle(color: Colors.red)),
              data: (lotes) => lotes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Aún no hay lotes de entrada.',
                        style: TextStyle(fontSize: 12, color: Colors.white38),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: lotes
                          .map((l) => _LoteCard(lote: l, isDark: isDark))
                          .toList(),
                    ),
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
  final LoteEntrada lote;
  final bool isDark;
  const _LoteCard({required this.lote, this.isDark = true});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMMM yyyy");
    final vivos = lote.brazaletes.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard2 : AppColors.bgCardLg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                      fmt.format(lote.fechaAdquisicion),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.bgLight : AppColors.bg,
                      ),
                    ),
                    Text(
                      [
                        lote.tipoAdquisicionNombre,
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
              Text(
                '$vivos/${lote.totalEjemplares}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 4),
              _CardMenu(
                size: 16,
                onEdit: () => context.push('/lotes-entrada/${lote.id}/editar'),
                onDelete: () {},
                isDark: isDark,
              ),
            ],
          ),
          if (lote.brazaletes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: lote.brazaletes
                  .map((b) => _BrazaleteBadge(numero: b, isDark: isDark))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrazaleteBadge extends StatelessWidget {
  final int numero;
  final bool isDark;
  const _BrazaleteBadge({required this.numero, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard : AppColors.bgLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppColors.border : AppColors.border1,
        ),
      ),
      child: Text(
        '#$numero',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.textPrimary : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET DETALLE GRUPO
// ─────────────────────────────────────────────────────────────────────────────
class _DetalleGrupoSheet extends StatelessWidget {
  final Grupo grupo;
  final TipoAnimal tipo;
  final GrupoConteo conteo;

  const _DetalleGrupoSheet({
    required this.grupo,
    required this.tipo,
    required this.conteo,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Tipo', tipo.nombre),
      ('Grupo', grupo.nombre),
      ('Aves vivas', '${conteo.vivos}'),
      ('Muertes', '${conteo.muertes}'),
      ('Descripción', grupo.descripcion ?? '—'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            grupo.nombre,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            '${tipo.nombre} · ${conteo.vivos} aves vivas',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      r.$1,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.45),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.$2,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar grupo'),
              onPressed: () {
                Navigator.pop(context);
                context.push('/grupos/${grupo.id}/editar');
              },
            ),
          ),
        ],
      ),
    );
  }
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
              color: Colors.white.withOpacity(0.8),
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
          color: danger ? Colors.red.withOpacity(0.3) : AppColors.border1,
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

class _CardMenu extends StatelessWidget {
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
}

class _FabMenuItem extends StatelessWidget {
  final IconData icon;
  final String label, desc;
  final VoidCallback onTap;
  const _FabMenuItem({
    required this.icon,
    required this.label,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.green),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
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
          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
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