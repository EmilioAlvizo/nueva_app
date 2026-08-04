import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/compact_form_controls.dart';
import '../model/animal/animal.dart';
import '../model/bajaAnimal/registrar_baja_animales_input.dart';
import '../model/catalogoItem/catalogo_item.dart';
import 'animales_provider.dart';
import 'baja_eligibility.dart';

class RegistrarBajaSheet extends ConsumerStatefulWidget {
  const RegistrarBajaSheet({
    super.key,
    required this.granjaId,
    required this.isDark,
    this.tipoAnimalIdInicial,
    this.initialBajaDate,
  });

  final String granjaId;
  final bool isDark;
  final String? tipoAnimalIdInicial;
  final DateTime? initialBajaDate;

  @override
  ConsumerState<RegistrarBajaSheet> createState() => _RegistrarBajaSheetState();
}

class _RegistrarBajaSheetState extends ConsumerState<RegistrarBajaSheet> {
  final _importeCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  late DateTime _fechaBaja;
  String? _tipoAnimalId;
  String? _razonBajaId;
  bool _guardando = false;
  String _query = '';
  final Set<String> _selectedAnimalIds = <String>{};

  @override
  void initState() {
    super.initState();
    _fechaBaja = widget.initialBajaDate ?? DateTime.now();
    _tipoAnimalId = widget.tipoAnimalIdInicial;
  }

