import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'comida_models.dart';
import 'comida_repository.dart';

part 'comida_provider.g.dart';

Duration? _noRetry(int _, Object _) => null;

@Riverpod(keepAlive: true)
ComidaRepository comidaRepository(Ref ref) =>
    SupabaseComidaRepository(Supabase.instance.client);

@Riverpod(retry: _noRetry)
Future<List<FoodMixture>> foodMixtures(Ref ref, String farmId) =>
    ref.watch(comidaRepositoryProvider).getMixtures(farmId);

@Riverpod(retry: _noRetry)
Future<List<FoodCategory>> foodCategories(Ref ref, String farmId) =>
    ref.watch(comidaRepositoryProvider).getCategories(farmId);

@Riverpod(retry: _noRetry)
Future<List<FoodGroup>> foodGroups(Ref ref, String farmId) =>
    ref.watch(comidaRepositoryProvider).getGroups(farmId);

@Riverpod(retry: _noRetry)
Future<FoodAccess> foodAccess(Ref ref, String farmId) =>
    ref.watch(comidaRepositoryProvider).getAccess(farmId);

@riverpod
class FoodMutations extends _$FoodMutations {
  @override
  Future<void> build() async {}

  Future<void> createCategory({required String farmId, required String name}) =>
      _run(
        farmId,
        () => ref
            .read(comidaRepositoryProvider)
            .createCategory(farmId: farmId, name: name),
        refreshMixtures: false,
      );

  Future<void> updateCategory({
    required String farmId,
    required String categoryId,
    required String name,
  }) => _run(
    farmId,
    () => ref
        .read(comidaRepositoryProvider)
        .updateCategory(farmId: farmId, categoryId: categoryId, name: name),
    refreshMixtures: true,
  );

  Future<void> deleteCategory({
    required String farmId,
    required String categoryId,
  }) => _run(
    farmId,
    () => ref
        .read(comidaRepositoryProvider)
        .deleteCategory(farmId: farmId, categoryId: categoryId),
  );

  Future<void> createMixture(MixtureInput input) => _run(
    input.farmId,
    () => ref.read(comidaRepositoryProvider).createMixture(input),
    refreshCategories: false,
  );

  Future<void> updateMixture({
    required String mixtureId,
    required MixtureInput input,
  }) => _run(
    input.farmId,
    () => ref
        .read(comidaRepositoryProvider)
        .updateMixture(mixtureId: mixtureId, input: input),
    refreshCategories: false,
  );

  Future<void> deleteMixture({
    required String farmId,
    required String mixtureId,
  }) => _run(
    farmId,
    () => ref
        .read(comidaRepositoryProvider)
        .deleteMixture(farmId: farmId, mixtureId: mixtureId),
    refreshCategories: false,
  );

  Future<void> _run(
    String farmId,
    Future<void> Function() operation, {
    bool refreshMixtures = true,
    bool refreshCategories = true,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(operation);
    if (!ref.mounted) return;
    state = result;
    if (result case AsyncData()) {
      if (refreshMixtures) ref.invalidate(foodMixturesProvider(farmId));
      if (refreshCategories) ref.invalidate(foodCategoriesProvider(farmId));
      return;
    }
    if (result case AsyncError(:final error, :final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
