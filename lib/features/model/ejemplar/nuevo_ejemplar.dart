// lib/features/animales/model/ejemplar/nuevo_ejemplar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../features/animales/animales_provider.dart';
//import '../../animales_provider.dart';
import '../grupo/grupo.dart';
import 'ejemplar.dart';

/// Bottom sheet para crear o editar un [Ejemplar].
///
/// - Modo creación: pasa `ejemplar: null`.
/// - Modo edición: pasa el [Ejemplar] existente; los campos se precargan.
class NuevoEjemplar extends ConsumerStatefulWidget {
  final String granjaId;
  final bool isDark;
  final Ejemplar? ejemplar;

  /// Tipo de animal preseleccionado (por ejemplo, el filtro activo de la
  /// pantalla) cuando se crea un ejemplar nuevo.
  final String? tipoAnimalIdInicial;

  const NuevoEjemplar({
    super.key,
    required this.granjaId,
    required this.isDark,
    this.ejemplar,
    this.tipoAnimalIdInicial,
  });

  @override
  ConsumerState<NuevoEjemplar> createState() => _NuevoEjemplarState();
}

class _NuevoEjemplarState extends ConsumerState<NuevoEjemplar> {
  final _formKey = GlobalKey<FormState>();
  final _brazaleteCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  String? _tipoAnimalId;
  String? _grupoId;
  String? _propositoId;
  String? _tipoAdquisicionId;
  DateTime _fecha = DateTime.now();
  bool _activo = true;
  bool _guardando = false;

  bool get _esEdicion => widget.ejemplar != null;

  @override
  void initState() {
    super.initState();
    final ej = widget.ejemplar;
    if (ej != null) {
      _tipoAnimalId = ej.tipoAnimalId;
      _grupoId = ej.grupoId;
      _propositoId = ej.propositoId;
      _tipoAdquisicionId = ej.tipoAdquisicionId;
      _brazaleteCtrl.text = ej.brazalete.toString();
      _costoCtrl.text = ej.costoAdquisicion?.toString() ?? '';
      _notasCtrl.text = ej.notas ?? '';
      _fecha = ej.fechaAdquisicion;
      _activo = ej.activo;
    } else if (widget.tipoAnimalIdInicial != null) {
      _tipoAnimalId = widget.tipoAnimalIdInicial;
    }
  }

  @override
  void dispose() {
    _brazaleteCtrl.dispose();
    _costoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _guardar() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) return;

