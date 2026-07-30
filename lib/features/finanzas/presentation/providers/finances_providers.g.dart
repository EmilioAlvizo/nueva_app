// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finances_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(financesRepository)
final financesRepositoryProvider = FinancesRepositoryProvider._();

final class FinancesRepositoryProvider
    extends
        $FunctionalProvider<
          FinancesRepository,
          FinancesRepository,
          FinancesRepository
        >
    with $Provider<FinancesRepository> {
  FinancesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'financesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financesRepositoryHash();

  @$internal
  @override
  $ProviderElement<FinancesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FinancesRepository create(Ref ref) {
    return financesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinancesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinancesRepository>(value),
    );
  }
}

String _$financesRepositoryHash() =>
    r'3eaff9357cb1673d8ec558f12181c91a50bad71c';

@ProviderFor(breakEvenPoints)
final breakEvenPointsProvider = BreakEvenPointsFamily._();

final class BreakEvenPointsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BreakEvenPoint>>,
          List<BreakEvenPoint>,
          FutureOr<List<BreakEvenPoint>>
        >
    with
        $FutureModifier<List<BreakEvenPoint>>,
        $FutureProvider<List<BreakEvenPoint>> {
  BreakEvenPointsProvider._({
    required BreakEvenPointsFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'breakEvenPointsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$breakEvenPointsHash();

  @override
  String toString() {
    return r'breakEvenPointsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<BreakEvenPoint>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<BreakEvenPoint>> create(Ref ref) {
    final argument = this.argument as String;
    return breakEvenPoints(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BreakEvenPointsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$breakEvenPointsHash() => r'387e34b604b34d22aee5d7f305dcadfba5c86349';

final class BreakEvenPointsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<BreakEvenPoint>>, String> {
  BreakEvenPointsFamily._()
    : super(
        retry: _noRetry,
        name: r'breakEvenPointsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BreakEvenPointsProvider call(String farmId) =>
      BreakEvenPointsProvider._(argument: farmId, from: this);

  @override
  String toString() => r'breakEvenPointsProvider';
}
