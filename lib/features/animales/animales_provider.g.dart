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

String _$conteosGruposHash() => r'76d7cd9ee00d0b2e17cf4efbf32e06bec3927b69';

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
          AsyncValue<List<AltaAnimales>>,
          List<AltaAnimales>,
          FutureOr<List<AltaAnimales>>
        >
    with
        $FutureModifier<List<AltaAnimales>>,
        $FutureProvider<List<AltaAnimales>> {
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
  $FutureProviderElement<List<AltaAnimales>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AltaAnimales>> create(Ref ref) {
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

String _$lotesDeGrupoHash() => r'f84373fa4818bb87d22dffeb5198691dcd60f7c8';

final class LotesDeGrupoFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AltaAnimales>>, String> {
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

@ProviderFor(altasByFarm)
final altasByFarmProvider = AltasByFarmFamily._();

final class AltasByFarmProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AltaAnimales>>,
          List<AltaAnimales>,
          FutureOr<List<AltaAnimales>>
        >
    with
        $FutureModifier<List<AltaAnimales>>,
        $FutureProvider<List<AltaAnimales>> {
  AltasByFarmProvider._({
    required AltasByFarmFamily super.from,
    required AltasQuery super.argument,
  }) : super(
         retry: null,
         name: r'altasByFarmProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$altasByFarmHash();

  @override
  String toString() {
    return r'altasByFarmProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AltaAnimales>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AltaAnimales>> create(Ref ref) {
    final argument = this.argument as AltasQuery;
    return altasByFarm(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AltasByFarmProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$altasByFarmHash() => r'1e80da80c51e019ca03b05fda9ddc0f20cc36910';

final class AltasByFarmFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AltaAnimales>>, AltasQuery> {
  AltasByFarmFamily._()
    : super(
        retry: null,
        name: r'altasByFarmProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AltasByFarmProvider call(AltasQuery query) =>
      AltasByFarmProvider._(argument: query, from: this);

  @override
  String toString() => r'altasByFarmProvider';
}

@ProviderFor(altaDistributions)
final altaDistributionsProvider = AltaDistributionsFamily._();

final class AltaDistributionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AltaDistribution>>,
          List<AltaDistribution>,
          FutureOr<List<AltaDistribution>>
        >
    with
        $FutureModifier<List<AltaDistribution>>,
        $FutureProvider<List<AltaDistribution>> {
  AltaDistributionsProvider._({
    required AltaDistributionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'altaDistributionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$altaDistributionsHash();

  @override
  String toString() {
    return r'altaDistributionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AltaDistribution>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AltaDistribution>> create(Ref ref) {
    final argument = this.argument as String;
    return altaDistributions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AltaDistributionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$altaDistributionsHash() => r'af09f9574646a627307ccf0c469719143e552383';

final class AltaDistributionsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AltaDistribution>>, String> {
  AltaDistributionsFamily._()
    : super(
        retry: null,
        name: r'altaDistributionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AltaDistributionsProvider call(String granjaId) =>
      AltaDistributionsProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'altaDistributionsProvider';
}

@ProviderFor(noGroupOverview)
final noGroupOverviewProvider = NoGroupOverviewFamily._();

final class NoGroupOverviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<NoGroupOverview>,
          NoGroupOverview,
          FutureOr<NoGroupOverview>
        >
    with $FutureModifier<NoGroupOverview>, $FutureProvider<NoGroupOverview> {
  NoGroupOverviewProvider._({
    required NoGroupOverviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'noGroupOverviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$noGroupOverviewHash();

  @override
  String toString() {
    return r'noGroupOverviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<NoGroupOverview> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<NoGroupOverview> create(Ref ref) {
    final argument = this.argument as String;
    return noGroupOverview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NoGroupOverviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$noGroupOverviewHash() => r'd1c35424cea93355bf7b04ffee10b1263860b046';

final class NoGroupOverviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<NoGroupOverview>, String> {
  NoGroupOverviewFamily._()
    : super(
        retry: null,
        name: r'noGroupOverviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NoGroupOverviewProvider call(String granjaId) =>
      NoGroupOverviewProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'noGroupOverviewProvider';
}

@ProviderFor(availableBracelets)
final availableBraceletsProvider = AvailableBraceletsFamily._();

final class AvailableBraceletsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<int>>,
          List<int>,
          FutureOr<List<int>>
        >
    with $FutureModifier<List<int>>, $FutureProvider<List<int>> {
  AvailableBraceletsProvider._({
    required AvailableBraceletsFamily super.from,
    required BraceletAvailabilityQuery super.argument,
  }) : super(
         retry: null,
         name: r'availableBraceletsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$availableBraceletsHash();

  @override
  String toString() {
    return r'availableBraceletsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<int>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<int>> create(Ref ref) {
    final argument = this.argument as BraceletAvailabilityQuery;
    return availableBracelets(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AvailableBraceletsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$availableBraceletsHash() =>
    r'59e373192e2ea11925a2206db7822cd83de549ee';

final class AvailableBraceletsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<int>>,
          BraceletAvailabilityQuery
        > {
  AvailableBraceletsFamily._()
    : super(
        retry: null,
        name: r'availableBraceletsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AvailableBraceletsProvider call(BraceletAvailabilityQuery query) =>
      AvailableBraceletsProvider._(argument: query, from: this);

  @override
  String toString() => r'availableBraceletsProvider';
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

@ProviderFor(bajasAnimales)
final bajasAnimalesProvider = BajasAnimalesFamily._();

final class BajasAnimalesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BajaAnimal>>,
          List<BajaAnimal>,
          FutureOr<List<BajaAnimal>>
        >
    with $FutureModifier<List<BajaAnimal>>, $FutureProvider<List<BajaAnimal>> {
  BajasAnimalesProvider._({
    required BajasAnimalesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'bajasAnimalesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bajasAnimalesHash();

  @override
  String toString() {
    return r'bajasAnimalesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<BajaAnimal>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<BajaAnimal>> create(Ref ref) {
    final argument = this.argument as String;
    return bajasAnimales(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BajasAnimalesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bajasAnimalesHash() => r'f6e431640576ba2d5bdb875a879ee13f58578f24';

final class BajasAnimalesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<BajaAnimal>>, String> {
  BajasAnimalesFamily._()
    : super(
        retry: null,
        name: r'bajasAnimalesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BajasAnimalesProvider call(String granjaId) =>
      BajasAnimalesProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'bajasAnimalesProvider';
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

@ProviderFor(razonesBaja)
final razonesBajaProvider = RazonesBajaFamily._();

final class RazonesBajaProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CatalogoItem>>,
          List<CatalogoItem>,
          FutureOr<List<CatalogoItem>>
        >
    with
        $FutureModifier<List<CatalogoItem>>,
        $FutureProvider<List<CatalogoItem>> {
  RazonesBajaProvider._({
    required RazonesBajaFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'razonesBajaProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$razonesBajaHash();

  @override
  String toString() {
    return r'razonesBajaProvider'
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
    return razonesBaja(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RazonesBajaProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$razonesBajaHash() => r'5c2f7f3de59d4e64ec9ec29c4248457d88851e10';

final class RazonesBajaFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<CatalogoItem>>, String> {
  RazonesBajaFamily._()
    : super(
        retry: null,
        name: r'razonesBajaProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RazonesBajaProvider call(String granjaId) =>
      RazonesBajaProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'razonesBajaProvider';
}
