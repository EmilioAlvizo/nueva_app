// lib/features/huevos/presentation/huevos_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../../../../shared/widgets/green_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../animales/animales_provider.dart';
import '../settings/presentation/providers/theme_provider.dart';
import 'huevo_repository.dart';
import 'huevo_models.dart';
import 'huevo_provider.dart';

// ─── Tabs ─────────────────────────────────────────────────────────────────────
enum _Tab { total, agregar, reducir }

// ─────────────────────────────────────────────────────────────────────────────
class HuevosScreen extends ConsumerStatefulWidget {
  final String granjaId;
  const HuevosScreen({super.key, required this.granjaId});

  @override
  ConsumerState<HuevosScreen> createState() => _HuevosScreenState();
}

class _HuevosScreenState extends ConsumerState<HuevosScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageCtrl;
  _Tab _activeTab = _Tab.total;

  // Filtro de tipo (comparte lógica con AnimalesScreen)
  String _tipoFiltro = 'all';

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: 0);
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
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final tiposAsync = ref.watch(tiposAnimalProvider(widget.granjaId));
    final tipos = tiposAsync.value ?? [];

    return Scaffold(
      backgroundColor: isDark ? AppColors.bg : AppColors.bgCard3Lg,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ──────────────────────────────────────────────────
            _HuevosAppBar(
              isDark: isDark,
              activeTab: _activeTab,
              tipos: tipos,
              tipoFiltro: _tipoFiltro,
              onTabSelected: _goToTab,
              onTipoFiltroChanged: (v) => setState(() => _tipoFiltro = v),
            ),

            // ── PageView ────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) =>
                    setState(() => _activeTab = _Tab.values[i]),
                children: [
                  _TotalTab(
                    granjaId: widget.granjaId,
                    tipoFiltro: _tipoFiltro,
                    tipos: tipos,
                    isDark: isDark,
                  ),
                  _AgregarTab(
                    granjaId: widget.granjaId,
                    tipoFiltro: _tipoFiltro,
                    tipos: tipos,
                    isDark: isDark,
                  ),
                  _ReducirTab(
                    granjaId: widget.granjaId,
                    tipoFiltro: _tipoFiltro,
                    tipos: tipos,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _HuevosAppBar extends StatelessWidget {
  final bool isDark;
  final _Tab activeTab;
  final List<dynamic> tipos;
  final String tipoFiltro;
  final ValueChanged<_Tab> onTabSelected;
  final ValueChanged<String> onTipoFiltroChanged;

  const _HuevosAppBar({
    required this.isDark,
    required this.activeTab,
    required this.tipos,
    required this.tipoFiltro,
    required this.onTabSelected,
    required this.onTipoFiltroChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Chips de tabs ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _Tab.values.map((tab) {
              final sel = tab == activeTab;
              final label = switch (tab) {
                _Tab.total => 'Total',
                _Tab.agregar => 'Agregar',
                _Tab.reducir => 'Reducir',
              };
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onTabSelected(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? (isDark
                              ? AppColors.naranjao
                              : AppColors.naranjal)
                          : (isDark ? AppColors.bgCard : AppColors.bgLight),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (sel) ...[
                        Icon(Icons.check,
                            size: 13,
                            color: isDark
                                ? AppColors.textPrimaryLg
                                : AppColors.textPrimary),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel
                              ? (isDark
                                  ? AppColors.textPrimaryLg
                                  : AppColors.textPrimary)
                              : (isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondaryLg),
                        ),
                      ),
                    ]),
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
// TAB TOTAL: stats + lista combinada de movimientos
// ─────────────────────────────────────────────────────────────────────────────
class _TotalTab extends ConsumerWidget {
  final String granjaId;
  final String tipoFiltro;
  final List<dynamic> tipos;
  final bool isDark;

  const _TotalTab({
    required this.granjaId,
    required this.tipoFiltro,
    required this.tipos,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(huevoStatsProvider(granjaId));
    final movsAsync = ref.watch(movimientosHuevoProvider(granjaId));

    return CustomScrollView(
      slivers: [
        // Stats tiles
        SliverToBoxAdapter(
          child: statsAsync.when(
            loading: () => const SizedBox(height: 80,
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => const SizedBox.shrink(),
            data: (stats) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                _StatTile(
                    value: '${stats.totalBuenos}',
                    label: 'Huevos',
                    color: AppColors.green,
                    isDark: isDark),
                const SizedBox(width: 10),
                _StatTile(
                    value: '\$${stats.totalIngreso.toStringAsFixed(0)}',
                    label: 'Ingreso',
                    color: const Color(0xFF2D3748),
                    isDark: isDark),
                const SizedBox(width: 10),
                _StatTile(
                    value: '${stats.totalVentas}',
                    label: 'Ventas',
                    color: const Color(0xFF7C3F2B),
                    isDark: isDark),
              ]),
            ),
          ),
        ),

        // Lista de movimientos
        movsAsync.when(
          loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Text('Error: $e'))),
          data: (movs) {
            final filtrados = tipoFiltro == 'all'
                ? movs
                : movs
                    .where((m) => m.tipoAnimalId == tipoFiltro)
                    .toList();

            if (filtrados.isEmpty) {
              return SliverToBoxAdapter(
                child: _EmptyHuevos(isDark: isDark),
              );
            }

            // Solo recolecciones en la tab total (las reducciones van en stats)
            final recs = filtrados
                .where((m) => m.tipo == TipoMovHuevo.recoleccion)
                .toList();

            if (recs.isEmpty) {
              return SliverToBoxAdapter(
                  child: _EmptyHuevos(isDark: isDark));
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final mov = recs[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MovHuevoCard(
                        mov: mov,
                        isDark: isDark,
                        tipos: tipos,
                        onTap: () => _editarRecoleccion(context, ref, mov),
                        onLongPress: () => _eliminarRecoleccion(
                            context, ref, mov.id, granjaId),
                      ),
                    );
                  },
                  childCount: recs.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _editarRecoleccion(
      BuildContext context, WidgetRef ref, MovHuevo mov) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RecoleccionForm(
        granjaId: granjaId,
        isDark: isDark,
        tipos: tipos,
        tipoAnimalIdInicial: mov.tipoAnimalId,
        grupoIdInicial: mov.grupoId,
        editando: mov,
      ),
    );
  }

  void _eliminarRecoleccion(
      BuildContext context, WidgetRef ref, String id, String granjaId) {
    ConfirmationDialog.show(
      context: context,
      isDark: isDark,
      title: 'Eliminar recolección',
      content: '¿Eliminar este registro de recolección? '
          'Esta acción no se puede deshacer.',
      onConfirm: () async {
        await ref.read(huevoRepositoryProvider).deleteRecoleccion(id);
        ref.invalidate(recoleccionesProvider(granjaId));
        ref.invalidate(movimientosHuevoProvider(granjaId));
        ref.invalidate(huevoStatsProvider(granjaId));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB AGREGAR: lista de recolecciones + FAB para nueva
// ─────────────────────────────────────────────────────────────────────────────
class _AgregarTab extends ConsumerWidget {
  final String granjaId;
  final String tipoFiltro;
  final List<dynamic> tipos;
  final bool isDark;

  const _AgregarTab({
    required this.granjaId,
    required this.tipoFiltro,
    required this.tipos,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync = ref.watch(recoleccionesProvider(granjaId));

    return Stack(
      children: [
        recsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (recs) {
            final filtradas = tipoFiltro == 'all'
                ? recs
                : recs
                    .where((r) => r.tipoAnimalId == tipoFiltro)
                    .toList();

            if (filtradas.isEmpty) {
              return _EmptyHuevos(isDark: isDark);
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              itemCount: filtradas.length,
              itemBuilder: (context, i) {
                final r = filtradas[i];
                final mov = MovHuevo.deRecoleccion(r);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MovHuevoCard(
                    mov: mov,
                    isDark: isDark,
                    tipos: tipos,
                    onTap: () => _editar(context, ref, mov),
                    onLongPress: () =>
                        _eliminar(context, ref, r.id),
                  ),
                );
              },
            );
          },
        ),

        // FAB
        Positioned(
          bottom: 24,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'fab_agregar',
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            onPressed: () => _nueva(context, ref),
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ],
    );
  }

  void _nueva(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RecoleccionForm(
        granjaId: granjaId,
        isDark: isDark,
        tipos: tipos,
        tipoAnimalIdInicial:
            tipoFiltro == 'all' ? null : tipoFiltro,
      ),
    );
  }

  void _editar(BuildContext context, WidgetRef ref, MovHuevo mov) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RecoleccionForm(
        granjaId: granjaId,
        isDark: isDark,
        tipos: tipos,
        tipoAnimalIdInicial: mov.tipoAnimalId,
        grupoIdInicial: mov.grupoId,
        editando: mov,
      ),
    );
  }

  void _eliminar(BuildContext context, WidgetRef ref, String id) {
    ConfirmationDialog.show(
      context: context,
      isDark: isDark,
      title: 'Eliminar recolección',
      content: '¿Eliminar este registro?',
      onConfirm: () async {
        await ref.read(huevoRepositoryProvider).deleteRecoleccion(id);
        ref.invalidate(recoleccionesProvider(granjaId));
        ref.invalidate(movimientosHuevoProvider(granjaId));
        ref.invalidate(huevoStatsProvider(granjaId));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB REDUCIR: lista de reducciones + FAB para nueva
// ─────────────────────────────────────────────────────────────────────────────
class _ReducirTab extends ConsumerWidget {
  final String granjaId;
  final String tipoFiltro;
  final List<dynamic> tipos;
  final bool isDark;

  const _ReducirTab({
    required this.granjaId,
    required this.tipoFiltro,
    required this.tipos,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final redsAsync = ref.watch(reduccionesProvider(granjaId));

    return Stack(
      children: [
        redsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (reds) {
            final filtradas = tipoFiltro == 'all'
                ? reds
                : reds
                    .where((r) => r.tipoAnimalId == tipoFiltro)
                    .toList();

            if (filtradas.isEmpty) {
              return _EmptyHuevos(
                  isDark: isDark, mensaje: 'Sin reducciones registradas');
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              itemCount: filtradas.length,
              itemBuilder: (context, i) {
                final r = filtradas[i];
                final mov = MovHuevo.deReduccion(r);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MovHuevoCard(
                    mov: mov,
                    isDark: isDark,
                    tipos: tipos,
                    onTap: () => _editar(context, ref, mov, r),
                    onLongPress: () =>
                        _eliminar(context, ref, r.id),
                  ),
                );
              },
            );
          },
        ),

        Positioned(
          bottom: 24,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'fab_reducir',
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            onPressed: () => _nueva(context, ref),
            child: const Icon(Icons.remove, size: 28),
          ),
        ),
      ],
    );
  }

  void _nueva(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReduccionForm(
        granjaId: granjaId,
        isDark: isDark,
        tipos: tipos,
        tipoAnimalIdInicial:
            tipoFiltro == 'all' ? null : tipoFiltro,
      ),
    );
  }

  void _editar(
      BuildContext context, WidgetRef ref, MovHuevo mov, ReduccionHuevo r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReduccionForm(
        granjaId: granjaId,
        isDark: isDark,
        tipos: tipos,
        tipoAnimalIdInicial: mov.tipoAnimalId,
        editando: r,
      ),
    );
  }

  void _eliminar(BuildContext context, WidgetRef ref, String id) {
    ConfirmationDialog.show(
      context: context,
      isDark: isDark,
      title: 'Eliminar reducción',
      content: '¿Eliminar este registro de reducción?',
      onConfirm: () async {
        await ref.read(huevoRepositoryProvider).deleteReduccion(id);
        ref.invalidate(reduccionesProvider(granjaId));
        ref.invalidate(movimientosHuevoProvider(granjaId));
        ref.invalidate(huevoStatsProvider(granjaId));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE MOVIMIENTO
// ─────────────────────────────────────────────────────────────────────────────
class _MovHuevoCard extends StatelessWidget {
  final MovHuevo mov;
  final bool isDark;
  final List<dynamic> tipos;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MovHuevoCard({
    required this.mov,
    required this.isDark,
    required this.tipos,
    required this.onTap,
    required this.onLongPress,
  });

  Color _colorTipo() {
    final idx = tipos.indexWhere((t) => t.id == mov.tipoAnimalId);
    return AppColors
        .tipoColor[(idx < 0 ? 0 : idx) % AppColors.tipoColor.length];
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMMM yyyy");
    final esRec = mov.tipo == TipoMovHuevo.recoleccion;
    final color = _colorTipo();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.bgCard : AppColors.bgLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.only(
                    top: 14, left: 14, right: 46, bottom: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Fila principal ───────────────────────────────
                    Row(children: [
                      Text(
                        mov.grupoNombre ?? mov.tipoNombre,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.textPrimaryLg,
                        ),
                      ),
                      const Spacer(),
                      // Columna 1
                      if (esRec) ...[
                        _StatCol(
                          icon: '🟡',
                          value: '${mov.huevosRotos}',
                          label: 'Rotos',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 16),
                        _StatCol(
                          icon: '🥚',
                          value: '${mov.huevosBuenos}',
                          label: 'Buenos',
                          isDark: isDark,
                        ),
                      ] else ...[
                        _StatCol(
                          icon: '💵',
                          value:
                              '${mov.importe?.toStringAsFixed(0) ?? '-'} \$',
                          label: mov.razonNombre ?? '',
                          isDark: isDark,
                          valueColor: AppColors.green,
                        ),
                        const SizedBox(width: 16),
                        _StatCol(
                          icon: '🥚',
                          value: '${mov.cantidad}',
                          label: 'Huevos',
                          isDark: isDark,
                        ),
                      ],
                      const SizedBox(width: 8),
                    ]),

                    // ── Fecha ────────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.07)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      child: Text(
                        fmt.format(mov.fecha),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Franja lateral con color del tipo
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 32,
                  color: color,
                  alignment: Alignment.center,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      mov.tipoNombre,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final bool isDark;
  final Color? valueColor;

  const _StatCol({
    required this.icon,
    required this.value,
    required this.label,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      Text(
        value,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: valueColor ??
              (isDark ? AppColors.textPrimary : AppColors.textPrimaryLg),
        ),
      ),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLg,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO DE RECOLECCIÓN
// ─────────────────────────────────────────────────────────────────────────────
class _RecoleccionForm extends ConsumerStatefulWidget {
  final String granjaId;
  final bool isDark;
  final List<dynamic> tipos;
  final String? tipoAnimalIdInicial;
  final String? grupoIdInicial;
  final MovHuevo? editando;

  const _RecoleccionForm({
    required this.granjaId,
    required this.isDark,
    required this.tipos,
    this.tipoAnimalIdInicial,
    this.grupoIdInicial,
    this.editando,
  });

  @override
  ConsumerState<_RecoleccionForm> createState() => _RecoleccionFormState();
}

class _RecoleccionFormState extends ConsumerState<_RecoleccionForm> {
  final _buenosCtrl = TextEditingController();
  final _rotosCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  String? _tipoSel;
  String? _grupoSel;
  DateTime _fecha = DateTime.now();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tipoSel = widget.tipoAnimalIdInicial;
    _grupoSel = widget.grupoIdInicial;
    if (widget.editando != null) {
      final e = widget.editando!;
      _buenosCtrl.text = '${e.huevosBuenos ?? 0}';
      _rotosCtrl.text = '${e.huevosRotos ?? 0}';
      _notasCtrl.text = e.notas ?? '';
      _fecha = e.fecha;
      _tipoSel = e.tipoAnimalId;
      _grupoSel = e.grupoId;
    }
  }

  @override
  void dispose() {
    _buenosCtrl.dispose();
    _rotosCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_tipoSel == null) {
      setState(() => _error = 'Selecciona un tipo de animal');
      return;
    }
    final buenos = int.tryParse(_buenosCtrl.text.trim()) ?? 0;
    final rotos = int.tryParse(_rotosCtrl.text.trim()) ?? 0;
    if (buenos == 0 && rotos == 0) {
      setState(() => _error = 'Ingresa al menos un huevo');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(huevoRepositoryProvider);

      if (widget.editando != null) {
        await repo.updateRecoleccion(
          id: widget.editando!.id,
          tipoAnimalId: _tipoSel!,
          grupoId: _grupoSel,
          fecha: _fecha,
          huevosBuenos: buenos,
          huevosRotos: rotos,
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        );
      } else {
        final periodoId =
            await repo.getPeriodoActivoId(widget.granjaId);
        await repo.addRecoleccion(
          granjaId: widget.granjaId,
          tipoAnimalId: _tipoSel!,
          periodoAlimentoId: periodoId,
          grupoId: _grupoSel,
          fecha: _fecha,
          huevosBuenos: buenos,
          huevosRotos: rotos,
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        );
      }

      ref.invalidate(recoleccionesProvider(widget.granjaId));
      ref.invalidate(movimientosHuevoProvider(widget.granjaId));
      ref.invalidate(huevoStatsProvider(widget.granjaId));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gruposAsync = ref.watch(gruposProvider(widget.granjaId));
    final gruposFiltrados = gruposAsync.value
            ?.where((g) => _tipoSel == null || g.tipoAnimalId == _tipoSel)
            .toList() ??
        [];
    final fmt = DateFormat("d 'de' MMMM yyyy");
    final esEdicion = widget.editando != null;

    return _FormSheet(
      isDark: widget.isDark,
      icon: Icons.egg_outlined,
      titulo: esEdicion ? 'Editar recolección' : 'Nueva recolección',
      subtitulo: 'Registra los huevos recolectados del día.',
      error: _error,
      isLoading: _isLoading,
      labelBoton: esEdicion ? 'Guardar cambios' : 'Registrar recolección',
      onSubmit: _submit,
      children: [
        // Tipo
        _SeccionChips(
          label: 'TIPO DE ANIMAL',
          items: widget.tipos.map((t) => (t.id as String, t.nombre as String)).toList(),
          seleccionado: _tipoSel,
          onSeleccionar: (id) => setState(() {
            _tipoSel = id;
            _grupoSel = null;
          }),
        ),
        const SizedBox(height: 20),

        // Grupo (opcional)
        _SeccionChips(
          label: 'GRUPO (opcional)',
          items: gruposFiltrados
              .map((g) => (g.id, g.nombre))
              .toList(),
          seleccionado: _grupoSel,
          onSeleccionar: (id) => setState(() =>
              _grupoSel = _grupoSel == id ? null : id),
          emptyMessage: _tipoSel == null
              ? 'Selecciona un tipo primero'
              : 'Sin grupos para este tipo',
          allowDeselect: true,
        ),
        const SizedBox(height: 20),

        // Fecha
        _FechaSelector(
          fecha: _fecha,
          isDark: widget.isDark,
          onChanged: (d) => setState(() => _fecha = d),
          fmt: fmt,
        ),
        const SizedBox(height: 20),

        // Huevos buenos
        AppTextField(
          controller: _buenosCtrl,
          label: 'HUEVOS BUENOS',
          hint: 'Ej. 12',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          validator: null,
        ),
        const SizedBox(height: 16),

        // Huevos rotos
        AppTextField(
          controller: _rotosCtrl,
          label: 'HUEVOS ROTOS',
          hint: 'Ej. 0',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          validator: null,
        ),
        const SizedBox(height: 16),

        // Notas
        AppTextField(
          controller: _notasCtrl,
          label: 'NOTAS (opcional)',
          hint: 'Observaciones…',
          textInputAction: TextInputAction.done,
          onFieldSubmitted: _isLoading ? null : () => _submit(),
          validator: null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO DE REDUCCIÓN
// ─────────────────────────────────────────────────────────────────────────────
class _ReduccionForm extends ConsumerStatefulWidget {
  final String granjaId;
  final bool isDark;
  final List<dynamic> tipos;
  final String? tipoAnimalIdInicial;
  final ReduccionHuevo? editando;

  const _ReduccionForm({
    required this.granjaId,
    required this.isDark,
    required this.tipos,
    this.tipoAnimalIdInicial,
    this.editando,
  });

  @override
  ConsumerState<_ReduccionForm> createState() => _ReduccionFormState();
}

class _ReduccionFormState extends ConsumerState<_ReduccionForm> {
  final _cantidadCtrl = TextEditingController();
  final _importeCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  String? _tipoSel;
  String? _razonSel;
  DateTime _fecha = DateTime.now();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tipoSel = widget.tipoAnimalIdInicial;
    if (widget.editando != null) {
      final e = widget.editando!;
      _cantidadCtrl.text = '${e.cantidad}';
      _importeCtrl.text = e.importe?.toStringAsFixed(0) ?? '';
      _notasCtrl.text = e.notas ?? '';
      _fecha = e.fecha;
      _tipoSel = e.tipoAnimalId;
      _razonSel = e.razonReduccionId;
    }
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _importeCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_tipoSel == null) {
      setState(() => _error = 'Selecciona un tipo de animal');
      return;
    }
    if (_razonSel == null) {
      setState(() => _error = 'Selecciona el motivo de la reducción');
      return;
    }
    final cantidad = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;
    if (cantidad <= 0) {
      setState(() => _error = 'Ingresa una cantidad mayor a 0');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(huevoRepositoryProvider);
      final importe = double.tryParse(
          _importeCtrl.text.trim().replaceAll(',', '.'));

      if (widget.editando != null) {
        await repo.updateReduccion(
          id: widget.editando!.id,
          tipoAnimalId: _tipoSel!,
          razonReduccionId: _razonSel!,
          cantidad: cantidad,
          importe: importe,
          fecha: _fecha,
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        );
      } else {
        final periodoId =
            await repo.getPeriodoActivoId(widget.granjaId);
        await repo.addReduccion(
          granjaId: widget.granjaId,
          tipoAnimalId: _tipoSel!,
          periodoAlimentoId: periodoId,
          razonReduccionId: _razonSel!,
          cantidad: cantidad,
          importe: importe,
          fecha: _fecha,
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        );
      }

      ref.invalidate(reduccionesProvider(widget.granjaId));
      ref.invalidate(movimientosHuevoProvider(widget.granjaId));
      ref.invalidate(huevoStatsProvider(widget.granjaId));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final razonesAsync = ref.watch(razonesReduccionProvider);
    final fmt = DateFormat("d 'de' MMMM yyyy");
    final esEdicion = widget.editando != null;

    return _FormSheet(
      isDark: widget.isDark,
      icon: Icons.remove_circle_outline,
      titulo: esEdicion ? 'Editar reducción' : 'Nueva reducción',
      subtitulo: 'Registra destino o merma de huevos.',
      error: _error,
      isLoading: _isLoading,
      labelBoton: esEdicion ? 'Guardar cambios' : 'Registrar reducción',
      onSubmit: _submit,
      children: [
        // Tipo
        _SeccionChips(
          label: 'TIPO DE ANIMAL',
          items: widget.tipos
              .map((t) => (t.id as String, t.nombre as String))
              .toList(),
          seleccionado: _tipoSel,
          onSeleccionar: (id) => setState(() => _tipoSel = id),
        ),
        const SizedBox(height: 20),

        // Razón
        razonesAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (razones) => _SeccionChips(
            label: 'MOTIVO',
            items: razones.map((r) => (r.id, r.nombre)).toList(),
            seleccionado: _razonSel,
            onSeleccionar: (id) => setState(() => _razonSel = id),
          ),
        ),
        const SizedBox(height: 20),

        // Fecha
        _FechaSelector(
          fecha: _fecha,
          isDark: widget.isDark,
          onChanged: (d) => setState(() => _fecha = d),
          fmt: fmt,
        ),
        const SizedBox(height: 20),

        // Cantidad
        AppTextField(
          controller: _cantidadCtrl,
          label: 'CANTIDAD DE HUEVOS',
          hint: 'Ej. 12',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          validator: null,
        ),
        const SizedBox(height: 16),

        // Importe (ventas)
        AppTextField(
          controller: _importeCtrl,
          label: 'IMPORTE \$ (opcional, para ventas)',
          hint: 'Ej. 75',
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          validator: null,
        ),
        const SizedBox(height: 16),

        // Notas
        AppTextField(
          controller: _notasCtrl,
          label: 'NOTAS (opcional)',
          hint: 'Observaciones…',
          textInputAction: TextInputAction.done,
          onFieldSubmitted: _isLoading ? null : () => _submit(),
          validator: null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS COMPARTIDOS
// ─────────────────────────────────────────────────────────────────────────────

/// Shell del modal de formulario (pill + header + error + children + botón)
class _FormSheet extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final String? error;
  final bool isLoading;
  final String labelBoton;
  final VoidCallback onSubmit;
  final List<Widget> children;

  const _FormSheet({
    required this.isDark,
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.error,
    required this.isLoading,
    required this.labelBoton,
    required this.onSubmit,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.bg : Colors.white;
    final titleColor =
        isDark ? AppColors.textPrimary : const Color(0xFF1A1A2E);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
              color: isDark ? AppColors.border : Colors.black12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.border : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.green, size: 24),
                ),
                const SizedBox(width: 16),
                Text(titulo,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    )),
              ]),
              const SizedBox(height: 8),
              Text(subtitulo,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4)),
              const SizedBox(height: 24),

              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(error!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              ...children,
              const SizedBox(height: 32),

              GreenButton(
                label: labelBoton,
                isLoading: isLoading,
                onPressed: onSubmit,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeccionChips extends StatelessWidget {
  final String label;
  final List<(String, String)> items;
  final String? seleccionado;
  final ValueChanged<String> onSeleccionar;
  final String? emptyMessage;
  final bool allowDeselect;

  const _SeccionChips({
    required this.label,
    required this.items,
    required this.seleccionado,
    required this.onSeleccionar,
    this.emptyMessage,
    this.allowDeselect = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(emptyMessage ?? 'Sin opciones',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                final sel = seleccionado == item.$1;
                return GestureDetector(
                  onTap: () => onSeleccionar(item.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          sel ? AppColors.green : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel
                              ? AppColors.green
                              : AppColors.border),
                    ),
                    child: Text(item.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? Colors.white
                              : AppColors.textSecondary,
                        )),
                  ),
                );
              }).toList(),
            ),
        ],
      );
}

class _FechaSelector extends StatelessWidget {
  final DateTime fecha;
  final bool isDark;
  final ValueChanged<DateTime> onChanged;
  final DateFormat fmt;

  const _FechaSelector({
    required this.fecha,
    required this.isDark,
    required this.onChanged,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FECHA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: fecha,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) onChanged(picked);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Text(fmt.format(fecha),
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14)),
              ]),
            ),
          ),
        ],
      );
}

class _StatTile extends StatelessWidget {
  final String value, label;
  final Color color;
  final bool isDark;

  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8))),
          ]),
        ),
      );
}

class _EmptyHuevos extends StatelessWidget {
  final bool isDark;
  final String? mensaje;
  const _EmptyHuevos({required this.isDark, this.mensaje});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🥚', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            mensaje ?? 'Sin registros de huevos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.textPrimaryLg,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Usa el botón + para registrar una recolección',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLg,
            ),
          ),
        ]),
      );
}