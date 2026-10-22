import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/app.dart';

/// Test della schermata di recupero password senza Firebase.
///
/// Senza `oobCode` il build non legge i provider: `AuthService` viene
/// risolto solo al submit.
void main() {
  Future<void> apriReset(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CommercialiApp(initialLocation: '/reset-password'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('senza oobCode mostra il form per inviare il link', (
    tester,
  ) async {
    await apriReset(tester);

    expect(find.text('Recupero password'), findsOneWidget);
    expect(find.text('Password dimenticata'), findsOneWidget);
    expect(find.byKey(const Key('campo-email')), findsOneWidget);
    expect(find.text('Invia link'), findsOneWidget);
    expect(find.byKey(const Key('campo-nuova-password')), findsNothing);
    expect(find.byKey(const Key('campo-conferma-password')), findsNothing);
  });

  testWidgets('il form email vuoto mostra l\'errore', (tester) async {
    await apriReset(tester);

    await tester.tap(find.byKey(const Key('pulsante-invia-link')));
    await tester.pumpAndSettle();

    expect(find.text('Inserisci l\'email'), findsOneWidget);
    expect(find.byKey(const Key('messaggio-errore-reset')), findsNothing);
  });

  testWidgets('un\'email non valida mostra l\'errore di formato', (
    tester,
  ) async {
    await apriReset(tester);

    await tester.enterText(find.byKey(const Key('campo-email')), 'mario');
    await tester.tap(find.byKey(const Key('pulsante-invia-link')));
    await tester.pumpAndSettle();

    expect(find.text('Inserisci un indirizzo email valido'), findsOneWidget);
  });

  testWidgets('"Torna al login" riporta alla schermata di accesso', (
    tester,
  ) async {
    await apriReset(tester);

    await tester.tap(find.text('Torna al login'));
    await tester.pumpAndSettle();

    expect(find.text('Accedi alla piattaforma'), findsOneWidget);
  });
}
