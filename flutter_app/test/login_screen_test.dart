import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/app.dart';

/// Test della schermata di accesso senza Firebase.
///
/// Il build non legge i provider: `AuthService` viene risolto solo al submit,
/// quindi qui si possono verificare testi, validazione e link.
void main() {
  Future<void> apriLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CloserApp(initialLocation: '/login'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra i testi e i collegamenti del login', (tester) async {
    await apriLogin(tester);

    expect(find.text('Closer'), findsOneWidget);
    expect(find.text('Accedi alla piattaforma'), findsOneWidget);
    expect(find.text('Accedi'), findsOneWidget);
    expect(find.text('Password dimenticata?'), findsOneWidget);
    expect(find.textContaining('Registra la tua azienda'), findsOneWidget);
  });

  testWidgets('la password è oscurata', (tester) async {
    await apriLogin(tester);

    final campo = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('campo-password')),
        matching: find.byType(EditableText),
      ),
    );
    expect(campo.obscureText, isTrue);
  });

  testWidgets('i campi vuoti mostrano gli errori', (tester) async {
    await apriLogin(tester);

    await tester.tap(find.byKey(const Key('pulsante-accedi')));
    await tester.pumpAndSettle();

    expect(find.text('Inserisci l\'email'), findsOneWidget);
    expect(find.text('Inserisci la password'), findsOneWidget);
  });

  testWidgets('un\'email non valida mostra l\'errore di formato', (tester) async {
    await apriLogin(tester);

    await tester.enterText(find.byKey(const Key('campo-email')), 'mario');
    await tester.enterText(find.byKey(const Key('campo-password')), 'segreta');
    await tester.tap(find.byKey(const Key('pulsante-accedi')));
    await tester.pumpAndSettle();

    expect(find.text('Inserisci un indirizzo email valido'), findsOneWidget);
    expect(find.text('Inserisci la password'), findsNothing);
  });

  testWidgets('"Password dimenticata?" apre il recupero', (tester) async {
    await apriLogin(tester);

    await tester.tap(find.text('Password dimenticata?'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Recupero password'),
      ),
      findsOneWidget,
    );
  });
}
