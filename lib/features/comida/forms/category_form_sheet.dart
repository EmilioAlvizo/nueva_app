import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../comida_models.dart';
import '../comida_provider.dart';
import '/features/settings/presentation/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';

class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({super.key, required this.farmId, this.category});

  final String farmId;
  final FoodCategory? category;

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final mutation = ref.watch(foodMutationsProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: isDark ? AppColors.bg : AppColors.bgLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: _DragHandle()),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isEditing ? 'Editar categoría' : 'Nueva categoría',
                          style: TextStyle(
                            color: isDark ? AppColors.textPrimary:AppColors.textPrimaryLg,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Cerrar',
                        onPressed: mutation.isLoading
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 80,
                    validator: FoodValidation.categoryName,
                    decoration: AppTheme.customDecoration(context: context,label:'Nombre', icon: Icons.sell_outlined),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: mutation.isLoading ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.naranjao,
                      foregroundColor: AppColors.textPrimaryLg,
                    ),
                    child: mutation.isLoading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isEditing ? 'Guardar cambios' : 'Crear categoría',
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final notifier = ref.read(foodMutationsProvider.notifier);
      if (widget.category case final category?) {
        await notifier.updateCategory(
          farmId: widget.farmId,
          categoryId: category.id,
          name: _nameController.text,
        );
      } else {
        await notifier.createCategory(
          farmId: widget.farmId,
          name: _nameController.text,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      _snack(_isEditing ? 'Categoría actualizada.' : 'Categoría creada.');
    } catch (error) {
      if (mounted) _snack(_message(error), isError: true);
    }
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.negative : AppColors.greenDark,
      ),
    );
  }

  static String _message(Object error) => switch (error) {
    PostgrestException(:final message) => message,
    ArgumentError(:final message) => '$message',
    _ => 'No se pudo guardar la categoría.',
  };
}

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
