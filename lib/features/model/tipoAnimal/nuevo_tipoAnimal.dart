// lib/features/model/tipoAnimal/nuevo_tipoAnimal.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
//import '/features/auth/data/auth_repository.dart';
//import '/features/settings/presentation/providers/theme_provider.dart';
import '../../animales/animales_repository.dart'
    hide animalesRepositoryProvider;
import '../../animales/animales_provider.dart';
import '../../granja/granja_provider.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/green_button.dart';
import 'tipoAnimal.dart';

class NuevoAnimal extends ConsumerStatefulWidget {
  final bool isDark;
  final TipoAnimal? initialTipo;

  const NuevoAnimal({super.key, required this.isDark, this.initialTipo});

  @override
  ConsumerState<NuevoAnimal> createState() => _NuevoAnimalState();
}

class _NuevoAnimalState extends ConsumerState<NuevoAnimal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialTipo?.nombre ?? '';
    _notesCtrl.text = widget.initialTipo?.descripcion ?? '';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final granjaId =
          widget.initialTipo?.granjaId ??
          ref.read(selectedFarmProvider)?.id ??
          '';
      final description = _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim();

      if (widget.initialTipo case final tipo?) {
        await ref
            .read(animalesRepositoryProvider)
            .updateTipoAnimal(
              tipoId: tipo.id,
              granjaId: granjaId,
              nombre: _nameCtrl.text.trim(),
              descripcion: description,
            );
      } else {
        await ref
            .read(animalesRepositoryProvider)
            .addTipoAnimal(
              granjaId: granjaId,
              nombre: _nameCtrl.text.trim(),
              descripcion: description,
            );
      }

      ref.invalidate(tiposAnimalProvider(granjaId));

      if (mounted) {
        Navigator.pop(context); // Cerramos el modal tras el éxito
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colores adaptativos según el tema actual
    final bgColor = widget.isDark ? AppColors.bg : Colors.white;
    final titleColor = widget.isDark
        ? AppColors.textPrimary
        : const Color(0xFF1A1A2E);

    return Padding(
      // Evita que el teclado móvil tape los inputs de texto
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: widget.isDark ? AppColors.border : Colors.black12,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicador de arrastre superior (Pill)
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? AppColors.border
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Encabezado con Icono y Título integrado
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.gite_rounded,
                        color: AppColors.green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      widget.initialTipo == null
                          ? 'Nuevo tipo de animal'
                          : 'Editar tipo de animal',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Registra un nuevo tipo de animal.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Banner de error (Si aplica)
                /* if (_errorMessage != null) ...[
                  StatusBanner(message: _errorMessage!, isError: true),
                  const SizedBox(height: 16),
                ], */

                // Campo de Texto Reutilizado
                AppTextField(
                  controller: _nameCtrl,
                  label: 'NOMBRE DEL TIPO DE ANIMAL',
                  hint: 'Ej. Granja El Avícola, Sección Poniente...',
                  textInputAction: TextInputAction.done,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    if (val.trim().length < 3) {
                      return 'Debe tener al menos 3 caracteres';
                    }
                    return null;
                  },
                  onFieldSubmitted: _isLoading ? null : _submit,
                ),
                const SizedBox(height: 20),

                // Campo 3: Notas Adicionales (Opcional)
                // Usamos AppTextField; si en tu diseño requiere múltiples líneas,
                // tu TextFormField interno se expandirá naturalmente o puedes asignarle el TextInputAction correspondiente.
                AppTextField(
                  controller: _notesCtrl,
                  label: 'DESCRIPCION',
                  hint: 'Ej. Capacidad para 500 aves, clima templado...',
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: _isLoading ? null : _submit,
                ),
                const SizedBox(height: 32),

                // Botón de Confirmación Reutilizado
                GreenButton(
                  label: widget.initialTipo == null
                      ? 'Crear e ingresar'
                      : 'Guardar cambios',
                  isLoading: _isLoading,
                  onPressed: _submit,
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
