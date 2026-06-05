// lib/features/granja/granja_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../auth/presentation/providers/auth_session_provider.dart';
import 'granja.dart';

class FarmRepository {
  /// Obtiene las granjas asociadas al usuario actual autenticado
  Future<List<Granja>> getMyFarms(String userId) async {
    final response = await supabase
        .from('granjas')
        .select('*, perfiles!granja_owner_id_fkey(id, nombre, email)')
        .eq('owner_id', userId)
        .order('created_at');

    return (response as List).map((json) => Granja.fromMap(json)).toList();
  }

  // Añade este método dentro de tu clase FarmRepository
  Future<void> createFarm({
    required String name,
    String? location,
    String? notes,
  }) async {
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) throw Exception('Usuario no autenticado');

    try {
      await supabase.from('granjas').insert({
        'nombre': name,
        'ubicacion': location?.isEmpty ?? true
            ? null
            : location, // Guarda null si está vacío
        'descripcion': notes?.isEmpty ?? true ? null : notes,
        'owner_id': userId,
        'created_by': userId,
      });
    } catch (e) {
      print(e);
    }

    print('dfdf');
  }
}

final farmRepositoryProvider = Provider<FarmRepository>((ref) {
  return FarmRepository();
});

/// Provider que expone la lista de granjas de la base de datos en tiempo real/asíncrona
/* final farmsStreamProvider = FutureProvider<List<Granja>>((ref) async {
  return ref.watch(farmRepositoryProvider).getMyFarms();
}); */

/// Depende de [authSessionProvider]: cuando el usuario cambia (login/logout),
/// este provider se invalida automáticamente y vuelve a ejecutar la query
/// con el userId correcto — esto resuelve el bug de granjas cacheadas.
final farmsProvider = FutureProvider.autoDispose<List<Granja>>((ref) async {
  final session = await ref.watch(authSessionProvider.future);

  final userId = session?.user.id;
  if (userId == null) return [];

  return ref.read(farmRepositoryProvider).getMyFarms(userId);
});


/* ¿Cómo consumir los datos de esta granja en otros módulos?
Cuando estés en cualquier otra vista de tu aplicación (por ejemplo, el panel de inventario o estadísticas de producción) y necesites consultar la base de datos filtrando solo por la granja activa, basta con leer el provider desde el método build:

Dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final activeFarm = ref.watch(selectedFarmProvider);

  if (activeFarm == null) {
    return const Text("Por favor selecciona una granja primero.");
  }

  return Text("Mostrando los datos de: ${activeFarm.name}");
  // Aquí puedes usar activeFarm.id para hacer consultas `.eq('farm_id', activeFarm.id)` en Supabase
} */