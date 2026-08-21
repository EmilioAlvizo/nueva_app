// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_session_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/model/miembro_granja/collaborators_screen.dart';
import '../../features/huevos/huevos_screen.dart';
import '../../features/comida/comida_screen.dart';
import '../../features/animales/animales_screen.dart';
import '../../features/granja/granja_provider.dart';
import '../../features/home/home_screen.dart';
import '../../features/finanzas/presentation/screens/finances_screen.dart';
import '../../features/ciclos/domain/cycle_models.dart';
import '../../features/ciclos/presentation/providers/cycle_providers.dart';
import '../../features/ciclos/presentation/screens/cycles_list_screen.dart';

// ─── Route names (constants → no magic strings) ───────────────────────────────
abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';

  // Rutas base dentro del Shell de Navegación
  static const home = '/granjas';
  static const animales = '/animales';
  static const huevos = '/huevos';
  static const comida = '/comida';
  static const finanzas = '/finanzas';
  static const grafica = '/grafica';
  static const productionCycles = '/production-cycles';

  static const collaborators = '/collaborators/:id';
}

const economicsV2Enabled = bool.fromEnvironment(
  'economics_v2_enabled',
  defaultValue: false,
);

bool canAccessEconomicsV2({
  required bool isEnabled,
  required CycleRole? role,
  required String? farmId,
}) =>
    isEnabled &&
    farmId != null &&
    (role == CycleRole.owner || role == CycleRole.editor);

String? resolveAppRedirect({
  required bool isLoading,
  required bool hasSession,
  required String matchedLocation,
}) {
  if (isLoading) return null;
  final onAuthRoute =
      matchedLocation == AppRoutes.login ||
      matchedLocation == AppRoutes.register;
  if (!hasSession && !onAuthRoute) return AppRoutes.login;
  if (hasSession && onAuthRoute) return AppRoutes.home;
  if (hasSession && matchedLocation == AppRoutes.grafica) {
    return AppRoutes.finanzas;
  }
  return null;
}

String? resolveEconomicsV2Redirect({
  required bool isEnabled,
  required CycleRole role,
  required String? farmId,
  required String matchedLocation,
}) {
  if (matchedLocation != AppRoutes.productionCycles) return null;
  if (!canAccessEconomicsV2(isEnabled: isEnabled, role: role, farmId: farmId)) {
    return AppRoutes.finanzas;
  }
  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthStateListenable(ref);

  return GoRouter(
    initialLocation:
        AppRoutes.home, // Cambiado para iniciar en la sección de granjas
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final sessionAsync = ref.read(authSessionProvider);
      return resolveAppRedirect(
        isLoading: sessionAsync.isLoading,
        hasSession: sessionAsync.value != null,
        matchedLocation: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(path: AppRoutes.grafica, redirect: (_, _) => AppRoutes.finanzas),
      GoRoute(
        path: AppRoutes.productionCycles,
        redirect: (_, state) {
          final farm = ref.read(selectedFarmProvider);
          final access = farm == null
              ? null
              : ref.read(cycleAccessProvider(farm.id)).value;
          return resolveEconomicsV2Redirect(
            isEnabled: economicsV2Enabled,
            role: access?.role ?? CycleRole.viewer,
            farmId: farm?.id,
            matchedLocation: state.matchedLocation,
          );
        },
        builder: (_, __) => const _ProductionCyclesRoute(),
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
                builder: (context, state) => AnimalesTabContainer(
                  screenBuilder: (granjaId) =>
                      AnimalesScreen(granjaId: granjaId),
                ),
              ),
            ],
          ),
          // Pestaña 2: Huevos
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.huevos,
                builder: (context, state) => AnimalesTabContainer(
                  screenBuilder: (granjaId) => HuevosScreen(granjaId: granjaId),
                ),
              ),
            ],
          ),
          // Pestaña 3: Comida
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.comida,
                builder: (context, state) => AnimalesTabContainer(
                  screenBuilder: (granjaId) => ComidaScreen(granjaId: granjaId),
                ),
              ),
            ],
          ),
          // Pestaña 4: Finanzas
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.finanzas,
                builder: (context, state) => AnimalesTabContainer(
                  screenBuilder: (granjaId) => FinancesScreen(farmId: granjaId),
                ),
              ),
            ],
          ),
        ],
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
    ref.listen(authSessionProvider, (_, __) => notifyListeners());
  }
}

class _ProductionCyclesRoute extends ConsumerWidget {
  const _ProductionCyclesRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farm = ref.watch(selectedFarmProvider);
    if (farm == null) return const SizedBox.shrink();
    return CyclesListScreen(farmId: farm.id);
  }
}

// ─── CONTROLADOR INTERMEDIO DE ANIMALES ──────────────────────────────────────
/// Este widget evalúa si hay una granja seleccionada en el estado de Riverpod.
/// Si hay, renderiza `AnimalesScreen(granjaId)`, si no, te pide seleccionar una.
class AnimalesTabContainer extends ConsumerWidget {
  // 1. Cambiamos el tipo a una función que recibe un String y devuelve un Widget
  final Widget Function(String granjaId) screenBuilder;

  const AnimalesTabContainer({
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
