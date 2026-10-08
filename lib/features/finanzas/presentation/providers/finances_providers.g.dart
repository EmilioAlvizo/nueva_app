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

@ProviderFor(financeExpenses)
final financeExpensesProvider = FinanceExpensesFamily._();

final class FinanceExpensesProvider
    extends
        $FunctionalProvider<
          AsyncValue<FinanceExpensesSnapshot>,
          FinanceExpensesSnapshot,
          FutureOr<FinanceExpensesSnapshot>
        >
    with
        $FutureModifier<FinanceExpensesSnapshot>,
        $FutureProvider<FinanceExpensesSnapshot> {
  FinanceExpensesProvider._({
    required FinanceExpensesFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'financeExpensesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$financeExpensesHash();

  @override
  String toString() {
    return r'financeExpensesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<FinanceExpensesSnapshot> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FinanceExpensesSnapshot> create(Ref ref) {
    final argument = this.argument as String;
    return financeExpenses(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FinanceExpensesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$financeExpensesHash() => r'b15ab46c03e8d77c30fa265a44d56472a2fa865f';

final class FinanceExpensesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<FinanceExpensesSnapshot>, String> {
  FinanceExpensesFamily._()
    : super(
        retry: _noRetry,
        name: r'financeExpensesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FinanceExpensesProvider call(String farmId) =>
      FinanceExpensesProvider._(argument: farmId, from: this);

  @override
  String toString() => r'financeExpensesProvider';
}

@ProviderFor(FinanceExpenseMutation)
final financeExpenseMutationProvider = FinanceExpenseMutationFamily._();

final class FinanceExpenseMutationProvider
    extends $AsyncNotifierProvider<FinanceExpenseMutation, void> {
  FinanceExpenseMutationProvider._({
    required FinanceExpenseMutationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'financeExpenseMutationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$financeExpenseMutationHash();

  @override
  String toString() {
    return r'financeExpenseMutationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FinanceExpenseMutation create() => FinanceExpenseMutation();

  @override
  bool operator ==(Object other) {
    return other is FinanceExpenseMutationProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$financeExpenseMutationHash() =>
    r'94dbcfe19155600624214b83fdfb0787d61f7456';

final class FinanceExpenseMutationFamily extends $Family
    with
        $ClassFamilyOverride<
          FinanceExpenseMutation,
          AsyncValue<void>,
          void,
          FutureOr<void>,
          String
        > {
  FinanceExpenseMutationFamily._()
    : super(
        retry: null,
        name: r'financeExpenseMutationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FinanceExpenseMutationProvider call(String farmId) =>
      FinanceExpenseMutationProvider._(argument: farmId, from: this);

  @override
  String toString() => r'financeExpenseMutationProvider';
}

abstract class _$FinanceExpenseMutation extends $AsyncNotifier<void> {
  late final _$args = ref.$arg as String;
  String get farmId => _$args;

  FutureOr<void> build(String farmId);
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
    return element.handleCreate(ref, () => build(_$args));
  }
}
