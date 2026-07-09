// ─── lib/features/model/loteEntrada/nuevo_loteEntrada.dart ───────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/green_button.dart';
import '../../animales/animales_provider.dart';
import '../../granja/granja_provider.dart';
import '../tipoAnimal/tipoAnimal.dart';
import '../grupo/grupo.dart';

// ─── Catálogos ────────────────────────────────────────────────────────────────
class _CatItem {
  final String id;
  final String nombre;
  const _CatItem(this.id, this.nombre);
}

final _tipoAdquisicionProvider = FutureProvider<List<_CatItem>>((ref) async {
  final data = await supabase
      .from('cat_tipo_adquisicion')
      .select('id, nombre')
      .order('nombre');
  return (data as List).map((e) => _CatItem(e['id'], e['nombre'])).toList();
});

final _propositoProvider = FutureProvider<List<_CatItem>>((ref) async {
  final data = await supabase
      .from('cat_proposito_animal')
      .select('id, nombre')
      .order('nombre');
  return (data as List).map((e) => _CatItem(e['id'], e['nombre'])).toList();
});

// Provider: brazaletes ya usados en la granja (para evitar duplicados)
final _brazaletesUsadosProvider = FutureProvider.family<Set<int>, String>((
  ref,
  granjaId,
) async {
  final data = await supabase
      .from('ejemplares')
      .select('brazalete')
      .eq('granja_id', granjaId);
  return {for (final e in data as List) e['brazalete'] as int};
});

// ─────────────────────────────────────────────────────────────────────────────
class NuevoLoteEntrada extends ConsumerStatefulWidget {
  final bool isDark;
  final String? tipoAnimalIdInicial;
  final String? grupoIdInicial;

  const NuevoLoteEntrada({
    super.key,
    required this.isDark,
    this.tipoAnimalIdInicial,
    this.grupoIdInicial,
  });

  @override
  ConsumerState<NuevoLoteEntrada> createState() => _NuevoLoteEntradaState();
}

class _NuevoLoteEntradaState extends ConsumerState<NuevoLoteEntrada> {
  final _formKey = GlobalKey<FormState>();
  final _proveedorCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _brazaleteManualCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  String? _tipoSeleccionado;
  String? _grupoSeleccionado;
  String? _tipoAdquisicionSeleccionado;
  String? _propositoSeleccionado;
  DateTime _fecha = DateTime.now();

  // Brazaletes seleccionados para este lote
  final Set<int> _brazaletesSeleccionados = {};

  @override
  void initState() {
    super.initState();
    _tipoSeleccionado = widget.tipoAnimalIdInicial;
    _grupoSeleccionado = widget.grupoIdInicial;
  }

