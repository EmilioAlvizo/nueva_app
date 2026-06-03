import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class AuthService {
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      supabase.auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String nombre,
  }) =>
      supabase.auth.signUp(
        email: email,
        password: password,
        data: {'nombre': nombre},
      );

  Future<void> signOut() => supabase.auth.signOut();

  User? get currentUser => supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  /// Translates Supabase exceptions to Spanish user-facing messages.
  static String parseError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials') ||
        msg.contains('email not confirmed') ||
        msg.contains('wrong password')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already exists') ||
        msg.contains('email_exists') ||
        msg.contains('already been registered')) {
      return 'Este correo ya está registrado.';
    }
    if (msg.contains('password should be at least') ||
        msg.contains('weak_password')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (msg.contains('network') || msg.contains('socket') ||
        msg.contains('connection')) {
      return 'Sin conexión. Revisa tu internet.';
    }
    if (msg.contains('email') && msg.contains('invalid')) {
      return 'Ingresa un correo válido.';
    }
    // Surface the raw message in debug so we can see exactly what Supabase returns
    // ignore: avoid_print
    print('[AuthService] Unhandled error: $e');
    return 'Error: ${e.toString()}';
  }
}