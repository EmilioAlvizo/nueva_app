import 'package:supabase_flutter/supabase_flutter.dart';

import 'huevo_models.dart';

abstract interface class HuevoRepository {
  Future<List<EggCollection>> getCollections(String farmId);
  Future<List<EggSale>> getSales(String farmId);
  Future<EggAccess> getAccess(String farmId);
  Future<void> createCollection(EggCollectionInput input);
  Future<void> updateCollection({
    required String collectionId,
    required EggCollectionInput input,
  });
  Future<void> deleteCollection({
    required String farmId,
    required String collectionId,
  });
  Future<void> createSale(EggSaleInput input);
  Future<void> updateSale({
    required String saleId,
    required EggSaleInput input,
  });
  Future<void> deleteSale({required String farmId, required String saleId});
}

final class SupabaseHuevoRepository implements HuevoRepository {
  SupabaseHuevoRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<EggCollection>> getCollections(String farmId) async {
    final data = await _client
        .from('recoleccion_huevo')
        .select(_collectionSelect)
        .eq('granja_id', farmId)
        .order('fecha_recoleccion', ascending: false)
        .order('created_at', ascending: false);
    return _rows(data).map(EggCollection.fromJson).toList();
  }

  @override
  Future<List<EggSale>> getSales(String farmId) async {
    final data = await _client
        .from('venta_huevo')
        .select(_saleSelect)
        .eq('granja_id', farmId)
        .order('fecha_venta', ascending: false)
        .order('created_at', ascending: false);
    return _rows(data).map(EggSale.fromJson).toList();
  }

  @override
  Future<EggAccess> getAccess(String farmId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const EggAccess(canEdit: false);

    final farm = await _client
        .from('granjas')
        .select('owner_id')
        .eq('id', farmId)
        .maybeSingle();
    if (farm?['owner_id'] == userId) return const EggAccess(canEdit: true);

    final membership = await _client
        .from('miembros_granja')
        .select('rol')
        .eq('granja_id', farmId)
        .eq('user_id', userId)
        .maybeSingle();
    return EggAccess(canEdit: membership?['rol'] == 'editor');
  }

  @override
  Future<void> createCollection(EggCollectionInput input) async {
    _validate(input.validate());
    await _client.from('recoleccion_huevo').insert({
      'granja_id': input.farmId,
      'grupo_id': input.groupId,
      'fecha_recoleccion': _date(input.date),
      'buenos': input.goodEggs,
      'rotos': input.brokenEggs,
      'created_by': _client.auth.currentUser?.id,
    });
  }

  @override
  Future<void> updateCollection({
    required String collectionId,
    required EggCollectionInput input,
  }) async {
    _validate(input.validate());
    await _client
        .from('recoleccion_huevo')
        .update({
          'grupo_id': input.groupId,
          'fecha_recoleccion': _date(input.date),
          'buenos': input.goodEggs,
          'rotos': input.brokenEggs,
        })
        .eq('id', collectionId)
        .eq('granja_id', input.farmId);
  }

  @override
  Future<void> deleteCollection({
    required String farmId,
    required String collectionId,
  }) async {
    await _client
        .from('recoleccion_huevo')
        .delete()
        .eq('id', collectionId)
        .eq('granja_id', farmId);
  }

  @override
  Future<void> createSale(EggSaleInput input) async {
    _validate(input.validate());
    await _client.from('venta_huevo').insert({
      'granja_id': input.farmId,
      'grupo_id': input.groupId,
      'fecha_venta': _date(input.date),
      'cantidad': input.quantity,
      'precio': input.unitPrice,
      'created_by': _client.auth.currentUser?.id,
    });
  }

  @override
  Future<void> updateSale({
    required String saleId,
    required EggSaleInput input,
  }) async {
    _validate(input.validate());
    await _client
        .from('venta_huevo')
        .update({
          'grupo_id': input.groupId,
          'fecha_venta': _date(input.date),
          'cantidad': input.quantity,
          'precio': input.unitPrice,
        })
        .eq('id', saleId)
        .eq('granja_id', input.farmId);
  }

  @override
  Future<void> deleteSale({
    required String farmId,
    required String saleId,
  }) async {
    await _client
        .from('venta_huevo')
        .delete()
        .eq('id', saleId)
        .eq('granja_id', farmId);
  }

  static void _validate(String? error) {
    if (error != null) throw ArgumentError(error);
  }

  static List<Map<String, dynamic>> _rows(Object? value) => [
    for (final row in value as List? ?? const [])
      Map<String, dynamic>.from(row as Map),
  ];

  static String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static const _collectionSelect = '''
    id,granja_id,grupo_id,fecha_recoleccion,buenos,rotos,created_by,created_at,
    group:grupos(nombre,tipo_animal_id,animal_type:tipo_animal(nombre)),
    author:perfiles(nombre)
  ''';

  static const _saleSelect = '''
    id,granja_id,grupo_id,fecha_venta,cantidad,precio,created_by,created_at,
    group:grupos(nombre,tipo_animal_id,animal_type:tipo_animal(nombre)),
    author:perfiles(nombre)
  ''';
}
