import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/compact_form_controls.dart';
import '../comida_models.dart';
import '../comida_provider.dart';
import '/features/settings/presentation/providers/theme_provider.dart';

class MixtureFormSheet extends ConsumerStatefulWidget {
  const MixtureFormSheet({
    super.key,
    required this.farmId,
    required this.categories,
    required this.groups,
    this.mixture,
  });

  final String farmId;
  final List<FoodCategory> categories;
  final List<FoodGroup> groups;
  final FoodMixture? mixture;

  @override
  ConsumerState<MixtureFormSheet> createState() => _MixtureFormSheetState();
}

class _MixtureFormSheetState extends ConsumerState<MixtureFormSheet> {
  final _metadataKey = GlobalKey<FormState>();
  final _ingredientKey = GlobalKey<FormState>();
  late final TextEditingController _countController;
  late final TextEditingController _quantityController;
  late final TextEditingController _costController;
  late DateTime _startDate;
  late final String _mixtureId;
  DateTime? _endDate;
  String? _groupId;
  String? _categoryId;
  int _step = 0;
  List<MixtureIngredientInput?> _ingredients = [];

  bool get _isEditing => widget.mixture != null;
  int get _ingredientIndex => _step - 1;
  List<FoodCategory> get _selectableCategories {
    final categories = <String, FoodCategory>{
      for (final category in widget.categories) category.id: category,
    };
    for (final ingredient
        in widget.mixture?.ingredients ?? const <MixtureIngredient>[]) {
      categories.putIfAbsent(
        ingredient.categoryId,
        () => FoodCategory(
          id: ingredient.categoryId,
          farmId: widget.farmId,
          name: ingredient.categoryName,
          isActive: ingredient.categoryIsActive,
        ),
      );
    }
    return categories.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  void initState() {
    super.initState();
    final mixture = widget.mixture;
    _mixtureId = mixture?.id ?? newFoodUuid();
    _startDate = mixture?.startDate ?? DateTime.now();
    _endDate = mixture?.endDate;
    _groupId = mixture?.groupId;
    _ingredients = [
      for (final ingredient
          in mixture?.ingredients ?? const <MixtureIngredient>[])
        MixtureIngredientInput(
          categoryId: ingredient.categoryId,
          quantityKg: ingredient.quantityKg,
          totalCost: ingredient.totalCost,
        ),
    ];
    _countController = TextEditingController(
      text: mixture == null ? '' : '${mixture.ingredients.length}',
    );
    _quantityController = TextEditingController();
    _costController = TextEditingController();
  }

  @override
  void dispose() {
    _countController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final mutation = ref.watch(foodMutationsProvider);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = MediaQuery.sizeOf(context).height - keyboard;
    final height = availableHeight.clamp(0.0, double.infinity) * 0.92;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Material(
        key: const ValueKey('mixture-form-sheet'),
        color: isDark ? AppColors.bg : AppColors.bgLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const _DragHandle(),
                _Header(
                  title: _step == 0
                      ? (_isEditing ? 'Editar mezcla' : 'Nueva mezcla')
                      : 'Ingrediente ${_ingredientIndex + 1} de ${_ingredients.length}',
                  onClose: mutation.isLoading
                      ? null
                      : () => Navigator.pop(context),
                ),
                if (_step > 0)
                  LinearProgressIndicator(
                    value: (_ingredientIndex + 1) / _ingredients.length,
                    minHeight: 3,
                    color: AppColors.naranjao,
                    backgroundColor: AppColors.bgCard,
                  ),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    key: const ValueKey('mixture-form-scroll-view'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: _step == 0
                        ? _metadataStep(mutation)
                        : _ingredientStep(mutation),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metadataStep(AsyncValue<void> mutation) => Form(
    key: _metadataKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CompactDateField(
          key: const ValueKey('mixture-start-date-field'),
          label: 'Fecha de inicio',
          value: _startDate,
          onTap: () => _pickDate(isEndDate: false),
        ),
        if (_isEditing) ...[
          const SizedBox(height: 16),
          CompactDateField(
            label: 'Fecha de término (opcional)',
            value: _endDate,
            placeholder: 'Mezcla activa',
            onTap: () => _pickDate(isEndDate: true),
            onClear: _endDate == null
                ? null
                : () => setState(() => _endDate = null),
          ),
        ],
        const SizedBox(height: 16),
        CompactDropdownFormField<String>(
          key: const ValueKey('mixture-group-field'),
          dropdownKey: const ValueKey('mixture-group-dropdown'),
          label: 'Grupo',
          value: _groupId,
          items: widget.groups.map((group) => group.id).toList(),
          itemLabelBuilder: (id) =>
              widget.groups.firstWhere((group) => group.id == id).name,
          itemKeyBuilder: (id) => ValueKey('mixture-group-option-$id'),
          onChanged: (value) => setState(() => _groupId = value),
          hintText: 'Selecciona un grupo',
          validator: (value) => value == null ? 'Selecciona un grupo.' : null,
        ),
        const SizedBox(height: 16),
        CompactLabeledField(
          key: const ValueKey('mixture-ingredient-count-field'),
          label: 'Cantidad de ingredientes',
          child: TextFormField(
            keyboardType: TextInputType.number,
            controller: _countController,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: compactInputDecoration(context, hintText: 'ej. 3'),
            validator: (value) => FoodValidation.ingredientCount(
              value,
              maximum: _selectableCategories.length,
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: mutation.isLoading ? null : _continueFromMetadata,
          style: _primaryButtonStyle,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Continuar'),
        ),
      ],
    ),
  );

  Widget _ingredientStep(AsyncValue<void> mutation) {
    final usedIds = {
      for (var index = 0; index < _ingredients.length; index++)
        if (index != _ingredientIndex && _ingredients[index] != null)
          _ingredients[index]!.categoryId,
    };
    final categories = _selectableCategories
        .where(
          (category) =>
              !usedIds.contains(category.id) &&
              (category.isActive || category.id == _categoryId),
        )
        .toList();
    return Form(
      key: _ingredientKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_ingredientIndex > 0)
            _AccumulatedIngredients(
              ingredients: _ingredients
                  .take(_ingredientIndex)
                  .whereType<MixtureIngredientInput>()
                  .toList(),
              categories: _selectableCategories,
            ),
          CompactDropdownFormField<String>(
            key: ValueKey('category-$_ingredientIndex-$_categoryId'),
            dropdownKey: ValueKey('category-dropdown-$_ingredientIndex'),
            label: 'Categoría',
            value: _categoryId,
            items: categories.map((category) => category.id).toList(),
            itemLabelBuilder: (id) {
              final category = categories.firstWhere((item) => item.id == id);
              return category.isActive
                  ? category.name
                  : '${category.name} (inactiva)';
            },
            itemKeyBuilder: (id) => ValueKey('category-option-$id'),
            hintText: 'Selecciona una categoría',
            prefixIcon: const Icon(Icons.sell_outlined),
            onChanged: (value) => setState(() => _categoryId = value),
            validator: (value) =>
                value == null ? 'Selecciona una categoría.' : null,
          ),
          const SizedBox(height: 16),
          CompactLabeledField(
            label: 'Cantidad en kg',
            child: TextFormField(
              key: const ValueKey('mixture-quantity-field'),
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: compactInputDecoration(
                context,
                hintText: '0.00',
                prefixIcon: const Icon(Icons.scale_outlined),
                suffixText: 'kg',
              ),
              validator: (value) {
                final quantity = FoodValidation.decimal(value ?? '');
                return quantity == null || !quantity.isFinite || quantity <= 0
                    ? 'La cantidad debe ser mayor que 0.'
                    : null;
              },
            ),
          ),
          const SizedBox(height: 16),
          CompactLabeledField(
            label: r'Precio ($)',
            child: TextFormField(
              key: const ValueKey('mixture-price-field'),
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: compactInputDecoration(
                context,
                hintText: 'Costo total de esta cantidad',
                prefixIcon: const Icon(Icons.attach_money_rounded),
              ),
              validator: (value) {
                final cost = FoodValidation.decimal(value ?? '');
                return cost == null || !cost.isFinite || cost < 0
                    ? 'El precio total no puede ser negativo.'
                    : null;
              },
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: mutation.isLoading ? null : _back,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: mutation.isLoading ? null : _continueIngredient,
                  style: _primaryButtonStyle,
                  icon:
                      mutation.isLoading &&
                          _ingredientIndex == _ingredients.length - 1
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _ingredientIndex == _ingredients.length - 1
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                  label: Text(
                    _ingredientIndex == _ingredients.length - 1
                        ? 'Guardar'
                        : 'Siguiente',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _continueFromMetadata() {
    if (!_metadataKey.currentState!.validate()) return;
    if (_endDate != null &&
        _dateOnly(_endDate!).isBefore(_dateOnly(_startDate))) {
      _snack(
        'La fecha de término no puede ser anterior al inicio.',
        isError: true,
      );
      return;
    }
    final count = int.parse(_countController.text.trim());
    setState(() {
      if (_ingredients.length > count) {
        _ingredients = _ingredients.take(count).toList();
      } else {
        _ingredients = [
          ..._ingredients,
          ...List.filled(count - _ingredients.length, null),
        ];
      }
      _step = 1;
      _loadIngredient(0);
    });
  }

  Future<void> _continueIngredient() async {
    if (!_ingredientKey.currentState!.validate()) return;
    final ingredient = MixtureIngredientInput(
      categoryId: _categoryId!,
      quantityKg: FoodValidation.decimal(_quantityController.text)!,
      totalCost: FoodValidation.decimal(_costController.text)!,
    );
    final duplicate = _ingredients.indexed.any(
      (entry) =>
          entry.$1 != _ingredientIndex &&
          entry.$2?.categoryId == ingredient.categoryId,
    );
    if (duplicate) {
      _snack(
        'No puedes repetir una categoría en la misma mezcla.',
        isError: true,
      );
      return;
    }
    _ingredients[_ingredientIndex] = ingredient;
    if (_ingredientIndex < _ingredients.length - 1) {
      setState(() {
        _step++;
        _loadIngredient(_ingredientIndex);
      });
      return;
    }
    await _save();
  }

  void _back() {
    setState(() {
      if (_ingredientIndex == 0) {
        _step = 0;
      } else {
        _step--;
        _loadIngredient(_ingredientIndex);
      }
    });
  }

  void _loadIngredient(int index) {
    final ingredient = _ingredients[index];
    _categoryId = ingredient?.categoryId;
    _quantityController.text = ingredient == null
        ? ''
        : _decimalText(ingredient.quantityKg);
    _costController.text = ingredient == null
        ? ''
        : _decimalText(ingredient.totalCost);
  }

  Future<void> _save() async {
    final input = MixtureInput(
      mixtureId: _mixtureId,
      farmId: widget.farmId,
      groupId: _groupId!,
      startDate: _startDate,
      endDate: _isEditing ? _endDate : null,
      expectedUpdatedAt: widget.mixture?.updatedAt,
      ingredients: _ingredients.whereType<MixtureIngredientInput>().toList(),
    );
    final error = input.validate();
    if (error != null) {
      _snack(error, isError: true);
      return;
    }
    try {
      final notifier = ref.read(foodMutationsProvider.notifier);
      if (widget.mixture case final mixture?) {
        await notifier.updateMixture(mixtureId: mixture.id, input: input);
      } else {
        await notifier.createMixture(input);
      }
      if (!mounted) return;
      Navigator.pop(context);
      _snack(_isEditing ? 'Mezcla actualizada.' : 'Mezcla creada.');
    } catch (error) {
      if (mounted) _snack(_errorMessage(error), isError: true);
    }
  }

  Future<void> _pickDate({required bool isEndDate}) async {
    final initial = isEndDate ? (_endDate ?? _startDate) : _startDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isEndDate) {
        _endDate = selected;
      } else {
        _startDate = selected;
      }
    });
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.negative : AppColors.greenDark,
      ),
    );
  }

  static String _errorMessage(Object error) => switch (error) {
    PostgrestException(:final message) => message,
    ArgumentError(:final message) => '$message',
    _ => 'No se pudo guardar la mezcla.',
  };

  static String _decimalText(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});

  final String title;
  final VoidCallback? onClose;
  //final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 2. Opcional: Detecta si ese tema padre específico es oscuro
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLg,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Cerrar',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _AccumulatedIngredients extends StatelessWidget {
  const _AccumulatedIngredients({
    required this.ingredients,
    required this.categories,
  });

  final List<MixtureIngredientInput> ingredients;
  final List<FoodCategory> categories;

  @override
  Widget build(BuildContext context) {
    final totalKg = ingredients.fold<double>(
      0,
      (sum, item) => sum + item.quantityKg,
    );
    final totalCost = ingredients.fold<double>(
      0,
      (sum, item) => sum + item.totalCost,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ingredientes acumulados',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final ingredient in ingredients)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      categories
                              .where((item) => item.id == ingredient.categoryId)
                              .firstOrNull
                              ?.name ??
                          'Categoría',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Text(
                    '${ingredient.quantityKg.toStringAsFixed(2)} kg · \$${ingredient.totalCost.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          Text(
            'Total: ${totalKg.toStringAsFixed(2)} kg · \$${totalCost.toStringAsFixed(2)}',
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

ButtonStyle get _primaryButtonStyle => FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(52),
  backgroundColor: AppColors.naranjao,
  foregroundColor: AppColors.textPrimaryLg,
);

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 5,
    decoration: BoxDecoration(
      color: AppColors.textMuted,
      borderRadius: BorderRadius.circular(99),
    ),
  );
}
