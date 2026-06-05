// lib/features/auth/domain/auth_failure.dart
/// Typed failures instead of raw strings — keeps UI decoupled from Supabase.
enum AuthFailure {
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  networkError,
  unknown;

  String get message => switch (this) {
        AuthFailure.invalidCredentials  => 'Correo o contraseña incorrectos.',
        AuthFailure.emailAlreadyInUse   => 'Este correo ya está registrado.',
        AuthFailure.weakPassword        => 'La contraseña debe tener al menos 6 caracteres.',
        AuthFailure.networkError        => 'Sin conexión. Revisa tu internet.',
        AuthFailure.unknown             => 'Ocurrió un error inesperado.',
      };

  static AuthFailure fromException(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials') ||
        msg.contains('wrong password') ||
        msg.contains('email not confirmed')) {
      return AuthFailure.invalidCredentials;
    }
    if (msg.contains('user already registered') ||
        msg.contains('already exists') ||
        msg.contains('email_exists') ||
        msg.contains('already been registered') ||
        msg.contains('duplicate')) {
      return AuthFailure.emailAlreadyInUse;
    }
    if (msg.contains('password should be at least') ||
        msg.contains('weak_password')) {
      return AuthFailure.weakPassword;
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection')) {
      return AuthFailure.networkError;
    }
    // Expose raw error in debug to catch new Supabase error strings quickly
    // ignore: avoid_print
    print('[AuthFailure] Unhandled: $e');
    return AuthFailure.unknown;
  }
}