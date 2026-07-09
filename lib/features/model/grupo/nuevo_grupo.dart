// lib/features/model/grupo/nuevo_grupo.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/green_button.dart';
import '../../animales/animales_provider.dart';
import '../../granja/granja_provider.dart';
import '../tipoAnimal/tipoAnimal.dart';

class NuevoGrupo extends ConsumerStatefulWidget {
  final bool isDark;
  // Opcional: si se llama desde dentro de un grupo ya filtrado
  final String? tipoAnimalIdInicial;

  const NuevoGrupo({super.key, required this.isDark, this.tipoAnimalIdInicial});

  @override
  ConsumerState<NuevoGrupo> createState() => _NuevoGrupoState();
}

class _NuevoGrupoState extends ConsumerState<NuevoGrupo> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _tipoSeleccionado; // id del tipo elegido

  @override
  void initState() {
    super.initState();
    _tipoSeleccionado = widget.tipoAnimalIdInicial;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(List<TipoAnimal> tipos) async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipoSeleccionado == null) {
      setState(() => _errorMessage = 'Selecciona un tipo de animal');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final granjaId = ref.read(selectedFarmProvider)?.id ?? '';
      final userId = supabase.auth.currentUser?.id ?? '';

      await supabase.from('grupos').insert({
        'granja_id': granjaId,
        'tipo_animal_id': _tipoSeleccionado,
        'nombre': _nameCtrl.text.trim(),
        'descripcion': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'created_by': userId,
      });

      // Refrescar lista de grupos en la pantalla
      ref.invalidate(gruposProvider(granjaId));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al crear el grupo. Inténtalo de nuevo.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final granjaId = ref.read(selectedFarmProvider)?.id ?? '';
    final tiposAsync = ref.watch(tiposAnimalProvider(granjaId));

    final bgColor = widget.isDark ? AppColors.bg : Colors.white;
    final titleColor = widget.isDark
        ? AppColors.textPrimary
        : const Color(0xFF1A1A2E);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: widget.isDark ? AppColors.border : Colors.black12,
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
                // Pill
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

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.create_new_folder_outlined,
                        color: AppColors.green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Nuevo grupo',
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
                  'Un corral o agrupación dentro de un tipo de animal.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Error banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Selector de tipo de animal
                tiposAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(
                    'Error cargando tipos: $e',
                    style: const TextStyle(color: Colors.red),
                  ),
                  data: (tipos) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TIPO DE ANIMAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Chips de tipo
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tipos.map((t) {
                          final sel = _tipoSeleccionado == t.id;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _tipoSeleccionado = t.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.green : AppColors.bgCard,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: sel
                                      ? AppColors.green
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                t.nombre,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: sel
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (tipos.isEmpty)
                        const Text(
                          'No hay tipos de animal. Crea uno primero.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                AppTextField(
                  controller: _nameCtrl,
                  label: 'NOMBRE DEL GRUPO',
                  hint: 'Ej. Gallinero principal, Corral norte…',
                  textInputAction: TextInputAction.next,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    if (val.trim().length < 2) return 'Mínimo 2 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                AppTextField(
                  controller: _descCtrl,
                  label: 'DESCRIPCIÓN (opcional)',
                  hint: 'Ej. Corral para gallinas ponedoras adultas…',
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: _isLoading
                      ? null
                      : () {
                          tiposAsync.whenData((t) => _submit(t));
                        },
                ),
                const SizedBox(height: 32),

                GreenButton(
                  label: 'Crear grupo',
                  isLoading: _isLoading,
                  onPressed: () => tiposAsync.whenData((t) => _submit(t)),
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
