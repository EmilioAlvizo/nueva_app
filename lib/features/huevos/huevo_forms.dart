import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../shared/widgets/compact_form_controls.dart';
import 'huevo_filters.dart';
import 'huevo_models.dart';

typedef SaveCollection = Future<void> Function(EggCollectionInput input);
typedef SaveSale = Future<void> Function(EggSaleInput input);

class EggCollectionForm extends StatefulWidget {
  const EggCollectionForm({
    super.key,
    required this.farmId,
    required this.groups,
    required this.onSave,
    this.collection,
    this.initialGroupId,
  });

  final String farmId;
  final List<EggGroupChoice> groups;
  final SaveCollection onSave;
  final EggCollection? collection;
  final String? initialGroupId;

  @override
  State<EggCollectionForm> createState() => _EggCollectionFormState();
}

class _EggCollectionFormState extends State<EggCollectionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _goodController;
  late final TextEditingController _brokenController;
  late DateTime _date;
  String? _groupId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final collection = widget.collection;
    _groupId = resolveValidEggGroupId(
      collection?.groupId ?? widget.initialGroupId,
      widget.groups,
    );
    _date = collection?.date ?? DateTime.now();
    _goodController = TextEditingController(
      text: collection == null ? '' : '${collection.goodEggs}',
    );
    _brokenController = TextEditingController(
      text: collection == null ? '' : '${collection.brokenEggs}',
    );
  }

  @override
  void dispose() {
    _goodController.dispose();
    _brokenController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final input = EggCollectionInput(
      farmId: widget.farmId,
      groupId: _groupId ?? '',
      goodEggs: int.parse(_goodController.text.trim()),
      brokenEggs: int.parse(_brokenController.text.trim()),
      date: _date,
    );
    final validationError = input.validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(input);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar la recolección. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.collection != null;
    return _EggFormSheet(
      title: editing ? 'Editar recolección' : 'Nueva recolección',
      subtitle: 'Registra los huevos recolectados por grupo.',
      icon: Icons.egg_outlined,
      error: _error,
      saving: _saving,
      actionLabel: editing ? 'Guardar cambios' : 'Registrar recolección',
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            CompactDropdownFormField<String>(
              key: const Key('collection-group-field'),
              dropdownKey: const Key('collection-group-dropdown'),
              label: 'Grupo',
              value: _groupId,
              items: widget.groups.map((group) => group.id).toList(),
              itemLabelBuilder: (id) => widget.groups
                  .firstWhere((group) => group.id == id)
                  .displayName,
              itemKeyBuilder: (id) => Key('collection-group-option-$id'),
              hintText: 'Selecciona un grupo',
              prefixIcon: const Icon(Icons.groups_2_outlined),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _groupId = value),
              validator: (value) =>
                  value == null ? 'Selecciona un grupo.' : null,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CountField(
                    key: const Key('collection-good-field'),
                    controller: _goodController,
                    label: 'Huevos buenos',
                    enabled: !_saving,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CountField(
                    key: const Key('collection-broken-field'),
                    controller: _brokenController,
                    label: 'Huevos rotos',
                    enabled: !_saving,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CompactDateField(
              key: const Key('egg-date-field'),
              label: 'Fecha',
              value: _date,
              enabled: !_saving,
              onTap: _saving ? null : _pickDate,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (!mounted || selected == null) return;
    setState(() => _date = selected);
  }
}

class EggSaleForm extends StatefulWidget {
  const EggSaleForm({
    super.key,
    required this.farmId,
    required this.groups,
    required this.onSave,
    this.sale,
    this.initialGroupId,
  });

  final String farmId;
  final List<EggGroupChoice> groups;
  final SaveSale onSave;
  final EggSale? sale;
  final String? initialGroupId;

  @override
  State<EggSaleForm> createState() => _EggSaleFormState();
}

class _EggSaleFormState extends State<EggSaleForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late DateTime _date;
  String? _groupId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final sale = widget.sale;
    _groupId = resolveValidEggGroupId(
      sale?.groupId ?? widget.initialGroupId,
      widget.groups,
    );
    _date = sale?.date ?? DateTime.now();
    _quantityController = TextEditingController(
      text: sale == null ? '' : '${sale.quantity}',
    );
    _priceController = TextEditingController(
      text: sale == null ? '' : sale.unitPrice.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  double get _total {
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final price = _parsePrice(_priceController.text) ?? 0;
    final total = quantity * price;
    return total.isFinite ? total : 0;
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final input = EggSaleInput(
      farmId: widget.farmId,
      groupId: _groupId ?? '',
      quantity: int.parse(_quantityController.text.trim()),
      unitPrice: _parsePrice(_priceController.text)!,
      date: _date,
    );
    final validationError = input.validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(input);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar la venta. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.sale != null;
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    return _EggFormSheet(
      title: editing ? 'Editar venta' : 'Nueva venta',
      subtitle: 'Registra la cantidad y el precio unitario de la venta.',
      icon: Icons.point_of_sale_outlined,
      error: _error,
      saving: _saving,
      actionLabel: editing ? 'Guardar cambios' : 'Registrar venta',
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            CompactDropdownFormField<String>(
              key: const Key('sale-group-field'),
              dropdownKey: const Key('sale-group-dropdown'),
              label: 'Grupo',
              value: _groupId,
              items: widget.groups.map((group) => group.id).toList(),
              itemLabelBuilder: (id) => widget.groups
                  .firstWhere((group) => group.id == id)
                  .displayName,
              itemKeyBuilder: (id) => Key('sale-group-option-$id'),
              hintText: 'Selecciona un grupo',
              prefixIcon: const Icon(Icons.groups_2_outlined),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _groupId = value),
              validator: (value) =>
                  value == null ? 'Selecciona un grupo.' : null,
            ),
            const SizedBox(height: 16),
            CompactLabeledField(
              label: 'Cantidad',
              child: TextFormField(
                key: const Key('sale-quantity-field'),
                controller: _quantityController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: compactInputDecoration(
                  context,
                  enabled: !_saving,
                  prefixIcon: const Icon(Icons.egg_outlined),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final quantity = int.tryParse(value?.trim() ?? '');
                  return quantity == null || quantity <= 0
                      ? 'Ingresa una cantidad mayor que cero.'
                      : null;
                },
              ),
            ),
            const SizedBox(height: 16),
            CompactLabeledField(
              label: 'Precio unitario',
              child: TextFormField(
                key: const Key('sale-price-field'),
                controller: _priceController,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: compactInputDecoration(
                  context,
                  enabled: !_saving,
                  prefixText: r'$ ',
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final price = _parsePrice(value ?? '');
                  return price == null || !price.isFinite || price <= 0
                      ? 'Ingresa un precio válido mayor que cero.'
                      : null;
                },
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              label: 'Total calculado ${currency.format(_total)}',
              child: Container(
                key: const Key('sale-calculated-total'),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(
                      'Total',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      currency.format(_total),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            CompactDateField(
              key: const Key('egg-date-field'),
              label: 'Fecha',
              value: _date,
              enabled: !_saving,
              onTap: _saving ? null : _pickDate,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (!mounted || selected == null) return;
    setState(() => _date = selected);
  }
}

class _EggFormSheet extends StatelessWidget {
  const _EggFormSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.error,
    required this.saving,
    required this.actionLabel,
    required this.onSubmit,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? error;
  final bool saving;
  final String actionLabel;
  final VoidCallback onSubmit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = MediaQuery.sizeOf(context).height - keyboard;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Material(
        key: const Key('egg-form-sheet'),
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: availableHeight * 0.92),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(child: Icon(icon)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: theme.textTheme.titleLarge),
                                Text(
                                  subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Flexible(
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              child,
                              if (error != null) ...[
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    error!,
                                    key: const Key('egg-form-error'),
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FilledButton.icon(
                                  key: const Key('egg-form-submit'),
                                  onPressed: saving ? null : onSubmit,
                                  icon: saving
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.check_rounded),
                                  label: Text(actionLabel),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountField extends StatelessWidget {
  const _CountField({
    super.key,
    required this.controller,
    required this.label,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CompactLabeledField(
      label: label,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: compactInputDecoration(context, enabled: enabled),
        validator: (value) {
          final count = int.tryParse(value?.trim() ?? '');
          return count == null ? 'Ingresa 0 o más.' : null;
        },
      ),
    );
  }
}

double? _parsePrice(String value) {
  return double.tryParse(value.trim().replaceAll(',', '.'));
}
