// lib/features/model/miembro_granja/miembro_granja_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_client.dart';
import 'miembro_granja.dart';

class MiembroGranjaRepository {
  /// obtener la lista de miembros de una granja se requiere el Id de la granja [granjaId]
  Future<List<MiembroGranja>> getMembers(String granjaId) async {
    final response = await supabase
        .from('miembros_granja')
        .select('*, perfiles!miembros_granja_user_id_fkey(*)')
        .eq('granja_id', granjaId)
        .order('rol', ascending:true);

    return (response as List)
        .map((json) => MiembroGranja.fromMap(json))
        .toList();
  }

  /// Agregar un nuevo miembro a la granja se requiere el Id de la granja [granjaId], el email del usuario a invitar [email] y el rol que tendrá en la granja [role]
  Future<void> addMember({
    required String granjaId,
    required String email,
    required RolMiembro role,
  }) async {
    final invitedBy = supabase.auth.currentUser?.id;
    if (invitedBy == null) throw Exception('Usuario no autenticado');

    // Busca el perfil por email
    final profileRes = await supabase
        .from('perfiles')
        .select('id')
        .eq('email', email.trim())
        .maybeSingle();

    if (profileRes == null) {
      throw Exception('No existe ningún usuario con ese correo.');
    }

    final userId = profileRes['id'] as String;

    // Evita duplicados
    final existing = await supabase
        .from('miembros_granja')
        .select('id')
        .eq('granja_id', granjaId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      throw Exception('Este usuario ya es miembro de la granja.');
    }

    await supabase.from('miembros_granja').insert({
      'granja_id': granjaId,
      'user_id': userId,
      'rol': role.name,
      'invited_by': invitedBy,
    });
  }

  /// Eliminar un miembro de la granja por su Id de miembro [memberId]
  Future<void> removeMember(String memberId) async {
    await supabase.from('miembros_granja').delete().eq('id', memberId);
  }

  /// Cambiar el rol de un miembro de la granja por su Id de miembro [memberId] y el nuevo rol [newRole]
  Future<void> updateRole({
    required String memberId,
    required RolMiembro newRole,
  }) async {
    await supabase
        .from('miembros_granja')
        .update({'rol': newRole.name})
        .eq('id', memberId);
  }
}

// Provider estructural para exponer el repositorio
final miembroGranjaRepositoryProvider = Provider<MiembroGranjaRepository>((
  ref,
) {
  return MiembroGranjaRepository();
});


