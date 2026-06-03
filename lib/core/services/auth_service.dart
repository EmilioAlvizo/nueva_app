import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class AuthService {
  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign up with email, password and display name
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String nombre,
  }) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'nombre': nombre},
    );
    return response;
  }

  // Sign out
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  // Current user
  User? get currentUser => supabase.auth.currentUser;

  // Auth state stream
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;
}