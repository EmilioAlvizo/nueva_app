// lib/features/auth/presentation/providers/login_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_failure.dart';

// ─── State ────────────────────────────────────────────────────────────────────
sealed class LoginState {
  const LoginState();
}

class LoginIdle    extends LoginState { const LoginIdle(); }
class LoginLoading extends LoginState { const LoginLoading(); }
class LoginSuccess extends LoginState { const LoginSuccess(); }
class LoginError   extends LoginState {
  final String message;
  const LoginError(this.message);
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class LoginNotifier extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginIdle();

  Future<void> signIn({required String email, required String password}) async {
    state = const LoginLoading();
    try {
      final res = await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);

      state = res.user != null
          ? const LoginSuccess()
          : const LoginError('No se pudo iniciar sesión.');
    } catch (e) {
      state = LoginError(AuthFailure.fromException(e).message);
    }
  }

  void reset() => state = const LoginIdle();
}

final loginProvider =
    NotifierProvider.autoDispose<LoginNotifier, LoginState>(LoginNotifier.new);