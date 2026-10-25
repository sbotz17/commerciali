import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/appuntamento.dart';
import 'package:commerciali_app/data/models/cliente.dart';
import 'package:commerciali_app/data/models/task_item.dart';
import 'package:commerciali_app/features/calendario/calendario_screen.dart';

/// Test delle funzioni pure del calendario e dello stato vuoto della vista
/// giorno. Non serve Firebase: il corpo è un widget senza provider.
void main() {
  Appuntamento appuntamento({
    String id = 'a1',
    String? data = '2026-10-24',
    String? ora = '09:30',
    String? titolo = 'Visita ACME',
    String? operatoreId,
    String? clienteNome,
    String stato = 'da_fare',
    int durataMin = 60,
    List<String> invitatiUids = const [],
    Map<String, dynamic> conferme = const {},
    String statoCondivisione = statoCondivisioneNonCondiviso,
    Map<String, dynamic> promemoriaCliente = const {},
  }) {
    return Appuntamento(
      id: id,
      data: data,
      ora: ora,
      titolo: titolo,
      operatoreId: operatoreId,
      clienteNome: clienteNome,
      stato: stato,
      durataMin: durataMin,
      invitatiUids: invitatiUids,
      conferme: conferme,
      statoCondivisione: statoCondivisione,
      promemoriaCliente: promemoriaCliente,
    );
  }

  TaskItem task({
    String id = 't1',
    String? scadenzaData = '2026-10-24',
    String? scadenzaOra = '11:00',
    String? titolo = 'Richiamare cliente',
    String? operatoreId,
    String? clienteNome,
    String stato = 'aperto',
  }) {
    return TaskItem(
      id: id,
      scadenzaData: scadenzaData,
      scadenzaOra: scadenzaOra,
      titolo: titolo,
      operatoreId: operatoreId,
      clienteNome: clienteNome,
      stato: stato,
    );
  }

  group('elementiDaAppuntamenti', () {
    test('converte data, ora, titolo e tipo', () {
      final elementi = elementiDaAppuntamenti([appuntamento()]);

      expect(elementi, hasLength(1));
      final elemento = elementi.single;
      expect(elemento.data, '2026-10-24');
      expect(elemento.ora, '09:30');
      expect(elemento.titolo, 'Visita ACME');
      expect(elemento.tipo, tipoAppuntamento);
      expect(elemento.isAppuntamento, isTrue);
      expect(elemento.appuntamento?.id, 'a1');
      expect(elemento.task, isNull);
    });

    test('scarta gli appuntamenti senza data', () {
      final elementi = elementiDaAppuntamenti([
        appuntamento(id: 'a1', data: null),
        appuntamento(id: 'a2', data: '   '),
        appuntamento(id: 'a3'),
      ]);

      expect(elementi.map((elemento) => elemento.appuntamento?.id), ['a3']);
    });

    test('ora assente o non valida e titolo vuoto ricadono sui default', () {
      final elementi = elementiDaAppuntamenti([
        appuntamento(ora: null, titolo: '  '),
        appuntamento(id: 'a2', ora: '9:5'),
        appuntamento(id: 'a3', ora: '25:00'),
      ]);

      expect(elementi[0].ora, isNull);
      expect(elementi[0].titolo, 'Appuntamento');
      expect(elementi[1].ora, '09:05');
      expect(elementi[2].ora, '25:00');
    });
  });

  group('elementiDaTask', () {
    test('converte solo i task con scadenza', () {
      final elementi = elementiDaTask([
        task(),
        task(id: 't2', scadenzaData: null),
        task(id: 't3', scadenzaData: ''),
        task(id: 't4', scadenzaOra: null, scadenzaData: '2026-10-25'),
      ]);

      expect(elementi, hasLength(2));
      expect(elementi[0].appuntamento, isNull);
      expect(elementi[0].task?.id, 't1');
      expect(elementi[0].tipo, tipoTask);
      expect(elementi[0].isAppuntamento, isFalse);
      expect(elementi[0].ora, '11:00');
      expect(elementi[1].task?.id, 't4');
      expect(elementi[1].ora, isNull);
    });

    test('titolo vuoto ricade su Task', () {
      final elementi = elementiDaTask([task(titolo: '   ')]);
      expect(elementi.single.titolo, 'Task');
    });
  });

  group('raggruppaPerGiorno', () {
    test('raggruppa per giorno e ordina per ora', () {
      final elementi = [
        ...elementiDaAppuntamenti([
          appuntamento(id: 'a1', ora: '15:00'),
          appuntamento(id: 'a2', ora: null),
          appuntamento(id: 'a3', ora: '08:30'),
          appuntamento(id: 'a4', data: '2026-10-25', ora: '10:00'),
        ]),
        ...elementiDaTask([task(id: 't1', scadenzaOra: '09:15')]),
      ];

      final gruppi = raggruppaPerGiorno(elementi);

      expect(gruppi.keys.toList(), ['2026-10-24', '2026-10-25']);
      expect(gruppi['2026-10-24']!.map((elemento) => elemento.ora), [
        '08:30',
        '09:15',
        '15:00',
        null,
      ]);
      expect(gruppi['2026-10-25'], hasLength(1));
    });

    test('a parità di ora ordina per titolo', () {
      final gruppi = raggruppaPerGiorno([
        ...elementiDaAppuntamenti([
          appuntamento(id: 'a1', ora: '09:00', titolo: 'Zeta'),
          appuntamento(id: 'a2', ora: '09:00', titolo: 'alfa'),
        ]),
      ]);

      expect(gruppi['2026-10-24']!.map((elemento) => elemento.titolo), [
        'alfa',
        'Zeta',
      ]);
    });

    test('elenco vuoto produce una mappa vuota', () {
      expect(raggruppaPerGiorno(const []), isEmpty);
    });
  });

  group('giorniSettimana', () {
    test('parte dal lunedì e finisce alla domenica', () {
      final giorni = giorniSettimana(DateTime(2026, 10, 21)); // mercoledì

      expect(giorni, hasLength(7));
      expect(giorni.first, DateTime(2026, 10, 19));
      expect(giorni.last, DateTime(2026, 10, 25));
      expect(giorni.map((giorno) => giorno.weekday), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('funziona a cavallo di fine mese', () {
      final giorni = giorniSettimana(DateTime(2026, 11, 1)); // domenica

      expect(giorni.first, DateTime(2026, 10, 26));
      expect(giorni.last, DateTime(2026, 11, 1));
    });
  });

  group('etichettaGiorno', () {
    final oggi = DateTime(2026, 10, 24);

    test('oggi e domani', () {
      expect(etichettaGiorno(oggi, oggi: oggi), 'Oggi');
      expect(etichettaGiorno(DateTime(2026, 10, 25), oggi: oggi), 'Domani');
    });

    test('le altre date usano gg/mm/aaaa', () {
      expect(etichettaGiorno(DateTime(2026, 11, 1), oggi: oggi), '01/11/2026');
      expect(etichettaGiorno(DateTime(2026, 1, 5), oggi: oggi), '05/01/2026');
    });
  });

  group('etichette di stato', () {
    test('appuntamento e task usano le rispettive etichette', () {
      final appuntamentoFatto = elementiDaAppuntamenti([
        appuntamento(stato: 'fatto'),
      ]).single;
      final taskAperto = elementiDaTask([task()]).single;
      final taskCompletato = elementiDaTask([task(stato: 'completato')]).single;

      expect(etichettaStatoElemento(appuntamentoFatto), 'Fatto');
      expect(etichettaStatoElemento(taskAperto), 'Da fare');
      expect(etichettaStatoElemento(taskCompletato), 'Completato');
      expect(coloreStatoElemento(appuntamentoFatto), AppColors.accettato);
      expect(coloreStatoElemento(taskAperto), AppColors.attesa);
    });

    test('dettaglio con cliente e operatore', () {
      final elemento = elementiDaAppuntamenti([
        appuntamento(clienteNome: 'ACME Srl', operatoreId: 'u1'),
      ]).single;

      expect(
        dettaglioElemento(elemento, {'u1': 'Mario Rossi'}),
        'ACME Srl · Mario Rossi',
      );
      expect(dettaglioElemento(elemento, const {}), 'ACME Srl');
    });

    test('la condivisione mostra un badge solo quando è attiva', () {
      final nonCondiviso = elementiDaAppuntamenti([appuntamento()]).single;
      final inAttesa = elementiDaAppuntamenti([
        appuntamento(
          invitatiUids: const ['u1'],
          statoCondivisione: statoCondivisioneInAttesa,
        ),
      ]).single;
      final confermato = elementiDaAppuntamenti([
        appuntamento(
          invitatiUids: const ['u1'],
          conferme: const {
            'u1': {'stato': 'confermato'},
          },
          statoCondivisione: statoCondivisioneConfermato,
        ),
      ]).single;

      expect(etichettaCondivisioneElemento(nonCondiviso), isNull);
      expect(etichettaCondivisioneElemento(inAttesa), 'In attesa di conferma');
      expect(etichettaCondivisioneElemento(confermato), 'Confermato');
      expect(coloreCondivisioneElemento(inAttesa), AppColors.attesa);
      expect(coloreCondivisioneElemento(confermato), AppColors.accettato);
    });
  });

  testWidgets('la vista giorno vuota mostra "Nessun appuntamento"', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CorpoCalendario(
            elementi: const [],
            giorno: DateTime(2026, 10, 24),
            vista: VistaAgenda.giorno,
            aCard: true,
            caricamento: false,
            onRiprova: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendario-vuoto')), findsOneWidget);
    expect(find.text('Nessun appuntamento'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('la vista giorno mostra le voci del giorno', (tester) async {
    final elementi = [
      ...elementiDaAppuntamenti([appuntamento(ora: '09:30')]),
      ...elementiDaTask([task()]),
      ...elementiDaAppuntamenti([appuntamento(id: 'a9', data: '2026-10-30')]),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CorpoCalendario(
            elementi: elementi,
            giorno: DateTime(2026, 10, 24),
            vista: VistaAgenda.giorno,
            aCard: true,
            caricamento: false,
            onRiprova: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visita ACME'), findsOneWidget);
    expect(find.text('Richiamare cliente'), findsOneWidget);
    expect(find.byKey(const Key('calendario-vuoto')), findsNothing);
  });

  group('periodi del calendario', () {
    test('la vista predefinita è il calendario mensile', () {
      expect(stileAgendaPredefinito, StileAgenda.calendario);
      expect(vistaAgendaPredefinita, VistaAgenda.mese);
    });

    test('etichettaPeriodo per giorno, settimana e mese', () {
      final giorno = DateTime(2099, 10, 24);

      expect(etichettaPeriodo(VistaAgenda.giorno, giorno), '24/10/2099');
      expect(
        etichettaPeriodo(VistaAgenda.settimana, giorno),
        '19/10/2099 – 25/10/2099',
      );
      expect(etichettaPeriodo(VistaAgenda.mese, giorno), 'Ottobre 2099');
    });

    test('spostaPeriodo rispetta giorno, settimana e mese', () {
      final giorno = DateTime(2026, 1, 31);

      expect(
        spostaPeriodo(VistaAgenda.giorno, giorno, 1),
        DateTime(2026, 2, 1),
      );
      expect(
        spostaPeriodo(VistaAgenda.settimana, giorno, -1),
        DateTime(2026, 1, 24),
      );
      expect(spostaPeriodo(VistaAgenda.mese, giorno, 1), DateTime(2026, 2, 1));
    });

    test('la griglia del mese parte dal lunedì e contiene tutto il mese', () {
      final giorni = giorniGrigliaMese(DateTime(2026, 10, 15));

      expect(giorni.first.weekday, DateTime.monday);
      expect(giorni.first, DateTime(2026, 9, 28));
      expect(giorni.last, DateTime(2026, 11, 1));
      expect(giorni.length % 7, 0);
      expect(giorni, contains(DateTime(2026, 10, 31)));
      expect(giorni, isNot(contains(DateTime(2026, 11, 2))));
    });

    test('elementiNelPeriodo filtra giorno, settimana e mese', () {
      final elementi = [
        ...elementiDaAppuntamenti([
          appuntamento(id: 'a1', data: '2026-10-24', ora: '09:00'),
          appuntamento(id: 'a2', data: '2026-10-20', ora: '10:00'),
          appuntamento(id: 'a3', data: '2026-11-02', ora: '11:00'),
        ]),
      ];

      expect(
        elementiNelPeriodo(
          elementi,
          VistaAgenda.giorno,
          DateTime(2026, 10, 24),
        ),
        hasLength(1),
      );
      expect(
        elementiNelPeriodo(
          elementi,
          VistaAgenda.settimana,
          DateTime(2026, 10, 24),
        ),
        hasLength(2),
      );
      expect(
        elementiNelPeriodo(elementi, VistaAgenda.mese, DateTime(2026, 10, 1)),
        hasLength(2),
      );
    });
  });

  group('griglia oraria', () {
    test('minutiDaOra normalizza e scarta le ore non valide', () {
      expect(minutiDaOra('9:05'), 9 * 60 + 5);
      expect(minutiDaOra('09:30'), 570);
      expect(minutiDaOra(null), isNull);
      expect(minutiDaOra('25:00'), isNull);
      expect(minutiDaOra('testo'), isNull);
    });

    test('durataMinutiElemento usa la durata o il default', () {
      final appuntamentoLungo = elementiDaAppuntamenti([
        appuntamento(durataMin: 90),
      ]).single;
      final appuntamentoSenzaDurata = elementiDaAppuntamenti([
        appuntamento(durataMin: 0),
      ]).single;
      final taskSenzaDurata = elementiDaTask([task()]).single;

      expect(durataMinutiElemento(appuntamentoLungo), 90);
      expect(durataMinutiElemento(appuntamentoSenzaDurata), 30);
      expect(durataMinutiElemento(taskSenzaDurata), 30);
    });

    test('disponiVociGiorno affianca le voci sovrapposte', () {
      final voci = disponiVociGiorno(
        elementiDaAppuntamenti([
          appuntamento(id: 'a1', ora: '09:00', durataMin: 60),
          appuntamento(id: 'a2', ora: '09:30', durataMin: 60),
          appuntamento(id: 'a3', ora: '11:00', durataMin: 30),
        ]),
      );

      final prima = voci.firstWhere(
        (voce) => voce.elemento.appuntamento?.id == 'a1',
      );
      final seconda = voci.firstWhere(
        (voce) => voce.elemento.appuntamento?.id == 'a2',
      );
      final terza = voci.firstWhere(
        (voce) => voce.elemento.appuntamento?.id == 'a3',
      );

      expect(prima.corsie, 2);
      expect(seconda.corsie, 2);
      expect({prima.corsia, seconda.corsia}, {0, 1});
      expect(terza.corsie, 1);
      expect(voci.first.inizio, 9 * 60);
    });

    test('le voci senza ora restano fuori dalla griglia', () {
      final elementi = elementiDaAppuntamenti([
        appuntamento(ora: null),
        appuntamento(id: 'a2', ora: '09:00'),
      ]);

      expect(disponiVociGiorno(elementi), hasLength(1));
      expect(vociSenzaOrario(elementi), hasLength(1));
      expect(vociConOrario(elementi), hasLength(1));
    });

    test('intervalloOrarioElementi include le voci fuori orario standard', () {
      expect(intervalloOrarioElementi(const []), (
        inizio: 7 * 60,
        fine: 21 * 60,
      ));
      expect(
        intervalloOrarioElementi(
          elementiDaAppuntamenti([
            appuntamento(ora: '06:15', durataMin: 30),
            appuntamento(id: 'a2', ora: '22:00', durataMin: 90),
          ]),
        ),
        (inizio: 6 * 60, fine: 24 * 60),
      );
    });
  });

  group('dettaglio appuntamento', () {
    Future<void> mostraDettaglio(
      WidgetTester tester, {
      Size dimensione = const Size(390, 844),
      String? uidCorrente = 'u1',
    }) async {
      tester.view.physicalSize = dimensione;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final elemento = elementiDaAppuntamenti([
        appuntamento(
          invitatiUids: const ['u1', 'u2'],
          conferme: const {
            'u1': {'stato': 'confermato'},
          },
          statoCondivisione: statoCondivisioneInAttesa,
          promemoriaCliente: const {
            'inviato_at': '2026-10-25T08:00:00.000Z',
            'canali': {
              'whatsapp': {'stato': 'inviato'},
              'email': {'stato': 'inviato'},
            },
          },
        ),
      ]).single;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => DettaglioElementoDialog(
                      elemento: elemento,
                      nomiOperatori: const {'u1': 'Andrea', 'u2': 'Simone'},
                      uidCorrente: uidCorrente,
                      cliente: const Cliente(
                        id: 'c1',
                        nome: 'ACME',
                        referente: 'Rossi',
                        telefono: '021234',
                        email: 'info@acme.it',
                        piva: '12345678901',
                        indirizzo: 'Via Roma',
                        civico: '1',
                        cap: '20100',
                        citta: 'Milano',
                        provincia: 'MI',
                      ),
                    ),
                  ),
                  child: const Text('Apri'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri'));
      await tester.pumpAndSettle();
    }

    testWidgets('su telefono azioni impilate, allineate e senza overflow', (
      tester,
    ) async {
      await mostraDettaglio(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('calendario-dettaglio')), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const Key('calendario-dettaglio-contenuto')))
            .width,
        366,
      );
      expect(find.text('Panoramica'), findsOneWidget);
      expect(find.text('Cliente'), findsOneWidget);
      expect(find.text('Condivisione'), findsOneWidget);
      expect(find.text('ACME'), findsNothing);
      expect(find.text('Nome: ACME'), findsOneWidget);
      expect(find.text('Andrea'), findsOneWidget);
      expect(find.text('Simone'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.textSpan?.toPlainText() ?? widget.data ?? '').contains(
                'Promemoria cliente: Inviato su WhatsApp e Email',
              ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('calendario-invia-promemoria-cliente')),
        findsOneWidget,
      );

      final confermo = find.byKey(const Key('calendario-conferma-invito'));
      final rifiuta = find.byKey(const Key('calendario-rifiuta-invito'));
      final misuraConfermo = tester.getSize(confermo);
      final misuraRifiuta = tester.getSize(rifiuta);
      final posizioneConfermo = tester.getTopLeft(confermo);
      final posizioneRifiuta = tester.getTopLeft(rifiuta);

      // A tutta larghezza e con lo stesso bordo sinistro.
      expect(misuraConfermo.width, greaterThan(300));
      expect(misuraConfermo.width, misuraRifiuta.width);
      expect(posizioneConfermo.dx, posizioneRifiuta.dx);
      expect(posizioneRifiuta.dy, greaterThan(posizioneConfermo.dy));
      expect(tester.getBottomRight(rifiuta).dx, lessThanOrEqualTo(390));

      await tester.tap(find.byKey(const Key('calendario-chiudi')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('calendario-dettaglio')), findsNothing);
    });

    testWidgets('da tablet i due gruppi di azioni restano separati', (
      tester,
    ) async {
      await mostraDettaglio(tester, dimensione: const Size(900, 900));

      expect(tester.takeException(), isNull);
      final nonDisponibile = find.byKey(const Key('calendario-rifiuta-invito'));
      final elimina = find.byKey(const Key('calendario-elimina'));
      final confermo = find.byKey(const Key('calendario-conferma-invito'));
      final modifica = find.byKey(const Key('calendario-modifica'));

      // Prima riga: azioni secondarie. Seconda riga: azioni principali.
      expect(
        tester.getTopLeft(nonDisponibile).dy,
        tester.getTopLeft(elimina).dy,
      );
      expect(tester.getTopLeft(confermo).dy, tester.getTopLeft(modifica).dy);
      expect(
        tester.getTopLeft(confermo).dy,
        greaterThan(tester.getTopLeft(nonDisponibile).dy),
      );
      expect(tester.getTopRight(elimina).dx, closeTo(714, 1));
      expect(tester.getTopRight(modifica).dx, closeTo(714, 1));
    });

    testWidgets('da tablet il dettaglio è largo e le azioni sono a destra', (
      tester,
    ) async {
      // Utente non invitato: restano Modifica ed Elimina.
      await mostraDettaglio(
        tester,
        dimensione: const Size(900, 900),
        uidCorrente: 'u3',
      );

      expect(tester.takeException(), isNull);
      final contenuto = find.byKey(const Key('calendario-dettaglio-contenuto'));
      expect(tester.getSize(contenuto).width, 560);

      final modifica = find.byKey(const Key('calendario-modifica'));
      final elimina = find.byKey(const Key('calendario-elimina'));
      expect(tester.getTopLeft(modifica).dy, tester.getTopLeft(elimina).dy);
      expect(tester.getSize(modifica).width, lessThan(300));
      // L'ultima azione tocca il bordo destro del contenuto.
      expect(tester.getTopRight(modifica).dx, closeTo(900 - 170 - 16, 1));
    });
  });

  testWidgets('la vista mese mostra i giorni e le voci', (tester) async {
    final elementi = elementiDaAppuntamenti([
      appuntamento(titolo: 'Visita del mese', ora: '09:30'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: VistaMeseCalendario(
              mese: DateTime(2026, 10, 24),
              elementi: elementi,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendario-mese')), findsOneWidget);
    expect(find.text('LUN'), findsOneWidget);
    expect(find.text('Visita del mese'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
  });

  testWidgets('la vista giorno classica mostra eventi e senza orario', (
    tester,
  ) async {
    final elementi = [
      ...elementiDaAppuntamenti([
        appuntamento(titolo: 'Visita con orario', ora: '09:30'),
      ]),
      ...elementiDaTask([task(titolo: 'Task senza ora', scadenzaOra: null)]),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: VistaGrigliaOraria(
              giorni: [DateTime(2026, 10, 24)],
              elementi: elementi,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendario-griglia-giorno')), findsOneWidget);
    expect(find.text('Visita con orario'), findsOneWidget);
    expect(find.byKey(const Key('calendario-senza-orario')), findsOneWidget);
    expect(find.text('Task senza ora'), findsOneWidget);
  });

  testWidgets('la vista settimana classica mostra i sette giorni', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: VistaGrigliaOraria(
              giorni: giorniSettimana(DateTime(2026, 10, 24)),
              elementi: const [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendario-griglia-settimana')),
      findsOneWidget,
    );
    expect(find.text('LUN'), findsOneWidget);
    expect(find.text('DOM'), findsOneWidget);
  });
}
