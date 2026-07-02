// lib/features/comida/presentation/comida_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'comida_repository.dart';
import 'comida_models.dart';

part 'comida_provider.g.dart';

// ── Lotes de alimento ─────────────────────────────────────────────────────────
@riverpod
Future<List<LoteAlimento>> lotesAlimento(Ref ref, String granjaId) =>
    ref.watch(comidaRepositoryProvider).getLotes(granjaId);

// ── Periodos de alimento ──────────────────────────────────────────────────────
@riverpod
Future<List<PeriodoAlimento>> periodosAlimento(Ref ref, String granjaId) =>
    ref.watch(comidaRepositoryProvider).getPeriodos(granjaId);

// ── Stats totales ─────────────────────────────────────────────────────────────
@riverpod
Future<ComidaStats> comidaStats(Ref ref, String granjaId) async {
  final periodos = await ref.watch(periodosAlimentoProvider(granjaId).future);

  final totalKg =
      periodos.fold<double>(0, (s, p) => s + p.kgConsumidos);
  final totalEgreso =
      periodos.fold<double>(0, (s, p) => s + p.egresoCalculado);

  return ComidaStats(totalKg: totalKg, totalEgreso: totalEgreso);
}