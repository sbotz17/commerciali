import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/ruolo.dart';
import 'package:commerciali_app/features/impostazioni/nuovo_utente_screen.dart';

void main() {
  const amministratore = Ruolo(
    id: 'r1',
    nome: 'Amministratore',
    chiave: 'admin',
    sistema: true,
  );
  const commerciale = Ruolo(
    id: 'r2',
    nome: 'Commerciale',
    chiave: 'commerciale',
    sistema: true,
  );

  /// Monta la schermata in un'app minima, senza Firebase.
  Future<void> mostraNuovoUtente(
    WidgetTester tester, {
    List<Ruolo> ruoli = const [amministratore, commerciale],
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: NuovoUtenteScreen(ruoli: ruoli),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('generaPasswordTemporanea', () {
    test('ha 12 caratteri alfanumerici', () {
      final password = generaPasswordTemporanea();

      expect(password.length, 12);
      expect(RegExp(r'^[A-Za-z0-9]{12}$').hasMatch(password), isTrue);
    });

    test('accetta un generatore ripetibile nei test', () {
      expect(
        generaPasswordTemporanea(random: Random(7)),
        generaPasswordTemporanea(random: Random(7)),
      );
      expect(
        generaPasswordTemporanea(random: Random(7)),
        isNot(generaPasswordTemporanea(random: Random(8))),
      );
    });
  });

  group('validazione', () {
    test('nome obbligatorio', () {
      expect(validaNomeNuovoUtente(null), isNotNull);
      expect(validaNomeNuovoUtente('   '), isNotNull);
      expect(validaNomeNuovoUtente('Mario Rossi'), isNull);
    });

    test('email obbligatoria e plausibile', () {
      expect(validaEmailNuovoUtente(''), isNotNull);
      expect(validaEmailNuovoUtente('mario.rossi'), isNotNull);
      expect(validaEmailNuovoUtente('mario@azienda'), isNotNull);
      expect(validaEmailNuovoUtente('mario.rossi@example.it'), isNull);
    });

    test('password almeno 8 caratteri', () {
      expect(validaPasswordNuovoUtente('1234567'), isNotNull);
      expect(validaPasswordNuovoUtente('12345678'), isNull);
    });
  });

  group('ruoliNuovoUtente', () {
    test('usa i ruoli configurati', () {
      final voci = ruoliNuovoUtente(const [amministratore, commerciale]);

      expect(voci.map((voce) => voce.chiave), ['admin', 'commerciale']);
      expect(voci.first.etichetta, 'Amministratore');
    });

    test('senza ruoli ripiega su admin e commerciale', () {
      final voci = ruoliNuovoUtente(const []);

      expect(voci.map((voce) => voce.chiave), ['admin', 'commerciale']);
      expect(voci.map((voce) => voce.etichetta), [
        'Amministratore',
        'Commerciale',
      ]);
    });
  });

  group('NuovoUtenteScreen', () {
    testWidgets('mostra i campi del form', (tester) async {
      await mostraNuovoUtente(tester);

      expect(find.text('Nuovo utente'), findsOneWidget);
      expect(find.byKey(const Key('nuovo-utente-nome')), findsOneWidget);
      expect(find.byKey(const Key('nuovo-utente-email')), findsOneWidget);
      expect(find.byKey(const Key('nuovo-utente-ruolo')), findsOneWidget);
      expect(find.byKey(const Key('nuovo-utente-metodo')), findsOneWidget);
      expect(find.text('Invita via email'), findsOneWidget);
      expect(find.text('Password temporanea'), findsOneWidget);
      // Metodo predefinito: invito, nessuna password da comunicare.
      expect(find.byKey(const Key('nuovo-utente-password')), findsNothing);
    });

    testWidgets('nome ed email vuoti bloccano il salvataggio', (tester) async {
      await mostraNuovoUtente(tester);

      await tester.tap(find.byKey(const Key('nuovo-utente-salva')));
      await tester.pumpAndSettle();

      expect(find.text('Inserisci nome e cognome'), findsOneWidget);
      expect(find.text('Inserisci l\'email'), findsOneWidget);
      // Nessun errore di servizio: la validazione locale si ferma prima.
      expect(find.byKey(const Key('nuovo-utente-errore')), findsNothing);
    });

    testWidgets('email non valida blocca il salvataggio', (tester) async {
      await mostraNuovoUtente(tester);

      await tester.enterText(
        find.byKey(const Key('nuovo-utente-nome')),
        'Mario Rossi',
      );
      await tester.enterText(
        find.byKey(const Key('nuovo-utente-email')),
        'mario.rossi',
      );
      await tester.tap(find.byKey(const Key('nuovo-utente-salva')));
      await tester.pumpAndSettle();

      expect(
        find.text('Inserisci un\'email valida (es. nome@azienda.it)'),
        findsOneWidget,
      );
    });

    testWidgets('il metodo password temporanea mostra il campo', (
      tester,
    ) async {
      await mostraNuovoUtente(tester);

      await tester.tap(find.text('Password temporanea'));
      await tester.pumpAndSettle();

      final campo = tester.widget<TextFormField>(
        find.byKey(const Key('nuovo-utente-password')),
      );
      expect(campo.controller?.text.length, 12);
      expect(
        find.textContaining('Comunica questa password all\'utente'),
        findsOneWidget,
      );
    });

    testWidgets('senza ruoli configurati la tendina ripiega sui ruoli base', (
      tester,
    ) async {
      await mostraNuovoUtente(tester, ruoli: const []);

      expect(find.text('Amministratore'), findsOneWidget);
    });
  });
}
