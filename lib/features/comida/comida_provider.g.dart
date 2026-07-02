// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comida_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(lotesAlimento)
final lotesAlimentoProvider = LotesAlimentoFamily._();

final class LotesAlimentoProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LoteAlimento>>,
          List<LoteAlimento>,
          FutureOr<List<LoteAlimento>>
        >
    with
        $FutureModifier<List<LoteAlimento>>,
        $FutureProvider<List<LoteAlimento>> {
  LotesAlimentoProvider._({
    required LotesAlimentoFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'lotesAlimentoProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lotesAlimentoHash();

  @override
  String toString() {
    return r'lotesAlimentoProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<LoteAlimento>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LoteAlimento>> create(Ref ref) {
    final argument = this.argument as String;
    return lotesAlimento(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LotesAlimentoProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lotesAlimentoHash() => r'5dc8b435269901bf4146e0dc993467f5066970f0';

final class LotesAlimentoFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<LoteAlimento>>, String> {
  LotesAlimentoFamily._()
    : super(
        retry: null,
        name: r'lotesAlimentoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LotesAlimentoProvider call(String granjaId) =>
      LotesAlimentoProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'lotesAlimentoProvider';
}

@ProviderFor(periodosAlimento)
final periodosAlimentoProvider = PeriodosAlimentoFamily._();

final class PeriodosAlimentoProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PeriodoAlimento>>,
          List<PeriodoAlimento>,
          FutureOr<List<PeriodoAlimento>>
        >
    with
        $FutureModifier<List<PeriodoAlimento>>,
        $FutureProvider<List<PeriodoAlimento>> {
  PeriodosAlimentoProvider._({
    required PeriodosAlimentoFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'periodosAlimentoProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$periodosAlimentoHash();

  @override
  String toString() {
    return r'periodosAlimentoProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<PeriodoAlimento>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PeriodoAlimento>> create(Ref ref) {
    final argument = this.argument as String;
    return periodosAlimento(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PeriodosAlimentoProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$periodosAlimentoHash() => r'd1c3b1fce05b2b104c87f7f6a762c388f35b7165';

final class PeriodosAlimentoFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<PeriodoAlimento>>, String> {
  PeriodosAlimentoFamily._()
    : super(
        retry: null,
        name: r'periodosAlimentoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PeriodosAlimentoProvider call(String granjaId) =>
      PeriodosAlimentoProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'periodosAlimentoProvider';
}

@ProviderFor(comidaStats)
final comidaStatsProvider = ComidaStatsFamily._();

final class ComidaStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ComidaStats>,
          ComidaStats,
          FutureOr<ComidaStats>
        >
    with $FutureModifier<ComidaStats>, $FutureProvider<ComidaStats> {
  ComidaStatsProvider._({
    required ComidaStatsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'comidaStatsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$comidaStatsHash();

  @override
  String toString() {
    return r'comidaStatsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ComidaStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ComidaStats> create(Ref ref) {
    final argument = this.argument as String;
    return comidaStats(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ComidaStatsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$comidaStatsHash() => r'0b13ede51ecb27a4002264c9e473cea9b50fc635';

final class ComidaStatsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ComidaStats>, String> {
  ComidaStatsFamily._()
    : super(
        retry: null,
        name: r'comidaStatsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ComidaStatsProvider call(String granjaId) =>
      ComidaStatsProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'comidaStatsProvider';
}
