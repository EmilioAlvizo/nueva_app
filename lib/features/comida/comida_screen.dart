// lib/features/comida/presentation/comida_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../../../../shared/widgets/green_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../animales/animales_provider.dart';
import '../animales/tipo_filtro.dart';
import '../settings/presentation/providers/theme_provider.dart';
import 'comida_repository.dart';
import 'comida_models.dart';
import 'comida_provider.dart';

// ─── Tabs ─────────────────────────────────────────────────────────────────────
enum _Tab { total, agregar }

// ─────────────────────────────────────────────────────────────────────────────
class ComidaScreen extends ConsumerStatefulWidget {
  final String granjaId;
  const ComidaScreen({super.key, required this.granjaId});

  @override
  ConsumerState<ComidaScreen> createState() => _ComidaScreenState();
}

class _ComidaScreenState extends ConsumerState<ComidaScreen> {
  late final PageController _pageCtrl;
  _Tab _activeTab = _Tab.total;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
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
    // Filtro de tipo viene del provider global (compartido con home_screen)
    final tipoFiltro = ref.watch(tipoFiltroProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bg : AppColors.bgCard3Lg,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ──────────────────────────────────────────────────
            _ComidaAppBar(
              isDark: isDark,
              activeTab: _activeTab,
              onTabSelected: _goToTab,
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
                    tipoFiltro: tipoFiltro,
                    tipos: tipos,
                    isDark: isDark,
                  ),
                  _AgregarTab(
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR (solo tabs — el filtro de tipo vive en home_screen)
// ─────────────────────────────────────────────────────────────────────────────
class _ComidaAppBar extends StatelessWidget {
  final bool isDark;
  final _Tab activeTab;
  final ValueChanged<_Tab> onTabSelected;

  const _ComidaAppBar({
    required this.isDark,
    required this.activeTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: _Tab.values.map((tab) {
          final sel = tab == activeTab;
          final label =
              tab == _Tab.total ? 'Total' : 'Agregar';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onTabSelected(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: sel
                      ? (isDark
                          ? AppColors.naranjao
                          : AppColors.naranjal)
                      : (isDark
                          ? AppColors.bgCard
                          : AppColors.bgLight),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB TOTAL: stats + lista de periodos (uso/egreso)
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
    final statsAsync = ref.watch(comidaStatsProvider(granjaId));
    final periodosAsync = ref.watch(periodosAlimentoProvider(granjaId));

    return CustomScrollView(
      slivers: [
        // ── Stats ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: statsAsync.when(
            loading: () => const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                _StatTile(
                  value: '${stats.totalKg.toStringAsFixed(1)}',
                  label: 'Kg',
                  color: AppColors.green,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _StatTile(
                  value: '${stats.totalEgreso.toStringAsFixed(0)} \$',
                  label: 'Egreso',
                  color: const Color(0xFF2D3748),
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                // Tercer tile vacío como en la imagen
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3F2B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(children: [
                      Text('────',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 16)),
                      Text('────',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 10)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── Lista periodos ────────────────────────────────────────────
        periodosAsync.when(
          loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) =>
              SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
          data: (periodos) {
            final filtrados = tipoFiltro == 'all'
                ? periodos
                : periodos
                    .where((p) => p.tipoAnimalId == tipoFiltro)
                    .toList();

            if (filtrados.isEmpty) {
              return SliverToBoxAdapter(
                  child: _EmptyComida(isDark: isDark));
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final p = filtrados[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PeriodoCard(
                        periodo: p,
                        tipos: tipos,
                        isDark: isDark,
                        onTap: () => _editar(context, ref, p),
                        onLongPress: () =>
                            _eliminar(context, ref, p.id),
                      ),
                    );
                  },
                  childCount: filtrados.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _editar(BuildContext context, WidgetRef ref, PeriodoAlimento p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PeriodoForm(
        granjaId: granjaId,
        isDark: isDark,
        tipos: tipos,
        editando: p,
      ),
    );
  }

  void _eliminar(
      BuildContext context, WidgetRef ref, String id) {
    ConfirmationDialog.show(
      context: context,
      isDark: isDark,
      title: 'Eliminar período',
      content: '¿Eliminar este período de uso de alimento?',
      onConfirm: () async {
        await ref.read(comidaRepositoryProvider).deletePeriodo(id);
        ref.invalidate(periodosAlimentoProvider(granjaId));
        ref.invalidate(comidaStatsProvider(granjaId));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB AGREGAR: lista de lotes (compras) + FAB para nueva compra
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
    final lotesAsync = ref.watch(lotesAlimentoProvider(granjaId));

    return Stack(
      children: [
        lotesAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (lotes) {
            final filtrados = tipoFiltro == 'all'
                ? lotes
                : lotes
                    .where((l) => l.tipoAnimalId == tipoFiltro)
                    .toList();

            if (filtrados.isEmpty) {
              return _EmptyComida(
                  isDark: isDark,
                  mensaje: 'Sin compras registradas');
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              itemCount: filtrados.length,
              itemBuilder: (context, i) {
                final l = filtrados[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LoteCard(
                    lote: l,
                    tipos: tipos,
                    isDark: isDark,
                    onTap: () => _editar(context, ref, l),
                    onLongPress: () =>
                        _eliminar(context, ref, l.id),
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
            heroTag: 'fab_comida',
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
      builder: (_) => _LoteForm(
        granjaId: granjaId,
        isDark: isDark,
        tipos: tipos,
        tipoAnimalIdInicial: tipoFiltro == 'all' ? null : tipoFiltro,
      ),
    );
  }

  void _editar(BuildContext context, WidgetRef ref, LoteAlimento l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LoteForm(
        granjaId: granjaId,
        isDark: isDark,
        tipos: tipos,
        editando: l,
      ),
    );
  }

  void _eliminar(BuildContext context, WidgetRef ref, String id) {
    ConfirmationDialog.show(
      context: context,
      isDark: isDark,
      title: 'Eliminar lote de alimento',
      content:
          '¿Eliminar esta compra? También se eliminarán sus períodos de uso.',
      onConfirm: () async {
        await ref.read(comidaRepositoryProvider).deleteLote(id);
        ref.invalidate(lotesAlimentoProvider(granjaId));
        ref.invalidate(periodosAlimentoProvider(granjaId));
        ref.invalidate(comidaStatsProvider(granjaId));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE PERÍODO (tab Total) — muestra egreso acumulado y kg consumidos
// ─────────────────────────────────────────────────────────────────────────────
class _PeriodoCard extends StatelessWidget {
  final PeriodoAlimento periodo;
  final List<dynamic> tipos;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PeriodoCard({
    required this.periodo,
    required this.tipos,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  Color _colorTipo() {
    final idx = tipos.indexWhere((t) => t.id == periodo.tipoAnimalId);
    return AppColors
        .tipoColor[(idx < 0 ? 0 : idx) % AppColors.tipoColor.length];
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMMM yyyy");
    final color = _colorTipo();
    final nombre = periodo.nombreAlimento ??
        periodo.proveedor ??
        'Sin nombre';

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
                    Row(children: [
                      Expanded(
                        child: Text(
                          nombre,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimary
                                : AppColors.textPrimaryLg,
                          ),
                        ),
                      ),
                      // Egreso
                      _CardStat(
                        icon: '💸',
                        value:
                            '${periodo.egresoCalculado.toStringAsFixed(0)} \$',
                        label: 'Egreso',
                        isDark: isDark,
                        valueColor: AppColors.green,
                      ),
                      const SizedBox(width: 16),
                      // Kg consumidos
                      _CardStat(
                        icon: '🛍',
                        value:
                            '${periodo.kgConsumidos.toStringAsFixed(1)} Kg',
                        label: 'Cantidad',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                    ]),
                    // Fecha + días
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
                      child: Row(children: [
                        Text(
                          fmt.format(periodo.fechaInicio),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLg,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${periodo.diasActivo} días',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLg,
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              // Franja lateral
              Positioned(
                right: 0, top: 0, bottom: 0,
                child: Container(
                  width: 32,
                  color: color,
                  alignment: Alignment.center,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      periodo.tipoNombre,
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

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE LOTE (tab Agregar) — muestra precio y kg de la compra
// ─────────────────────────────────────────────────────────────────────────────
class _LoteCard extends StatelessWidget {
  final LoteAlimento lote;
  final List<dynamic> tipos;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LoteCard({
    required this.lote,
    required this.tipos,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  Color _colorTipo() {
    final idx = tipos.indexWhere((t) => t.id == lote.tipoAnimalId);
    return AppColors
        .tipoColor[(idx < 0 ? 0 : idx) % AppColors.tipoColor.length];
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMMM yyyy");
    final color = _colorTipo();
    final nombre = lote.proveedor ?? 'Sin nombre';

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
                    Row(children: [
                      Expanded(
                        child: Text(
                          nombre,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimary
                                : AppColors.textPrimaryLg,
                          ),
                        ),
                      ),
                      // Precio
                      _CardStat(
                        icon: '🏷',
                        value:
                            '${lote.precioTotal.toStringAsFixed(0)} \$',
                        label: 'Precio',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 16),
                      // Kg
                      _CardStat(
                        icon: '🛍',
                        value:
                            '${lote.cantidadKg.toStringAsFixed(1)} Kg',
                        label: 'Cantidad',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                    ]),
                    // Fecha + días desde compra
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
                      child: Row(children: [
                        Text(
                          fmt.format(lote.fechaCompra),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLg,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${DateTime.now().difference(lote.fechaCompra).inDays} días',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLg,
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              // Franja lateral
              Positioned(
                right: 0, top: 0, bottom: 0,
                child: Container(
                  width: 32,
                  color: color,
                  alignment: Alignment.center,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      lote.tipoNombre,
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

class _CardStat extends StatelessWidget {
  final String icon, value, label;
  final bool isDark;
  final Color? valueColor;

  const _CardStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor ??
                  (isDark
                      ? AppColors.textPrimary
                      : AppColors.textPrimaryLg),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLg,
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO DE LOTE (compra de alimento)
// ─────────────────────────────────────────────────────────────────────────────
class _LoteForm extends ConsumerStatefulWidget {
  final String granjaId;
  final bool isDark;
  final List<dynamic> tipos;
  final String? tipoAnimalIdInicial;
  final LoteAlimento? editando;

  const _LoteForm({
    required this.granjaId,
    required this.isDark,
    required this.tipos,
    this.tipoAnimalIdInicial,
    this.editando,
  });

  @override
  ConsumerState<_LoteForm> createState() => _LoteFormState();
}

class _LoteFormState extends ConsumerState<_LoteForm> {
  final _proveedorCtrl = TextEditingController();
  final _kgCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  String? _tipoSel;
  DateTime _fecha = DateTime.now();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tipoSel = widget.tipoAnimalIdInicial;
    if (widget.editando != null) {
      final e = widget.editando!;
      _proveedorCtrl.text = e.proveedor ?? '';
      _kgCtrl.text = e.cantidadKg.toStringAsFixed(1);
      _precioCtrl.text = e.precioTotal.toStringAsFixed(0);
      _notasCtrl.text = e.notas ?? '';
      _fecha = e.fechaCompra;
      _tipoSel = e.tipoAnimalId;
    }
  }

  @override
  void dispose() {
    _proveedorCtrl.dispose();
    _kgCtrl.dispose();
    _precioCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_tipoSel == null) {
      setState(() => _error = 'Selecciona un tipo de animal');
      return;
    }
    final kg =
        double.tryParse(_kgCtrl.text.trim().replaceAll(',', '.'));
    if (kg == null || kg <= 0) {
      setState(() => _error = 'Ingresa los kg correctamente');
      return;
    }
    final precio =
        double.tryParse(_precioCtrl.text.trim().replaceAll(',', '.'));
    if (precio == null || precio < 0) {
      setState(() => _error = 'Ingresa el precio correctamente');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(comidaRepositoryProvider);
      final proveedor = _proveedorCtrl.text.trim().isEmpty
          ? null
          : _proveedorCtrl.text.trim();
      final notas = _notasCtrl.text.trim().isEmpty
          ? null
          : _notasCtrl.text.trim();

      if (widget.editando != null) {
        await repo.updateLote(
          id: widget.editando!.id,
          tipoAnimalId: _tipoSel!,
          fechaCompra: _fecha,
          cantidadKg: kg,
          precioTotal: precio,
          proveedor: proveedor,
          notas: notas,
        );
      } else {
        await repo.addLote(
          granjaId: widget.granjaId,
          tipoAnimalId: _tipoSel!,
          fechaCompra: _fecha,
          cantidadKg: kg,
          precioTotal: precio,
          proveedor: proveedor,
          notas: notas,
        );
      }

      ref.invalidate(lotesAlimentoProvider(widget.granjaId));
      ref.invalidate(periodosAlimentoProvider(widget.granjaId));
      ref.invalidate(comidaStatsProvider(widget.granjaId));

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
    final fmt = DateFormat("d 'de' MMMM yyyy");
    final esEdicion = widget.editando != null;

    return _FormSheet(
      isDark: widget.isDark,
      icon: Icons.shopping_bag_outlined,
      titulo: esEdicion ? 'Editar compra' : 'Nueva compra de alimento',
      subtitulo: 'Registra un lote de alimento adquirido.',
      error: _error,
      isLoading: _isLoading,
      labelBoton: esEdicion ? 'Guardar cambios' : 'Registrar compra',
      onSubmit: _submit,
      children: [
        // Tipo de animal
        _SeccionChips(
          label: 'TIPO DE ANIMAL',
          items: widget.tipos
              .map((t) => (t.id as String, t.nombre as String))
              .toList(),
          seleccionado: _tipoSel,
          onSeleccionar: (id) => setState(() => _tipoSel = id),
        ),
        const SizedBox(height: 20),

        // Nombre / proveedor
        AppTextField(
          controller: _proveedorCtrl,
          label: 'NOMBRE / PROVEEDOR',
          hint: 'Ej. Migaj, Prepollo, Granja San Luis…',
          textInputAction: TextInputAction.next,
          validator: null,
        ),
        const SizedBox(height: 16),

        // Fecha
        _FechaSelector(
          fecha: _fecha,
          isDark: widget.isDark,
          onChanged: (d) => setState(() => _fecha = d),
          fmt: fmt,
        ),
        const SizedBox(height: 16),

        // Kg
        AppTextField(
          controller: _kgCtrl,
          label: 'CANTIDAD (Kg)',
          hint: 'Ej. 40.0',
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          validator: null,
        ),
        const SizedBox(height: 16),

        // Precio total
        AppTextField(
          controller: _precioCtrl,
          label: 'PRECIO TOTAL (\$)',
          hint: 'Ej. 415',
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
// FORMULARIO DE PERÍODO (editar uso del alimento)
// ─────────────────────────────────────────────────────────────────────────────
class _PeriodoForm extends ConsumerStatefulWidget {
  final String granjaId;
  final bool isDark;
  final List<dynamic> tipos;
  final PeriodoAlimento editando;

  const _PeriodoForm({
    required this.granjaId,
    required this.isDark,
    required this.tipos,
    required this.editando,
  });

  @override
  ConsumerState<_PeriodoForm> createState() => _PeriodoFormState();
}

class _PeriodoFormState extends ConsumerState<_PeriodoForm> {
  final _kgConsumidosCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  late DateTime _fechaInicio;
  DateTime? _fechaFin;
  late bool _activo;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.editando;
    _kgConsumidosCtrl.text = e.kgConsumidos.toStringAsFixed(1);
    _notasCtrl.text = e.notas ?? '';
    _fechaInicio = e.fechaInicio;
    _fechaFin = e.fechaFin;
    _activo = e.activo;
  }

  @override
  void dispose() {
    _kgConsumidosCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final kg = double.tryParse(
        _kgConsumidosCtrl.text.trim().replaceAll(',', '.'));
    if (kg == null || kg < 0) {
      setState(() => _error = 'Ingresa los kg consumidos correctamente');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(comidaRepositoryProvider).updatePeriodo(
            id: widget.editando.id,
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
            activo: _activo,
            kgConsumidos: kg,
            notas: _notasCtrl.text.trim().isEmpty
                ? null
                : _notasCtrl.text.trim(),
          );

      ref.invalidate(periodosAlimentoProvider(widget.granjaId));
      ref.invalidate(comidaStatsProvider(widget.granjaId));

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
    final fmt = DateFormat("d 'de' MMMM yyyy");

    return _FormSheet(
      isDark: widget.isDark,
      icon: Icons.grass_outlined,
      titulo: 'Editar período de uso',
      subtitulo: 'Actualiza el consumo y estado del lote.',
      error: _error,
      isLoading: _isLoading,
      labelBoton: 'Guardar cambios',
      onSubmit: _submit,
      children: [
        // Info del lote (solo lectura)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lote: ${widget.editando.proveedor ?? 'Sin nombre'} · '
                '${widget.editando.cantidadKgLote.toStringAsFixed(1)} Kg · '
                '\$${widget.editando.precioTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Fecha inicio
        _FechaSelector(
          fecha: _fechaInicio,
          isDark: widget.isDark,
          onChanged: (d) => setState(() => _fechaInicio = d),
          fmt: fmt,
          label: 'FECHA INICIO',
        ),
        const SizedBox(height: 16),

        // Kg consumidos
        AppTextField(
          controller: _kgConsumidosCtrl,
          label: 'KG CONSUMIDOS',
          hint: 'Ej. 15.0',
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          
          textInputAction: TextInputAction.next,
          validator: null,
        ),
        const SizedBox(height: 16),

        // Toggle activo
        Row(children: [
          Expanded(
            child: Text(
              'Período activo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isDark
                    ? AppColors.textPrimary
                    : AppColors.textPrimaryLg,
              ),
            ),
          ),
          Switch(
            value: _activo,
            onChanged: (v) => setState(() => _activo = v),
            activeColor: AppColors.green,
          ),
        ]),
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
class _FormSheet extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String titulo, subtitulo, labelBoton;
  final String? error;
  final bool isLoading;
  final VoidCallback onSubmit;
  final List<Widget> children;

  const _FormSheet({
    required this.isDark,
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.labelBoton,
    required this.error,
    required this.isLoading,
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
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.border : Colors.grey.shade300,
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
                Expanded(
                  child: Text(titulo,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      )),
                ),
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
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
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

  const _SeccionChips({
    required this.label,
    required this.items,
    required this.seleccionado,
    required this.onSeleccionar,
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
            const Text('Sin tipos disponibles',
                style: TextStyle(
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
                      color: sel ? AppColors.green : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? AppColors.green : AppColors.border),
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
  final String label;

  const _FechaSelector({
    required this.fecha,
    required this.isDark,
    required this.onChanged,
    required this.fmt,
    this.label = 'FECHA DE COMPRA',
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
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: fecha,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 365)),
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
                        color: AppColors.textPrimary, fontSize: 14)),
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
                    fontSize: 20,
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

class _EmptyComida extends StatelessWidget {
  final bool isDark;
  final String? mensaje;
  const _EmptyComida({required this.isDark, this.mensaje});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🌾', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            mensaje ?? 'Sin registros de alimento',
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
            'Usa el botón + para registrar una compra',
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