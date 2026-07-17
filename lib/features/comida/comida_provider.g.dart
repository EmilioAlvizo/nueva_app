// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comida_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(comidaRepository)
final comidaRepositoryProvider = ComidaRepositoryProvider._();

final class ComidaRepositoryProvider
    extends
        $FunctionalProvider<
          ComidaRepository,
          ComidaRepository,
          ComidaRepository
        >
    with $Provider<ComidaRepository> {
  ComidaRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'comidaRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$comidaRepositoryHash();

  @$internal
  @override
  $ProviderElement<ComidaRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ComidaRepository create(Ref ref) {
    return comidaRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ComidaRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ComidaRepository>(value),
    );
  }
}

String _$comidaRepositoryHash() => r'f2b9052313d7da481d698b70d5fcc879c57f5d00';

@ProviderFor(foodMixtures)
final foodMixturesProvider = FoodMixturesFamily._();

final class FoodMixturesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FoodMixture>>,
          List<FoodMixture>,
          FutureOr<List<FoodMixture>>
        >
    with
        $FutureModifier<List<FoodMixture>>,
        $FutureProvider<List<FoodMixture>> {
  FoodMixturesProvider._({
    required FoodMixturesFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'foodMixturesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$foodMixturesHash();

  @override
  String toString() {
    return r'foodMixturesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<FoodMixture>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FoodMixture>> create(Ref ref) {
    final argument = this.argument as String;
    return foodMixtures(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FoodMixturesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$foodMixturesHash() => r'536ab6a16f81c2e56f3a52afd5b7d889105c8061';

final class FoodMixturesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<FoodMixture>>, String> {
  FoodMixturesFamily._()
    : super(
        retry: _noRetry,
        name: r'foodMixturesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FoodMixturesProvider call(String farmId) =>
      FoodMixturesProvider._(argument: farmId, from: this);

  @override
  String toString() => r'foodMixturesProvider';
}

@ProviderFor(foodCategories)
final foodCategoriesProvider = FoodCategoriesFamily._();

final class FoodCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FoodCategory>>,
          List<FoodCategory>,
          FutureOr<List<FoodCategory>>
        >
    with
        $FutureModifier<List<FoodCategory>>,
        $FutureProvider<List<FoodCategory>> {
  FoodCategoriesProvider._({
    required FoodCategoriesFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'foodCategoriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$foodCategoriesHash();

  @override
  String toString() {
    return r'foodCategoriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<FoodCategory>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FoodCategory>> create(Ref ref) {
    final argument = this.argument as String;
    return foodCategories(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FoodCategoriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$foodCategoriesHash() => r'298f5cff3acc3a0790d4561321874368f5af8c87';

final class FoodCategoriesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<FoodCategory>>, String> {
  FoodCategoriesFamily._()
    : super(
        retry: _noRetry,
        name: r'foodCategoriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FoodCategoriesProvider call(String farmId) =>
      FoodCategoriesProvider._(argument: farmId, from: this);

  @override
  String toString() => r'foodCategoriesProvider';
}

@ProviderFor(foodGroups)
final foodGroupsProvider = FoodGroupsFamily._();

final class FoodGroupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FoodGroup>>,
          List<FoodGroup>,
          FutureOr<List<FoodGroup>>
        >
    with $FutureModifier<List<FoodGroup>>, $FutureProvider<List<FoodGroup>> {
  FoodGroupsProvider._({
    required FoodGroupsFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'foodGroupsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$foodGroupsHash();

  @override
  String toString() {
    return r'foodGroupsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<FoodGroup>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FoodGroup>> create(Ref ref) {
    final argument = this.argument as String;
    return foodGroups(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FoodGroupsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$foodGroupsHash() => r'ce46aa985e394225e156fcf056f17ae39c294e67';

final class FoodGroupsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<FoodGroup>>, String> {
  FoodGroupsFamily._()
    : super(
        retry: _noRetry,
        name: r'foodGroupsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FoodGroupsProvider call(String farmId) =>
      FoodGroupsProvider._(argument: farmId, from: this);

  @override
  String toString() => r'foodGroupsProvider';
}

@ProviderFor(foodAccess)
final foodAccessProvider = FoodAccessFamily._();

final class FoodAccessProvider
    extends
        $FunctionalProvider<
          AsyncValue<FoodAccess>,
          FoodAccess,
          FutureOr<FoodAccess>
        >
    with $FutureModifier<FoodAccess>, $FutureProvider<FoodAccess> {
  FoodAccessProvider._({
    required FoodAccessFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'foodAccessProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$foodAccessHash();

  @override
  String toString() {
    return r'foodAccessProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<FoodAccess> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<FoodAccess> create(Ref ref) {
    final argument = this.argument as String;
    return foodAccess(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FoodAccessProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$foodAccessHash() => r'c069b85734a0fea0ce9933e0d18895539662cd67';

final class FoodAccessFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<FoodAccess>, String> {
  FoodAccessFamily._()
    : super(
        retry: _noRetry,
        name: r'foodAccessProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FoodAccessProvider call(String farmId) =>
      FoodAccessProvider._(argument: farmId, from: this);

  @override
  String toString() => r'foodAccessProvider';
}

@ProviderFor(FoodMutations)
final foodMutationsProvider = FoodMutationsProvider._();

final class FoodMutationsProvider
    extends $AsyncNotifierProvider<FoodMutations, void> {
  FoodMutationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foodMutationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foodMutationsHash();

  @$internal
  @override
  FoodMutations create() => FoodMutations();
}

String _$foodMutationsHash() => r'cb4f532ea796b37ac807a7699be2c99ee0bfb293';

abstract class _$FoodMutations extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
