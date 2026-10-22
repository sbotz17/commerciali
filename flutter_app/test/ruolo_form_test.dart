import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/ruolo.dart';
import 'package:commerciali_app/features/impostazioni/ruolo_form_screen.dart';
import 'package:commerciali_app/state/azienda_providers.dart';

/// Test del form dei ruoli.
///
/// La schermata non legge `spServiceProvider` finché la validazione non passa:
/// nei test il provider è sovrascritto da una funzione che lancia, così
/// un'eventuale chiamata a Firebase farebbe fallire il test.
void main() {
  Future<void> apriForm(WidgetTester tester, {Ruolo? ruolo}) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          spServiceProvider.overrideWith(
            (ref) => throw StateError('Firebase non disponibile nei test'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: RuoloFormScreen(ruolo: ruolo),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> premiSalva(WidgetTester tester) async {
    final salva = find.byKey(const Key('salva-ruolo'));
    await tester.ensureVisible(salva);
    await tester.pumpAndSettle();
    await tester.tap(salva);
    await tester.pumpAndSettle();
  }

  testWidgets('nuovo ruolo: mostra campi e tendine dei permessi', (tester) async {
    await apriForm(tester);

    expect(find.text('Nuovo ruolo'), findsOneWidget);
    expect(find.byKey(const Key('ruolo-nome')), findsOneWidget);
    expect(find.byKey(const Key('ruolo-descrizione')), findsOneWidget);
    expect(find.byKey(const Key('ruolo-sconto')), findsOneWidget);
    expect(find.text('Permessi per area'), findsOneWidget);
    expect(find.byKey(const Key('ruolo-permesso-clienti')), findsOneWidget);
    expect(find.byKey(const Key('ruolo-permesso-dashboard')), findsOneWidget);
    expect(find.byKey(const Key('ruolo-permesso-impostazioni')), findsOneWidget);
  });

  testWidgets('nome vuoto: resta l\'errore di validazione', (tester) async {
    await apriForm(tester);
    await premiSalva(tester);

    expect(find.text('Inserisci il nome del ruolo'), findsOneWidget);
    // Nessuna chiamata al servizio: il provider lancia se letto.
    expect(find.byKey(const Key('ruolo-errore')), findsNothing);
  });

  testWidgets('ruolo esistente: campi precompilati e titolo di modifica', (
    tester,
  ) async {
    await apriForm(
      tester,
      ruolo: const Ruolo(
        id: 'r1',
        nome: 'Commerciale',
        descrizione: 'Vendite e preventivi',
        scontoMax: 15,
        permessi: {'clienti': 'entrambi', 'listino': 'lettura'},
      ),
    );

    expect(find.text('Modifica ruolo'), findsOneWidget);
    final nome = tester.widget<TextFormField>(
      find.byKey(const Key('ruolo-nome')),
    );
    final descrizione = tester.widget<TextFormField>(
      find.byKey(const Key('ruolo-descrizione')),
    );
    final sconto = tester.widget<TextFormField>(
      find.byKey(const Key('ruolo-sconto')),
    );
    expect(nome.controller?.text, 'Commerciale');
    expect(descrizione.controller?.text, 'Vendite e preventivi');
    expect(sconto.controller?.text, '15');

    expect(
      find.descendant(
        of: find.byKey(const Key('ruolo-permesso-clienti')),
        matching: find.text('Lettura e scrittura'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('ruolo-permesso-listino')),
        matching: find.text('Sola lettura'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('sconto massimo predefinito a zero', (tester) async {
    await apriForm(tester);

    final sconto = tester.widget<TextFormField>(
      find.byKey(const Key('ruolo-sconto')),
    );
    expect(sconto.controller?.text, '0');
  });
}
