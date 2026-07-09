import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nueva_app/features/animales/animales_provider.dart';
import 'package:nueva_app/features/model/altaAnimales/bracelet_assignment.dart';
import 'package:nueva_app/features/model/altaAnimales/registrar_alta_animales_input.dart';

import '../../../../core/theme/app_colors.dart';

const _visibleAvailableBraceletLimit = 10;

class AnimalRegistrationSheet extends ConsumerStatefulWidget {
  const AnimalRegistrationSheet({
    super.key,
    required this.granjaId,
    required this.isDark,
    this.initialQuantity = 1,
    this.tipoAnimalIdInicial,
  });

  final String granjaId;
  final bool isDark;
  final int initialQuantity;
  final String? tipoAnimalIdInicial;

  @override
  ConsumerState<AnimalRegistrationSheet> createState() =>
      _AnimalRegistrationSheetState();
}

class _AnimalRegistrationSheetState
    extends ConsumerState<AnimalRegistrationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _manualBraceletController = TextEditingController();
  final _manualBraceletFocusNode = FocusNode();
  final _providerController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  final _singleBraceletController = TextEditingController();

  late int _quantity;
  late DateTime _date;
  String? _tipoAnimalId;
  String? _grupoId;
  String? _propositoId;
  String? _tipoAdquisicionId;
  bool _useSingleBracelet = false;
  bool _braceletPanelEnabled = false;
  bool _saving = false;
  String? _errorText;
  BraceletAssignment? _assignment;

  bool get _isSingleMode => _quantity == 1;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity < 1 ? 1 : widget.initialQuantity;
    _date = DateTime.now();
    _tipoAnimalId = widget.tipoAnimalIdInicial;
  }

  @override
  void dispose() {
    _manualBraceletController.dispose();
    _manualBraceletFocusNode.dispose();
    _providerController.dispose();
    _costController.dispose();
    _notesController.dispose();
    _singleBraceletController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tiposAsync = ref.watch(tiposAnimalProvider(widget.granjaId));
    final gruposAsync = ref.watch(gruposProvider(widget.granjaId));
    final propositosAsync = ref.watch(propositosProvider(widget.granjaId));
    final tiposAdquisicionAsync = ref.watch(
      tiposAdquisicionProvider(widget.granjaId),
    );

    final availableAsync = _tipoAnimalId == null
        ? const AsyncValue<List<int>>.data([])
        : ref.watch(
            availableBraceletsProvider(
              BraceletAvailabilityQuery(
                granjaId: widget.granjaId,
                tipoAnimalId: _tipoAnimalId!,
              ),
            ),
          );

    final grupos = (gruposAsync.value ?? [])
        .where(
          (grupo) =>
              _tipoAnimalId == null || grupo.tipoAnimalId == _tipoAnimalId,
        )
        .toList();

    final tipos = tiposAsync.value ?? const [];
    if (_tipoAnimalId == null && tipos.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tipoAnimalId == null) {
          setState(() => _tipoAnimalId = tipos.single.id);
        }
      });
    }

    if (_grupoId != null && !grupos.any((grupo) => grupo.id == _grupoId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _grupoId = null);
        }
      });
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.bg : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
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
                  _isSingleMode
                      ? 'Nueva alta de animal'
                      : 'Nueva alta múltiple',
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
                  'Registra el alta primero y luego los animales vinculados.',
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLg,
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: _errorText!),
                ],
                const SizedBox(height: 18),
                tiposAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Error: $error'),
                  data: (tipos) => DropdownButtonFormField<String>(
                    initialValue: _tipoAnimalId,
                    items: tipos
                        .map(
                          (tipo) => DropdownMenuItem(
                            value: tipo.id,
                            child: Text(tipo.nombre),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _tipoAnimalId = value;
                        _assignment = null;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Selecciona un tipo' : null,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de animal',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  initialValue: _grupoId,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin grupo'),
                    ),
                    ...grupos.map(
                      (grupo) => DropdownMenuItem<String?>(
                        value: grupo.id,
                        child: Text(grupo.nombre),
                      ),
                    ),
                  ],
                  onChanged: _tipoAnimalId == null
                      ? null
                      : (value) => setState(() => _grupoId = value),
                  decoration: const InputDecoration(labelText: 'Grupo'),
                ),
                const SizedBox(height: 14),
                propositosAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Error: $error'),
                  data: (items) => DropdownButtonFormField<String>(
                    initialValue: _propositoId,
                    items: items
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.nombre),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _propositoId = value),
                    validator: (value) =>
                        value == null ? 'Selecciona un propósito' : null,
                    decoration: const InputDecoration(labelText: 'Propósito'),
                  ),
                ),
                const SizedBox(height: 14),
                tiposAdquisicionAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Error: $error'),
                  data: (items) => DropdownButtonFormField<String>(
                    initialValue: _tipoAdquisicionId,
                    items: items
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.nombre),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _tipoAdquisicionId = value),
                    validator: (value) =>
                        value == null ? 'Selecciona una adquisición' : null,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de adquisición',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _QuantityField(
                  quantity: _quantity,
                  onDecrement: _quantity > 1
                      ? () => _setQuantity(_quantity - 1)
                      : null,
                  onIncrement: () => _setQuantity(_quantity + 1),
                ),
                const SizedBox(height: 14),
                _DateField(
                  value: _date,
                  isDark: widget.isDark,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 18),
                availableAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Error: $error'),
                  data: (available) => _buildBraceletSection(available),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _providerController,
                  decoration: const InputDecoration(
                    labelText: 'Proveedor (opcional)',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _costController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Costo total (opcional)',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    return double.tryParse(value.trim().replaceAll(',', '.')) ==
                            null
                        ? 'Ingresa un número válido'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isSingleMode
                              ? 'Registrar alta'
                              : 'Registrar alta múltiple',
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBraceletSection(List<int> available) {
    if (_isSingleMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Asignar brazalete'),
              subtitle: const Text('Opcional cuando registras un solo animal'),
              value: _useSingleBracelet,
              onChanged: (value) => setState(() => _useSingleBracelet = value),
            ),
          ),
          if (_useSingleBracelet)
            TextFormField(
              controller: _singleBraceletController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Brazalete'),
              validator: (value) {
                if (!_useSingleBracelet) {
                  return null;
                }
                final parsed = int.tryParse((value ?? '').trim());
                if (parsed == null || parsed <= 0) {
                  return 'Ingresa un brazalete válido';
                }
                return null;
              },
            ),
        ],
      );
    }

    final assignment = _assignment = BraceletAssignment(
      totalCount: _quantity,
      available: available,
      selected: _assignment?.selected ?? const [],
    );
    final selectedSet = assignment.selected.toSet();
    final selectedCount = assignment.selected.length;
    final totalCount = assignment.totalCount;
    final visibleBracelets = _buildVisibleBracelets(assignment, available);
    final hiddenBraceletsCount = available.length - visibleBracelets.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BraceletHeaderCard(
          isDark: widget.isDark,
          enabled: _braceletPanelEnabled,
          onChanged: (value) => setState(() {
            _braceletPanelEnabled = value;
            _errorText = null;
            _manualBraceletController.clear();
            if (!value) {
              _assignment = assignment.clear();
            }
          }),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          child: _braceletPanelEnabled
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF181D16)
                          : AppColors.bgCardLg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFF6C4B2B).withValues(alpha: 0.75),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Asignación de brazaletes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: widget.isDark
                                ? AppColors.textPrimary
                                : AppColors.textPrimaryLg,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Elige hasta $totalCount brazaletes disponibles para este registro.',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLg,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _BraceletCounterPill(
                              label: '$selectedCount/$totalCount asignados',
                              isDark: widget.isDark,
                              tone: _BraceletCounterTone.accent,
                            ),
                            _BraceletCounterPill(
                              label:
                                  'Seleccionados: $selectedCount / $totalCount',
                              isDark: widget.isDark,
                              tone: _BraceletCounterTone.neutral,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            TextButton(
                              onPressed: available.isEmpty
                                  ? null
                                  : () => setState(() {
                                      _assignment = assignment.autoAssign();
                                      _errorText = null;
                                    }),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.naranjao,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('Auto-asignar'),
                            ),
                            if (assignment.selected.isNotEmpty)
                              TextButton(
                                onPressed: () => setState(() {
                                  _assignment = assignment.clear();
                                  _errorText = null;
                                }),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFF38BA8),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: const Text('Limpiar'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (available.isEmpty)
                          Text(
                            'No hay brazaletes disponibles para este tipo de animal.',
                            style: TextStyle(
                              color: widget.isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondaryLg,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: visibleBracelets.map((bracelet) {
                              final isSelected = selectedSet.contains(bracelet);
                              final limitReached =
                                  !isSelected && !assignment.hasSelectionRoom;
                              return _BraceletChip(
                                bracelet: bracelet,
                                isSelected: isSelected,
                                isDisabled: limitReached,
                                onTap: () => _toggleBraceletSelection(
                                  assignment,
                                  bracelet,
                                ),
                              );
                            }).toList(),
                          ),
                        if (hiddenBraceletsCount > 0) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Mostrando ${visibleBracelets.length} opciones. Puedes agregar manualmente cualquier otro número disponible.',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondaryLg,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _BraceletManualField(
                                controller: _manualBraceletController,
                                focusNode: _manualBraceletFocusNode,
                                isDark: widget.isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _BraceletAddButton(
                              isDark: widget.isDark,
                              onPressed: () => _addManualBracelet(available),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            assignment.selected.isEmpty
                                ? 'Todavía no has seleccionado brazaletes.'
                                : 'Seleccionados: ${assignment.selected.map((value) => '#$value').join(', ')}',
                            key: ValueKey<String>(
                              assignment.selected.join(','),
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondaryLg,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Los números mostrados están disponibles para este tipo de animal en esta granja. Cuando un ejemplar muere, su brazalete vuelve a quedar libre.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: widget.isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLg,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _setQuantity(int value) {
    setState(() {
      _quantity = value;
      _assignment = null;
      _useSingleBracelet = value == 1 ? _useSingleBracelet : false;
      _braceletPanelEnabled = value > 1 ? _braceletPanelEnabled : false;
      if (value > 1) {
        _singleBraceletController.clear();
      }
    });
  }

  List<int> _buildVisibleBracelets(
    BraceletAssignment assignment,
    List<int> available,
  ) {
    final selectedSet = assignment.selected.toSet();
    final visibleSet = <int>{};
    var visibleUnselected = 0;

    for (final bracelet in available) {
      if (selectedSet.contains(bracelet)) {
        visibleSet.add(bracelet);
        continue;
      }

      if (visibleUnselected >= _visibleAvailableBraceletLimit) {
        continue;
      }

      visibleSet.add(bracelet);
      visibleUnselected++;
    }

    return available.where(visibleSet.contains).toList();
  }

  void _toggleBraceletSelection(BraceletAssignment assignment, int bracelet) {
    if (assignment.isSelected(bracelet)) {
      setState(() {
        _assignment = assignment.remove(bracelet);
        _errorText = null;
      });
      return;
    }

    if (!assignment.hasSelectionRoom) {
      setState(() {
        _errorText = 'Solo puedes asignar hasta $_quantity brazaletes';
      });
      return;
    }

    try {
      setState(() {
        _assignment = assignment.manualAdd(bracelet);
        _errorText = null;
      });
    } on ArgumentError catch (error) {
      setState(
        () => _errorText = error.message?.toString() ?? 'Brazalete inválido',
      );
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );

    if (selected != null) {
      setState(() => _date = selected);
    }
  }

  void _addManualBracelet(List<int> available) {
    final rawValue = _manualBraceletController.text.trim();
    final value = int.tryParse(rawValue);

    if (value == null) {
      setState(() => _errorText = 'Ingresa un brazalete válido');
      return;
    }

    if (!available.contains(value)) {
      setState(() => _errorText = 'Ese brazalete no está disponible');
      return;
    }

    try {
      final assignment =
          (_assignment ??
                  BraceletAssignment(
                    totalCount: _quantity,
                    available: available,
                  ))
              .manualAdd(value);
      setState(() {
        _assignment = assignment;
        _manualBraceletController.clear();
        _manualBraceletFocusNode.unfocus();
        _errorText = null;
      });
    } on ArgumentError catch (error) {
      setState(
        () => _errorText = error.message?.toString() ?? 'Brazalete inválido',
      );
    }
  }

  Future<void> _save() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) {
      return;
    }

    if (_tipoAnimalId == null ||
        _propositoId == null ||
        _tipoAdquisicionId == null) {
      setState(() => _errorText = 'Completa los campos requeridos');
      return;
    }

    final bracelets = _resolveBracelets();
    if (!_isSingleMode && bracelets.length > _quantity) {
      setState(() => _errorText = 'Hay más brazaletes que animales');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      final cost = _costController.text.trim().isEmpty
          ? null
          : double.tryParse(_costController.text.trim().replaceAll(',', '.'));
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
      final provider = _providerController.text.trim().isEmpty
          ? null
          : _providerController.text.trim();

      await ref
          .read(animalesRepositoryProvider)
          .registrarAltaAnimales(
            RegistrarAltaAnimalesInput(
              granjaId: widget.granjaId,
              tipoAnimalId: _tipoAnimalId!,
              grupoId: _grupoId,
              propositoId: _propositoId,
              tipoAdquisicionId: _tipoAdquisicionId,
              fechaAlta: _date,
              cantidad: _quantity,
              bracelets: bracelets.isEmpty ? null : bracelets,
              proveedor: provider,
              costoTotal: cost,
              notas: notes,
            ),
          );

      ref.invalidate(animalesProvider(widget.granjaId));
      ref.invalidate(conteosGruposProvider(widget.granjaId));
      ref.invalidate(noGroupOverviewProvider(widget.granjaId));
      ref.invalidate(
        altasByFarmProvider(AltasQuery(granjaId: widget.granjaId)),
      );
      if (_tipoAnimalId != null) {
        ref.invalidate(
          availableBraceletsProvider(
            BraceletAvailabilityQuery(
              granjaId: widget.granjaId,
              tipoAnimalId: _tipoAnimalId!,
            ),
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      setState(() => _errorText = 'No se pudo registrar el alta: $error');
      print(error);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  List<int> _resolveBracelets() {
    if (_isSingleMode) {
      if (!_useSingleBracelet) {
        return const [];
      }
      final parsed = int.tryParse(_singleBraceletController.text.trim());
      return parsed == null ? const [] : [parsed];
    }

    return (_assignment?.selected ?? const <int>[]).toList();
  }
}

enum _BraceletCounterTone { accent, neutral }

class _BraceletHeaderCard extends StatelessWidget {
  const _BraceletHeaderCard({
    required this.isDark,
    required this.enabled,
    required this.onChanged,
  });

  final bool isDark;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151913) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled
              ? AppColors.naranjao.withValues(alpha: 0.9)
              : const Color(0xFF6C4B2B).withValues(alpha: 0.75),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asignar brazaletes (opcional)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Actívalo solo si quieres definir los números desde ahora.',
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
          const SizedBox(width: 12),
          Switch.adaptive(
            value: enabled,
            activeColor: AppColors.naranjao,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _BraceletCounterPill extends StatelessWidget {
  const _BraceletCounterPill({
    required this.label,
    required this.isDark,
    required this.tone,
  });

  final String label;
  final bool isDark;
  final _BraceletCounterTone tone;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch (tone) {
      _BraceletCounterTone.accent => AppColors.naranjao.withValues(alpha: 0.18),
      _BraceletCounterTone.neutral =>
        (isDark ? AppColors.bgCard : AppColors.bgInputLg).withValues(
          alpha: 0.9,
        ),
    };
    final borderColor = switch (tone) {
      _BraceletCounterTone.accent => AppColors.naranjao.withValues(alpha: 0.45),
      _BraceletCounterTone.neutral =>
        (isDark ? AppColors.border1lg : AppColors.border1).withValues(
          alpha: 0.8,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLg,
        ),
      ),
    );
  }
}

class _BraceletChip extends StatelessWidget {
  const _BraceletChip({
    required this.bracelet,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  final int bracelet;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected
        ? const Color(0xFFD7A36A)
        : isDisabled
        ? const Color(0xFF2B3028)
        : const Color(0xFF394238);
    final textColor = isSelected
        ? const Color(0xFF18130E)
        : isDisabled
        ? const Color(0xFF6E766C)
        : const Color(0xFFE8EEDD);

    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      scale: isSelected ? 1.02 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFE7BF8D)
                    : isDisabled
                    ? Colors.transparent
                    : const Color(0xFF4B5947),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#$bracelet',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: isSelected
                      ? Padding(
                          key: ValueKey(bracelet),
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(Icons.close, size: 14, color: textColor),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BraceletManualField extends StatelessWidget {
  const _BraceletManualField({
    required this.controller,
    required this.focusNode,
    required this.isDark,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        hintText: 'Otro número',
        filled: true,
        fillColor: isDark ? const Color(0xFF2D342B) : AppColors.bgCardLg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: const Color(0xFF4B5947).withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class _BraceletAddButton extends StatelessWidget {
  const _BraceletAddButton({required this.isDark, required this.onPressed});

  final bool isDark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isDark
              ? const Color(0xFF3A4635)
              : AppColors.bgCard2Lg,
          foregroundColor: isDark
              ? AppColors.textPrimary
              : AppColors.textPrimaryLg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text(
          '+ Añadir',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _QuantityField extends StatelessWidget {
  const _QuantityField({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Cantidad'),
      child: Row(
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '$quantity',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.isDark,
    required this.onTap,
  });

  final DateTime value;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Fecha de alta'),
        child: Text(
          DateFormat("d 'de' MMMM yyyy").format(value),
          style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLg,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Text(message, style: const TextStyle(color: Colors.redAccent)),
    );
  }
}