  @override
  void dispose() {
    _importeCtrl.dispose();
    _notasCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tiposAsync = ref.watch(tiposAnimalProvider(widget.granjaId));
    final razonesAsync = ref.watch(razonesBajaProvider(widget.granjaId));
    final animalesAsync = ref.watch(animalesProvider(widget.granjaId));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final tipos = tiposAsync.value ?? const [];
    if (_tipoAnimalId == null && tipos.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tipoAnimalId == null) {
          setState(() => _tipoAnimalId = tipos.single.id);
        }
      });
    }

    final animalesElegiblesPorTipo = (animalesAsync.value ?? const <Animal>[])
        .where(
          (animal) =>
              _tipoAnimalId != null &&
              isAnimalEligibleForBaja(
                animal,
                tipoAnimalId: _tipoAnimalId!,
                fechaBaja: _fechaBaja,
              ),
        )
        .toList(growable: false);

    final animalesElegibles = animalesElegiblesPorTipo
        .where((animal) {
          final query = _query.trim().toLowerCase();
          if (query.isEmpty) {
            return true;
          }

          final bracelet = animal.brazalete?.toString() ?? '';
          return bracelet.contains(query) ||
              animal.grupoNombre.toLowerCase().contains(query) ||
              animal.tipoNombre.toLowerCase().contains(query);
        })
        .toList(growable: false);

    final selectedAnimals = (animalesAsync.value ?? const <Animal>[])
        .where((animal) => _selectedAnimalIds.contains(animal.id))
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.6,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) {
          return Material(
            key: const Key('registrar-baja-sheet'),
            color: widget.isDark ? AppColors.bg : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: ListView(
              key: const Key('registrar-baja-scroll-view'),
              controller: scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? AppColors.border1lg
                          : AppColors.border1,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Nueva baja',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: widget.isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLg,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Selecciona los animales activos que deseas marcar como baja.',
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLg,
                  ),
                ),
                const SizedBox(height: 18),
                tiposAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Error: $error'),
                  data: (tipos) => CompactDropdownFormField<String>(
                    key: const Key('baja-animal-type-field'),
                    dropdownKey: const Key('baja-animal-type-dropdown'),
                    label: 'Tipo de animal',
                    value: _tipoAnimalId,
                    items: tipos.map((tipo) => tipo.id).toList(),
                    itemLabelBuilder: (id) =>
                        tipos.firstWhere((tipo) => tipo.id == id).nombre,
                    itemKeyBuilder: (id) => Key('baja-animal-type-option-$id'),
                    hintText: 'Selecciona un tipo',
                    onChanged: (value) {
                      setState(() {
                        _tipoAnimalId = value;
                        _selectedAnimalIds.clear();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 14),
                razonesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Error: $error'),
                  data: (razones) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Razón de baja',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLg,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _RazonBajaSelector(
                        razones: razones,
                        seleccionadaId: _razonBajaId,
                        isDark: widget.isDark,
                        onSelected: (id) => setState(() => _razonBajaId = id),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CompactDateField(
                  key: const Key('baja-date-field'),
                  label: 'Fecha',
                  value: _fechaBaja,
                  onTap: _seleccionarFecha,
                  formatter: (value) =>
                      DateFormat("d 'de' MMMM yyyy").format(value),
                ),
                const SizedBox(height: 16),
                CompactLabeledField(
                  label: 'Importe (opcional)',
                  child: TextField(
                    key: const Key('baja-amount-field'),
                    controller: _importeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: compactInputDecoration(
                      context,
                      prefixText: '\$ ',
                      hintText: '0.00',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CompactLabeledField(
                  label: 'Notas (opcional)',
                  child: TextField(
                    key: const Key('baja-notes-field'),
                    controller: _notasCtrl,
                    maxLines: 3,
                    decoration: compactInputDecoration(
                      context,
                      hintText: 'Detalles adicionales…',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                CompactLabeledField(
                  label: 'Buscar animal',
                  child: TextField(
                    key: const Key('baja-search-field'),
                    controller: _searchCtrl,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: compactInputDecoration(
                      context,
                      hintText: 'Brazalete, grupo o tipo',
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SelectedAnimalsSummary(
                  animals: selectedAnimals,
                  isDark: widget.isDark,
                  onRemove: (animalId) =>
                      setState(() => _selectedAnimalIds.remove(animalId)),
                ),
                const SizedBox(height: 12),
                Text(
                  'Animales afectados',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLg,
                  ),
                ),
                const SizedBox(height: 8),
                animalesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Error: $error'),
                  data: (_) {
                    if (_tipoAnimalId == null) {
                      return _InfoBox(
                        isDark: widget.isDark,
                        message:
                            'Selecciona un tipo para listar animales activos.',
                      );
                    }

                    if (animalesElegiblesPorTipo.isEmpty) {
                      return _InfoBox(
                        isDark: widget.isDark,
                        message:
                            'No hay animales disponibles para este tipo y fecha.',
                      );
                    }

                    if (animalesElegibles.isEmpty) {
                      return _InfoBox(
                        isDark: widget.isDark,
                        message:
                            'No hay animales que coincidan con la búsqueda.',
                      );
                    }

                    return Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.isDark
                              ? AppColors.border1lg
                              : AppColors.border1,
                        ),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: animalesElegibles.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: widget.isDark
                              ? AppColors.border1lg
                              : AppColors.border1,
                        ),
                        itemBuilder: (context, index) {
                          final animal = animalesElegibles[index];
                          final selected = _selectedAnimalIds.contains(
                            animal.id,
                          );
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (_) => _toggleAnimal(animal.id),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              animal.brazalete != null
                                  ? '#${animal.brazalete} · ${animal.tipoNombre}'
                                  : 'Sin brazalete · ${animal.tipoNombre}',
                            ),
                            subtitle: Text(animal.grupoNombre),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_guardando ? 'Guardando…' : 'Registrar baja'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _toggleAnimal(String animalId) {
    setState(() {
      if (_selectedAnimalIds.contains(animalId)) {
        _selectedAnimalIds.remove(animalId);
      } else {
        _selectedAnimalIds.add(animalId);
      }
    });
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaBaja,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (!mounted || fecha == null) {
      return;
    }

    final tipoAnimalId = _tipoAnimalId;
    final animales = ref
        .read(animalesProvider(widget.granjaId))
        .unwrapPrevious()
        .value;
    if (tipoAnimalId == null) {
      setState(() => _fechaBaja = fecha);
      return;
    }

    final reconciliation = reconcileBajaSelectionIfAvailable(
      selectedAnimalIds: _selectedAnimalIds,
      animals: animales,
      tipoAnimalId: tipoAnimalId,
      fechaBaja: fecha,
    );
    setState(() {
      _fechaBaja = fecha;
      if (reconciliation != null) {
        _selectedAnimalIds
          ..clear()
          ..addAll(reconciliation.eligibleIds);
      }
    });

    if (reconciliation != null && reconciliation.removedCount > 0) {
      _showMessage(_removedSelectionsMessage(reconciliation.removedCount));
    }
  }

  Future<void> _guardar() async {
    if (_tipoAnimalId == null) {
      _showMessage('Selecciona un tipo de animal.');
      return;
    }
    if (_razonBajaId == null) {
      _showMessage('Selecciona una razón de baja.');
      return;
    }
    if (_selectedAnimalIds.isEmpty) {
      _showMessage('Selecciona al menos un animal.');
      return;
    }

    setState(() => _guardando = true);
    try {
      final importeTexto = _importeCtrl.text.trim();
      final importe = importeTexto.isEmpty
          ? null
          : double.tryParse(importeTexto.replaceAll(',', '.'));
      if (importeTexto.isNotEmpty && importe == null) {
        _showMessage('Ingresa un importe válido.');
        return;
      }

      late final List<Animal> animales;
      try {
        animales = await ref.read(animalesProvider(widget.granjaId).future);
      } catch (_) {
        _showMessage(
          'No se pudo actualizar la lista de animales. Intenta nuevamente.',
        );
        return;
      }

      if (!mounted) {
        return;
      }

      final reconciliation = reconcileBajaSelection(
        selectedAnimalIds: _selectedAnimalIds,
        animals: animales,
        tipoAnimalId: _tipoAnimalId!,
        fechaBaja: _fechaBaja,
      );
      if (reconciliation.removedCount > 0) {
        setState(() {
          _selectedAnimalIds
            ..clear()
            ..addAll(reconciliation.eligibleIds);
        });
        _showMessage(
          'La selección cambió. ${_removedSelectionsMessage(reconciliation.removedCount)}',
        );
        return;
      }

      if (_selectedAnimalIds.isEmpty) {
        _showMessage('Selecciona al menos un animal.');
        return;
      }

      await ref
          .read(animalesRepositoryProvider)
          .registrarBajaAnimales(
            RegistrarBajaAnimalesInput(
              granjaId: widget.granjaId,
              tipoAnimalId: _tipoAnimalId!,
              razonBajaId: _razonBajaId!,
              fechaBaja: _fechaBaja,
              animalIds: _selectedAnimalIds.toList(growable: false),
              importeTotal: importe,
              notas: _notasCtrl.text.trim().isEmpty
                  ? null
                  : _notasCtrl.text.trim(),
            ),
          );

      invalidateAnimalesInventoryMutationProviders(ref, widget.granjaId);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _selectedAnimalIds.length == 1
                  ? 'Baja registrada correctamente'
                  : 'Bajas registradas correctamente',
            ),
          ),
        );
      }
    } catch (error) {
      _showMessage('Error al registrar la baja: $error');
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  String _removedSelectionsMessage(int count) => count == 1
      ? 'Se quitó 1 animal porque ya no es válido para la fecha seleccionada.'
      : 'Se quitaron $count animales porque ya no son válidos para la fecha seleccionada.';

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RazonBajaSelector extends StatelessWidget {
  const _RazonBajaSelector({
    required this.razones,
    required this.seleccionadaId,
    required this.isDark,
    required this.onSelected,
  });

  final List<CatalogoItem> razones;
  final String? seleccionadaId;
  final bool isDark;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: razones
          .map((razon) {
            final active = razon.id == seleccionadaId;
            return ChoiceChip(
              label: Text(razon.nombre),
              selected: active,
              onSelected: (_) => onSelected(razon.id),
              selectedColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.18),
              labelStyle: TextStyle(
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : (isDark
                          ? AppColors.textPrimary
                          : AppColors.textPrimaryLg),
              ),
              backgroundColor: isDark ? AppColors.bgCard2 : AppColors.bgLight,
              side: BorderSide(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : (isDark ? AppColors.border1lg : AppColors.border1),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _SelectedAnimalsSummary extends StatelessWidget {
  const _SelectedAnimalsSummary({
    required this.animals,
    required this.isDark,
    required this.onRemove,
  });

  final List<Animal> animals;
  final bool isDark;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textPrimary : AppColors.textPrimaryLg;
    final helperColor = isDark
        ? AppColors.textSecondary
        : AppColors.textSecondaryLg;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard : AppColors.bgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.border1lg : AppColors.border1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            animals.isEmpty
                ? 'No hay animales seleccionados'
                : '${animals.length} animal${animals.length == 1 ? '' : 'es'} seleccionado${animals.length == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          if (animals.isEmpty)
            Text(
              'Marca uno o más animales activos para registrar la baja.',
              style: TextStyle(fontSize: 12, color: helperColor),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final animal in animals)
                  InputChip(
                    label: Text(
                      animal.brazalete != null
                          ? '#${animal.brazalete} · ${animal.grupoNombre}'
                          : 'Sin brazalete · ${animal.grupoNombre}',
                    ),
                    onDeleted: () => onRemove(animal.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.isDark, required this.message});

  final bool isDark;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard : AppColors.bgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.border1lg : AppColors.border1,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLg,
        ),
      ),
    );
  }
}
