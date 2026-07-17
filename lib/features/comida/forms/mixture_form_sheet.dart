import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../comida_models.dart';
import '../comida_provider.dart';
import '/features/settings/presentation/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';

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
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Material(
        color: isDark ? AppColors.bg : AppColors.bgLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height),
            child: Column(
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
                Expanded(
                  child: SingleChildScrollView(
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
        _SectionLabel(label: 'Fecha de inicio'),
        _DateField(value: _startDate, onTap: () => _pickDate(isEndDate: false)),
        if (_isEditing) ...[
          const SizedBox(height: 16),
          const _SectionLabel(label: 'Fecha de término (opcional)'),
          _DateField(
            value: _endDate,
            placeholder: 'Mezcla activa',
            onTap: () => _pickDate(isEndDate: true),
            onClear: _endDate == null
                ? null
                : () => setState(() => _endDate = null),
          ),
        ],
        const SizedBox(height: 16),
        const _SectionLabel(label: 'Grupo'),
        DropdownButtonFormField<String>(
          initialValue: _groupId,
          isExpanded: true,
          dropdownColor: AppColors.bgCard,
          decoration:AppTheme.customDecoration(context: context,label:
            'Selecciona un grupo',
            icon: Icons.groups_2_outlined,
          ),
          items: [
            for (final group in widget.groups)
              DropdownMenuItem(value: group.id, child: Text(group.name)),
          ],
          onChanged: (value) => setState(() => _groupId = value),
          validator: (value) => value == null ? 'Selecciona un grupo.' : null,
        ),
        const SizedBox(height: 16),
        const _SectionLabel(label: 'Cantidad de ingredientes'),
        TextFormField(
          controller: _countController,
          keyboardType: TextInputType.number,
          decoration: AppTheme.customDecoration(context: context,label:'Ej. 3',icon: Icons.format_list_numbered_rounded),
          validator: (value) => FoodValidation.ingredientCount(
            value,
            maximum: _selectableCategories.length,
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
          const _SectionLabel(label: 'Categoría'),
          DropdownButtonFormField<String>(
            key: ValueKey('category-$_ingredientIndex-$_categoryId'),
            initialValue: _categoryId,
            isExpanded: true,
            dropdownColor: AppColors.bgCard,
            decoration: _decoration(
              'Selecciona una categoría',
              Icons.sell_outlined,
            ),
            items: [
              for (final category in categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(
                    category.isActive
                        ? category.name
                        : '${category.name} (inactiva)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
            validator: (value) =>
                value == null ? 'Selecciona una categoría.' : null,
          ),
          const SizedBox(height: 16),
          const _SectionLabel(label: 'Cantidad en kg'),
          TextFormField(
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: AppTheme.customDecoration(context: context,label:'0.00', icon:Icons.scale_outlined, suffix: 'kg'),
            validator: (value) {
              final quantity = FoodValidation.decimal(value ?? '');
              return quantity == null || !quantity.isFinite || quantity <= 0
                  ? 'La cantidad debe ser mayor que 0.'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          const _SectionLabel(label: r'Precio ($)'),
          TextFormField(
            controller: _costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration(
              'Costo total de esta cantidad',
              Icons.attach_money_rounded,
            ),
            validator: (value) {
              final cost = FoodValidation.decimal(value ?? '');
              return cost == null || !cost.isFinite || cost < 0
                  ? 'El precio total no puede ser negativo.'
                  : null;
            },
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

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 12, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 7),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.onTap,
    this.placeholder = 'Selecciona una fecha',
    this.onClear,
  });

  final DateTime? value;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: InputDecorator(
      decoration: _decoration('', Icons.calendar_today_outlined).copyWith(
        suffixIcon: onClear == null
            ? const Icon(Icons.keyboard_arrow_down_rounded)
            : IconButton(
                tooltip: 'Quitar fecha de término',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
      child: Text(
        value == null ? placeholder : DateFormat('dd/MM/yyyy').format(value!),
      ),
    ),
  );
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

InputDecoration _decoration(String hint, IconData icon, {String? suffix}) =>
    InputDecoration(
      hintText: hint.isEmpty ? null : hint,
      prefixIcon: Icon(icon),
      suffixText: suffix,
      filled: true,
      fillColor: AppColors.bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );

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
