import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/bando.dart';
import 'package:commerciali_app/features/bandi/bandi_screen.dart';

void main() {
  Bando bando({
    String id = 'b1',
    String? titolo = 'Voucher Digitalizzazione PMI',
    String? descrizione = 'Contributo a fondo perduto per software gestionale',
    String? dataChiusura = '2026-12-31',
    String? stato = 'attivo',
    List<String> regioni = const ['lombardia'],
    bool tutteRegioni = false,
    List<String> codiciAteco = const [],
    bool tuttiAteco = false,
    String? fonte = 'incentivi.gov.it',
    String? linkUfficiale,
    num? agevolazioneMin,
    num? agevolazioneMax,
  }) {
    return Bando(
      id: id,
      titolo: titolo,
      descrizione: descrizione,
      dataChiusura: dataChiusura,
      stato: stato,
      regioni: regioni,
      tutteRegioni: tutteRegioni,
      codiciAteco: codiciAteco,
      tuttiAteco: tuttiAteco,
      fonte: fonte,
      linkUfficiale: linkUfficiale,
      agevolazioneMin: agevolazioneMin,
      agevolazioneMax: agevolazioneMax,
    );
  }

  group('etichette bando', () {
    test('traduce gli stati noti', () {
      expect(etichettaStatoBando('attivo'), 'Attivo');
      expect(etichettaStatoBando('in_scadenza'), 'In scadenza');
      expect(etichettaStatoBando('permanente'), 'Permanente');
    });

    test('stato assente o sconosciuto resta leggibile', () {
      expect(etichettaStatoBando(null), '—');
      expect(etichettaStatoBando('  '), '—');
      expect(etichettaStatoBando('sospeso'), 'sospeso');
    });

    test('regione con iniziale maiuscola e senza duplicati', () {
      expect(etichettaRegione('lombardia'), 'Lombardia');
      expect(
        regioniDisponibili([
          bando(regioni: const ['lombardia', 'veneto']),
          bando(id: 'b2', regioni: const ['Lombardia', 'piemonte']),
        ]),
        ['Lombardia', 'Piemonte', 'Veneto'],
      );
    });
  });

  group('formati bando', () {
    test('data ISO in formato italiano', () {
      expect(formattaDataBando('2026-12-31'), '31/12/2026');
      expect(formattaDataBando('2026-01-05T10:00:00Z'), '05/01/2026');
      expect(formattaDataBando(null), '—');
      expect(formattaDataBando(''), '—');
      expect(formattaDataBando('31/12/2026'), '31/12/2026');
    });

    test('importo in euro con formato italiano', () {
      expect(formattaImportoBando(50000), contains('50.000'));
      expect(formattaImportoBando(50000), contains('€'));
      expect(formattaImportoBando(null), '—');
    });

    test('link ufficiale solo http/https', () {
      expect(
        uriUfficialeBando(bando(linkUfficiale: 'https://example.com/bando')),
        Uri.parse('https://example.com/bando'),
      );
      expect(uriUfficialeBando(bando(linkUfficiale: null)), isNull);
      expect(uriUfficialeBando(bando(linkUfficiale: '  ')), isNull);
      expect(
        uriUfficialeBando(bando(linkUfficiale: 'javascript:alert(1)')),
        isNull,
      );
    });
  });

  group('matchAtecoBando', () {
    test('codice ATECO vuoto tiene tutti i bandi', () {
      expect(matchAtecoBando(bando(codiciAteco: const ['62']), ''), isTrue);
    });

    test('bando aperto a tutti o senza codici è sempre compatibile', () {
      final tutti = bando(tuttiAteco: true);
      final senzaCodici = bando(codiciAteco: const []);
      expect(matchAtecoBando(tutti, '62.01'), isTrue);
      expect(matchAtecoBando(senzaCodici, '62.01'), isTrue);
      expect(
        matchAtecoBando(bando(codiciAteco: const ['62'], tuttiAteco: true), '43'),
        isTrue,
      );
    });

    test('combacia sul prefisso di 2 caratteri', () {
      final b = bando(codiciAteco: const [' 62.01 ', '63.11']);
      expect(matchAtecoBando(b, '62'), isTrue);
      expect(matchAtecoBando(b, '6201'), isTrue);
      expect(matchAtecoBando(b, '631'), isTrue);
    });

    test('codice diverso non combacia', () {
      final b = bando(codiciAteco: const ['62.01']);
      expect(matchAtecoBando(b, '43'), isFalse);
      expect(matchAtecoBando(b, '61.90'), isFalse);
    });
  });

  group('filtraBandi', () {
    final elenco = [
      bando(id: 'digitale', titolo: 'Voucher digitalizzazione'),
      bando(
        id: 'ristorazione',
        titolo: 'Bonus ristorazione',
        descrizione: 'Nuovi forni per PMI',
        stato: 'in_scadenza',
        regioni: const ['veneto'],
      ),
      bando(
        id: 'nazionale',
        titolo: 'Incentivo nazionale',
        descrizione: 'Aperto a tutte le imprese',
        regioni: const [],
        tutteRegioni: true,
      ),
    ];

    test('senza filtri restituisce tutto', () {
      expect(filtraBandi(elenco).map((b) => b.id), [
        'digitale',
        'ristorazione',
        'nazionale',
      ]);
    });

    test('cerca in titolo e descrizione senza maiuscole', () {
      expect(filtraBandi(elenco, testo: 'VOUCHER').map((b) => b.id), [
        'digitale',
      ]);
      expect(filtraBandi(elenco, testo: 'forni').map((b) => b.id), [
        'ristorazione',
      ]);
    });

    test('filtra per stato', () {
      expect(filtraBandi(elenco, stato: 'in_scadenza').map((b) => b.id), [
        'ristorazione',
      ]);
      expect(filtraBandi(elenco, stato: 'attivo').map((b) => b.id), [
        'digitale',
        'nazionale',
      ]);
    });

    test('filtra per regione e tiene i bandi nazionali', () {
      expect(filtraBandi(elenco, regione: 'Veneto').map((b) => b.id), [
        'ristorazione',
        'nazionale',
      ]);
      expect(filtraBandi(elenco, regione: 'lombardia').map((b) => b.id), [
        'digitale',
        'nazionale',
      ]);
    });

    test('combina i filtri', () {
      expect(
        filtraBandi(elenco, testo: 'bonus', stato: 'attivo').map((b) => b.id),
        isEmpty,
      );
    });

    test('filtra per ATECO e tiene i bandi aperti a tutti', () {
      final conAteco = [
        bando(id: 'digitale', codiciAteco: const ['62.01', '62.02']),
        bando(id: 'commercio', codiciAteco: const ['47.11']),
        bando(id: 'nazionale', tuttiAteco: true),
        bando(id: 'senza-codici'),
      ];

      expect(filtraBandi(conAteco, ateco: '62').map((b) => b.id), [
        'digitale',
        'nazionale',
        'senza-codici',
      ]);
      expect(filtraBandi(conAteco, ateco: '47').map((b) => b.id), [
        'commercio',
        'nazionale',
        'senza-codici',
      ]);
      expect(filtraBandi(conAteco, ateco: '43').map((b) => b.id), [
        'nazionale',
        'senza-codici',
      ]);
    });
  });

  group('scadenzaImminente', () {
    final oggi = DateTime(2026, 10, 22);

    test('vero entro 30 giorni', () {
      expect(
        scadenzaImminente(bando(dataChiusura: '2026-11-10'), oggi: oggi),
        isTrue,
      );
      expect(
        scadenzaImminente(bando(dataChiusura: '2026-10-22'), oggi: oggi),
        isTrue,
      );
    });

    test('falso oltre 30 giorni, passata o assente', () {
      expect(
        scadenzaImminente(bando(dataChiusura: '2027-01-15'), oggi: oggi),
        isFalse,
      );
      expect(
        scadenzaImminente(bando(dataChiusura: '2026-10-01'), oggi: oggi),
        isFalse,
      );
      expect(scadenzaImminente(bando(dataChiusura: null), oggi: oggi), isFalse);
    });
  });

  group('messaggioErroreBandi', () {
    test('permessi negati spiega il problema', () {
      final errore = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      expect(messaggioErroreBandi(errore), contains('Non hai i permessi'));
    });

    test('errore generico invita a riprovare', () {
      expect(
        messaggioErroreBandi(Exception('rete')),
        contains('Controlla la connessione'),
      );
    });
  });

  group('ElencoBandi', () {
    Future<void> mostraElenco(
      WidgetTester tester, {
      List<Bando> bandi = const [],
      bool caricamento = false,
      Object? errore,
      bool largo = false,
      bool filtriAttivi = false,
      VoidCallback? onRiprova,
      VoidCallback? onAzzeraFiltri,
      ValueChanged<Bando>? onApri,
      bool attendi = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ElencoBandi(
              bandi: bandi,
              caricamento: caricamento,
              errore: errore,
              largo: largo,
              filtriAttivi: filtriAttivi,
              onRiprova: onRiprova ?? () {},
              onAzzeraFiltri: onAzzeraFiltri,
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

    testWidgets('mostra lo stato vuoto senza bandi', (tester) async {
      await mostraElenco(tester);

      expect(find.text('Nessun bando'), findsOneWidget);
      expect(find.text('Nessun bando trovato'), findsNothing);
    });

    testWidgets('mostra lo stato "nessun risultato" con i filtri attivi',
        (tester) async {
      var azzerati = 0;
      await mostraElenco(
        tester,
        filtriAttivi: true,
        onAzzeraFiltri: () => azzerati++,
      );

      expect(find.text('Nessun bando trovato'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bandi-azzera-filtri')));
      expect(azzerati, 1);
    });

    testWidgets('mostra lo stato di caricamento', (tester) async {
      await mostraElenco(tester, caricamento: true, attendi: false);

      expect(find.byKey(const Key('bandi-caricamento')), findsOneWidget);
      expect(find.text('Nessun bando'), findsNothing);
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

      expect(find.text('Bandi non disponibili'), findsOneWidget);
      expect(find.textContaining('Non hai i permessi'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bandi-riprova')));
      expect(riprove, 1);
    });

    testWidgets('su telefono mostra una card per bando', (tester) async {
      Bando? aperto;
      await mostraElenco(
        tester,
        bandi: [
          bando(stato: 'in_scadenza', dataChiusura: '2026-11-10'),
          bando(id: 'b2', titolo: 'Bonus ristorazione', stato: 'attivo'),
        ],
        onApri: (b) => aperto = b,
      );

      expect(find.byKey(const Key('lista-bandi')), findsOneWidget);
      expect(find.byKey(const Key('tabella-bandi')), findsNothing);
      expect(find.text('Voucher Digitalizzazione PMI'), findsOneWidget);
      expect(find.text('In scadenza'), findsOneWidget);
      expect(find.text('10/11/2026'), findsOneWidget);
      expect(find.text('incentivi.gov.it'), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('bando-b1')));
      expect(aperto?.id, 'b1');
    });

    testWidgets('da 600 px mostra la tabella', (tester) async {
      await mostraElenco(tester, bandi: [bando()], largo: true);

      expect(find.byKey(const Key('tabella-bandi')), findsOneWidget);
      expect(find.byKey(const Key('lista-bandi')), findsNothing);
      expect(find.text('Titolo'), findsOneWidget);
      expect(find.text('Scadenza'), findsOneWidget);
      expect(find.text('Fonte'), findsOneWidget);
    });
  });

  group('BandoDettaglioDialog', () {
    Future<void> mostraDialogo(WidgetTester tester, Bando bando) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BandoDettaglioDialog(bando: bando),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('mostra descrizione, importi e link ufficiale',
        (tester) async {
      await mostraDialogo(
        tester,
        bando(
          linkUfficiale: 'https://example.com/bando',
          agevolazioneMin: 5000,
          agevolazioneMax: 50000,
        ),
      );

      expect(
        find.textContaining('Contributo a fondo perduto'),
        findsOneWidget,
      );
      expect(find.textContaining('Da'), findsWidgets);
      expect(find.byKey(const Key('apri-link-bando')), findsOneWidget);
      expect(find.text('Apri link ufficiale'), findsOneWidget);
    });

    testWidgets('senza link valido non mostra il pulsante', (tester) async {
      await mostraDialogo(tester, bando(linkUfficiale: 'javascript:alert(1)'));

      expect(find.byKey(const Key('apri-link-bando')), findsNothing);
      expect(find.text('Nessuna descrizione disponibile.'), findsNothing);
    });
  });
}
