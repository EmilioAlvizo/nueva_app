// lib/features/model/miembro_granja/miembro_granja.dart
import 'package:nueva_app/features/model/perfil/perfil.dart';

class MiembroGranja {
  final String id;
  final String granjaId;
  final String userId;
  final RolMiembro rol;
  final DateTime joinedAt;
  
  final Perfil? perfil;

  const MiembroGranja({
    required this.id,
    required this.granjaId,
    required this.userId,
    required this.rol,
    required this.joinedAt,
    this.perfil,
  });

  factory MiembroGranja.fromMap(Map<String, dynamic> map) {
    // Supabase devuelve la relación anidada de la tabla 'perfiles'
    final profileData = map['perfiles'] as Map<String, dynamic>?;

    return MiembroGranja(
      id: map['id'] as String,
      granjaId: map['granja_id'] as String,
      userId: map['user_id'] as String,
      rol: RolMiembro.fromStr(map['rol'] as String? ?? 'viewer'), // Mapeo seguro del Enum
      joinedAt: DateTime.parse(map['joined_at'] as String? ?? DateTime.now().toIso8601String()),
      perfil: profileData != null ? Perfil.fromMap(profileData) : null,
    );
  }
}

enum RolMiembro {
  owner,
  editor,
  viewer;

  /// Convierte un String de la base de datos Supabase al Enum de Dart
  static RolMiembro fromStr(String val) {
    return RolMiembro.values.firstWhere(
      (e) => e.name == val.toLowerCase().trim(),
      orElse: () => RolMiembro.viewer, // Respaldo seguro por defecto
    );
  }

  /// Para cuando necesites enviar el rol de regreso a Supabase en un insert/update
  String toStr() => name;

  /// Etiquetas legibles para mostrar directamente en la UI
  String get label => switch (this) {
        RolMiembro.owner  => 'Administrador',
        RolMiembro.editor => 'Editor',
        RolMiembro.viewer => 'Lector',
      };
}