  @override
  void dispose() {
    _proveedorCtrl.dispose();
    _costoCtrl.dispose();
    _notasCtrl.dispose();
    _brazaleteManualCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  /// Auto-asigna los siguientes [cantidad] brazaletes disponibles
  void _autoAsignar(Set<int> usados, int cantidad) {
    if (cantidad <= 0) return;
    final nuevos = <int>[];
    int siguiente = (usados.isEmpty && _brazaletesSeleccionados.isEmpty)
        ? 1
        : ([
                ...usados,
                ..._brazaletesSeleccionados,
              ].reduce((a, b) => a > b ? a : b)) +
              1;

    while (nuevos.length < cantidad) {
      if (!usados.contains(siguiente) &&
          !_brazaletesSeleccionados.contains(siguiente)) {
        nuevos.add(siguiente);
      }
      siguiente++;
    }
    setState(() => _brazaletesSeleccionados.addAll(nuevos));
  }

  void _agregarManual(Set<int> usados) {
    final n = int.tryParse(_brazaleteManualCtrl.text.trim());
    if (n == null || n <= 0) {
      setState(() => _errorMessage = 'Ingresa un número válido mayor a 0');
      return;
    }
    if (usados.contains(n)) {
      setState(() => _errorMessage = 'El brazalete #$n ya está en uso');
      return;
    }
    if (_brazaletesSeleccionados.contains(n)) {
      setState(() => _errorMessage = 'El brazalete #$n ya está en esta lista');
      return;
    }
    setState(() {
      _brazaletesSeleccionados.add(n);
      _errorMessage = null;
    });
    _brazaleteManualCtrl.clear();
  }

  Future<void> _submit(List<TipoAnimal> tipos, List<Grupo> grupos) async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipoSeleccionado == null) {
      setState(() => _errorMessage = 'Selecciona un tipo de animal');
      return;
    }
    if (_grupoSeleccionado == null) {
      setState(() => _errorMessage = 'Selecciona un grupo');
      return;
    }
    if (_tipoAdquisicionSeleccionado == null) {
      setState(() => _errorMessage = 'Selecciona el tipo de adquisición');
      return;
    }
    if (_propositoSeleccionado == null) {
      setState(() => _errorMessage = 'Selecciona el propósito');
      return;
    }
    if (_brazaletesSeleccionados.isEmpty) {
      setState(
        () => _errorMessage = 'Agrega al menos un brazalete o usa Auto-asignar',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final granjaId = ref.read(selectedFarmProvider)?.id ?? '';
      final userId = supabase.auth.currentUser?.id ?? '';
      final costo = double.tryParse(
        _costoCtrl.text.trim().replaceAll(',', '.'),
      );

      final brazaletes = _brazaletesSeleccionados.toList()..sort();

      await supabase.rpc(
        'registrar_lote_entrada',
        params: {
          'p_granja_id': granjaId,
          'p_tipo_animal_id': _tipoSeleccionado,
          'p_grupo_id': _grupoSeleccionado,
          'p_proposito_id': _propositoSeleccionado,
          'p_tipo_adquisicion_id': _tipoAdquisicionSeleccionado,
          'p_fecha_adquisicion': DateFormat('yyyy-MM-dd').format(_fecha),
          'p_brazaletes': brazaletes,
          'p_costo_total': costo,
          'p_proveedor': _proveedorCtrl.text.trim().isEmpty
              ? null
              : _proveedorCtrl.text.trim(),
          'p_notas': _notasCtrl.text.trim().isEmpty
              ? null
              : _notasCtrl.text.trim(),
          'p_created_by': userId,
        },
      );

      ref.invalidate(conteosGruposProvider(granjaId));
      ref.invalidate(lotesDeGrupoProvider(_grupoSeleccionado!));
      ref.invalidate(_brazaletesUsadosProvider(granjaId));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al registrar el lote: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final granjaId = ref.read(selectedFarmProvider)?.id ?? '';
    final tiposAsync = ref.watch(tiposAnimalProvider(granjaId));
    final gruposAsync = ref.watch(gruposProvider(granjaId));
    final tipoAdqAsync = ref.watch(_tipoAdquisicionProvider);
    final propositoAsync = ref.watch(_propositoProvider);
    final usadosAsync = ref.watch(_brazaletesUsadosProvider(granjaId));

    final bgColor = widget.isDark ? AppColors.bg : Colors.white;
    final titleColor = widget.isDark
        ? AppColors.textPrimary
        : const Color(0xFF1A1A2E);
    final fmtFecha = DateFormat("d 'de' MMMM yyyy");

    final gruposFiltrados =
        gruposAsync.value
            ?.where(
              (g) =>
                  _tipoSeleccionado == null ||
                  g.tipoAnimalId == _tipoSeleccionado,
            )
            .toList() ??
        [];

    final usados = usadosAsync.value ?? {};

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: widget.isDark ? AppColors.border : Colors.black12,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pill
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? AppColors.border
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Nuevo lote de entrada',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Registra varios ejemplares adquiridos juntos.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Error banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Tipo de animal ────────────────────────────────────
                tiposAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (tipos) => _SeccionChips(
                    label: 'TIPO DE ANIMAL',
                    items: tipos.map((t) => (t.id, t.nombre)).toList(),
                    seleccionado: _tipoSeleccionado,
                    onSeleccionar: (id) => setState(() {
                      _tipoSeleccionado = id;
                      _grupoSeleccionado = null;
                    }),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Grupo ─────────────────────────────────────────────
                _SeccionChips(
                  label: 'GRUPO',
                  items: gruposFiltrados.map((g) => (g.id, g.nombre)).toList(),
                  seleccionado: _grupoSeleccionado,
                  onSeleccionar: (id) =>
                      setState(() => _grupoSeleccionado = id),
                  emptyMessage: _tipoSeleccionado == null
                      ? 'Selecciona un tipo primero'
                      : 'No hay grupos para este tipo',
                ),
                const SizedBox(height: 20),

                // ── Tipo adquisición ──────────────────────────────────
                tipoAdqAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (items) => _SeccionChips(
                    label: 'TIPO DE ADQUISICIÓN',
                    items: items.map((i) => (i.id, i.nombre)).toList(),
                    seleccionado: _tipoAdquisicionSeleccionado,
                    onSeleccionar: (id) =>
                        setState(() => _tipoAdquisicionSeleccionado = id),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Propósito ─────────────────────────────────────────
                propositoAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (items) => _SeccionChips(
                    label: 'PROPÓSITO',
                    items: items.map((i) => (i.id, i.nombre)).toList(),
                    seleccionado: _propositoSeleccionado,
                    onSeleccionar: (id) =>
                        setState(() => _propositoSeleccionado = id),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Fecha ─────────────────────────────────────────────
                _SectionLabel(label: 'FECHA DE ADQUISICIÓN'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _elegirFecha,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          fmtFecha.format(_fecha),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── BRAZALETES ────────────────────────────────────────
                _BrazaletesWidget(
                  usados: usados,
                  seleccionados: _brazaletesSeleccionados,
                  manualCtrl: _brazaleteManualCtrl,
                  onAutoAsignar: (cantidad) => _autoAsignar(usados, cantidad),
                  onAgregarManual: () => _agregarManual(usados),
                  onRemover: (n) =>
                      setState(() => _brazaletesSeleccionados.remove(n)),
                  onClearError: () => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 20),

                // ── Proveedor ─────────────────────────────────────────
                AppTextField(
                  controller: _proveedorCtrl,
                  label: 'PROVEEDOR (opcional)',
                  hint: 'Ej. Granja San Luis, Mercado local…',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),

                // ── Costo total ───────────────────────────────────────
                AppTextField(
                  controller: _costoCtrl,
                  label: 'COSTO TOTAL (opcional)',
                  hint: 'Ej. 1500',
                  textInputAction: TextInputAction.next,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Notas ─────────────────────────────────────────────
                AppTextField(
                  controller: _notasCtrl,
                  label: 'NOTAS (opcional)',
                  hint: 'Cualquier observación relevante…',
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: _isLoading
                      ? null
                      : () => tiposAsync.whenData(
                          (tipos) => gruposAsync.whenData(
                            (grupos) => _submit(tipos, grupos),
                          ),
                        ),
                ),
                const SizedBox(height: 32),

                GreenButton(
                  label:
                      'Registrar lote (${_brazaletesSeleccionados.length} aves)',
                  isLoading: _isLoading,
                  onPressed: () => tiposAsync.whenData(
                    (tipos) => gruposAsync.whenData(
                      (grupos) => _submit(tipos, grupos),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET DE BRAZALETES
// ─────────────────────────────────────────────────────────────────────────────
class _BrazaletesWidget extends StatefulWidget {
  final Set<int> usados;
  final Set<int> seleccionados;
  final TextEditingController manualCtrl;
  final ValueChanged<int> onAutoAsignar;
  final VoidCallback onAgregarManual;
  final ValueChanged<int> onRemover;
  final VoidCallback onClearError;

  const _BrazaletesWidget({
    required this.usados,
    required this.seleccionados,
    required this.manualCtrl,
    required this.onAutoAsignar,
    required this.onAgregarManual,
    required this.onRemover,
    required this.onClearError,
  });

  @override
  State<_BrazaletesWidget> createState() => _BrazaletesWidgetState();
}

class _BrazaletesWidgetState extends State<_BrazaletesWidget> {
  // Panel inline de auto-asignar (true = visible)
  bool _autoExpanded = false;
  final _cantAutoCtrl = TextEditingController(text: '10');

  @override
  void dispose() {
    _cantAutoCtrl.dispose();
    super.dispose();
  }

  List<int> _preview() {
    final cantidad = int.tryParse(_cantAutoCtrl.text.trim()) ?? 0;
    if (cantidad <= 0) return [];
    final todos = {...widget.usados, ...widget.seleccionados};
    final result = <int>[];
    int sig = todos.isEmpty ? 1 : todos.reduce((a, b) => a > b ? a : b) + 1;
    while (result.length < cantidad) {
      if (!todos.contains(sig)) result.add(sig);
      sig++;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final selList = widget.seleccionados.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label + botón Auto-asignar ─────────────────────────────────
        Row(
          children: [
            const _SectionLabel(label: 'BRAZALETES (opcional)'),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _autoExpanded = !_autoExpanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Auto-asignar',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    _autoExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Asigna números para identificar cada ave del lote. '
          'Puedes hacerlo después.',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),

        // ── Panel inline Auto-asignar ──────────────────────────────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _autoExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _buildAutoPanel(),
          secondChild: const SizedBox(width: double.infinity),
        ),

        const SizedBox(height: 8),

        // ── Contador ───────────────────────────────────────────────────
        Text(
          'Seleccionados: ${widget.seleccionados.length}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: widget.seleccionados.isEmpty
                ? AppColors.textSecondary
                : AppColors.green,
          ),
        ),
        const SizedBox(height: 10),

        // ── Chips de brazaletes ────────────────────────────────────────
        if (selList.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selList
                .map(
                  (n) => GestureDetector(
                    onTap: () => widget.onRemover(n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '#$n',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.close,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
        ],

        // ── Input manual + Añadir ──────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: widget.manualCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Otro número',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onSubmitted: (_) => widget.onAgregarManual(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                widget.onClearError();
                widget.onAgregarManual();
              },
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 16, color: AppColors.green),
                    const SizedBox(width: 4),
                    const Text(
                      'Añadir',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAutoPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cantidad rápida
          const Text(
            'CANTIDAD',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final qty in ['5', '10', '20', '50']) ...[
                GestureDetector(
                  onTap: () => setState(() => _cantAutoCtrl.text = qty),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _cantAutoCtrl.text == qty
                          ? AppColors.green
                          : AppColors.bgCard2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _cantAutoCtrl.text == qty
                            ? AppColors.green
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      qty,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _cantAutoCtrl.text == qty
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Input personalizado compacto
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.bgCard2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _cantAutoCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'N',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}), // re-render preview
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Previsualización
          Builder(
            builder: (_) {
              final prev = _preview();
              if (prev.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PREVISUALIZACIÓN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...prev
                          .take(15)
                          .map(
                            (n) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: AppColors.green.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '#$n',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.green,
                                ),
                              ),
                            ),
                          ),
                      if (prev.length > 15)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          child: Text(
                            '+${prev.length - 15} más',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),

          // Botón Asignar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              onPressed: () {
                final cantidad = int.tryParse(_cantAutoCtrl.text.trim()) ?? 0;
                if (cantidad > 0) {
                  widget.onAutoAsignar(cantidad);
                  setState(() => _autoExpanded = false);
                }
              },
              child: Text(
                'Asignar ${_preview().length > 0 ? "(${_preview().length} brazaletes)" : ""}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 0.8,
    ),
  );
}

class _SeccionChips extends StatelessWidget {
  final String label;
  final List<(String, String)> items;
  final String? seleccionado;
  final ValueChanged<String> onSeleccionar;
  final String? emptyMessage;

  const _SeccionChips({
    required this.label,
    required this.items,
    required this.seleccionado,
    required this.onSeleccionar,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionLabel(label: label),
      const SizedBox(height: 8),
      if (items.isEmpty)
        Text(
          emptyMessage ?? 'Sin opciones disponibles',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        )
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
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: sel ? AppColors.green : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel ? AppColors.green : AppColors.border,
                  ),
                ),
                child: Text(
                  item.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
    ],
  );
}
