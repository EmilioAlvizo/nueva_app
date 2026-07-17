import 'package:supabase_flutter/supabase_flutter.dart';

import 'comida_models.dart';

abstract interface class ComidaRepository {
  Future<List<FoodMixture>> getMixtures(String farmId);
  Future<List<FoodCategory>> getCategories(String farmId);
  Future<List<FoodGroup>> getGroups(String farmId);
  Future<FoodAccess> getAccess(String farmId);

  Future<void> createCategory({required String farmId, required String name});
  Future<void> updateCategory({
    required String farmId,
    required String categoryId,
    required String name,
  });
  Future<void> deleteCategory({
    required String farmId,
    required String categoryId,
  });
  Future<void> createMixture(MixtureInput input);
  Future<void> updateMixture({
    required String mixtureId,
    required MixtureInput input,
  });
  Future<void> deleteMixture({
    required String farmId,
    required String mixtureId,
  });
}

final class SupabaseComidaRepository implements ComidaRepository {
  SupabaseComidaRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<FoodMixture>> getMixtures(String farmId) async {
    final data = await _client
        .from('mezcla')
        .select(_mixtureSelect)
        .eq('granja_id', farmId)
        .order('fecha_inicio', ascending: false)
        .order('created_at', ascending: false);
    return _rows(data).map(FoodMixture.fromJson).toList();
  }

  @override
  Future<List<FoodCategory>> getCategories(String farmId) async {
    final data = await _client
        .from('cat_comida')
        .select('id,granja_id,nombre,activo,created_at')
        .eq('granja_id', farmId)
        .eq('activo', true)
        .order('nombre');
    return _rows(data).map(FoodCategory.fromJson).toList();
  }

  @override
  Future<List<FoodGroup>> getGroups(String farmId) async {
    final data = await _client
        .from('grupos')
        .select('id,nombre')
        .eq('granja_id', farmId)
        .order('nombre');
    return _rows(data).map(FoodGroup.fromJson).toList();
  }

  @override
  Future<FoodAccess> getAccess(String farmId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const FoodAccess(canEdit: false);

    final farm = await _client
        .from('granjas')
        .select('owner_id')
        .eq('id', farmId)
        .maybeSingle();
    if (farm?['owner_id'] == userId) return const FoodAccess(canEdit: true);

    final membership = await _client
        .from('miembros_granja')
        .select('rol')
        .eq('granja_id', farmId)
        .eq('user_id', userId)
        .maybeSingle();
    return FoodAccess(canEdit: membership?['rol'] == 'editor');
  }

  @override
  Future<void> createCategory({
    required String farmId,
    required String name,
  }) async {
    final error = FoodValidation.categoryName(name);
    if (error != null) throw ArgumentError(error);
    await _client.from('cat_comida').insert({
      'granja_id': farmId,
      'nombre': name.trim(),
      'activo': true,
      'created_by': _client.auth.currentUser?.id,
    });
  }

  @override
  Future<void> updateCategory({
    required String farmId,
    required String categoryId,
    required String name,
  }) async {
    final error = FoodValidation.categoryName(name);
    if (error != null) throw ArgumentError(error);
    await _client
        .from('cat_comida')
        .update({'nombre': name.trim()})
        .eq('id', categoryId)
        .eq('granja_id', farmId);
  }

  @override
  Future<void> deleteCategory({
    required String farmId,
    required String categoryId,
  }) => _client.rpc<void>(
    'eliminar_categoria_comida_segura',
    params: {'p_granja_id': farmId, 'p_categoria_id': categoryId},
  );

  @override
  Future<void> createMixture(MixtureInput input) {
    final error = input.validate();
    if (error != null) throw ArgumentError(error);
    return _client.rpc<void>(
      'crear_mezcla_completa',
      params: {
        'p_granja_id': input.farmId,
        'p_mezcla_id': input.mixtureId,
        'p_fecha_inicio': _date(input.startDate),
        'p_grupo_id': input.groupId,
        'p_ingredientes': input.ingredients
            .map((item) => item.toJson())
            .toList(),
      },
    );
  }

  @override
  Future<void> updateMixture({
    required String mixtureId,
    required MixtureInput input,
  }) {
    final error = input.validate();
    if (error != null) throw ArgumentError(error);
    if (input.expectedUpdatedAt == null) {
      throw ArgumentError('Falta la versión esperada de la mezcla.');
    }
    return _client.rpc<void>(
      'actualizar_mezcla_completa',
      params: {
        'p_mezcla_id': mixtureId,
        'p_granja_id': input.farmId,
        'p_expected_updated_at': input.expectedUpdatedAt!
            .toUtc()
            .toIso8601String(),
        'p_fecha_inicio': _date(input.startDate),
        'p_fecha_termino': input.endDate == null ? null : _date(input.endDate!),
        'p_grupo_id': input.groupId,
        'p_ingredientes': input.ingredients
            .map((item) => item.toJson())
            .toList(),
      },
    );
  }

  @override
  Future<void> deleteMixture({
    required String farmId,
    required String mixtureId,
  }) => _client.rpc<void>(
    'eliminar_mezcla_completa',
    params: {'p_granja_id': farmId, 'p_mezcla_id': mixtureId},
  );

  static List<Map<String, dynamic>> _rows(Object? value) => [
    for (final row in value as List? ?? const [])
      Map<String, dynamic>.from(row as Map),
  ];

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static const _mixtureSelect = '''
    id,granja_id,fecha_inicio,fecha_termino,created_at,updated_at,grupo_id,
    grupos(nombre),
    mezcla_comida(
      id,cantidad,
      comida(id,cat_comida_id,precio,cantidad,cat_comida(nombre,activo))
    )
  ''';
}
