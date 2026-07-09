import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'miembro_granja_repository.dart';
import 'miembro_granja.dart';

part 'miembro_granja_provider.g.dart'; // ← esta línea es obligatoria
// ─── Lista de miembros (por granja) ──────────────────────────────────────────
// AsyncNotifier.family: un notifier independiente por granjaId.
// Usar AsyncNotifier en lugar de FutureProvider.family nos permite
// mutarlo (add/update/remove) y recargar sin invalidar desde afuera.
// ─── MembersNotifier ──────────────────────────────────────────────────────────
// AsyncNotifierProvider.family crea un notifier independiente por granjaId.
// La clase base correcta es FamilyAsyncNotifier<State, Arg>.
// Esto nos permite mutar la lista (add/update/remove) y recargar
// internamente sin necesidad de invalidar desde afuera.

@riverpod
class Members extends _$Members {
  MiembroGranjaRepository get _repo =>
      ref.read(miembroGranjaRepositoryProvider);

  @override
  Future<List<MiembroGranja>> build(String granjaId) => _repo.getMembers(granjaId);

  Future<void> addMember({
    required String email,
    required RolMiembro role,
  }) async {
    state = const AsyncLoading<List<MiembroGranja>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _repo.addMember(granjaId: granjaId, email: email, role: role);
      return _repo.getMembers(granjaId);
    });
  }

  Future<void> updateRole({
    required String memberId,
    required RolMiembro newRole,
  }) async {
    state = const AsyncLoading<List<MiembroGranja>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _repo.updateRole(memberId: memberId, newRole: newRole);
      return _repo.getMembers(granjaId);
    });
  }

  Future<void> removeMember(String memberId) async {
    state = const AsyncLoading<List<MiembroGranja>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _repo.removeMember(memberId);
      return _repo.getMembers(granjaId);
    });
  }
}