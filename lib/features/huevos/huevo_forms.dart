import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
            DropdownButtonFormField<String>(
              key: const Key('collection-group-field'),
              initialValue: _groupId,
              decoration: const InputDecoration(
                labelText: 'Grupo',
                prefixIcon: Icon(Icons.groups_2_outlined),
              ),
              items: [
                for (final group in widget.groups)
                  DropdownMenuItem(
                    value: group.id,
                    child: Text(group.displayName),
                  ),
              ],
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CountField(
                    key: const Key('collection-broken-field'),
                    controller: _brokenController,
                    label: 'Huevos rotos',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DateField(
              date: _date,
              onChanged: (date) => setState(() => _date = date),
            ),
          ],
        ),
      ),
    );
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
            DropdownButtonFormField<String>(
              key: const Key('sale-group-field'),
              initialValue: _groupId,
              decoration: const InputDecoration(
                labelText: 'Grupo',
                prefixIcon: Icon(Icons.groups_2_outlined),
              ),
              items: [
                for (final group in widget.groups)
                  DropdownMenuItem(
                    value: group.id,
                    child: Text(group.displayName),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _groupId = value),
              validator: (value) =>
                  value == null ? 'Selecciona un grupo.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('sale-quantity-field'),
              controller: _quantityController,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                prefixIcon: Icon(Icons.egg_outlined),
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final quantity = int.tryParse(value?.trim() ?? '');
                return quantity == null || quantity <= 0
                    ? 'Ingresa una cantidad mayor que cero.'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('sale-price-field'),
              controller: _priceController,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Precio unitario',
                prefixText: r'$ ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final price = _parsePrice(value ?? '');
                return price == null || !price.isFinite || price <= 0
                    ? 'Ingresa un precio válido mayor que cero.'
                    : null;
              },
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
            _DateField(
              date: _date,
              onChanged: (date) => setState(() => _date = date),
            ),
          ],
        ),
      ),
    );
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
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
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
                    child,
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        error!,
                        key: const Key('egg-form-error'),
                        style: TextStyle(color: theme.colorScheme.error),
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
          ),
        ),
      ),
    );
  }
}

class _CountField extends StatelessWidget {
  const _CountField({super.key, required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final count = int.tryParse(value?.trim() ?? '');
        return count == null ? 'Ingresa 0 o más.' : null;
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onChanged});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('egg-date-field'),
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (!context.mounted || selected == null) return;
        onChanged(selected);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Fecha',
          prefixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text(DateFormat('dd/MM/yyyy').format(date)),
      ),
    );
  }
}

double? _parsePrice(String value) {
  return double.tryParse(value.trim().replaceAll(',', '.'));
}
