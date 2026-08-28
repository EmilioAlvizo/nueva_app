// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cycle_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(cycleRepository)
final cycleRepositoryProvider = CycleRepositoryProvider._();

final class CycleRepositoryProvider
    extends
        $FunctionalProvider<CycleRepository, CycleRepository, CycleRepository>
    with $Provider<CycleRepository> {
  CycleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cycleRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cycleRepositoryHash();

  @$internal
  @override
  $ProviderElement<CycleRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CycleRepository create(Ref ref) {
    return cycleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CycleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CycleRepository>(value),
    );
  }
}

String _$cycleRepositoryHash() => r'eaee28c89994c9d596209b90a8f14830111cd582';

@ProviderFor(economicsV2Repository)
final economicsV2RepositoryProvider = EconomicsV2RepositoryProvider._();

final class EconomicsV2RepositoryProvider
    extends
        $FunctionalProvider<
          EconomicsV2Repository,
          EconomicsV2Repository,
          EconomicsV2Repository
        >
    with $Provider<EconomicsV2Repository> {
  EconomicsV2RepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'economicsV2RepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$economicsV2RepositoryHash();

  @$internal
  @override
  $ProviderElement<EconomicsV2Repository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EconomicsV2Repository create(Ref ref) {
    return economicsV2Repository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EconomicsV2Repository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EconomicsV2Repository>(value),
    );
  }
}

String _$economicsV2RepositoryHash() =>
    r'60b26daf5fe92bb54f1ddafee83e1659614f25cc';

@ProviderFor(economicsV2LifecycleRepository)
final economicsV2LifecycleRepositoryProvider =
    EconomicsV2LifecycleRepositoryProvider._();

final class EconomicsV2LifecycleRepositoryProvider
    extends
        $FunctionalProvider<
          EconomicsV2LifecycleRepository,
          EconomicsV2LifecycleRepository,
          EconomicsV2LifecycleRepository
        >
    with $Provider<EconomicsV2LifecycleRepository> {
  EconomicsV2LifecycleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'economicsV2LifecycleRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$economicsV2LifecycleRepositoryHash();

  @$internal
  @override
  $ProviderElement<EconomicsV2LifecycleRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EconomicsV2LifecycleRepository create(Ref ref) {
    return economicsV2LifecycleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EconomicsV2LifecycleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EconomicsV2LifecycleRepository>(
        value,
      ),
    );
  }
}

String _$economicsV2LifecycleRepositoryHash() =>
    r'f653d47cfb5a5eac4112783441cd7a122067582c';

@ProviderFor(economicsV2Cycles)
final economicsV2CyclesProvider = EconomicsV2CyclesFamily._();

