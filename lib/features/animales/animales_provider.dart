// ─── lib/features/animales/animales_provider.dart ─────
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'animales_repository.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import '../model/grupo/grupo.dart';
import '../model/altaAnimales/altaAnimales.dart';
import '../model/animal/animal.dart';
import '../model/bajaAnimal/baja_animal.dart';
import '../model/catalogoItem/catalogo_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;

part 'animales_provider.g.dart';

// ── Repositorio singleton ─────────────────────────────────────────────────────
@Riverpod(keepAlive: true)
AnimalesRepository animalesRepository(Ref ref) =>
    AnimalesRepository(Supabase.instance.client);

// ── Tipos de animal ───────────────────────────────────────────────────────────
@riverpod
Future<List<TipoAnimal>> tiposAnimal(Ref ref, String granjaId) =>
    ref.watch(animalesRepositoryProvider).getTipos(granjaId);

// ── Grupos ────────────────────────────────────────────────────────────────────
@riverpod
Future<List<Grupo>> grupos(Ref ref, String granjaId) =>
    ref.watch(animalesRepositoryProvider).getGrupos(granjaId);

// ── Conteos por grupo (vivos / muertes / total) ───────────────────────────────
@riverpod
Future<Map<String, GrupoConteo>> conteosGrupos(Ref ref, String granjaId) async {
  final repo = ref.watch(animalesRepositoryProvider);
  final raw = await repo.getConteosGrupos(granjaId);
  return raw.map(
    (k, v) => MapEntry(
      k,
      GrupoConteo(vivos: v.vivos, muertes: v.muertes, total: v.total),
    ),
  );
}

class GrupoConteo {
  final int vivos;
  final int muertes;
  final int total;
  const GrupoConteo({
    required this.vivos,
    required this.muertes,
    required this.total,
  });
}

class AltasQuery {
  const AltasQuery({required this.granjaId, this.grupoId});

  final String granjaId;
  final String? grupoId;

  @override
  bool operator ==(Object other) {
    return other is AltasQuery &&
        other.granjaId == granjaId &&
        other.grupoId == grupoId;
  }

  @override
  int get hashCode => Object.hash(granjaId, grupoId);
}

class BraceletAvailabilityQuery {
  const BraceletAvailabilityQuery({
    required this.granjaId,
    required this.tipoAnimalId,
  });

  final String granjaId;
  final String tipoAnimalId;

  @override
  bool operator ==(Object other) {
    return other is BraceletAvailabilityQuery &&
        other.granjaId == granjaId &&
        other.tipoAnimalId == tipoAnimalId;
  }

  @override
  int get hashCode => Object.hash(granjaId, tipoAnimalId);
}

// ── Lotes de un grupo (carga lazy al expandir) ────────────────────────────────
@riverpod
Future<List<AltaAnimales>> lotesDeGrupo(Ref ref, String grupoId) =>
    ref.watch(animalesRepositoryProvider).vistaAltasAnimales(grupoId);

@riverpod
Future<List<AltaAnimales>> altasByFarm(Ref ref, AltasQuery query) {
  return ref
      .watch(animalesRepositoryProvider)
      .getAltas(query.granjaId, grupoId: query.grupoId);
}

@riverpod
Future<NoGroupOverview> noGroupOverview(Ref ref, String granjaId) {
  return ref.watch(animalesRepositoryProvider).getNoGroupOverview(granjaId);
}

@riverpod
Future<List<int>> availableBracelets(Ref ref, BraceletAvailabilityQuery query) {
  return ref
      .watch(animalesRepositoryProvider)
      .getAvailableBracelets(query.granjaId, query.tipoAnimalId);
}

// ── Animales individuales (tab "Animales") ────────────────────────────────
@riverpod
Future<List<Animal>> animales(Ref ref, String granjaId) =>
    ref.watch(animalesRepositoryProvider).getAnimales(granjaId);

// ── Bajas de ejemplares (tab "Bajas") ─────────────────────────────────────────
@riverpod
Future<List<BajaAnimal>> bajasAnimales(Ref ref, String granjaId) =>
    ref.watch(animalesRepositoryProvider).getBajasAnimales(granjaId);

// ── Catálogos para el formulario de ejemplar ──────────────────────────────────
@riverpod
Future<List<CatalogoItem>> propositos(Ref ref, String granjaId) =>
    ref.watch(animalesRepositoryProvider).getPropositos(granjaId);

@riverpod
Future<List<CatalogoItem>> tiposAdquisicion(Ref ref, String granjaId) =>
    ref.watch(animalesRepositoryProvider).getTiposAdquisicion(granjaId);

@riverpod
Future<List<CatalogoItem>> razonesBaja(Ref ref, String granjaId) =>
    ref.watch(animalesRepositoryProvider).getRazonesBaja(granjaId);

void invalidateAnimalesInventoryMutationProviders(
  WidgetRef ref,
  String granjaId,
) {
  ref.invalidate(bajasAnimalesProvider(granjaId));
  ref.invalidate(animalesProvider(granjaId));
  ref.invalidate(conteosGruposProvider(granjaId));
  ref.invalidate(noGroupOverviewProvider(granjaId));
  ref.invalidate(lotesDeGrupoProvider);
  ref.invalidate(altasByFarmProvider);
}
