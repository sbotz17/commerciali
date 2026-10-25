import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/appuntamento.dart';
import 'package:commerciali_app/features/calendario/appuntamento_form_screen.dart';

/// Test delle funzioni pure del form appuntamento e del form stesso.
///
/// Il form, in test, non trova Firebase inizializzato: il caricamento di
/// clienti e utenti fallisce senza rompere la schermata, che resta visibile
/// con i campi e l'avviso d'errore. Il salvataggio non viene mai eseguito
/// davvero.
void main() {
  group('validaTitoloAppuntamento', () {
    test('null restituisce un errore', () {
      expect(
        validaTitoloAppuntamento(null),
        'Inserisci il titolo dell\'appuntamento',
      );
    });

    test('stringa vuota restituisce un errore', () {
      expect(
        validaTitoloAppuntamento(''),
        'Inserisci il titolo dell\'appuntamento',
      );
    });

    test('solo spazi restituisce un errore', () {
      expect(
        validaTitoloAppuntamento('   '),
        'Inserisci il titolo dell\'appuntamento',
      );
    });

    test('un titolo valido supera la validazione', () {
      expect(validaTitoloAppuntamento('Visita Acme'), isNull);
    });

    test('gli spazi esterni vengono ignorati', () {
      expect(validaTitoloAppuntamento('  Visita Acme  '), isNull);
    });
  });

  group('validaDataAppuntamento', () {
    test('data assente o vuota è un errore', () {
      expect(
        validaDataAppuntamento(null),
        'Inserisci una data valida (gg/mm/aaaa)',
      );
      expect(
        validaDataAppuntamento('   '),
        'Inserisci una data valida (gg/mm/aaaa)',
      );
    });

    test('data italiana valida supera la validazione', () {
      expect(validaDataAppuntamento('24/10/2026'), isNull);
      expect(validaDataAppuntamento('01/01/2026'), isNull);
    });

    test('formato ISO e testo libero sono rifiutati', () {
      expect(validaDataAppuntamento('2026-10-24'), isNotNull);
      expect(validaDataAppuntamento('domani'), isNotNull);
      expect(validaDataAppuntamento('24/10'), isNotNull);
    });

    test('un giorno inesistente è un errore', () {
      expect(validaDataAppuntamento('31/02/2026'), isNotNull);
      expect(validaDataAppuntamento('32/01/2026'), isNotNull);
    });
  });

  group('validaCallAppuntamento', () {
    test('nessuna call non richiede link', () {
      expect(validaCallAppuntamento('nessuna', null), isNull);
      expect(validaCallAppuntamento('nessuna', 'testo non url'), isNull);
      expect(validaCallAppuntamento(null, null), isNull);
    });

    test('provider senza link è un errore', () {
      expect(
        validaCallAppuntamento('google_meet', ''),
        'Incolla il link della call o scegli "Nessuna call"',
      );
      expect(
        validaCallAppuntamento('teams', '   '),
        'Incolla il link della call o scegli "Nessuna call"',
      );
    });

    test('link non http/https è un errore', () {
      expect(
        validaCallAppuntamento('manuale', 'meet.google.com/abc'),
        'Inserisci un link valido (https://...)',
      );
      expect(
        validaCallAppuntamento('manuale', 'ftp://example.com'),
        'Inserisci un link valido (https://...)',
      );
    });

    test('link http/https valido supera la validazione', () {
      expect(
        validaCallAppuntamento('google_meet', 'https://meet.google.com/abc'),
        isNull,
      );
      expect(
        validaCallAppuntamento('teams', 'http://example.com/team'),
        isNull,
      );
    });
  });

  group('uriMapsIndirizzo', () {
    test('indirizzo assente o vuoto non produce un link', () {
      expect(uriMapsIndirizzo(null), isNull);
      expect(uriMapsIndirizzo(''), isNull);
      expect(uriMapsIndirizzo('   '), isNull);
    });

    test('produce un link https di Google Maps con la destinazione', () {
      final uri = uriMapsIndirizzo('Via Roma 1, Milano');

      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], 'Via Roma 1, Milano');
    });

    test('codifica spazi e caratteri speciali', () {
      const indirizzo = 'Via Roma 1, Milano (MI) & dintorni';
      final uri = uriMapsIndirizzo(indirizzo)!;

      expect(uri.queryParameters['destination'], indirizzo);
      expect(uri.toString(), contains('destination='));
      expect(uri.toString(), isNot(contains(' ')));
      expect(uri.toString(), isNot(contains('(')));
      expect(uri.toString(), contains('%26'));
    });

    test('ignora gli spazi esterni all\'indirizzo', () {
      final uri = uriMapsIndirizzo('  Via Verdi 10  ')!;

      expect(uri.queryParameters['destination'], 'Via Verdi 10');
    });
  });

  group('AppuntamentoFormScreen', () {
    Future<void> apriForm(
      WidgetTester tester, {
      Appuntamento? appuntamento,
    }) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AppuntamentoFormScreen(
              appuntamento: appuntamento,
              dataIniziale: DateTime(2026, 10, 24),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> premiSalva(WidgetTester tester) async {
      final salva = find.byKey(const Key('salva-appuntamento'));
      await tester.ensureVisible(salva);
      await tester.pumpAndSettle();
      await tester.tap(salva);
      await tester.pumpAndSettle();
    }

    testWidgets('mostra tutti i campi del nuovo appuntamento', (tester) async {
      await apriForm(tester);

      expect(find.text('Nuovo appuntamento'), findsOneWidget);
      for (final chiave in [
        'appuntamento-titolo',
        'appuntamento-data',
        'appuntamento-ora',
        'appuntamento-data-fine',
        'appuntamento-ora-fine',
        'appuntamento-tutto-il-giorno',
        'appuntamento-ripeti',
        'appuntamento-notifica',
        'appuntamento-privato',
        'appuntamento-cliente',
        'appuntamento-nuovo-cliente',
        'appuntamento-operatore',
        'appuntamento-avvisa-cliente',
        'appuntamento-avviso-senza-cliente',
        'appuntamento-condivisione',
        'appuntamento-call-provider',
        'appuntamento-call-url',
        'appuntamento-call-copia',
        'appuntamento-call-apri',
        'appuntamento-luogo',
        'appuntamento-indirizzo',
        'appuntamento-maps',
        'appuntamento-allegati-aggiungi',
        'appuntamento-note',
        'appuntamento-stato',
      ]) {
        expect(find.byKey(Key(chiave)), findsOneWidget, reason: chiave);
      }
    });

    testWidgets('mostra la sezione Avviso al cliente', (tester) async {
      await apriForm(tester);

      expect(find.text('AVVISO AL CLIENTE'), findsOneWidget);
      expect(find.text('Avvisa il cliente'), findsOneWidget);
      expect(find.textContaining('Seleziona un cliente'), findsOneWidget);
    });

    testWidgets('Luogo e note sta subito sotto data e ora', (tester) async {
      await apriForm(tester);

      final appuntamento = tester.getTopLeft(find.text('APPUNTAMENTO')).dy;
      final luogo = tester.getTopLeft(find.text('LUOGO E NOTE')).dy;
      final ripetizione = tester.getTopLeft(find.text('RIPETIZIONE')).dy;

      expect(luogo, greaterThan(appuntamento));
      expect(luogo, lessThan(ripetizione));
    });

    testWidgets('cambiando data il giorno automatico viene sostituito', (
      tester,
    ) async {
      await apriForm(tester);

      await tester.tap(find.byKey(const Key('appuntamento-ripeti')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ogni settimana').last);
      await tester.pumpAndSettle();

      final sabato = find.byKey(const Key('appuntamento-ripeti-giorno-6'));
      final lunedi = find.byKey(const Key('appuntamento-ripeti-giorno-1'));
      expect(tester.widget<FilterChip>(sabato).selected, isTrue);
      expect(tester.widget<FilterChip>(lunedi).selected, isFalse);

      await tester.enterText(
        find.byKey(const Key('appuntamento-data')),
        '26/10/2026',
      );
      await tester.pumpAndSettle();

      expect(tester.widget<FilterChip>(lunedi).selected, isTrue);
      expect(tester.widget<FilterChip>(sabato).selected, isFalse);
    });

    testWidgets('la ripetizione settimanale protegge il giorno di inizio', (
      tester,
    ) async {
      await apriForm(tester);

      await tester.tap(find.byKey(const Key('appuntamento-ripeti')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ogni settimana').last);
      await tester.pumpAndSettle();

      final sabato = find.byKey(const Key('appuntamento-ripeti-giorno-6'));
      expect(sabato, findsOneWidget);
      expect(tester.widget<FilterChip>(sabato).selected, isTrue);
      expect(
        find.byKey(const Key('appuntamento-anteprima-ripetizione')),
        findsOneWidget,
      );
      expect(find.textContaining('sabato'), findsWidgets);

      await tester.tap(sabato);
      await tester.pumpAndSettle();

      expect(tester.widget<FilterChip>(sabato).selected, isTrue);
      expect(
        find.text('Il giorno di inizio deve restare selezionato.'),
        findsOneWidget,
      );
    });

    testWidgets('il campo note occupa tutta la larghezza', (tester) async {
      await apriForm(tester);

      final larghezzaNote = tester
          .getSize(find.byKey(const Key('appuntamento-note')))
          .width;
      final larghezzaLuogo = tester
          .getSize(find.byKey(const Key('appuntamento-luogo')))
          .width;

      expect(larghezzaNote, greaterThan(larghezzaLuogo * 1.5));
    });

    testWidgets('apre il dialogo di condivisione con colleghi e gruppi', (
      tester,
    ) async {
      await apriForm(tester);

      final condivisione = find.byKey(const Key('appuntamento-condivisione'));
      await tester.ensureVisible(condivisione);
      await tester.pumpAndSettle();
      await tester.tap(condivisione);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('dialogo-condivisione-appuntamento')),
        findsOneWidget,
      );
      expect(
        find.text('Nessun collega disponibile da invitare.'),
        findsOneWidget,
      );
    });

    testWidgets('propone data iniziale e orari di inizio e fine', (
      tester,
    ) async {
      await apriForm(tester);

      String testo(String chiave) => tester
          .widget<TextFormField>(find.byKey(Key(chiave)))
          .controller!
          .text;

      expect(testo('appuntamento-data'), '24/10/2026');
      expect(testo('appuntamento-data-fine'), '24/10/2026');
      expect(testo('appuntamento-ora'), '09:00');
      expect(testo('appuntamento-ora-fine'), '10:00');
      expect(find.text('Da fare'), findsOneWidget);
    });

    testWidgets('il titolo vuoto blocca il salvataggio', (tester) async {
      await apriForm(tester);
      await premiSalva(tester);

      expect(
        find.text('Inserisci il titolo dell\'appuntamento'),
        findsOneWidget,
      );
    });

    testWidgets('una data non valida mostra l\'errore', (tester) async {
      await apriForm(tester);

      await tester.enterText(
        find.byKey(const Key('appuntamento-titolo')),
        'Visita Acme',
      );
      await tester.enterText(
        find.byKey(const Key('appuntamento-data')),
        '31/02/2026',
      );
      await premiSalva(tester);

      expect(
        find.text('Inserisci una data valida (gg/mm/aaaa)'),
        findsOneWidget,
      );
    });

    testWidgets('il salvataggio fallito mostra l\'avviso d\'errore', (
      tester,
    ) async {
      await apriForm(tester);

      await tester.enterText(
        find.byKey(const Key('appuntamento-titolo')),
        'Visita Acme',
      );
      await premiSalva(tester);

      expect(find.byKey(const Key('appuntamento-errore')), findsOneWidget);
    });

    testWidgets('in modifica precompila i campi dalla riga', (tester) async {
      await apriForm(
        tester,
        appuntamento: const Appuntamento(
          id: 'a1',
          titolo: 'Visita ACME',
          data: '2026-11-05',
          ora: '09:30',
          durataMin: 45,
          luogo: 'Sede cliente',
          indirizzo: 'Via Roma 1, Milano',
          note: 'Portare il catalogo',
          stato: 'fatto',
        ),
      );

      expect(find.text('Modifica appuntamento'), findsOneWidget);
      expect(find.text('Visita ACME'), findsOneWidget);
      expect(find.text('05/11/2026'), findsNWidgets(2));
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('10:15'), findsOneWidget);
      expect(find.text('Sede cliente'), findsOneWidget);
      expect(find.text('Via Roma 1, Milano'), findsOneWidget);
      expect(find.text('Portare il catalogo'), findsOneWidget);
      expect(find.text('Fatto'), findsOneWidget);
    });
  });
}
