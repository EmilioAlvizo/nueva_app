// lib/features/model/loteEntrada/nuevo_loteEntrada.dart
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

// ─── Modelos de catálogo simples ──────────────────────────────────────────────
class _CatItem {
  final String id;
  final String nombre;
  const _CatItem(this.id, this.nombre);
}

// ─── Provider de catálogos (cargados una vez) ─────────────────────────────────
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
  final _cantidadCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  String? _tipoSeleccionado;
  String? _grupoSeleccionado;
  String? _tipoAdquisicionSeleccionado;
  String? _propositoSeleccionado;
  DateTime _fecha = DateTime.now();

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
    _cantidadCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      //locale: const Locale('es', 'MX'),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  // RPC que ya existe en tu DB — inserta lote + ejemplares en una transacción
  Future<void> _submit(
    List<TipoAnimal> tipos,
    List<Grupo> grupos,
  ) async {
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final granjaId = ref.read(selectedFarmProvider)?.id ?? '';
      final userId = supabase.auth.currentUser?.id ?? '';
      final cantidad = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;
      final costo = double.tryParse(_costoCtrl.text.trim().replaceAll(',', '.'));

      // Usa la RPC registrar_lote_entrada que ya tienes en Supabase
      await supabase.rpc('registrar_lote_entrada', params: {
        'p_granja_id': granjaId,
        'p_tipo_animal_id': _tipoSeleccionado,
        'p_grupo_id': _grupoSeleccionado,
        'p_proposito_id': _propositoSeleccionado,
        'p_tipo_adquisicion_id': _tipoAdquisicionSeleccionado,
        'p_fecha_adquisicion': DateFormat('yyyy-MM-dd').format(_fecha),
        'p_cantidad': cantidad,
        'p_costo_total': costo,
        'p_proveedor': _proveedorCtrl.text.trim().isEmpty
            ? null
            : _proveedorCtrl.text.trim(),
        'p_notas': _notasCtrl.text.trim().isEmpty
            ? null
            : _notasCtrl.text.trim(),
        'p_created_by': userId,
      });

      // Refrescar conteos y lotes
      ref.invalidate(conteosGruposProvider(granjaId));
      ref.invalidate(lotesDeGrupoProvider(_grupoSeleccionado!));

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

    final bgColor = widget.isDark ? AppColors.bg : Colors.white;
    final titleColor = widget.isDark ? AppColors.textPrimary : const Color(0xFF1A1A2E);
    final fmtFecha = DateFormat("d 'de' MMMM yyyy");

    // Grupos filtrados por tipo seleccionado
    final gruposFiltrados = gruposAsync.value
            ?.where((g) =>
                _tipoSeleccionado == null ||
                g.tipoAnimalId == _tipoSeleccionado)
            .toList() ??
        [];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
              color: widget.isDark ? AppColors.border : Colors.black12),
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
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: widget.isDark ? AppColors.border : Colors.grey.shade300,
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
                        color: AppColors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.inventory_2_outlined,
                          color: AppColors.green, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Text('Nuevo lote de entrada',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Registra varios ejemplares adquiridos juntos.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),

                // Error banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13)),
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
                      _grupoSeleccionado = null; // reset grupo
                    }),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Grupo (filtrado por tipo) ──────────────────────────
                _SeccionChips(
                  label: 'GRUPO',
                  items: gruposFiltrados.map((g) => (g.id, g.nombre)).toList(),
                  seleccionado: _grupoSeleccionado,
                  onSeleccionar: (id) => setState(() => _grupoSeleccionado = id),
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

                // ── Fecha de adquisición ──────────────────────────────
                _SectionLabel(label: 'FECHA DE ADQUISICIÓN'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _elegirFecha,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Text(
                          fmtFecha.format(_fecha),
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Cantidad de ejemplares ────────────────────────────
                AppTextField(
                  controller: _cantidadCtrl,
                  label: 'CANTIDAD DE EJEMPLARES',
                  hint: 'Ej. 10',
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.number,
                  /* inputFormatters: [FilteringTextInputFormatter.digitsOnly], */
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Ingresa la cantidad';
                    }
                    final n = int.tryParse(val.trim());
                    if (n == null || n <= 0) return 'Debe ser mayor a 0';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Proveedor (opcional) ──────────────────────────────
                AppTextField(
                  controller: _proveedorCtrl,
                  label: 'PROVEEDOR (opcional)',
                  hint: 'Ej. Granja San Luis, Mercado local…',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),

                // ── Costo total (opcional) ────────────────────────────
                AppTextField(
                  controller: _costoCtrl,
                  label: 'COSTO TOTAL (opcional)',
                  hint: 'Ej. 1500',
                  textInputAction: TextInputAction.next,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  /* inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ], */
                ),
                const SizedBox(height: 20),

                // ── Notas (opcional) ──────────────────────────────────
                AppTextField(
                  controller: _notasCtrl,
                  label: 'NOTAS (opcional)',
                  hint: 'Cualquier observación relevante…',
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: _isLoading
                      ? null
                      : () => tiposAsync.whenData((tipos) =>
                          gruposAsync.whenData((grupos) => _submit(tipos, grupos))),
                ),
                const SizedBox(height: 32),

                GreenButton(
                  label: 'Registrar lote',
                  isLoading: _isLoading,
                  onPressed: () => tiposAsync.whenData((tipos) =>
                      gruposAsync.whenData((grupos) => _submit(tipos, grupos))),
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
// WIDGETS AUXILIARES COMPARTIDOS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SeccionChips extends StatelessWidget {
  final String label;
  final List<(String, String)> items; // (id, nombre)
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: label),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            emptyMessage ?? 'Sin opciones disponibles',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
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
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.green : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? AppColors.green : AppColors.border),
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
}