    if (_tipoAnimalId == null ||
        _grupoId == null ||
        _propositoId == null ||
        _tipoAdquisicionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos requeridos')),
      );
      return;
    }

    setState(() => _guardando = true);
    final repo = ref.read(animalesRepositoryProvider);
    final costo = _costoCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_costoCtrl.text.trim());
    final notas = _notasCtrl.text.trim().isEmpty
        ? null
        : _notasCtrl.text.trim();

    try {
      if (_esEdicion) {
        await repo.updateEjemplar(
          id: widget.ejemplar!.id,
          tipoAnimalId: _tipoAnimalId!,
          grupoId: _grupoId!,
          brazalete: int.parse(_brazaleteCtrl.text.trim()),
          propositoId: _propositoId!,
          tipoAdquisicionId: _tipoAdquisicionId!,
          fechaAdquisicion: _fecha,
          costoAdquisicion: costo,
          notas: notas,
          activo: _activo,
        );
      } else {
        await repo.addEjemplar(
          granjaId: widget.granjaId,
          tipoAnimalId: _tipoAnimalId!,
          grupoId: _grupoId!,
          brazalete: int.parse(_brazaleteCtrl.text.trim()),
          propositoId: _propositoId!,
          tipoAdquisicionId: _tipoAdquisicionId!,
          fechaAdquisicion: _fecha,
          costoAdquisicion: costo,
          notas: notas,
        );
      }

      ref.invalidate(ejemplaresProvider(widget.granjaId));
      ref.invalidate(conteosGruposProvider(widget.granjaId));

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    final tiposAsync = ref.watch(tiposAnimalProvider(widget.granjaId));
    final gruposAsync = ref.watch(gruposProvider(widget.granjaId));
    final propositosAsync = ref.watch(propositosProvider(widget.granjaId));
    final tiposAdqAsync = ref.watch(tiposAdquisicionProvider(widget.granjaId));

    final tipos = tiposAsync.value ?? [];
    final gruposTodos = gruposAsync.value ?? [];
    final grupos = _tipoAnimalId == null
        ? <Grupo>[]
        : gruposTodos.where((g) => g.tipoAnimalId == _tipoAnimalId).toList();

    // Si cambiamos de tipo y el grupo elegido ya no aplica, lo limpiamos.
    if (_grupoId != null && !grupos.any((g) => g.id == _grupoId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _grupoId = null);
      });
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.bgCard : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.border1lg : AppColors.border1,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(
                  _esEdicion ? 'Editar ejemplar' : 'Nuevo ejemplar',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLg,
                  ),
                ),
                const SizedBox(height: 18),

                // ── Tipo de animal ──────────────────────────────────────
                _Label('Tipo de animal', isDark),
                DropdownButtonFormField<String>(
                  value: _tipoAnimalId,
                  items: tipos
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(t.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _tipoAnimalId = v;
                    _grupoId = null;
                  }),
                  validator: (v) => v == null ? 'Selecciona un tipo' : null,
                  decoration: const InputDecoration(
                    hintText: 'Selecciona un tipo',
                  ),
                ),
                const SizedBox(height: 14),

                // ── Grupo ────────────────────────────────────────────────
                _Label('Grupo', isDark),
                DropdownButtonFormField<String>(
                  value: _grupoId,
                  items: grupos
                      .map(
                        (g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(g.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: _tipoAnimalId == null
                      ? null
                      : (v) => setState(() => _grupoId = v),
                  validator: (v) => v == null ? 'Selecciona un grupo' : null,
                  decoration: InputDecoration(
                    hintText: _tipoAnimalId == null
                        ? 'Elige primero un tipo'
                        : 'Selecciona un grupo',
                  ),
                ),
                const SizedBox(height: 14),

                // ── Brazalete ────────────────────────────────────────────
                _Label('Número de brazalete', isDark),
                TextFormField(
                  controller: _brazaleteCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Ej. 24'),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Ingresa un número válido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Propósito ────────────────────────────────────────────
                _Label('Propósito', isDark),
                propositosAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error al cargar propósitos: $e'),
                  data: (props) => DropdownButtonFormField<String>(
                    value: _propositoId,
                    items: props
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.nombre),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _propositoId = v),
                    validator: (v) =>
                        v == null ? 'Selecciona un propósito' : null,
                    decoration: const InputDecoration(
                      hintText: 'Selecciona un propósito',
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Forma de adquisición ─────────────────────────────────
                _Label('Forma de adquisición', isDark),
                tiposAdqAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error al cargar catálogo: $e'),
                  data: (lista) => DropdownButtonFormField<String>(
                    value: _tipoAdquisicionId,
                    items: lista
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.nombre),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _tipoAdquisicionId = v),
                    validator: (v) => v == null ? 'Selecciona una opción' : null,
                    decoration: const InputDecoration(
                      hintText: 'Selecciona una opción',
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Fecha de adquisición ─────────────────────────────────
                _Label('Fecha de adquisición', isDark),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _seleccionarFecha,
                  child: InputDecorator(
                    decoration: const InputDecoration(),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLg,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat("d 'de' MMMM yyyy").format(_fecha),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.textPrimary
                                : AppColors.textPrimaryLg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Costo (opcional) ─────────────────────────────────────
                _Label('Costo de adquisición (opcional)', isDark),
                TextFormField(
                  controller: _costoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(hintText: r'$ 0.00'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return double.tryParse(v.trim()) == null
                        ? 'Ingresa un número válido'
                        : null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Notas (opcional) ─────────────────────────────────────
                _Label('Notas (opcional)', isDark),
                TextFormField(
                  controller: _notasCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Observaciones…',
                  ),
                ),

                if (_esEdicion) ...[
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _activo,
                    onChanged: (v) => setState(() => _activo = v),
                    activeColor: AppColors.green,
                    title: Text(
                      'Ejemplar activo',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.textPrimaryLg,
                      ),
                    ),
                    subtitle: Text(
                      'Desactívalo solo si ya no corresponde a una baja formal',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLg,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _guardando ? null : _guardar,
                    child: _guardando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _esEdicion ? 'Guardar cambios' : 'Agregar ejemplar',
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final bool isDark;
  const _Label(this.text, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLg,
        ),
      ),
    );
  }
}