// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'huevo_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(recolecciones)
final recoleccionesProvider = RecoleccionesFamily._();

final class RecoleccionesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RecoleccionHuevo>>,
          List<RecoleccionHuevo>,
          FutureOr<List<RecoleccionHuevo>>
        >
    with
        $FutureModifier<List<RecoleccionHuevo>>,
        $FutureProvider<List<RecoleccionHuevo>> {
  RecoleccionesProvider._({
    required RecoleccionesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'recoleccionesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recoleccionesHash();

  @override
  String toString() {
    return r'recoleccionesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<RecoleccionHuevo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RecoleccionHuevo>> create(Ref ref) {
    final argument = this.argument as String;
    return recolecciones(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RecoleccionesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recoleccionesHash() => r'abc84ceaba5a635a21af5ac68f122fe4c963c4de';

final class RecoleccionesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<RecoleccionHuevo>>, String> {
  RecoleccionesFamily._()
    : super(
        retry: null,
        name: r'recoleccionesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RecoleccionesProvider call(String granjaId) =>
      RecoleccionesProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'recoleccionesProvider';
}

@ProviderFor(reducciones)
final reduccionesProvider = ReduccionesFamily._();

final class ReduccionesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ReduccionHuevo>>,
          List<ReduccionHuevo>,
          FutureOr<List<ReduccionHuevo>>
        >
    with
        $FutureModifier<List<ReduccionHuevo>>,
        $FutureProvider<List<ReduccionHuevo>> {
  ReduccionesProvider._({
    required ReduccionesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'reduccionesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reduccionesHash();

  @override
  String toString() {
    return r'reduccionesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ReduccionHuevo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ReduccionHuevo>> create(Ref ref) {
    final argument = this.argument as String;
    return reducciones(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReduccionesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reduccionesHash() => r'e04ca7cce0da8ab13de15679ce1985c9e4c5f2c0';

final class ReduccionesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ReduccionHuevo>>, String> {
  ReduccionesFamily._()
    : super(
        retry: null,
        name: r'reduccionesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReduccionesProvider call(String granjaId) =>
      ReduccionesProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'reduccionesProvider';
}

@ProviderFor(movimientosHuevo)
final movimientosHuevoProvider = MovimientosHuevoFamily._();

final class MovimientosHuevoProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MovHuevo>>,
          List<MovHuevo>,
          FutureOr<List<MovHuevo>>
        >
    with $FutureModifier<List<MovHuevo>>, $FutureProvider<List<MovHuevo>> {
  MovimientosHuevoProvider._({
    required MovimientosHuevoFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'movimientosHuevoProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movimientosHuevoHash();

  @override
  String toString() {
    return r'movimientosHuevoProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MovHuevo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MovHuevo>> create(Ref ref) {
    final argument = this.argument as String;
    return movimientosHuevo(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MovimientosHuevoProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movimientosHuevoHash() => r'201af7d41e415eb268cc7afb5fd8a0b4e9e6e10e';

final class MovimientosHuevoFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<MovHuevo>>, String> {
  MovimientosHuevoFamily._()
    : super(
        retry: null,
        name: r'movimientosHuevoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MovimientosHuevoProvider call(String granjaId) =>
      MovimientosHuevoProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'movimientosHuevoProvider';
}

@ProviderFor(huevoStats)
final huevoStatsProvider = HuevoStatsFamily._();

final class HuevoStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<HuevoStats>,
          HuevoStats,
          FutureOr<HuevoStats>
        >
    with $FutureModifier<HuevoStats>, $FutureProvider<HuevoStats> {
  HuevoStatsProvider._({
    required HuevoStatsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'huevoStatsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$huevoStatsHash();

  @override
  String toString() {
    return r'huevoStatsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<HuevoStats> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<HuevoStats> create(Ref ref) {
    final argument = this.argument as String;
    return huevoStats(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HuevoStatsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$huevoStatsHash() => r'7a4ec6d3a546e2d4636b750edd4d1321876c91ba';

final class HuevoStatsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<HuevoStats>, String> {
  HuevoStatsFamily._()
    : super(
        retry: null,
        name: r'huevoStatsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HuevoStatsProvider call(String granjaId) =>
      HuevoStatsProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'huevoStatsProvider';
}

@ProviderFor(razonesReduccion)
final razonesReduccionProvider = RazonesReduccionProvider._();

final class RazonesReduccionProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CatItemHuevo>>,
          List<CatItemHuevo>,
          FutureOr<List<CatItemHuevo>>
        >
    with
        $FutureModifier<List<CatItemHuevo>>,
        $FutureProvider<List<CatItemHuevo>> {
  RazonesReduccionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'razonesReduccionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$razonesReduccionHash();

  @$internal
  @override
  $FutureProviderElement<List<CatItemHuevo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CatItemHuevo>> create(Ref ref) {
    return razonesReduccion(ref);
  }
}

String _$razonesReduccionHash() => r'9d5d31021bce88ed43e235d1800973dbdbb466f9';
