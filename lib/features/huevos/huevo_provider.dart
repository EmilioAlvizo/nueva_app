// lib/features/huevos/presentation/huevo_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'huevo_repository.dart';
import 'huevo_models.dart';

part 'huevo_provider.g.dart';

// ── Recolecciones ─────────────────────────────────────────────────────────────
@riverpod
Future<List<RecoleccionHuevo>> recolecciones(
  Ref ref,
  String granjaId,
) =>
    ref.watch(huevoRepositoryProvider).getRecolecciones(granjaId);

// ── Reducciones ───────────────────────────────────────────────────────────────
@riverpod
Future<List<ReduccionHuevo>> reducciones(
  Ref ref,
  String granjaId,
) =>
    ref.watch(huevoRepositoryProvider).getReducciones(granjaId);

// ── Lista combinada y ordenada por fecha desc ─────────────────────────────────
@riverpod
Future<List<MovHuevo>> movimientosHuevo(
  Ref ref,
  String granjaId,
) async {
  final recs = await ref.watch(recoleccionesProvider(granjaId).future);
  final reds = await ref.watch(reduccionesProvider(granjaId).future);

  final movs = [
    ...recs.map(MovHuevo.deRecoleccion),
    ...reds.map(MovHuevo.deReduccion),
  ]..sort((a, b) => b.fecha.compareTo(a.fecha));

  return movs;
}

// ── Stats totales ─────────────────────────────────────────────────────────────
@riverpod
Future<HuevoStats> huevoStats(
  Ref ref,
  String granjaId,
) async {
  final recs = await ref.watch(recoleccionesProvider(granjaId).future);
  final reds = await ref.watch(reduccionesProvider(granjaId).future);

  final totalBuenos = recs.fold<int>(0, (s, r) => s + r.huevosBuenos);
  final totalRotos = recs.fold<int>(0, (s, r) => s + r.huevosRotos);

  double ingreso = 0;
  int ventas = 0;
  final Map<String, int> porRazon = {};

  for (final red in reds) {
    porRazon[red.razonNombre] = (porRazon[red.razonNombre] ?? 0) + red.cantidad;
    if (red.importe != null) {
      ingreso += red.importe!;
      ventas += red.cantidad;
    }
  }

  return HuevoStats(
    totalRecolectados: totalBuenos + totalRotos,
    totalBuenos: totalBuenos,
    totalRotos: totalRotos,
    totalIngreso: ingreso,
    totalVentas: ventas,
    porRazon: porRazon,
  );
}

// ── Razones de reducción (catálogo) ──────────────────────────────────────────
@riverpod
Future<List<CatItemHuevo>> razonesReduccion(Ref ref) =>
    ref.watch(huevoRepositoryProvider).getRazonesReduccion();