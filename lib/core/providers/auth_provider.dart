import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

// ─── Service provider ─────────────────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ─── Current user (live stream) ───────────────────────────────────────────────
final currentUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges.map(
        (state) => state.session?.user,
      );
});

// ─── Auth state ───────────────────────────────────────────────────────────────
enum AuthStatus { idle, loading, success, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? successMessage;

  const AuthState({
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.successMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? successMessage,
  }) =>
      AuthState(
        status: status ?? this.status,
        errorMessage: errorMessage,
        successMessage: successMessage,
      );

  bool get isLoading => status == AuthStatus.loading;
  bool get hasError  => status == AuthStatus.error;
}

// ─── Login notifier (Notifier API) ────────────────────────────────────────────
class LoginNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final res = await ref
          .read(authServiceProvider)
          .signIn(email: email, password: password);
      if (res.user != null) {
        state = state.copyWith(status: AuthStatus.success);
        return true;
      }
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'No se pudo iniciar sesión.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: AuthService.parseError(e),
      );
      return false;
    }
  }

  void reset() => state = const AuthState();
}

final loginProvider =
    NotifierProvider<LoginNotifier, AuthState>(LoginNotifier.new);

// ─── Register notifier (Notifier API) ────────────────────────────────────────
class RegisterNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<bool> signUp({
    required String email,
    required String password,
    required String nombre,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final res = await ref.read(authServiceProvider).signUp(
            email: email,
            password: password,
            nombre: nombre,
          );
      if (res.user != null) {
        if (res.session != null) {
          // Email confirmation disabled → auto-confirmed, go to home
          state = state.copyWith(status: AuthStatus.success);
          return true;
        } else {
          // Email confirmation required → stay, show message
          state = state.copyWith(
            status: AuthStatus.success,
            successMessage: 'Cuenta creada ✓  Revisa tu correo para confirmarla.',
          );
          return false;
        }
      }
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'No se pudo crear la cuenta.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: AuthService.parseError(e),
      );
      return false;
    }
  }

  void reset() => state = const AuthState();
}

final registerProvider =
    NotifierProvider<RegisterNotifier, AuthState>(RegisterNotifier.new);