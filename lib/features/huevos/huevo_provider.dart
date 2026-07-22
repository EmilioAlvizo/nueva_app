import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'huevo_models.dart';
import 'huevo_repository.dart';

part 'huevo_provider.g.dart';

Duration? _noRetry(int _, Object _) => null;

@Riverpod(keepAlive: true)
HuevoRepository huevoRepository(Ref ref) {
  return SupabaseHuevoRepository(Supabase.instance.client);
}

@Riverpod(retry: _noRetry)
Future<EggData> huevoData(Ref ref, String farmId) async {
  final repository = ref.watch(huevoRepositoryProvider);
  final collectionsFuture = repository.getCollections(farmId);
  final salesFuture = repository.getSales(farmId);
  return EggData(
    collections: await collectionsFuture,
    sales: await salesFuture,
  );
}

@Riverpod(retry: _noRetry)
Future<EggAccess> huevoAccess(Ref ref, String farmId) {
  return ref.watch(huevoRepositoryProvider).getAccess(farmId);
}

@riverpod
class HuevoFilters extends _$HuevoFilters {
  @override
  EggFilters build(String farmId) => const EggFilters();

  void setGroup(String? groupId) {
    state = state.copyWith(groupId: groupId, clearGroup: groupId == null);
  }

  void setPeriod(EggPeriod period) {
    state = state.copyWith(period: period);
  }
}

@riverpod
class HuevoMutations extends _$HuevoMutations {
  @override
  Future<void> build() async {}

  Future<void> createCollection(EggCollectionInput input) => _run(
    input.farmId,
    () => ref.read(huevoRepositoryProvider).createCollection(input),
  );

  Future<void> updateCollection({
    required String collectionId,
    required EggCollectionInput input,
  }) => _run(
    input.farmId,
    () => ref
        .read(huevoRepositoryProvider)
        .updateCollection(collectionId: collectionId, input: input),
  );

  Future<void> deleteCollection({
    required String farmId,
    required String collectionId,
  }) => _run(
    farmId,
    () => ref
        .read(huevoRepositoryProvider)
        .deleteCollection(farmId: farmId, collectionId: collectionId),
  );

  Future<void> createSale(EggSaleInput input) => _run(
    input.farmId,
    () => ref.read(huevoRepositoryProvider).createSale(input),
  );

  Future<void> updateSale({
    required String saleId,
    required EggSaleInput input,
  }) => _run(
    input.farmId,
    () => ref
        .read(huevoRepositoryProvider)
        .updateSale(saleId: saleId, input: input),
  );

  Future<void> deleteSale({required String farmId, required String saleId}) =>
      _run(
        farmId,
        () => ref
            .read(huevoRepositoryProvider)
            .deleteSale(farmId: farmId, saleId: saleId),
      );

  Future<void> _run(String farmId, Future<void> Function() operation) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(operation);
    if (!ref.mounted) return;
    state = result;
    if (result case AsyncData()) {
      ref.invalidate(huevoDataProvider(farmId));
      return;
    }
    if (result case AsyncError(:final error, :final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
