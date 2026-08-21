import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/core/router/app_router.dart';
import 'package:rancho/features/ciclos/domain/cycle_models.dart';
import 'package:rancho/features/home/home_screen.dart';
import 'package:rancho/l10n/app_localizations_es.dart';

void main() {
  test('Finanzas is canonical and legacy grafica redirects for a session', () {
    expect(AppRoutes.finanzas, '/finanzas');
    expect(AppRoutes.grafica, '/grafica');
    expect(
      resolveAppRedirect(
        isLoading: false,
        hasSession: true,
        matchedLocation: AppRoutes.grafica,
      ),
      AppRoutes.finanzas,
    );
  });

  test('legacy grafica still respects authentication', () {
    expect(
      resolveAppRedirect(
        isLoading: false,
        hasSession: false,
        matchedLocation: AppRoutes.grafica,
      ),
      AppRoutes.login,
    );
  });

  test('V2 cycle route redirects when access is unavailable', () {
    expect(
      resolveEconomicsV2Redirect(
        isEnabled: false,
        role: CycleRole.owner,
        farmId: 'farm-1',
        matchedLocation: AppRoutes.productionCycles,
      ),
      AppRoutes.finanzas,
    );
    expect(
      resolveEconomicsV2Redirect(
        isEnabled: true,
        role: CycleRole.viewer,
        farmId: 'farm-1',
        matchedLocation: AppRoutes.productionCycles,
      ),
      AppRoutes.finanzas,
    );
    expect(
      resolveEconomicsV2Redirect(
        isEnabled: true,
        role: CycleRole.owner,
        farmId: null,
        matchedLocation: AppRoutes.productionCycles,
      ),
      AppRoutes.finanzas,
    );
  });

  test('V2 cycle route remains available to enabled owners and editors', () {
    expect(
      resolveEconomicsV2Redirect(
        isEnabled: true,
        role: CycleRole.owner,
        farmId: 'farm-1',
        matchedLocation: AppRoutes.productionCycles,
      ),
      isNull,
    );
    expect(
      resolveEconomicsV2Redirect(
        isEnabled: true,
        role: CycleRole.editor,
        farmId: 'farm-1',
        matchedLocation: AppRoutes.productionCycles,
      ),
      isNull,
    );
  });

  test('home branch title identifies Finanzas', () {
    expect(homeBranchTitle(4, AppLocalizationsEs()), 'Finanzas');
  });
}
