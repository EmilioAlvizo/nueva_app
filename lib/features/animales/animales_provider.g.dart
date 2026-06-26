// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'animales_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(animalesRepository)
final animalesRepositoryProvider = AnimalesRepositoryProvider._();

final class AnimalesRepositoryProvider
    extends
        $FunctionalProvider<
          AnimalesRepository,
          AnimalesRepository,
          AnimalesRepository
        >
    with $Provider<AnimalesRepository> {
  AnimalesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'animalesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$animalesRepositoryHash();

  @$internal
  @override
  $ProviderElement<AnimalesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AnimalesRepository create(Ref ref) {
    return animalesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnimalesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnimalesRepository>(value),
    );
  }
}

String _$animalesRepositoryHash() =>
    r'3e902d469ff771752e378028aa6dca9e53a0ad34';

@ProviderFor(tiposAnimal)
final tiposAnimalProvider = TiposAnimalFamily._();

final class TiposAnimalProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TipoAnimal>>,
          List<TipoAnimal>,
          FutureOr<List<TipoAnimal>>
        >
    with $FutureModifier<List<TipoAnimal>>, $FutureProvider<List<TipoAnimal>> {
  TiposAnimalProvider._({
    required TiposAnimalFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tiposAnimalProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tiposAnimalHash();

  @override
  String toString() {
    return r'tiposAnimalProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TipoAnimal>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TipoAnimal>> create(Ref ref) {
    final argument = this.argument as String;
    return tiposAnimal(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TiposAnimalProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tiposAnimalHash() => r'cad7f25024fa188c361cafd0c4e4ab76cf1957ec';

final class TiposAnimalFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TipoAnimal>>, String> {
  TiposAnimalFamily._()
    : super(
        retry: null,
        name: r'tiposAnimalProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TiposAnimalProvider call(String granjaId) =>
      TiposAnimalProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'tiposAnimalProvider';
}

@ProviderFor(grupos)
final gruposProvider = GruposFamily._();

final class GruposProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Grupo>>,
          List<Grupo>,
          FutureOr<List<Grupo>>
        >
    with $FutureModifier<List<Grupo>>, $FutureProvider<List<Grupo>> {
  GruposProvider._({
    required GruposFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'gruposProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$gruposHash();

  @override
  String toString() {
    return r'gruposProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Grupo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Grupo>> create(Ref ref) {
    final argument = this.argument as String;
    return grupos(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GruposProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$gruposHash() => r'5b40022b89c77179e9ed6515d24805ff01d79cf4';

final class GruposFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Grupo>>, String> {
  GruposFamily._()
    : super(
        retry: null,
        name: r'gruposProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GruposProvider call(String granjaId) =>
      GruposProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'gruposProvider';
}

@ProviderFor(conteosGrupos)
final conteosGruposProvider = ConteosGruposFamily._();

final class ConteosGruposProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, GrupoConteo>>,
          Map<String, GrupoConteo>,
          FutureOr<Map<String, GrupoConteo>>
        >
    with
        $FutureModifier<Map<String, GrupoConteo>>,
        $FutureProvider<Map<String, GrupoConteo>> {
  ConteosGruposProvider._({
    required ConteosGruposFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'conteosGruposProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conteosGruposHash();

  @override
  String toString() {
    return r'conteosGruposProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, GrupoConteo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, GrupoConteo>> create(Ref ref) {
    final argument = this.argument as String;
    return conteosGrupos(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConteosGruposProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conteosGruposHash() => r'0a7eca93c633fe96ca24005c393ef1d870546d23';

final class ConteosGruposFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Map<String, GrupoConteo>>, String> {
  ConteosGruposFamily._()
    : super(
        retry: null,
        name: r'conteosGruposProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ConteosGruposProvider call(String granjaId) =>
      ConteosGruposProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'conteosGruposProvider';
}

@ProviderFor(lotesDeGrupo)
final lotesDeGrupoProvider = LotesDeGrupoFamily._();

final class LotesDeGrupoProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LoteEntrada>>,
          List<LoteEntrada>,
          FutureOr<List<LoteEntrada>>
        >
    with
        $FutureModifier<List<LoteEntrada>>,
        $FutureProvider<List<LoteEntrada>> {
  LotesDeGrupoProvider._({
    required LotesDeGrupoFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'lotesDeGrupoProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lotesDeGrupoHash();

  @override
  String toString() {
    return r'lotesDeGrupoProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<LoteEntrada>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LoteEntrada>> create(Ref ref) {
    final argument = this.argument as String;
    return lotesDeGrupo(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LotesDeGrupoProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lotesDeGrupoHash() => r'b8c747571c6bebb04ab0ff22ba18e1032dc375bf';

final class LotesDeGrupoFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<LoteEntrada>>, String> {
  LotesDeGrupoFamily._()
    : super(
        retry: null,
        name: r'lotesDeGrupoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LotesDeGrupoProvider call(String grupoId) =>
      LotesDeGrupoProvider._(argument: grupoId, from: this);

  @override
  String toString() => r'lotesDeGrupoProvider';
}

@ProviderFor(animales)
final animalesProvider = AnimalesFamily._();

final class AnimalesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Animal>>,
          List<Animal>,
          FutureOr<List<Animal>>
        >
    with $FutureModifier<List<Animal>>, $FutureProvider<List<Animal>> {
  AnimalesProvider._({
    required AnimalesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'animalesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$animalesHash();

  @override
  String toString() {
    return r'animalesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Animal>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Animal>> create(Ref ref) {
    final argument = this.argument as String;
    return animales(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AnimalesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$animalesHash() => r'ff38046cfe14b51051ff0621e3f8f6eb5a00d078';

final class AnimalesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Animal>>, String> {
  AnimalesFamily._()
    : super(
        retry: null,
        name: r'animalesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AnimalesProvider call(String granjaId) =>
      AnimalesProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'animalesProvider';
}

@ProviderFor(bajasEjemplares)
final bajasEjemplaresProvider = BajasEjemplaresFamily._();

final class BajasEjemplaresProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BajaEjemplar>>,
          List<BajaEjemplar>,
          FutureOr<List<BajaEjemplar>>
        >
    with
        $FutureModifier<List<BajaEjemplar>>,
        $FutureProvider<List<BajaEjemplar>> {
  BajasEjemplaresProvider._({
    required BajasEjemplaresFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'bajasEjemplaresProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bajasEjemplaresHash();

  @override
  String toString() {
    return r'bajasEjemplaresProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<BajaEjemplar>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<BajaEjemplar>> create(Ref ref) {
    final argument = this.argument as String;
    return bajasEjemplares(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BajasEjemplaresProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bajasEjemplaresHash() => r'8becd152083252bb2c653f4a9b72cb1c222536ae';

final class BajasEjemplaresFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<BajaEjemplar>>, String> {
  BajasEjemplaresFamily._()
    : super(
        retry: null,
        name: r'bajasEjemplaresProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BajasEjemplaresProvider call(String granjaId) =>
      BajasEjemplaresProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'bajasEjemplaresProvider';
}

@ProviderFor(propositos)
final propositosProvider = PropositosFamily._();

final class PropositosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CatalogoItem>>,
          List<CatalogoItem>,
          FutureOr<List<CatalogoItem>>
        >
    with
        $FutureModifier<List<CatalogoItem>>,
        $FutureProvider<List<CatalogoItem>> {
  PropositosProvider._({
    required PropositosFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'propositosProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$propositosHash();

  @override
  String toString() {
    return r'propositosProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<CatalogoItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CatalogoItem>> create(Ref ref) {
    final argument = this.argument as String;
    return propositos(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PropositosProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$propositosHash() => r'723624cb905c56f8c1e53722578ebe98fd1d549c';

final class PropositosFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<CatalogoItem>>, String> {
  PropositosFamily._()
    : super(
        retry: null,
        name: r'propositosProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PropositosProvider call(String granjaId) =>
      PropositosProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'propositosProvider';
}

@ProviderFor(tiposAdquisicion)
final tiposAdquisicionProvider = TiposAdquisicionFamily._();

final class TiposAdquisicionProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CatalogoItem>>,
          List<CatalogoItem>,
          FutureOr<List<CatalogoItem>>
        >
    with
        $FutureModifier<List<CatalogoItem>>,
        $FutureProvider<List<CatalogoItem>> {
  TiposAdquisicionProvider._({
    required TiposAdquisicionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tiposAdquisicionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tiposAdquisicionHash();

  @override
  String toString() {
    return r'tiposAdquisicionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<CatalogoItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CatalogoItem>> create(Ref ref) {
    final argument = this.argument as String;
    return tiposAdquisicion(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TiposAdquisicionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tiposAdquisicionHash() => r'efcfb26712f56d6f5bf85b21c899b1741d9c0300';

final class TiposAdquisicionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<CatalogoItem>>, String> {
  TiposAdquisicionFamily._()
    : super(
        retry: null,
        name: r'tiposAdquisicionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TiposAdquisicionProvider call(String granjaId) =>
      TiposAdquisicionProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'tiposAdquisicionProvider';
}
