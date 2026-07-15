// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_session_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/model/miembro_granja/collaborators_screen.dart';
import '../../features/animales/animales_screen.dart';
import '../../features/ciclos/presentation/screens/cycle_create_screen.dart';
import '../../features/ciclos/presentation/screens/cycle_detail_screen.dart';
import '../../features/ciclos/presentation/screens/cycles_list_screen.dart';
import '../../features/granja/granja_provider.dart';
import '../../features/home/home_screen.dart';

// ─── Route names (constants → no magic strings) ───────────────────────────────
abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';

  // Rutas base dentro del Shell de Navegación
  static const home = '/granjas';
  static const animales = '/animales';
  static const ciclos = '/ciclos';
  static const ciclosNew = '/ciclos/nuevo';
  static const huevos = '/huevos';
  static const comida = '/comida';
  static const grafica = '/grafica';

  static const collaborators = '/collaborators/:id';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthStateListenable(ref);

  return GoRouter(
    initialLocation:
        AppRoutes.home, // Cambiado para iniciar en la sección de granjas
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final sessionAsync = ref.read(authSessionProvider);
      if (sessionAsync.isLoading) return null;

      final hasSession = sessionAsync.value != null;
      final onAuthRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      if (!hasSession && !onAuthRoute) return AppRoutes.login;
      if (hasSession && onAuthRoute) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),

      // ─── SHELL DE NAVEGACIÓN (Mantiene HomeScreen como contenedor) ───
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          // Retornamos el HomeScreen pasándole el shell (las sub-pantallas inyectadas)
          return HomeScreen(navigationShell: navigationShell);
        },
        branches: [
          // Pestaña 0: Granjas / Home principal
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) =>
                    const GranjasTab(), // Extraído el antiguo _Body aquí
              ),
            ],
          ),
          // Pestaña 1: Animales
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.animales,
                builder: (context, state) => SelectedFarmTabContainer(
                  screenBuilder: (granjaId) =>
                      AnimalesScreen(granjaId: granjaId),
                ),
              ),
            ],
          ),
          // Pestaña 2: Ciclos productivos
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.ciclos,
                builder: (context, state) => SelectedFarmTabContainer(
                  screenBuilder: (granjaId) =>
                      CyclesListScreen(farmId: granjaId),
                ),
                routes: [
                  GoRoute(
                    path: 'nuevo',
                    builder: (context, state) => SelectedFarmTabContainer(
                      screenBuilder: (granjaId) =>
                          CycleCreateScreen(farmId: granjaId),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        CycleDetailScreen(cycleId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          // Pestaña 3: Gráfica
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.grafica,
                builder: (context, state) =>
                    const Center(child: Text('Pantalla de Gráficas')),
              ),
            ],
          ),
        ],
      ),

      // Exact legacy destinations redirect to the canonical Cycles route.
      GoRoute(
        path: AppRoutes.huevos,
        redirect: (_, _) => AppRoutes.ciclos,
        builder: (_, _) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.comida,
        redirect: (_, _) => AppRoutes.ciclos,
        builder: (_, _) => const SizedBox.shrink(),
      ),

      // Rutas secundarias detalladas que se empujan encima de todo el cascarón (Full Screen)
      GoRoute(
        path: '/collaborators/:id',
        builder: (context, state) {
          final farmId = state.pathParameters['id']!;
          final farmName = state.extra as String? ?? 'Granja';
          return CollaboratorsScreen(farmId: farmId, farmName: farmName);
        },
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Página no encontrada: ${state.error}')),
    ),
  );
});

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen(authSessionProvider, (_, _) => notifyListeners());
  }
}

// ─── CONTROLADOR INTERMEDIO DE GRANJA SELECCIONADA ────────────────────────────
/// Este widget evalúa si hay una granja seleccionada en el estado de Riverpod.
/// Si hay, renderiza la pantalla que recibe su ID; si no, pide seleccionarla.
class SelectedFarmTabContainer extends ConsumerWidget {
  // 1. Cambiamos el tipo a una función que recibe un String y devuelve un Widget
  final Widget Function(String granjaId) screenBuilder;

  const SelectedFarmTabContainer({
    super.key,
    required this.screenBuilder, // 2. Actualizamos el constructor
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFarm = ref.watch(selectedFarmProvider);

    if (selectedFarm == null) {
      return const Center(
        child: Text(
          'Por favor, selecciona una granja en la pestaña de inicio primero.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    // 3. Invocamos la función constructora pasando el ID
    return screenBuilder(selectedFarm.id);
  }
}
