// lib/features/home/presentation/widgets/settings_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
//import '/features/auth/data/auth_repository.dart';
//import '/features/settings/presentation/providers/theme_provider.dart';
import '../granja/granja_repository.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/green_button.dart';


class NuevaGranja extends ConsumerStatefulWidget {
  final bool isDark;

  const NuevaGranja({super.key, required this.isDark});

  @override
  ConsumerState<NuevaGranja> createState() => _NuevaGranjaState();
}

class _NuevaGranjaState extends ConsumerState<NuevaGranja> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Llamamos al repositorio para guardar en Supabase
      await ref.read(farmRepositoryProvider).createFarm(
        name: _nameCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );
      
      // Invalidamos el stream provider para que la lista del Home se refresque automáticamente
      ref.invalidate(farmsProvider);

      if (mounted) {
        Navigator.pop(context); // Cerramos el modal tras el éxito
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocurrió un error al crear la granja. Inténtalo de nuevo.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colores adaptativos según el tema actual
    final bgColor = widget.isDark ? AppColors.bgCard : Colors.white;
    final titleColor = widget.isDark ? AppColors.textPrimary : const Color(0xFF1A1A2E);
    final inputLabelColor = widget.isDark ? AppColors.bgInput : const Color(0xFFF0F4F8);

    return Padding(
      // Evita que el teclado móvil tape los inputs de texto
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                      color: widget.isDark ? AppColors.border : Colors.grey.shade300,
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
                        color: AppColors.green.withOpacity(0.12),
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
                      'Nueva Granja',
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
                  'Registra un nuevo entorno de producción para empezar a gestionar tus gallinas y recolecciones.',
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
                  label: 'NOMBRE DE LA GRANJA',
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

                // Campo 2: Ubicación (Opcional)
                AppTextField(
                  controller: _locationCtrl,
                  label: 'UBICACIÓN',
                  hint: 'Ej. Kilómetro 4.5 Carretera Central...',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),

                // Campo 3: Notas Adicionales (Opcional)
                // Usamos AppTextField; si en tu diseño requiere múltiples líneas, 
                // tu TextFormField interno se expandirá naturalmente o puedes asignarle el TextInputAction correspondiente.
                AppTextField(
                  controller: _notesCtrl,
                  label: 'NOTAS ADICIONALES',
                  hint: 'Ej. Capacidad para 500 aves, clima templado...',
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: _isLoading ? null : _submit,
                ),
                const SizedBox(height: 32),

                // Botón de Confirmación Reutilizado
                GreenButton(
                  label: 'Crear e ingresar',
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