final class EconomicsV2CyclesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EconomicsV2Cycle>>,
          List<EconomicsV2Cycle>,
          FutureOr<List<EconomicsV2Cycle>>
        >
    with
        $FutureModifier<List<EconomicsV2Cycle>>,
        $FutureProvider<List<EconomicsV2Cycle>> {
  EconomicsV2CyclesProvider._({
    required EconomicsV2CyclesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'economicsV2CyclesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$economicsV2CyclesHash();

  @override
  String toString() {
    return r'economicsV2CyclesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<EconomicsV2Cycle>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<EconomicsV2Cycle>> create(Ref ref) {
    final argument = this.argument as String;
    return economicsV2Cycles(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EconomicsV2CyclesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$economicsV2CyclesHash() => r'b0f764c33ba92bb2a632e5a314b327630249c4e0';

final class EconomicsV2CyclesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<EconomicsV2Cycle>>, String> {
  EconomicsV2CyclesFamily._()
    : super(
        retry: null,
        name: r'economicsV2CyclesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EconomicsV2CyclesProvider call(String farmId) =>
      EconomicsV2CyclesProvider._(argument: farmId, from: this);

  @override
  String toString() => r'economicsV2CyclesProvider';
}

@ProviderFor(economicsV2Access)
final economicsV2AccessProvider = EconomicsV2AccessFamily._();

final class EconomicsV2AccessProvider
    extends
        $FunctionalProvider<
          AsyncValue<EconomicsV2FarmAccess>,
          EconomicsV2FarmAccess,
          FutureOr<EconomicsV2FarmAccess>
        >
    with
        $FutureModifier<EconomicsV2FarmAccess>,
        $FutureProvider<EconomicsV2FarmAccess> {
  EconomicsV2AccessProvider._({
    required EconomicsV2AccessFamily super.from,
    required String super.argument,
  }) : super(
         retry: doNotRetryProvider,
         name: r'economicsV2AccessProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$economicsV2AccessHash();

  @override
  String toString() {
    return r'economicsV2AccessProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<EconomicsV2FarmAccess> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EconomicsV2FarmAccess> create(Ref ref) {
    final argument = this.argument as String;
    return economicsV2Access(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EconomicsV2AccessProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$economicsV2AccessHash() => r'a37a1f09dfdd6dc96cf863f411d44c8175c0e63f';

final class EconomicsV2AccessFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<EconomicsV2FarmAccess>, String> {
  EconomicsV2AccessFamily._()
    : super(
        retry: doNotRetryProvider,
        name: r'economicsV2AccessProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EconomicsV2AccessProvider call(String farmId) =>
      EconomicsV2AccessProvider._(argument: farmId, from: this);

  @override
  String toString() => r'economicsV2AccessProvider';
}

@ProviderFor(economicsV2CycleSummaries)
final economicsV2CycleSummariesProvider = EconomicsV2CycleSummariesFamily._();

final class EconomicsV2CycleSummariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<EconomicsV2CyclesDashboard>,
          EconomicsV2CyclesDashboard,
          FutureOr<EconomicsV2CyclesDashboard>
        >
    with
        $FutureModifier<EconomicsV2CyclesDashboard>,
        $FutureProvider<EconomicsV2CyclesDashboard> {
  EconomicsV2CycleSummariesProvider._({
    required EconomicsV2CycleSummariesFamily super.from,
    required String super.argument,
  }) : super(
         retry: doNotRetryProvider,
         name: r'economicsV2CycleSummariesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$economicsV2CycleSummariesHash();

  @override
  String toString() {
    return r'economicsV2CycleSummariesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<EconomicsV2CyclesDashboard> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EconomicsV2CyclesDashboard> create(Ref ref) {
    final argument = this.argument as String;
    return economicsV2CycleSummaries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EconomicsV2CycleSummariesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$economicsV2CycleSummariesHash() =>
    r'c391960485fa094f7af184829c1faa82f3c59a3f';

final class EconomicsV2CycleSummariesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<EconomicsV2CyclesDashboard>,
          String
        > {
  EconomicsV2CycleSummariesFamily._()
    : super(
        retry: doNotRetryProvider,
        name: r'economicsV2CycleSummariesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EconomicsV2CycleSummariesProvider call(String farmId) =>
      EconomicsV2CycleSummariesProvider._(argument: farmId, from: this);

  @override
  String toString() => r'economicsV2CycleSummariesProvider';
}

@ProviderFor(economicsV2CycleDetail)
final economicsV2CycleDetailProvider = EconomicsV2CycleDetailFamily._();

final class EconomicsV2CycleDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<EconomicsV2CycleDetail>,
          EconomicsV2CycleDetail,
          FutureOr<EconomicsV2CycleDetail>
        >
    with
        $FutureModifier<EconomicsV2CycleDetail>,
        $FutureProvider<EconomicsV2CycleDetail> {
  EconomicsV2CycleDetailProvider._({
    required EconomicsV2CycleDetailFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: doNotRetryProvider,
         name: r'economicsV2CycleDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$economicsV2CycleDetailHash();

  @override
  String toString() {
    return r'economicsV2CycleDetailProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<EconomicsV2CycleDetail> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EconomicsV2CycleDetail> create(Ref ref) {
    final argument = this.argument as (String, String);
    return economicsV2CycleDetail(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is EconomicsV2CycleDetailProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$economicsV2CycleDetailHash() =>
    r'3fb42e7606e2d28cf7842f2168caf1c6b373bdb8';

final class EconomicsV2CycleDetailFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<EconomicsV2CycleDetail>,
          (String, String)
        > {
  EconomicsV2CycleDetailFamily._()
    : super(
        retry: doNotRetryProvider,
        name: r'economicsV2CycleDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EconomicsV2CycleDetailProvider call(String farmId, String cycleId) =>
      EconomicsV2CycleDetailProvider._(argument: (farmId, cycleId), from: this);

  @override
  String toString() => r'economicsV2CycleDetailProvider';
}

@ProviderFor(economicsV2CycleMembers)
final economicsV2CycleMembersProvider = EconomicsV2CycleMembersFamily._();

final class EconomicsV2CycleMembersProvider
    extends
        $FunctionalProvider<
          AsyncValue<EconomicsV2CycleMembers>,
          EconomicsV2CycleMembers,
          FutureOr<EconomicsV2CycleMembers>
        >
    with
        $FutureModifier<EconomicsV2CycleMembers>,
        $FutureProvider<EconomicsV2CycleMembers> {
  EconomicsV2CycleMembersProvider._({
    required EconomicsV2CycleMembersFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: doNotRetryProvider,
         name: r'economicsV2CycleMembersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$economicsV2CycleMembersHash();

  @override
  String toString() {
    return r'economicsV2CycleMembersProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<EconomicsV2CycleMembers> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EconomicsV2CycleMembers> create(Ref ref) {
    final argument = this.argument as (String, String);
    return economicsV2CycleMembers(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is EconomicsV2CycleMembersProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$economicsV2CycleMembersHash() =>
    r'9b336bf817acbc17c2932e514bbd377fef3cf45a';

final class EconomicsV2CycleMembersFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<EconomicsV2CycleMembers>,
          (String, String)
        > {
  EconomicsV2CycleMembersFamily._()
    : super(
        retry: doNotRetryProvider,
        name: r'economicsV2CycleMembersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EconomicsV2CycleMembersProvider call(String farmId, String cycleId) =>
      EconomicsV2CycleMembersProvider._(
        argument: (farmId, cycleId),
        from: this,
      );

  @override
  String toString() => r'economicsV2CycleMembersProvider';
}

@ProviderFor(economicsV2CycleFeeds)
final economicsV2CycleFeedsProvider = EconomicsV2CycleFeedsFamily._();

final class EconomicsV2CycleFeedsProvider
    extends
        $FunctionalProvider<
          AsyncValue<EconomicsV2CycleFeeds>,
          EconomicsV2CycleFeeds,
          FutureOr<EconomicsV2CycleFeeds>
        >
    with
        $FutureModifier<EconomicsV2CycleFeeds>,
        $FutureProvider<EconomicsV2CycleFeeds> {
  EconomicsV2CycleFeedsProvider._({
    required EconomicsV2CycleFeedsFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: doNotRetryProvider,
         name: r'economicsV2CycleFeedsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$economicsV2CycleFeedsHash();

  @override
  String toString() {
    return r'economicsV2CycleFeedsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<EconomicsV2CycleFeeds> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EconomicsV2CycleFeeds> create(Ref ref) {
    final argument = this.argument as (String, String);
    return economicsV2CycleFeeds(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is EconomicsV2CycleFeedsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$economicsV2CycleFeedsHash() =>
    r'9e10be621f1458812e815a39d423d25ecfd2d030';

final class EconomicsV2CycleFeedsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<EconomicsV2CycleFeeds>,
          (String, String)
        > {
  EconomicsV2CycleFeedsFamily._()
    : super(
        retry: doNotRetryProvider,
        name: r'economicsV2CycleFeedsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EconomicsV2CycleFeedsProvider call(String farmId, String cycleId) =>
      EconomicsV2CycleFeedsProvider._(argument: (farmId, cycleId), from: this);

  @override
  String toString() => r'economicsV2CycleFeedsProvider';
}

@ProviderFor(economicsV2CycleExpenses)
final economicsV2CycleExpensesProvider = EconomicsV2CycleExpensesFamily._();

final class EconomicsV2CycleExpensesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EconomicsV2CycleExpense>>,
          List<EconomicsV2CycleExpense>,
          FutureOr<List<EconomicsV2CycleExpense>>
        >
    with
        $FutureModifier<List<EconomicsV2CycleExpense>>,
        $FutureProvider<List<EconomicsV2CycleExpense>> {
  EconomicsV2CycleExpensesProvider._({
    required EconomicsV2CycleExpensesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: doNotRetryProvider,
         name: r'economicsV2CycleExpensesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$economicsV2CycleExpensesHash();

  @override
  String toString() {
    return r'economicsV2CycleExpensesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<EconomicsV2CycleExpense>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<EconomicsV2CycleExpense>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return economicsV2CycleExpenses(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is EconomicsV2CycleExpensesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$economicsV2CycleExpensesHash() =>
    r'93aa3b3a929d5a4c220792abac33df920b38f6f5';

final class EconomicsV2CycleExpensesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<EconomicsV2CycleExpense>>,
          (String, String)
        > {
  EconomicsV2CycleExpensesFamily._()
    : super(
        retry: doNotRetryProvider,
        name: r'economicsV2CycleExpensesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EconomicsV2CycleExpensesProvider call(String farmId, String cycleId) =>
      EconomicsV2CycleExpensesProvider._(
        argument: (farmId, cycleId),
        from: this,
      );

  @override
  String toString() => r'economicsV2CycleExpensesProvider';
}

@ProviderFor(economicsV2CycleProjections)
final economicsV2CycleProjectionsProvider =
    EconomicsV2CycleProjectionsFamily._();

final class EconomicsV2CycleProjectionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EconomicsV2SavedProjection>>,
          List<EconomicsV2SavedProjection>,
          FutureOr<List<EconomicsV2SavedProjection>>
        >
    with
        $FutureModifier<List<EconomicsV2SavedProjection>>,
        $FutureProvider<List<EconomicsV2SavedProjection>> {
  EconomicsV2CycleProjectionsProvider._({
    required EconomicsV2CycleProjectionsFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: doNotRetryProvider,
         name: r'economicsV2CycleProjectionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$economicsV2CycleProjectionsHash();

  @override
  String toString() {
    return r'economicsV2CycleProjectionsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<EconomicsV2SavedProjection>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<EconomicsV2SavedProjection>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return economicsV2CycleProjections(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is EconomicsV2CycleProjectionsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$economicsV2CycleProjectionsHash() =>
    r'f88f2c827931541de334a01912987d9352c18215';

final class EconomicsV2CycleProjectionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<EconomicsV2SavedProjection>>,
          (String, String)
        > {
  EconomicsV2CycleProjectionsFamily._()
    : super(
        retry: doNotRetryProvider,
        name: r'economicsV2CycleProjectionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EconomicsV2CycleProjectionsProvider call(String farmId, String cycleId) =>
      EconomicsV2CycleProjectionsProvider._(
        argument: (farmId, cycleId),
        from: this,
      );

  @override
  String toString() => r'economicsV2CycleProjectionsProvider';
}

@ProviderFor(economicsV2CycleReadiness)
final economicsV2CycleReadinessProvider = EconomicsV2CycleReadinessFamily._();

final class EconomicsV2CycleReadinessProvider
    extends
        $FunctionalProvider<
          AsyncValue<EconomicsV2CycleReadiness>,
          EconomicsV2CycleReadiness,
          FutureOr<EconomicsV2CycleReadiness>
        >
    with
        $FutureModifier<EconomicsV2CycleReadiness>,
        $FutureProvider<EconomicsV2CycleReadiness> {
  EconomicsV2CycleReadinessProvider._({
    required EconomicsV2CycleReadinessFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: doNotRetryProvider,
         name: r'economicsV2CycleReadinessProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$economicsV2CycleReadinessHash();

  @override
  String toString() {
    return r'economicsV2CycleReadinessProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<EconomicsV2CycleReadiness> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EconomicsV2CycleReadiness> create(Ref ref) {
    final argument = this.argument as (String, String);
    return economicsV2CycleReadiness(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is EconomicsV2CycleReadinessProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$economicsV2CycleReadinessHash() =>
    r'b772ec874b37ab37a0fc87a6cd11f8ff47db9c88';

final class EconomicsV2CycleReadinessFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<EconomicsV2CycleReadiness>,
          (String, String)
        > {
  EconomicsV2CycleReadinessFamily._()
    : super(
        retry: doNotRetryProvider,
        name: r'economicsV2CycleReadinessProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EconomicsV2CycleReadinessProvider call(String farmId, String cycleId) =>
      EconomicsV2CycleReadinessProvider._(
        argument: (farmId, cycleId),
        from: this,
      );

  @override
  String toString() => r'economicsV2CycleReadinessProvider';
}

@ProviderFor(cycleCatalogs)
final cycleCatalogsProvider = CycleCatalogsProvider._();

final class CycleCatalogsProvider
    extends
        $FunctionalProvider<
          AsyncValue<CycleCatalogs>,
          CycleCatalogs,
          FutureOr<CycleCatalogs>
        >
    with $FutureModifier<CycleCatalogs>, $FutureProvider<CycleCatalogs> {
  CycleCatalogsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cycleCatalogsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cycleCatalogsHash();

  @$internal
  @override
  $FutureProviderElement<CycleCatalogs> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CycleCatalogs> create(Ref ref) {
    return cycleCatalogs(ref);
  }
}

String _$cycleCatalogsHash() => r'f233089f0690c2fc23a9c29fa78948e0ade23831';

@ProviderFor(cycles)
final cyclesProvider = CyclesFamily._();

final class CyclesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Cycle>>,
          List<Cycle>,
          FutureOr<List<Cycle>>
        >
    with $FutureModifier<List<Cycle>>, $FutureProvider<List<Cycle>> {
  CyclesProvider._({
    required CyclesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'cyclesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$cyclesHash();

  @override
  String toString() {
    return r'cyclesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Cycle>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Cycle>> create(Ref ref) {
    final argument = this.argument as String;
    return cycles(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CyclesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$cyclesHash() => r'e2c1ecf545a10f97447d54d37b29cf1e97e2b2c0';

final class CyclesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Cycle>>, String> {
  CyclesFamily._()
    : super(
        retry: null,
        name: r'cyclesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CyclesProvider call(String farmId) =>
      CyclesProvider._(argument: farmId, from: this);

  @override
  String toString() => r'cyclesProvider';
}

@ProviderFor(cycleDetail)
final cycleDetailProvider = CycleDetailFamily._();

final class CycleDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<CycleDetail>,
          CycleDetail,
          FutureOr<CycleDetail>
        >
    with $FutureModifier<CycleDetail>, $FutureProvider<CycleDetail> {
  CycleDetailProvider._({
    required CycleDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'cycleDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$cycleDetailHash();

  @override
  String toString() {
    return r'cycleDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CycleDetail> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CycleDetail> create(Ref ref) {
    final argument = this.argument as String;
    return cycleDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CycleDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$cycleDetailHash() => r'5b80f241c8ebdf007a03c134b7939ab1679d9aa7';

final class CycleDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CycleDetail>, String> {
  CycleDetailFamily._()
    : super(
        retry: null,
        name: r'cycleDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CycleDetailProvider call(String cycleId) =>
      CycleDetailProvider._(argument: cycleId, from: this);

  @override
  String toString() => r'cycleDetailProvider';
}

@ProviderFor(cycleEconomics)
final cycleEconomicsProvider = CycleEconomicsFamily._();

final class CycleEconomicsProvider
    extends
        $FunctionalProvider<
          AsyncValue<CycleEconomics?>,
          CycleEconomics?,
          FutureOr<CycleEconomics?>
        >
    with $FutureModifier<CycleEconomics?>, $FutureProvider<CycleEconomics?> {
  CycleEconomicsProvider._({
    required CycleEconomicsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'cycleEconomicsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$cycleEconomicsHash();

  @override
  String toString() {
    return r'cycleEconomicsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CycleEconomics?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CycleEconomics?> create(Ref ref) {
    final argument = this.argument as String;
    return cycleEconomics(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CycleEconomicsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$cycleEconomicsHash() => r'82896723188a6693da60e538f37f46b67709689c';

final class CycleEconomicsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CycleEconomics?>, String> {
  CycleEconomicsFamily._()
    : super(
        retry: null,
        name: r'cycleEconomicsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CycleEconomicsProvider call(String cycleId) =>
      CycleEconomicsProvider._(argument: cycleId, from: this);

  @override
  String toString() => r'cycleEconomicsProvider';
}

@ProviderFor(cycleTimeline)
final cycleTimelineProvider = CycleTimelineFamily._();

final class CycleTimelineProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CycleTimelineItem>>,
          List<CycleTimelineItem>,
          FutureOr<List<CycleTimelineItem>>
        >
    with
        $FutureModifier<List<CycleTimelineItem>>,
        $FutureProvider<List<CycleTimelineItem>> {
  CycleTimelineProvider._({
    required CycleTimelineFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'cycleTimelineProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$cycleTimelineHash();

  @override
  String toString() {
    return r'cycleTimelineProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<CycleTimelineItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CycleTimelineItem>> create(Ref ref) {
    final argument = this.argument as String;
    return cycleTimeline(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CycleTimelineProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$cycleTimelineHash() => r'73ff44b416c4646bfeb9edec2c137c0d3b55a121';

final class CycleTimelineFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<CycleTimelineItem>>, String> {
  CycleTimelineFamily._()
    : super(
        retry: null,
        name: r'cycleTimelineProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CycleTimelineProvider call(String cycleId) =>
      CycleTimelineProvider._(argument: cycleId, from: this);

  @override
  String toString() => r'cycleTimelineProvider';
}

@ProviderFor(cycleGroups)
final cycleGroupsProvider = CycleGroupsFamily._();

final class CycleGroupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CycleGroup>>,
          List<CycleGroup>,
          FutureOr<List<CycleGroup>>
        >
    with $FutureModifier<List<CycleGroup>>, $FutureProvider<List<CycleGroup>> {
  CycleGroupsProvider._({
    required CycleGroupsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'cycleGroupsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$cycleGroupsHash();

  @override
  String toString() {
    return r'cycleGroupsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<CycleGroup>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CycleGroup>> create(Ref ref) {
    final argument = this.argument as String;
    return cycleGroups(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CycleGroupsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$cycleGroupsHash() => r'93988df5fe941cf462780010ec5e209356cbaaa8';

final class CycleGroupsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<CycleGroup>>, String> {
  CycleGroupsFamily._()
    : super(
        retry: null,
        name: r'cycleGroupsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CycleGroupsProvider call(String farmId) =>
      CycleGroupsProvider._(argument: farmId, from: this);

  @override
  String toString() => r'cycleGroupsProvider';
}

@ProviderFor(eligibleCycleMembers)
final eligibleCycleMembersProvider = EligibleCycleMembersFamily._();

final class EligibleCycleMembersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CycleMemberCandidate>>,
          List<CycleMemberCandidate>,
          FutureOr<List<CycleMemberCandidate>>
        >
    with
        $FutureModifier<List<CycleMemberCandidate>>,
        $FutureProvider<List<CycleMemberCandidate>> {
  EligibleCycleMembersProvider._({
    required EligibleCycleMembersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'eligibleCycleMembersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$eligibleCycleMembersHash();

  @override
  String toString() {
    return r'eligibleCycleMembersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<CycleMemberCandidate>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CycleMemberCandidate>> create(Ref ref) {
    final argument = this.argument as String;
    return eligibleCycleMembers(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EligibleCycleMembersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$eligibleCycleMembersHash() =>
    r'bd09f2776c7e93c0cdaa7ab13b96c8cd394e2720';

final class EligibleCycleMembersFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<CycleMemberCandidate>>,
          String
        > {
  EligibleCycleMembersFamily._()
    : super(
        retry: null,
        name: r'eligibleCycleMembersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EligibleCycleMembersProvider call(String farmId) =>
      EligibleCycleMembersProvider._(argument: farmId, from: this);

  @override
  String toString() => r'eligibleCycleMembersProvider';
}

@ProviderFor(cycleAccess)
final cycleAccessProvider = CycleAccessFamily._();

final class CycleAccessProvider
    extends
        $FunctionalProvider<
          AsyncValue<CycleAccess>,
          CycleAccess,
          FutureOr<CycleAccess>
        >
    with $FutureModifier<CycleAccess>, $FutureProvider<CycleAccess> {
  CycleAccessProvider._({
    required CycleAccessFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'cycleAccessProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$cycleAccessHash();

  @override
  String toString() {
    return r'cycleAccessProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CycleAccess> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CycleAccess> create(Ref ref) {
    final argument = this.argument as String;
    return cycleAccess(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CycleAccessProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$cycleAccessHash() => r'e0b43f1922f5974a678653ca6db927230904751f';

final class CycleAccessFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CycleAccess>, String> {
  CycleAccessFamily._()
    : super(
        retry: null,
        name: r'cycleAccessProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CycleAccessProvider call(String farmId) =>
      CycleAccessProvider._(argument: farmId, from: this);

  @override
  String toString() => r'cycleAccessProvider';
}

@ProviderFor(CycleMutations)
final cycleMutationsProvider = CycleMutationsProvider._();

final class CycleMutationsProvider
    extends $AsyncNotifierProvider<CycleMutations, void> {
  CycleMutationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cycleMutationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cycleMutationsHash();

  @$internal
  @override
  CycleMutations create() => CycleMutations();
}

String _$cycleMutationsHash() => r'bc96e8735597a06d2659cabb874dfa2361966696';

abstract class _$CycleMutations extends $AsyncNotifier<void> {
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

@ProviderFor(EconomicsV2Mutations)
final economicsV2MutationsProvider = EconomicsV2MutationsProvider._();

final class EconomicsV2MutationsProvider
    extends $AsyncNotifierProvider<EconomicsV2Mutations, EconomicsV2Result?> {
  EconomicsV2MutationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'economicsV2MutationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$economicsV2MutationsHash();

  @$internal
  @override
  EconomicsV2Mutations create() => EconomicsV2Mutations();
}

String _$economicsV2MutationsHash() =>
    r'ed37d76f01da737c89b0fb7df73c351270475efa';

abstract class _$EconomicsV2Mutations
    extends $AsyncNotifier<EconomicsV2Result?> {
  FutureOr<EconomicsV2Result?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<EconomicsV2Result?>, EconomicsV2Result?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<EconomicsV2Result?>, EconomicsV2Result?>,
              AsyncValue<EconomicsV2Result?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(EconomicsV2LifecycleMutations)
final economicsV2LifecycleMutationsProvider =
    EconomicsV2LifecycleMutationsProvider._();

final class EconomicsV2LifecycleMutationsProvider
    extends $AsyncNotifierProvider<EconomicsV2LifecycleMutations, Object?> {
  EconomicsV2LifecycleMutationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'economicsV2LifecycleMutationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$economicsV2LifecycleMutationsHash();

  @$internal
  @override
  EconomicsV2LifecycleMutations create() => EconomicsV2LifecycleMutations();
}

String _$economicsV2LifecycleMutationsHash() =>
    r'e6bcafa5424c3464dad0a5c4df43a77f93242d5a';

abstract class _$EconomicsV2LifecycleMutations extends $AsyncNotifier<Object?> {
  FutureOr<Object?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Object?>, Object?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Object?>, Object?>,
              AsyncValue<Object?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(FinanceCyclesWorkflow)
final financeCyclesWorkflowProvider = FinanceCyclesWorkflowFamily._();

final class FinanceCyclesWorkflowProvider
    extends
        $NotifierProvider<FinanceCyclesWorkflow, FinanceCyclesWorkflowState> {
  FinanceCyclesWorkflowProvider._({
    required FinanceCyclesWorkflowFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'financeCyclesWorkflowProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$financeCyclesWorkflowHash();

  @override
  String toString() {
    return r'financeCyclesWorkflowProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FinanceCyclesWorkflow create() => FinanceCyclesWorkflow();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinanceCyclesWorkflowState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinanceCyclesWorkflowState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FinanceCyclesWorkflowProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$financeCyclesWorkflowHash() =>
    r'27ba837df4ac8b9238fd36fab15769418c58fea8';

final class FinanceCyclesWorkflowFamily extends $Family
    with
        $ClassFamilyOverride<
          FinanceCyclesWorkflow,
          FinanceCyclesWorkflowState,
          FinanceCyclesWorkflowState,
          FinanceCyclesWorkflowState,
          String
        > {
  FinanceCyclesWorkflowFamily._()
    : super(
        retry: null,
        name: r'financeCyclesWorkflowProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FinanceCyclesWorkflowProvider call(String farmId) =>
      FinanceCyclesWorkflowProvider._(argument: farmId, from: this);

  @override
  String toString() => r'financeCyclesWorkflowProvider';
}

abstract class _$FinanceCyclesWorkflow
    extends $Notifier<FinanceCyclesWorkflowState> {
  late final _$args = ref.$arg as String;
  String get farmId => _$args;

  FinanceCyclesWorkflowState build(String farmId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<FinanceCyclesWorkflowState, FinanceCyclesWorkflowState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                FinanceCyclesWorkflowState,
                FinanceCyclesWorkflowState
              >,
              FinanceCyclesWorkflowState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(FinanceCycleWorkspaceMutations)
final financeCycleWorkspaceMutationsProvider =
    FinanceCycleWorkspaceMutationsFamily._();

final class FinanceCycleWorkspaceMutationsProvider
    extends $AsyncNotifierProvider<FinanceCycleWorkspaceMutations, void> {
  FinanceCycleWorkspaceMutationsProvider._({
    required FinanceCycleWorkspaceMutationsFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'financeCycleWorkspaceMutationsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$financeCycleWorkspaceMutationsHash();

  @override
  String toString() {
    return r'financeCycleWorkspaceMutationsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  FinanceCycleWorkspaceMutations create() => FinanceCycleWorkspaceMutations();

  @override
  bool operator ==(Object other) {
    return other is FinanceCycleWorkspaceMutationsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$financeCycleWorkspaceMutationsHash() =>
    r'2ffdb37f52a8db5846629c46c7853cb0e921518b';

final class FinanceCycleWorkspaceMutationsFamily extends $Family
    with
        $ClassFamilyOverride<
          FinanceCycleWorkspaceMutations,
          AsyncValue<void>,
          void,
          FutureOr<void>,
          (String, String)
        > {
  FinanceCycleWorkspaceMutationsFamily._()
    : super(
        retry: null,
        name: r'financeCycleWorkspaceMutationsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FinanceCycleWorkspaceMutationsProvider call(String farmId, String cycleId) =>
      FinanceCycleWorkspaceMutationsProvider._(
        argument: (farmId, cycleId),
        from: this,
      );

  @override
  String toString() => r'financeCycleWorkspaceMutationsProvider';
}

abstract class _$FinanceCycleWorkspaceMutations extends $AsyncNotifier<void> {
  late final _$args = ref.$arg as (String, String);
  String get farmId => _$args.$1;
  String get cycleId => _$args.$2;

  FutureOr<void> build(String farmId, String cycleId);
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
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}

@ProviderFor(FinanceCycleCreation)
final financeCycleCreationProvider = FinanceCycleCreationFamily._();

final class FinanceCycleCreationProvider
    extends
        $AsyncNotifierProvider<FinanceCycleCreation, EconomicsV2CycleCreated?> {
  FinanceCycleCreationProvider._({
    required FinanceCycleCreationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'financeCycleCreationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$financeCycleCreationHash();

  @override
  String toString() {
    return r'financeCycleCreationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FinanceCycleCreation create() => FinanceCycleCreation();

  @override
  bool operator ==(Object other) {
    return other is FinanceCycleCreationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$financeCycleCreationHash() =>
    r'65aa4483eb489e6ee150d64a2c9e8cbb092fd087';

final class FinanceCycleCreationFamily extends $Family
    with
        $ClassFamilyOverride<
          FinanceCycleCreation,
          AsyncValue<EconomicsV2CycleCreated?>,
          EconomicsV2CycleCreated?,
          FutureOr<EconomicsV2CycleCreated?>,
          String
        > {
  FinanceCycleCreationFamily._()
    : super(
        retry: null,
        name: r'financeCycleCreationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FinanceCycleCreationProvider call(String farmId) =>
      FinanceCycleCreationProvider._(argument: farmId, from: this);

  @override
  String toString() => r'financeCycleCreationProvider';
}

abstract class _$FinanceCycleCreation
    extends $AsyncNotifier<EconomicsV2CycleCreated?> {
  late final _$args = ref.$arg as String;
  String get farmId => _$args;

  FutureOr<EconomicsV2CycleCreated?> build(String farmId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<EconomicsV2CycleCreated?>,
              EconomicsV2CycleCreated?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<EconomicsV2CycleCreated?>,
                EconomicsV2CycleCreated?
              >,
              AsyncValue<EconomicsV2CycleCreated?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
