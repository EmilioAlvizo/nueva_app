// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'miembro_granja_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Members)
final membersProvider = MembersFamily._();

final class MembersProvider
    extends $AsyncNotifierProvider<Members, List<MiembroGranja>> {
  MembersProvider._({
    required MembersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'membersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$membersHash();

  @override
  String toString() {
    return r'membersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  Members create() => Members();

  @override
  bool operator ==(Object other) {
    return other is MembersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$membersHash() => r'bfe21cede25d83185f93f4e505098d1f787b2299';

final class MembersFamily extends $Family
    with
        $ClassFamilyOverride<
          Members,
          AsyncValue<List<MiembroGranja>>,
          List<MiembroGranja>,
          FutureOr<List<MiembroGranja>>,
          String
        > {
  MembersFamily._()
    : super(
        retry: null,
        name: r'membersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MembersProvider call(String granjaId) =>
      MembersProvider._(argument: granjaId, from: this);

  @override
  String toString() => r'membersProvider';
}

abstract class _$Members extends $AsyncNotifier<List<MiembroGranja>> {
  late final _$args = ref.$arg as String;
  String get granjaId => _$args;

  FutureOr<List<MiembroGranja>> build(String granjaId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<MiembroGranja>>, List<MiembroGranja>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<MiembroGranja>>, List<MiembroGranja>>,
              AsyncValue<List<MiembroGranja>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
