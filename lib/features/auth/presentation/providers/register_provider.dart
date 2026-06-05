// lib/features/auth/presentation/providers/register_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_failure.dart';

// ─── State ────────────────────────────────────────────────────────────────────
sealed class RegisterState {
  const RegisterState();
}

class RegisterIdle            extends RegisterState { const RegisterIdle(); }
class RegisterLoading         extends RegisterState { const RegisterLoading(); }
/// Session != null → auto-confirmed, navigate to home.
class RegisterSuccessAutoConfirm extends RegisterState { const RegisterSuccessAutoConfirm(); }
/// Session == null → email confirmation required, stay on screen.
class RegisterSuccessNeedsConfirm extends RegisterState { const RegisterSuccessNeedsConfirm(); }
class RegisterError           extends RegisterState {
  final String message;
  const RegisterError(this.message);
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class RegisterNotifier extends Notifier<RegisterState> {
  @override
  RegisterState build() => const RegisterIdle();

  Future<void> signUp({
    required String email,
    required String password,
    required String nombre,
  }) async {
    state = const RegisterLoading();
    try {
      final res = await ref.read(authRepositoryProvider).signUp(
            email: email,
            password: password,
            nombre: nombre,
          );

      if (res.user == null) {
        state = const RegisterError('No se pudo crear la cuenta.');
        return;
      }

      state = res.session != null
          ? const RegisterSuccessAutoConfirm()
          : const RegisterSuccessNeedsConfirm();
    } catch (e) {
      state = RegisterError(AuthFailure.fromException(e).message);
    }
  }

  void reset() => state = const RegisterIdle();
}

final registerProvider =
    NotifierProvider.autoDispose<RegisterNotifier, RegisterState>(
        RegisterNotifier.new);