// lib/features/model/miembro_granja/miembro_granja.dart
import 'package:nueva_app/features/model/perfil/perfil.dart';

class MiembroGranja {
  final String id;
  final String granjaId;
  final String userId;
  final RolMiembro rol;
  final DateTime joinedAt;
  final String? invitedBy;
  final bool isPending; // true cuando joined_at == invited_at (aún no acepta)
  final Perfil? perfil;

  const MiembroGranja({
    required this.id,
    required this.granjaId,
    required this.userId,
    required this.rol,
    required this.joinedAt,
    this.invitedBy,
    this.isPending = false,
    this.perfil,
  });

  factory MiembroGranja.fromMap(Map<String, dynamic> map) {
    final profileData = map['perfiles'] as Map<String, dynamic>?;
    return MiembroGranja(
      id: map['id'] as String,
      granjaId: map['granja_id'] as String,
      userId: map['user_id'] as String,
      rol: RolMiembro.fromStr(map['rol'] as String? ?? 'viewer'),
      joinedAt: DateTime.parse(
        map['joined_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      invitedBy: map['invited_by'] as String?,
      perfil: profileData != null ? Perfil.fromMap(profileData) : null,
    );
  }
}

enum RolMiembro {
  owner,
  editor,
  viewer;
 
  static RolMiembro fromStr(String val) => RolMiembro.values.firstWhere(
        (e) => e.name == val.toLowerCase().trim(),
        orElse: () => RolMiembro.viewer,
      );
 
  String get label => switch (this) {
        RolMiembro.owner  => 'Admin',
        RolMiembro.editor => 'Editor',
        RolMiembro.viewer => 'Visor',
      };
 
  String get description => switch (this) {
        RolMiembro.owner  => 'Puede crear, editar y eliminar',
        RolMiembro.editor => 'Puede añadir y modificar registros',
        RolMiembro.viewer => 'Sólo puede ver información',
      };
}
