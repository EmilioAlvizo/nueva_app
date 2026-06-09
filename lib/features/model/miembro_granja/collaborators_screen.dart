// lib/features/model/miembro_granja/collaborators_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/green_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../granja/granja_provider.dart';
import 'miembro_granja.dart';
import 'miembro_granja_repository.dart';

class CollaboratorsScreen extends ConsumerWidget {
  final String farmId;
  final String farmName;

  const CollaboratorsScreen({
    super.key,
    required this.farmId,
    required this.farmName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obtenemos la granja seleccionada para saber a quién estamos invitando
    //final activeFarm = ref.watch(selectedFarmProvider);
    //final farmName = activeFarm?.nombre ?? 'Granja';

    // 1. ESCUCHAMOS EL PROVIDER REAL EN LUGAR DE USAR MOCK DATA
    final membersAsync = ref.watch(farmMembersProvider(farmId));

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Colaboradores: $farmName',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.green,
              size: 26,
            ),
            onPressed: () => _showAddCollaboratorModal(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.green),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error al cargar colaboradores: $err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.negative),
            ),
          ),
        ),
        data: (members) {
          if (members.isEmpty) {
            return const Center(
              child: Text(
                'Aún no hay colaboradores invitados.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.green,
            onRefresh: () async => ref.invalidate(
              farmMembersProvider,
            ), // Permite deslizar para refrescar la lista
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final miembro = members[index];

                // Extraemos los datos del perfil anidado de forma segura
                final nombre = miembro.perfil?.nombre ?? 'Usuario sin nombre';
                final email = miembro.perfil?.email ?? 'Sin correo';

                return _CollaboratorCard(
                  nombre: nombre,
                  email: email,
                  rolLabel: miembro
                      .rol
                      .label, // El getter 'label' que creamos en tu Enum (Administrador, Editor, etc.)
                  rolEnumStr: miembro.rol.name, // 'owner', 'editor', 'viewer'
                  onTap: () => _showEditRoleModal(context, nombre, miembro),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ─── MODAL: AGREGAR COLABORADOR ─────────────────────────────────────────────
  void _showAddCollaboratorModal(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 20,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invitar Colaborador',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ingresa el correo electrónico de la persona que deseas añadir.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: emailCtrl,
              label: 'Correo Electrónico',
              hint: 'ejemplo@correo.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            GreenButton(
              label: 'Enviar Invitación',
              onPressed: () {
                // Aquí irá tu ref.read(tuNotifier.notifier).invitar(...)
                ref.read(miembroGranjaRepositoryProvider).addMember(granjaId: farmId, email: emailCtrl.text.trim(), role: RolMiembro.editor);
                ref.invalidate(farmMembersProvider(farmId));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── MODAL: MODIFICAR ROL ───────────────────────────────────────────────────
  void _showEditRoleModal(
    BuildContext context,
    String nombre,
    MiembroGranja miembro,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modificar Rol de $nombre',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Rol actual: ${miembro.rol.label}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _RoleOptionTile(
              title: 'Administrador',
              subtitle: 'Control total de la granja',
              isSelected: miembro.rol.name == 'owner',
            ),
            _RoleOptionTile(
              title: 'Editor',
              subtitle: 'Puede añadir y modificar registros',
              isSelected: miembro.rol.name == 'editor',
            ),
            _RoleOptionTile(
              title: 'Lector',
              subtitle: 'Solo visualización de datos',
              isSelected: miembro.rol.name == 'viewer',
            ),
            const SizedBox(height: 12),
            _RoleOptionTile(
              title: 'Eliminar Colaborador',
              subtitle: 'Revocar acceso inmediatamente',
              isSelected: false,
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WIDGET COMPONENTE: TARJETA DE COLABORADOR ───────────────────────────────
class _CollaboratorCard extends StatelessWidget {
  final String nombre;
  final String email;
  final String rolLabel; // Ej: 'Administrador'
  final String rolEnumStr; // Ej: 'owner'
  final VoidCallback onTap;

  const _CollaboratorCard({
    required this.nombre,
    required this.email,
    required this.rolLabel,
    required this.rolEnumStr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = nombre
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    // Color según el valor string del Enum en PostgreSQL
    final roleColor = rolEnumStr == 'owner'
        ? AppColors.amber
        : (rolEnumStr == 'editor' ? AppColors.green : AppColors.textSecondary);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgCardLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.bgInput,
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: roleColor.withOpacity(0.3)),
              ),
              child: Text(
                rolLabel,
                style: TextStyle(
                  color: roleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WIDGET COMPONENTE: OPCIONES DE ROL ──────────────────────────────────────
class _RoleOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isDestructive;

  const _RoleOptionTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDestructive
        ? AppColors.negative
        : AppColors.textPrimary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: isSelected
          ? const Icon(
              Icons.check_circle_rounded,
              color: AppColors.green,
              size: 20,
            )
          : (isDestructive
                ? const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.negative,
                    size: 20,
                  )
                : null),
      onTap: () {
        // Ejecutar cambio de rol / borrado
        Navigator.pop(context);
      },
    );
  }
}
