import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/core/router/app_router.dart';
import 'package:nueva_app/features/home/home_screen.dart';
import 'package:nueva_app/l10n/app_localizations_es.dart';

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

  test('home branch title identifies Finanzas', () {
    expect(homeBranchTitle(4, AppLocalizationsEs()), 'Finanzas');
  });
}
