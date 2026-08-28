import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/core/router/app_router.dart';
import 'package:rancho/features/home/home_screen.dart';
import 'package:rancho/features/finanzas/presentation/widgets/finance_tab_bar.dart';
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

  test('V2 compatibility route preserves flag and farm guards', () {
    expect(
      resolveEconomicsV2Redirect(
        isEnabled: false,
        farmId: 'farm-1',
        matchedLocation: AppRoutes.productionCycles,
      ),
      AppRoutes.finanzas,
    );
    expect(
      resolveEconomicsV2Redirect(
        isEnabled: true,
        farmId: 'farm-1',
        matchedLocation: AppRoutes.productionCycles,
      ),
      AppRoutes.financeCycles,
    );
    expect(
      resolveEconomicsV2Redirect(
        isEnabled: true,
        farmId: null,
        matchedLocation: AppRoutes.productionCycles,
      ),
      AppRoutes.finanzas,
    );
  });

  test('V2 compatibility route canonicalizes eligible requests to Finance', () {
    expect(
      resolveEconomicsV2Redirect(
        isEnabled: true,
        farmId: 'farm-1',
        matchedLocation: AppRoutes.productionCycles,
      ),
      AppRoutes.financeCycles,
    );
    expect(resolveFinanceInitialTab('cycles'), FinanceTab.cycles);
    expect(resolveFinanceInitialTab(null), FinanceTab.balance);
  });

  test('home branch title identifies Finanzas', () {
    expect(homeBranchTitle(4, AppLocalizationsEs()), 'Finanzas');
  });
}
