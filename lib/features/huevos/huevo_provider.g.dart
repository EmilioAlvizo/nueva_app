// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'huevo_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(huevoRepository)
final huevoRepositoryProvider = HuevoRepositoryProvider._();

final class HuevoRepositoryProvider
    extends
        $FunctionalProvider<HuevoRepository, HuevoRepository, HuevoRepository>
    with $Provider<HuevoRepository> {
  HuevoRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'huevoRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$huevoRepositoryHash();

  @$internal
  @override
  $ProviderElement<HuevoRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HuevoRepository create(Ref ref) {
    return huevoRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HuevoRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HuevoRepository>(value),
    );
  }
}

String _$huevoRepositoryHash() => r'8f9af848878aed37beece96c207bb6eff7956046';

@ProviderFor(huevoData)
final huevoDataProvider = HuevoDataFamily._();

final class HuevoDataProvider
    extends $FunctionalProvider<AsyncValue<EggData>, EggData, FutureOr<EggData>>
    with $FutureModifier<EggData>, $FutureProvider<EggData> {
  HuevoDataProvider._({
    required HuevoDataFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'huevoDataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$huevoDataHash();

  @override
  String toString() {
    return r'huevoDataProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<EggData> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<EggData> create(Ref ref) {
    final argument = this.argument as String;
    return huevoData(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HuevoDataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$huevoDataHash() => r'9873bef096a15e598e5538674abc3ef78f05f780';

final class HuevoDataFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<EggData>, String> {
  HuevoDataFamily._()
    : super(
        retry: _noRetry,
        name: r'huevoDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HuevoDataProvider call(String farmId) =>
      HuevoDataProvider._(argument: farmId, from: this);

  @override
  String toString() => r'huevoDataProvider';
}

@ProviderFor(huevoAccess)
final huevoAccessProvider = HuevoAccessFamily._();

final class HuevoAccessProvider
    extends
        $FunctionalProvider<
          AsyncValue<EggAccess>,
          EggAccess,
          FutureOr<EggAccess>
        >
    with $FutureModifier<EggAccess>, $FutureProvider<EggAccess> {
  HuevoAccessProvider._({
    required HuevoAccessFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'huevoAccessProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$huevoAccessHash();

  @override
  String toString() {
    return r'huevoAccessProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<EggAccess> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<EggAccess> create(Ref ref) {
    final argument = this.argument as String;
    return huevoAccess(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HuevoAccessProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$huevoAccessHash() => r'3158c5015c9e9e70a8a00b5781825e74e0f5082a';

final class HuevoAccessFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<EggAccess>, String> {
  HuevoAccessFamily._()
    : super(
        retry: _noRetry,
        name: r'huevoAccessProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HuevoAccessProvider call(String farmId) =>
      HuevoAccessProvider._(argument: farmId, from: this);

  @override
  String toString() => r'huevoAccessProvider';
}

@ProviderFor(HuevoFilters)
final huevoFiltersProvider = HuevoFiltersFamily._();

final class HuevoFiltersProvider
    extends $NotifierProvider<HuevoFilters, EggFilters> {
  HuevoFiltersProvider._({
    required HuevoFiltersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'huevoFiltersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$huevoFiltersHash();

  @override
  String toString() {
    return r'huevoFiltersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  HuevoFilters create() => HuevoFilters();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EggFilters value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EggFilters>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HuevoFiltersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$huevoFiltersHash() => r'e1ac3d50046d80a5c1278a643ee3c7cdebdc1eca';

final class HuevoFiltersFamily extends $Family
    with
        $ClassFamilyOverride<
          HuevoFilters,
          EggFilters,
          EggFilters,
          EggFilters,
          String
        > {
  HuevoFiltersFamily._()
    : super(
        retry: null,
        name: r'huevoFiltersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HuevoFiltersProvider call(String farmId) =>
      HuevoFiltersProvider._(argument: farmId, from: this);

  @override
  String toString() => r'huevoFiltersProvider';
}

abstract class _$HuevoFilters extends $Notifier<EggFilters> {
  late final _$args = ref.$arg as String;
  String get farmId => _$args;

  EggFilters build(String farmId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<EggFilters, EggFilters>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EggFilters, EggFilters>,
              EggFilters,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(HuevoMutations)
final huevoMutationsProvider = HuevoMutationsProvider._();

final class HuevoMutationsProvider
    extends $AsyncNotifierProvider<HuevoMutations, void> {
  HuevoMutationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'huevoMutationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$huevoMutationsHash();

  @$internal
  @override
  HuevoMutations create() => HuevoMutations();
}

String _$huevoMutationsHash() => r'66ed066e335d782af67486521c994b95fb07ffe4';

abstract class _$HuevoMutations extends $AsyncNotifier<void> {
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
