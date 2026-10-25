import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/preventivo.dart';
import 'package:commerciali_app/data/services/sp_service.dart';
import 'package:commerciali_app/features/preventivi/preventivi_screen.dart';
import 'package:commerciali_app/state/azienda_providers.dart';

/// Servizio dati finto per la schermata dei preventivi.
///
/// Solo i metodi usati dalla schermata sono implementati davvero; gli altri
/// passano da `noSuchMethod` e fallirebbero il test, così nessuna chiamata a
/// Firebase può passare inosservata.
class _ServizioPreventiviFinto implements SpService {
  _ServizioPreventiviFinto(this.preventivi);

  final List<Preventivo> preventivi;

  @override
  void setAziendaAttiva(String? id) {}

  @override
  Future<List<Preventivo>> getPreventivi({String? soloUtenteId}) async =>
      preventivi;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  group('PreventiviScreen: apertura dall\'elenco', () {
    /// Monta la schermata vera su un router minimo: l'elenco su `/preventivi`,
    /// poi le rotte dell'editor (nuovo e per id) che mostrano un testo
    /// riconoscibile al posto della schermata vera, così il test non tocca
    /// Firebase.
    Future<void> mostraSchermata(
      WidgetTester tester, {
      required List<Preventivo> preventivi,
    }) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/preventivi',
        routes: [
          GoRoute(
            path: '/preventivi',
            builder: (context, state) =>
                const Scaffold(body: PreventiviScreen()),
          ),
          GoRoute(
            path: '/preventivi/nuovo',
            builder: (context, state) =>
                const Scaffold(body: Text('EDITOR NUOVO')),
          ),
          GoRoute(
            path: '/preventivi/:id',
            builder: (context, state) =>
                Scaffold(body: Text('EDITOR ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spServiceProvider.overrideWith(
              (ref) => _ServizioPreventiviFinto(preventivi),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('cliccando una riga apre l\'editor del preventivo scelto',
        (tester) async {
      await mostraSchermata(
        tester,
        preventivi: [
          preventivo(id: 'p1', numero: 'PRV-0001'),
          preventivo(
            id: 'p2',
            numero: 'PRV-0002',
            cliente: 'Rossi Impianti',
            stato: 'inviato',
          ),
        ],
      );

      expect(find.byKey(const Key('lista-preventivi')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('preventivo-p2')));
      await tester.pumpAndSettle();

      expect(find.text('EDITOR p2'), findsOneWidget);
      expect(find.text('EDITOR NUOVO'), findsNothing);
    });

    testWidgets('preventivo senza id resta sull\'elenco senza crash',
        (tester) async {
      await mostraSchermata(
        tester,
        preventivi: [preventivo(id: '', numero: 'PRV-0003')],
      );

      await tester.tap(find.byKey(const ValueKey('preventivo-')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lista-preventivi')), findsOneWidget);
      expect(find.text('EDITOR NUOVO'), findsNothing);
      expect(find.textContaining('EDITOR '), findsNothing);
    });
  });
}
