import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:rancho/features/auth/presentation/screens/login_screen.dart';
import 'package:rancho/main.dart';

void main() {
  testWidgets('unauthenticated app shell opens login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWithValue(const AsyncData(null)),
        ],
        child: const GallinasApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
