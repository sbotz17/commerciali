import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/features/impostazioni/nuova_azienda_screen.dart';

void main() {
  /// Monta la schermata in un'app minima, senza Firebase.
  Future<void> mostraNuovaAzienda(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const NuovaAziendaScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('validazione nuova azienda', () {
    test('nome o ragione sociale obbligatorio', () {
      expect(validaNomeNuovaAzienda(null), isNotNull);
      expect(validaNomeNuovaAzienda('   '), isNotNull);
      expect(validaNomeNuovaAzienda('Rossi Srl'), isNull);
    });

    test('email amministratore obbligatoria e plausibile', () {
      expect(validaEmailNuovaAzienda(null), isNotNull);
      expect(validaEmailNuovaAzienda(''), isNotNull);
      expect(validaEmailNuovaAzienda('mario.rossi'), isNotNull);
      expect(validaEmailNuovaAzienda('mario@azienda'), isNotNull);
      expect(validaEmailNuovaAzienda('mario.rossi@example.it'), isNull);
    });

    test('messaggio di errore in italiano', () {
      expect(
        messaggioErroreNuovaAzienda(ArgumentError('Dati non validi')),
        'Dati non validi',
      );
      expect(
        messaggioErroreNuovaAzienda(
          StateError('L\'azienda è stata creata, ma manca l\'amministratore.'),
        ),
        contains('L\'azienda è stata creata'),
      );
    });
  });

  group('NuovaAziendaScreen', () {
    testWidgets('mostra i campi dell\'azienda e del primo amministratore', (
      tester,
    ) async {
      await mostraNuovaAzienda(tester);

      expect(find.text('Nuova azienda'), findsOneWidget);
      expect(find.byKey(const Key('nuova-azienda-nome')), findsOneWidget);
      expect(find.byKey(const Key('nuova-azienda-piva')), findsOneWidget);
      expect(
        find.byKey(const Key('nuova-azienda-codice-fiscale')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('nuova-azienda-indirizzo')), findsOneWidget);
      expect(find.byKey(const Key('nuova-azienda-comune')), findsOneWidget);
      expect(find.byKey(const Key('nuova-azienda-provincia')), findsOneWidget);
      expect(find.byKey(const Key('nuova-azienda-cap')), findsOneWidget);
      expect(find.byKey(const Key('nuova-azienda-telefono')), findsOneWidget);
      expect(find.byKey(const Key('nuova-azienda-email')), findsOneWidget);
      expect(find.byKey(const Key('nuova-azienda-pec')), findsOneWidget);
      expect(
        find.byKey(const Key('nuova-azienda-admin-nome')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('nuova-azienda-admin-email')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('nuova-azienda-metodo')), findsOneWidget);
      expect(find.text('Invita via email'), findsOneWidget);
      expect(find.text('Password temporanea'), findsOneWidget);
      // Metodo predefinito: invito, nessuna password da comunicare.
      expect(find.byKey(const Key('nuova-azienda-password')), findsNothing);
    });

    testWidgets('nome azienda ed email vuoti bloccano il salvataggio', (
      tester,
    ) async {
      await mostraNuovaAzienda(tester);

      final salva = find.byKey(const Key('nuova-azienda-salva'));
      await tester.ensureVisible(salva);
      await tester.pumpAndSettle();
      await tester.tap(salva);
      await tester.pumpAndSettle();

      expect(
        find.text('Inserisci il nome o la ragione sociale'),
        findsOneWidget,
      );
      expect(
        find.text('Inserisci l\'email dell\'amministratore'),
        findsOneWidget,
      );
      // Nessun errore di servizio: la validazione locale si ferma prima.
      expect(find.byKey(const Key('nuova-azienda-errore')), findsNothing);
    });

    testWidgets('email amministratore non valida blocca il salvataggio', (
      tester,
    ) async {
      await mostraNuovaAzienda(tester);

      await tester.enterText(
        find.byKey(const Key('nuova-azienda-nome')),
        'Rossi Srl',
      );
      await tester.enterText(
        find.byKey(const Key('nuova-azienda-admin-email')),
        'mario.rossi',
      );

      final salva = find.byKey(const Key('nuova-azienda-salva'));
      await tester.ensureVisible(salva);
      await tester.pumpAndSettle();
      await tester.tap(salva);
      await tester.pumpAndSettle();

      expect(
        find.text('Inserisci un\'email valida (es. nome@azienda.it)'),
        findsOneWidget,
      );
    });

    testWidgets('il metodo password temporanea mostra il campo precompilato', (
      tester,
    ) async {
      await mostraNuovaAzienda(tester);

      await tester.tap(find.text('Password temporanea'));
      await tester.pumpAndSettle();

      final campo = tester.widget<TextFormField>(
        find.byKey(const Key('nuova-azienda-password')),
      );
      expect(campo.controller?.text.length, 12);
      expect(
        find.textContaining('Comunica questa password'),
        findsOneWidget,
      );
    });
  });
}
