// lib/features/model/miembro_granja/miembro_granja_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_client.dart';
import 'miembro_granja.dart';

class MiembroGranjaRepository {
  /// obtener la lista de miembros de una granja se requiere el Id de la granja [granjaId]
  Future<List<MiembroGranja>> getFarmMembers(String granjaId) async {
    try {
      // Consultamos la tabla intermedia y traemos los datos anidados de perfiles
      final response = await supabase
          .from(
            'miembros_granja',
          ) // <- Asegúrate de usar el nombre exacto de tu tabla
          .select(
            '*, perfiles!miembros_granja_user_id_fkey(*)',
          ) // <- Esto inyecta el mapa para 'ownerProfile' o 'perfil'
          .eq('granja_id', granjaId);

      return (response as List)
          .map((json) => MiembroGranja.fromMap(json))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener colaboradores de la granja: $e');
    }
  }

  /// Agregar un nuevo miembro a la granja se requiere el Id de la granja [granjaId], el email del usuario a invitar [email] y el rol que tendrá en la granja [role]
  Future<void> addMember({
    required String granjaId,
    required String email,
    required RolMiembro role,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');
    try {
      // encontrar el usuario por email para obtener su userId
      final userResponse = await supabase.from('perfiles')
        .select('id')
        .eq('email', email)
        .single();

      await supabase.from('miembros_granja').insert({
        'granja_id': granjaId,
        'user_id': userResponse['id'],
        'rol': role.toStr(),
        'invited_by': userId,
      });
    } catch (e) {
      throw Exception('Error al agregar miembro a la granja: $e');
    }
  }

  /// Eliminar un miembro de la granja por su Id de miembro [memberId]
  Future<void> removeMember({required String memberId}) async {
    try {
      await supabase.from('miembros_granja').delete().eq('id', memberId);
    } catch (e) {
      throw Exception('Error al eliminar miembrode la granja: $e');
    }
  }

  /// Cambiar el rol de un miembro de la granja por su Id de miembro [memberId] y el nuevo rol [newRole]
  Future<void> changeMemberRole({
    required String memberId,
    required RolMiembro newRole,
  }) async {
    try {
      await supabase
          .from('miembros_granja')
          .update({'rol': newRole.toStr()})
          .eq('id', memberId);
    } catch (e) {
      throw Exception('Error al cambiar el rol del miembro de la granja: $e');
    }
  }
}

// Provider estructural para exponer el repositorio
final miembroGranjaRepositoryProvider = Provider<MiembroGranjaRepository>((
  ref,
) {
  return MiembroGranjaRepository();
});

/// Provider auto-desechable que expone la lista de miembros de la granja seleccionada.
final farmMembersProvider = FutureProvider.autoDispose
    .family<List<MiembroGranja>, String>((ref, granjaId) async {
      // Ahora va directo al repositorio usando el ID que llegó por parámetro de la pantalla
      final repository = ref.read(miembroGranjaRepositoryProvider);
      return repository.getFarmMembers(granjaId);
    });
