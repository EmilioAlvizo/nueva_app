// lib/features/auth/presentation/providers/auth_session_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../data/auth_repository.dart';

/// Streams the Supabase auth state — the router listens to this to redirect.
/// This is the single source of truth for "is the user logged in?".
final authSessionProvider = StreamProvider<sb.Session?>((ref) {
  return ref
      .watch(authRepositoryProvider)
      .authStateChanges
      .map((state) => state.session);
});