// lib/features/auth/data/auth_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';

/// Pure data layer — all Supabase calls live here.
class AuthRepository {
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

  /// Emits every time the auth state changes (sign in, sign out, token refresh…)
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(),
);