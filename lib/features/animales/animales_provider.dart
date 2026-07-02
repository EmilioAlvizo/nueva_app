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
Future<Map<String, GrupoConteo>> conteosGrupos(
  Ref ref,
  String granjaId,
) async {
  final repo = ref.watch(animalesRepositoryProvider);
  final raw = await repo.getConteosGrupos(granjaId);
  return raw.map(
    (k, v) => MapEntry(k, GrupoConteo(vivos: v.vivos, muertes: v.muertes, total: v.total)),
  );
}

class GrupoConteo {
  final int vivos;
  final int muertes;
  final int total;
  const GrupoConteo({required this.vivos, required this.muertes, required this.total});
}

// ── Lotes de un grupo (carga lazy al expandir) ────────────────────────────────
@riverpod
Future<List<AltaAnimales>> lotesDeGrupo(Ref ref, String grupoId) =>
    ref.watch(animalesRepositoryProvider).vistaAltasAnimales(grupoId);

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