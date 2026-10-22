import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/preventivo.dart';
import 'package:commerciali_app/features/dashboard/dashboard_screen.dart';

void main() {
  Preventivo preventivo({
    String id = 'p1',
    String? numero = 'PRV-0001',
    String? cliente = 'Acme S.r.l.',
    String stato = 'bozza',
    num totale = 1234.5,
    String? createdAt,
  }) {
    return Preventivo(
      id: id,
      numero: numero,
      clienteNome: cliente,
      stato: stato,
      totaleIva: totale,
      createdAt: createdAt,
    );
  }

  /// Avvolge [CorpoDashboard] in un'app minima senza provider né Firebase.
  Future<void> mostraDashboard(
    WidgetTester tester, {
    List<Preventivo> preventivi = const [],
    int numeroClienti = 0,
    bool caricamento = false,
    Object? errore,
    bool largo = false,
    VoidCallback? onRiprova,
    VoidCallback? onNuovoPreventivo,
    VoidCallback? onNuovoCliente,
    VoidCallback? onBandi,
    VoidCallback? onCatalogo,
    ValueChanged<Preventivo>? onApriPreventivo,
    bool attendi = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CorpoDashboard(
            preventivi: preventivi,
            statistiche: calcolaStatistiche(preventivi),
            numeroClienti: numeroClienti,
            caricamento: caricamento,
            errore: errore,
            largo: largo,
            onRiprova: onRiprova ?? () {},
            onNuovoPreventivo: onNuovoPreventivo ?? () {},
            onNuovoCliente: onNuovoCliente ?? () {},
            onBandi: onBandi ?? () {},
            onCatalogo: onCatalogo ?? () {},
            onApriPreventivo: onApriPreventivo,
          ),
        ),
      ),
    );
    if (attendi) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  group('calcolaStatistiche', () {
    test('conta gli stati e somma il valore aperto', () {
      final statistiche = calcolaStatistiche([
        preventivo(id: 'p1', stato: 'bozza', totale: 100),
        preventivo(id: 'p2', stato: 'bozza', totale: 50.5),
        preventivo(id: 'p3', stato: 'inviato', totale: 200),
        preventivo(id: 'p4', stato: 'accettato', totale: 999),
        preventivo(id: 'p5', stato: 'rifiutato', totale: 999),
        preventivo(id: 'p6', stato: 'revisionato', totale: 999),
      ]);

      expect(statistiche.totalePreventivi, 6);
      expect(statistiche.bozze, 2);
      expect(statistiche.inviati, 1);
      expect(statistiche.accettati, 1);
      expect(statistiche.rifiutati, 1);
      expect(statistiche.valoreAperto, closeTo(350.5, 0.001));
    });

    test('lista vuota produce tutti zeri', () {
      final statistiche = calcolaStatistiche([]);

      expect(statistiche.totalePreventivi, 0);
      expect(statistiche.bozze, 0);
      expect(statistiche.inviati, 0);
      expect(statistiche.accettati, 0);
      expect(statistiche.rifiutati, 0);
      expect(statistiche.valoreAperto, 0);
    });

    test('normalizza maiuscole e spazi negli stati', () {
      final statistiche = calcolaStatistiche([
        preventivo(stato: ' Bozza '),
        preventivo(stato: 'INVIATO'),
        preventivo(stato: 'Accettato'),
      ]);

      expect(statistiche.bozze, 1);
      expect(statistiche.inviati, 1);
      expect(statistiche.accettati, 1);
      expect(statistiche.totalePreventivi, 3);
    });

    test('gli stati sconosciuti entrano solo nel totale', () {
      final statistiche = calcolaStatistiche([
        preventivo(stato: 'archiviato', totale: 500),
      ]);

      expect(statistiche.totalePreventivi, 1);
      expect(statistiche.bozze, 0);
      expect(statistiche.valoreAperto, 0);
    });
  });

  group('ultimiPreventivi', () {
    test('restituisce al massimo cinque preventivi, dal più recente', () {
      final elenco = [
        for (var i = 1; i <= 7; i++)
          preventivo(
            id: 'p$i',
            createdAt: '2026-10-0${i}T10:00:00.000',
          ),
      ];

      final ultimi = ultimiPreventivi(elenco);

      expect(ultimi.length, 5);
      expect(ultimi.map((p) => p.id), ['p7', 'p6', 'p5', 'p4', 'p3']);
    });

    test('ordina anche un elenco ricevuto fuori ordine', () {
      final ultimi = ultimiPreventivi([
        preventivo(id: 'vecchio', createdAt: '2026-01-01T10:00:00.000'),
        preventivo(id: 'nuovo', createdAt: '2026-10-01T10:00:00.000'),
      ]);

      expect(ultimi.map((p) => p.id), ['nuovo', 'vecchio']);
    });

    test('elenco vuoto resta vuoto', () {
      expect(ultimiPreventivi([]), isEmpty);
    });
  });

  group('testoNumeroClienti', () {
    test('singolare e plurale', () {
      expect(testoNumeroClienti(0), '0 clienti in anagrafica');
      expect(testoNumeroClienti(1), '1 cliente in anagrafica');
      expect(testoNumeroClienti(12), '12 clienti in anagrafica');
    });
  });

  group('messaggioErroreDashboard', () {
    test('permessi negati spiega il problema', () {
      final errore = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      expect(
        messaggioErroreDashboard(errore),
        contains('Non hai i permessi'),
      );
    });

    test('errore generico invita a riprovare', () {
      expect(
        messaggioErroreDashboard(Exception('rete')),
        contains('connessione e riprova'),
      );
    });
  });

  group('CorpoDashboard', () {
    testWidgets('mostra lo stato vuoto con il pulsante Nuovo preventivo',
        (tester) async {
      var nuovi = 0;
      await mostraDashboard(tester, onNuovoPreventivo: () => nuovi++);

      expect(find.text('Nessun preventivo'), findsOneWidget);
      expect(find.text('0 clienti in anagrafica'), findsOneWidget);

      final pulsante = find.byKey(
        const Key('dashboard-nuovo-preventivo-vuoto'),
      );
      await tester.ensureVisible(pulsante);
      await tester.tap(pulsante);
      expect(nuovi, 1);
    });

    testWidgets('mostra lo stato di caricamento', (tester) async {
      await mostraDashboard(tester, caricamento: true, attendi: false);

      expect(find.byKey(const Key('dashboard-caricamento')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-statistiche')), findsNothing);
    });

    testWidgets('mostra errore e Riprova richiama il caricamento',
        (tester) async {
      var riprove = 0;
      await mostraDashboard(
        tester,
        errore: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
        onRiprova: () => riprove++,
      );

      expect(find.text('Dashboard non disponibile'), findsOneWidget);
      expect(find.textContaining('Non hai i permessi'), findsOneWidget);

      await tester.tap(find.byKey(const Key('dashboard-riprova')));
      expect(riprove, 1);
    });

    testWidgets('mostra i conteggi e il valore aperto formattato in italiano',
        (tester) async {
      await mostraDashboard(
        tester,
        preventivi: [
          preventivo(id: 'p1', stato: 'bozza', totale: 100),
          preventivo(id: 'p2', stato: 'inviato', totale: 1134.5),
          preventivo(id: 'p3', stato: 'accettato', totale: 500),
        ],
      );

      Finder valore(String chiave, String testo) => find.descendant(
            of: find.byKey(Key('dashboard-stat-$chiave')),
            matching: find.textContaining(testo),
          );

      expect(valore('totale', '3'), findsOneWidget);
      expect(valore('bozze', '1'), findsOneWidget);
      expect(valore('inviati', '1'), findsOneWidget);
      expect(valore('accettati', '1'), findsOneWidget);
      expect(valore('rifiutati', '0'), findsOneWidget);
      expect(valore('valore-aperto', '1.234,50'), findsOneWidget);
    });

    testWidgets('mostra solo gli ultimi cinque preventivi', (tester) async {
      final elenco = [
        for (var i = 1; i <= 7; i++)
          preventivo(
            id: 'p$i',
            numero: 'PRV-000$i',
            createdAt: '2026-10-0${i}T10:00:00.000',
          ),
      ];
      await mostraDashboard(tester, preventivi: elenco);

      expect(
        find.byKey(const ValueKey('dashboard-preventivo-p7')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard-preventivo-p3')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard-preventivo-p2')),
        findsNothing,
      );
    });

    testWidgets('apre il preventivo selezionato', (tester) async {
      Preventivo? aperto;
      await mostraDashboard(
        tester,
        preventivi: [preventivo(id: 'p1')],
        onApriPreventivo: (p) => aperto = p,
      );

      await tester.tap(
        find.byKey(const ValueKey('dashboard-preventivo-p1')),
      );
      expect(aperto?.id, 'p1');
    });

    testWidgets('le azioni rapide richiamano le destinazioni', (tester) async {
      var nuovoPreventivo = 0;
      var nuovoCliente = 0;
      var bandi = 0;
      var catalogo = 0;
      await mostraDashboard(
        tester,
        onNuovoPreventivo: () => nuovoPreventivo++,
        onNuovoCliente: () => nuovoCliente++,
        onBandi: () => bandi++,
        onCatalogo: () => catalogo++,
      );

      Future<void> premi(String chiave) async {
        final pulsante = find.byKey(Key('dashboard-azione-$chiave'));
        await tester.ensureVisible(pulsante);
        await tester.tap(pulsante);
      }

      await premi('nuovo-preventivo');
      await premi('nuovo-cliente');
      await premi('bandi');
      await premi('catalogo');

      expect(nuovoPreventivo, 1);
      expect(nuovoCliente, 1);
      expect(bandi, 1);
      expect(catalogo, 1);
    });

    testWidgets('su telefono le statistiche sono su due colonne',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await mostraDashboard(tester);

      final totale = tester.getTopLeft(
        find.byKey(const Key('dashboard-stat-totale')),
      );
      final bozze = tester.getTopLeft(
        find.byKey(const Key('dashboard-stat-bozze')),
      );
      final inviati = tester.getTopLeft(
        find.byKey(const Key('dashboard-stat-inviati')),
      );

      expect(bozze.dy, totale.dy);
      expect(bozze.dx, greaterThan(totale.dx));
      expect(inviati.dy, greaterThan(totale.dy));
    });

    testWidgets('su desktop le statistiche sono su quattro colonne',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await mostraDashboard(tester, largo: true);

      final totale = tester.getTopLeft(
        find.byKey(const Key('dashboard-stat-totale')),
      );
      final accettati = tester.getTopLeft(
        find.byKey(const Key('dashboard-stat-accettati')),
      );
      final rifiutati = tester.getTopLeft(
        find.byKey(const Key('dashboard-stat-rifiutati')),
      );
      final valoreAperto = tester.getTopLeft(
        find.byKey(const Key('dashboard-stat-valore-aperto')),
      );

      expect(accettati.dy, totale.dy);
      expect(rifiutati.dy, greaterThan(totale.dy));
      expect(valoreAperto.dy, rifiutati.dy);
    });
  });
}
