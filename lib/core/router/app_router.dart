// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_session_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/home_screen.dart';

// ─── Route names (constants → no magic strings) ───────────────────────────────
abstract final class AppRoutes {
  static const login    = '/login';
  static const register = '/register';
  static const home     = '/';
}

// ─── Router provider ──────────────────────────────────────────────────────────
// The router is created once but depends on the auth stream — go_router's
// `refreshListenable` triggers a re-evaluation of `redirect` every time the
// auth state changes (login, logout, token refresh…).
final appRouterProvider = Provider<GoRouter>((ref) {
  // Convert the Stream<Session?> into a Listenable that GoRouter understands.
  final authNotifier = _AuthStateListenable(ref);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final sessionAsync = ref.read(authSessionProvider);

      // While the stream hasn't emitted yet, don't redirect.
      if (sessionAsync.isLoading) return null;

      final hasSession = sessionAsync.value != null;
      final onAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      if (!hasSession && !onAuthRoute) return AppRoutes.login;
      if (hasSession  && onAuthRoute)  return AppRoutes.home;
      return null; // no redirect needed
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
    ],
    // Clean error page instead of a crash
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Página no encontrada: ${state.error}')),
    ),
  );
});

// ─── Helper: bridges Riverpod stream → ChangeNotifier ────────────────────────
// GoRouter's refreshListenable expects a Listenable. We watch the auth stream
// and call notifyListeners() every time it emits a new value.
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    // Keep a reference to cancel the subscription when this is disposed.
    ref.listen(authSessionProvider, (_, __) => notifyListeners());
  }
}