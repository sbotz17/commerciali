import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/preventivo.dart';
import 'package:commerciali_app/features/preventivi/preventivi_screen.dart';

void main() {
  Preventivo preventivo({
    String id = 'p1',
    String? numero = 'PRV-0001',
    String? cliente = 'Acme S.r.l.',
    String stato = 'bozza',
    num totale = 1234.5,
  }) {
    return Preventivo(
      id: id,
      numero: numero,
      clienteNome: cliente,
      stato: stato,
      totaleIva: totale,
    );
  }

  /// Avvolge [ElencoPreventivi] in un'app minima senza provider né Firebase.
  Future<void> mostraElenco(
    WidgetTester tester, {
    List<Preventivo> preventivi = const [],
    bool caricamento = false,
    Object? errore,
    bool ricercaAttiva = false,
    bool largo = false,
    VoidCallback? onRiprova,
    VoidCallback? onNuovo,
    ValueChanged<Preventivo>? onApri,
    bool attendi = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ElencoPreventivi(
            preventivi: preventivi,
            caricamento: caricamento,
            errore: errore,
            ricercaAttiva: ricercaAttiva,
            largo: largo,
            onRiprova: onRiprova ?? () {},
            onNuovo: onNuovo ?? () {},
            onApri: onApri ?? (_) {},
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

  group('etichettaStatoPreventivo', () {
    test('traduce i cinque stati della vecchia app', () {
      expect(etichettaStatoPreventivo('bozza'), 'Bozza');
      expect(etichettaStatoPreventivo('inviato'), 'Inviato');
      expect(etichettaStatoPreventivo('accettato'), 'Accettato');
      expect(etichettaStatoPreventivo('rifiutato'), 'Rifiutato');
      expect(etichettaStatoPreventivo('revisionato'), 'Revisionato');
    });

    test('ignora maiuscole e spazi', () {
      expect(etichettaStatoPreventivo(' Accettato '), 'Accettato');
    });

    test('stato vuoto ricade su Bozza', () {
      expect(etichettaStatoPreventivo(''), 'Bozza');
      expect(etichettaStatoPreventivo('   '), 'Bozza');
    });

    test('stato sconosciuto resta visibile', () {
      expect(etichettaStatoPreventivo('archiviato'), 'archiviato');
    });
  });

  group('formatoNumeroPreventivo', () {
    test('progressivo a quattro cifre', () {
      expect(formatoNumeroPreventivo(1), 'PRV-0001');
      expect(formatoNumeroPreventivo(42), 'PRV-0042');
      expect(formatoNumeroPreventivo(1234), 'PRV-1234');
    });

    test('numeri oltre quattro cifre non vengono troncati', () {
      expect(formatoNumeroPreventivo(12345), 'PRV-12345');
    });
  });

  group('filtraPreventivi', () {
    final elenco = [
      preventivo(id: 'p1', numero: 'PRV-0001', cliente: 'Acme S.r.l.'),
      preventivo(
        id: 'p2',
        numero: 'PRV-0002-R1',
        cliente: 'Rossi Impianti',
        stato: 'accettato',
      ),
    ];

    test('testo vuoto restituisce tutto', () {
      expect(filtraPreventivi(elenco, '  '), elenco);
    });

    test('cerca per numero', () {
      final trovati = filtraPreventivi(elenco, '0002');
      expect(trovati.map((p) => p.id), ['p2']);
    });

    test('cerca per cliente ignorando maiuscole', () {
      final trovati = filtraPreventivi(elenco, 'acme');
      expect(trovati.map((p) => p.id), ['p1']);
    });

    test('nessuna corrispondenza restituisce lista vuota', () {
      expect(filtraPreventivi(elenco, 'beta'), isEmpty);
    });
  });

  group('messaggioErrorePreventivi', () {
    test('permessi negati spiega il problema', () {
      final errore = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      expect(
        messaggioErrorePreventivi(errore),
        contains('Non hai i permessi'),
      );
    });

    test('errore generico invita a riprovare', () {
      expect(
        messaggioErrorePreventivi(Exception('rete')),
        contains('connessione e riprova'),
      );
    });
  });

  group('ElencoPreventivi', () {
    testWidgets('mostra lo stato vuoto con il pulsante Nuovo preventivo',
        (tester) async {
      var nuovi = 0;
      await mostraElenco(tester, onNuovo: () => nuovi++);

      expect(find.text('Nessun preventivo'), findsOneWidget);
      expect(find.text('Nuovo preventivo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('preventivi-nuovo-vuoto')));
      expect(nuovi, 1);
    });

    testWidgets('mostra lo stato di caricamento', (tester) async {
      await mostraElenco(tester, caricamento: true, attendi: false);

      expect(find.byKey(const Key('preventivi-caricamento')), findsOneWidget);
      expect(find.text('Nessun preventivo'), findsNothing);
    });

    testWidgets('mostra errore e Riprova richiama il caricamento',
        (tester) async {
      var riprove = 0;
      await mostraElenco(
        tester,
        errore: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
        onRiprova: () => riprove++,
      );

      expect(find.text('Preventivi non disponibili'), findsOneWidget);
      expect(find.textContaining('Non hai i permessi'), findsOneWidget);

      await tester.tap(find.byKey(const Key('preventivi-riprova')));
      expect(riprove, 1);
    });

    testWidgets('ricerca senza risultati mostra il messaggio dedicato',
        (tester) async {
      await mostraElenco(tester, ricercaAttiva: true);

      expect(find.text('Nessun preventivo trovato'), findsOneWidget);
      expect(find.byKey(const Key('preventivi-nuovo-vuoto')), findsNothing);
    });

    testWidgets('su telefono mostra una card per preventivo', (tester) async {
      Preventivo? aperto;
      await mostraElenco(
        tester,
        preventivi: [
          preventivo(stato: 'accettato'),
        ],
        onApri: (p) => aperto = p,
      );

      expect(find.byKey(const Key('lista-preventivi')), findsOneWidget);
      expect(find.byKey(const Key('tabella-preventivi')), findsNothing);
      expect(find.text('PRV-0001'), findsOneWidget);
      expect(find.text('Acme S.r.l.'), findsOneWidget);
      expect(find.text('Accettato'), findsOneWidget);
      expect(find.textContaining('1.234,50'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('preventivo-p1')));
      expect(aperto?.id, 'p1');
    });

    testWidgets('da 600 px mostra la tabella con le quattro colonne',
        (tester) async {
      await mostraElenco(
        tester,
        preventivi: [
          preventivo(stato: 'inviato'),
        ],
        largo: true,
      );

      expect(find.byKey(const Key('tabella-preventivi')), findsOneWidget);
      expect(find.byKey(const Key('lista-preventivi')), findsNothing);
      expect(find.text('Numero'), findsOneWidget);
      expect(find.text('Cliente'), findsOneWidget);
      expect(find.text('Stato'), findsOneWidget);
      expect(find.text('Totale'), findsOneWidget);
      expect(find.text('Inviato'), findsOneWidget);
    });
  });
}
