// lib/features/animales/widgets/editar_baja_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'animales_provider.dart';
import '../model/bajaAnimal/baja_animal.dart';
import '../model/catalogoItem/catalogo_item.dart';
import '../../core/theme/app_colors.dart';

/// Bottom sheet para editar una baja ya registrada. Solo permite modificar
/// razón, fecha, importe y notas — no la cantidad de animales ni cuáles
/// están enlazados, ya que eso equivaldría a crear un evento nuevo.
class EditarBajaSheet extends ConsumerStatefulWidget {
  final BajaAnimal baja;
  final bool isDark;

  const EditarBajaSheet({
    super.key,
    required this.baja,
    required this.isDark,
  });

  @override
  ConsumerState<EditarBajaSheet> createState() => _EditarBajaSheetState();
}

class _EditarBajaSheetState extends ConsumerState<EditarBajaSheet> {
  late String _razonBajaId;
  late DateTime _fechaBaja;
  late final TextEditingController _importeCtrl;
  late final TextEditingController _notasCtrl;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _razonBajaId = widget.baja.razonBajaId;
    _fechaBaja = widget.baja.fechaBaja;
    _importeCtrl = TextEditingController(
      text: widget.baja.importeTotal != null
          ? widget.baja.importeTotal!.toStringAsFixed(2)
          : '',
    );
    _notasCtrl = TextEditingController(text: widget.baja.notas ?? '');
  }

  @override
  void dispose() {
    _importeCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final razonesAsync = ref.watch(razonesBajaProvider(widget.baja.granjaId));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: widget.isDark ? AppColors.bgCard : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? AppColors.border1lg
                          : AppColors.border1,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(
                  'Editar baja',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.baja.esLote
                      ? '${widget.baja.cantidadAnimales} animales · ${widget.baja.tipoNombre}'
                      : '${widget.baja.tipoNombre}'
                            '${widget.baja.brazaletes.isNotEmpty ? ' · #${widget.baja.brazaletes.first}' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLg,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Razón de baja ──────────────────────────────────────
                Text(
                  'Razón',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLg,
                  ),
                ),
                const SizedBox(height: 8),
                razonesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (razones) => _RazonSelector(
                    razones: razones,
                    seleccionadaId: _razonBajaId,
                    isDark: widget.isDark,
                    onSelected: (id) => setState(() => _razonBajaId = id),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Fecha ───────────────────────────────────────────────
                Text(
                  'Fecha',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLg,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _seleccionarFecha,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isDark
                            ? AppColors.border1lg
                            : AppColors.border1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: widget.isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLg,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat("d 'de' MMMM yyyy").format(_fechaBaja),
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.isDark
                                ? AppColors.textPrimary
                                : AppColors.textPrimaryLg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Importe ─────────────────────────────────────────────
                Text(
                  'Importe (opcional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLg,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _importeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    hintText: '0.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Notas ───────────────────────────────────────────────
                Text(
                  'Notas (opcional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLg,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notasCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Detalles adicionales…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Botón guardar ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Guardar cambios'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaBaja,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (fecha != null) setState(() => _fechaBaja = fecha);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final importeTexto = _importeCtrl.text.trim();
      final importe = importeTexto.isEmpty
          ? null
          : double.tryParse(importeTexto.replaceAll(',', '.'));

      await ref.read(animalesRepositoryProvider).actualizarBaja(
            id: widget.baja.id,
            razonBajaId: _razonBajaId,
            fechaBaja: _fechaBaja,
            importeTotal: importe,
            notas: _notasCtrl.text.trim().isEmpty
                ? null
                : _notasCtrl.text.trim(),
          );

      ref.invalidate(bajasAnimalesProvider(widget.baja.granjaId));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Baja actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

/// Chips seleccionables para elegir la razón de baja.
class _RazonSelector extends StatelessWidget {
  final List<CatalogoItem> razones;
  final String seleccionadaId;
  final bool isDark;
  final ValueChanged<String> onSelected;

  const _RazonSelector({
    required this.razones,
    required this.seleccionadaId,
    required this.isDark,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: razones.map((r) {
        final activo = r.id == seleccionadaId;
        return ChoiceChip(
          label: Text(r.nombre),
          selected: activo,
          onSelected: (_) => onSelected(r.id),
          selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
          labelStyle: TextStyle(
            fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
            color: activo
                ? Theme.of(context).colorScheme.primary
                : (isDark ? AppColors.textPrimary : AppColors.textPrimaryLg),
          ),
          backgroundColor: isDark ? AppColors.bgCard2 : AppColors.bgLight,
          side: BorderSide(
            color: activo
                ? Theme.of(context).colorScheme.primary
                : (isDark ? AppColors.border1lg : AppColors.border1),
          ),
        );
      }).toList(),
    );
  }
}