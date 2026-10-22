import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/visita.dart';
import 'package:commerciali_app/features/visite/visite_screen.dart';

void main() {
  Visita visita({
    String id = 'v1',
    String? cliente = 'ACME Srl',
    String data = '2026-10-22',
    String? ora = '09:30',
    int ordine = 0,
    String stato = 'da_fare',
    String? note,
  }) {
    return Visita(
      id: id,
      clienteId: 'cl-$id',
      clienteNome: cliente,
      data: data,
      ora: ora,
      ordine: ordine,
      stato: stato,
      note: note,
    );
  }

  group('etichettaStatoVisita', () {
    test('traduce i due stati della vecchia app', () {
      expect(etichettaStatoVisita('da_fare'), 'Da fare');
      expect(etichettaStatoVisita('fatto'), 'Fatto');
    });

    test('ignora maiuscole e spazi', () {
      expect(etichettaStatoVisita(' FATTO '), 'Fatto');
    });

    test('stato vuoto ricade su Da fare', () {
      expect(etichettaStatoVisita(''), 'Da fare');
      expect(etichettaStatoVisita('   '), 'Da fare');
    });

    test('stato sconosciuto resta visibile', () {
      expect(etichettaStatoVisita('rinviata'), 'rinviata');
    });
  });

  group('date italiane', () {
    test('formatta gg/mm/aaaa con gli zeri', () {
      expect(formattaDataVisita(DateTime(2026, 1, 5)), '05/01/2026');
    });

    test('data ISO per Firestore', () {
      expect(dataIsoVisita(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('interpreta una data italiana valida', () {
      final data = parseDataItaliana('05/01/2026');
      expect(data, isNotNull);
      expect(dataIsoVisita(data!), '2026-01-05');
    });

    test('rifiuta date impossibili e testo libero', () {
      expect(parseDataItaliana('31/02/2026'), isNull);
      expect(parseDataItaliana('2026-01-05'), isNull);
      expect(parseDataItaliana(''), isNull);
      expect(parseDataItaliana(null), isNull);
    });

    test('validatore con messaggio in italiano', () {
      expect(validaDataVisita('05/01/2026'), isNull);
      expect(validaDataVisita('x'), contains('gg/mm/aaaa'));
    });

    test('etichetta del giorno relativa a oggi', () {
      final oggi = DateTime(2026, 10, 22);
      expect(etichettaGiornoVisite(oggi, oggi: oggi), 'Oggi');
      expect(
        etichettaGiornoVisite(DateTime(2026, 10, 21), oggi: oggi),
        'Ieri',
      );
      expect(
        etichettaGiornoVisite(DateTime(2026, 10, 23), oggi: oggi),
        'Domani',
      );
      expect(
        etichettaGiornoVisite(DateTime(2026, 10, 20), oggi: oggi),
        '20/10/2026',
      );
    });
  });

  group('ora della visita', () {
    test('normalizza una e due cifre', () {
      expect(normalizzaOraVisita('9:5'), '09:05');
      expect(normalizzaOraVisita('09:30'), '09:30');
      expect(normalizzaOraVisita(' 23:59 '), '23:59');
    });

    test('ora assente è ammessa', () {
      expect(normalizzaOraVisita(''), isNull);
      expect(validaOraVisita(''), isNull);
    });

    test('ora non valida è un errore', () {
      expect(normalizzaOraVisita('24:00'), isNull);
      expect(normalizzaOraVisita('9.30'), isNull);
      expect(validaOraVisita('24:00'), contains('HH:MM'));
    });
  });

  group('ordinamento e riordino', () {
    test('ordina per ordine e poi per ora', () {
      final elenco = [
        visita(id: 'c', ordine: 2, ora: '08:00'),
        visita(id: 'b', ordine: 1, ora: '11:00'),
        visita(id: 'a', ordine: 1, ora: '09:00'),
      ];

      expect(ordinaVisite(elenco).map((v) => v.id), ['a', 'b', 'c']);
    });

    test('sposta una visita in basso e in alto', () {
      final elenco = [
        visita(id: 'a', ordine: 0),
        visita(id: 'b', ordine: 1),
        visita(id: 'c', ordine: 2),
      ];

      expect(spostaVisita(elenco, 0, 1).map((v) => v.id), ['b', 'a', 'c']);
      expect(spostaVisita(elenco, 2, -1).map((v) => v.id), ['a', 'c', 'b']);
    });

    test('ai bordi la lista resta invariata', () {
      final elenco = [
        visita(id: 'a', ordine: 0),
        visita(id: 'b', ordine: 1),
      ];

      expect(spostaVisita(elenco, 0, -1).map((v) => v.id), ['a', 'b']);
      expect(spostaVisita(elenco, 1, 1).map((v) => v.id), ['a', 'b']);
      expect(spostaVisita(elenco, 9, 1).map((v) => v.id), ['a', 'b']);
    });

    test('gli ordini salvati ripartono da zero', () {
      final elenco = [
        visita(id: 'a'),
        visita(id: 'b'),
        visita(id: 'c'),
      ];

      final ordini = ordiniVisite(elenco);
      expect(ordini.map((o) => o.id), ['a', 'b', 'c']);
      expect(ordini.map((o) => o.ordine), [0, 1, 2]);
    });
  });

  group('messaggioErroreVisite', () {
    test('permessi negati spiega il problema', () {
      final errore = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      expect(messaggioErroreVisite(errore), contains('Non hai i permessi'));
    });

    test('errore generico invita a riprovare', () {
      expect(
        messaggioErroreVisite(Exception('rete')),
        contains('connessione e riprova'),
      );
    });
  });

  group('ElencoVisite', () {
    Future<void> mostraElenco(
      WidgetTester tester, {
      List<Visita> visite = const [],
      bool caricamento = false,
      Object? errore,
      bool largo = false,
      VoidCallback? onRiprova,
      VoidCallback? onNuova,
      ValueChanged<Visita>? onModifica,
      void Function(int, int)? onSposta,
      bool attendi = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ElencoVisite(
              visite: visite,
              caricamento: caricamento,
              errore: errore,
              largo: largo,
              onRiprova: onRiprova ?? () {},
              onNuova: onNuova ?? () {},
              onModifica: onModifica ?? (_) {},
              onElimina: (_) {},
              onSposta: onSposta ?? (_, _) {},
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

    testWidgets('mostra lo stato vuoto con il pulsante Nuova visita',
        (tester) async {
      var nuove = 0;
      await mostraElenco(tester, onNuova: () => nuove++);

      expect(find.text('Nessuna visita'), findsOneWidget);
      expect(find.text('Nuova visita'), findsOneWidget);

      await tester.tap(find.byKey(const Key('visite-nuova-vuoto')));
      expect(nuove, 1);
    });

    testWidgets('mostra lo stato di caricamento', (tester) async {
      await mostraElenco(tester, caricamento: true, attendi: false);

      expect(find.byKey(const Key('visite-caricamento')), findsOneWidget);
      expect(find.text('Nessuna visita'), findsNothing);
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

      expect(find.text('Visite non disponibili'), findsOneWidget);
      expect(find.textContaining('Non hai i permessi'), findsOneWidget);

      await tester.tap(find.byKey(const Key('visite-riprova')));
      expect(riprove, 1);
    });

    testWidgets('su telefono mostra una card per visita', (tester) async {
      Visita? aperta;
      await mostraElenco(
        tester,
        visite: [
          visita(stato: 'fatto', note: 'Portare campioni'),
          visita(id: 'v2', cliente: 'Rossi Impianti', ordine: 1),
        ],
        onModifica: (v) => aperta = v,
      );

      expect(find.byKey(const Key('lista-visite')), findsOneWidget);
      expect(find.byKey(const Key('tabella-visite')), findsNothing);
      expect(find.text('09:30'), findsNWidgets(2));
      expect(find.text('ACME Srl'), findsOneWidget);
      expect(find.text('Fatto'), findsOneWidget);
      expect(find.text('Da fare'), findsOneWidget);
      expect(find.text('Portare campioni'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('visita-v1')));
      expect(aperta?.id, 'v1');
    });

    testWidgets('le frecce spostano la visita di una posizione',
        (tester) async {
      final chiamate = <(int, int)>[];
      await mostraElenco(
        tester,
        visite: [
          visita(),
          visita(id: 'v2', cliente: 'Rossi Impianti', ordine: 1),
        ],
        onSposta: (indice, scarto) => chiamate.add((indice, scarto)),
      );

      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('visita-su-v1')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const ValueKey('visita-giu-v1')));
      expect(chiamate, [(0, 1)]);
    });

    testWidgets('da 600 px mostra la tabella', (tester) async {
      await mostraElenco(
        tester,
        visite: [visita()],
        largo: true,
      );

      expect(find.byKey(const Key('tabella-visite')), findsOneWidget);
      expect(find.byKey(const Key('lista-visite')), findsNothing);
      expect(find.text('Ora'), findsOneWidget);
      expect(find.text('Cliente'), findsOneWidget);
      expect(find.text('Stato'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);
    });
  });
}
