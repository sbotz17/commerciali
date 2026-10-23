import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/appuntamento.dart';
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
  }) {
    return Appuntamento(
      id: id,
      data: data,
      ora: ora,
      titolo: titolo,
      operatoreId: operatoreId,
      clienteNome: clienteNome,
      stato: stato,
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
      final elementi = elementiDaAppuntamenti([
        appuntamento(),
      ]);

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
      expect(
        gruppi['2026-10-24']!.map((elemento) => elemento.ora),
        ['08:30', '09:15', '15:00', null],
      );
      expect(gruppi['2026-10-25'], hasLength(1));
    });

    test('a parità di ora ordina per titolo', () {
      final gruppi = raggruppaPerGiorno([
        ...elementiDaAppuntamenti([
          appuntamento(id: 'a1', ora: '09:00', titolo: 'Zeta'),
          appuntamento(id: 'a2', ora: '09:00', titolo: 'alfa'),
        ]),
      ]);

      expect(
        gruppi['2026-10-24']!.map((elemento) => elemento.titolo),
        ['alfa', 'Zeta'],
      );
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
      expect(
        etichettaGiorno(DateTime(2026, 10, 25), oggi: oggi),
        'Domani',
      );
    });

    test('le altre date usano gg/mm/aaaa', () {
      expect(
        etichettaGiorno(DateTime(2026, 11, 1), oggi: oggi),
        '01/11/2026',
      );
      expect(
        etichettaGiorno(DateTime(2026, 1, 5), oggi: oggi),
        '05/01/2026',
      );
    });
  });

  group('etichette di stato', () {
    test('appuntamento e task usano le rispettive etichette', () {
      final appuntamentoFatto = elementiDaAppuntamenti([
        appuntamento(stato: 'fatto'),
      ]).single;
      final taskAperto = elementiDaTask([task()]).single;
      final taskCompletato = elementiDaTask([
        task(stato: 'completato'),
      ]).single;

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

      expect(dettaglioElemento(elemento, {'u1': 'Mario Rossi'}),
          'ACME Srl · Mario Rossi');
      expect(dettaglioElemento(elemento, const {}), 'ACME Srl');
    });
  });

  testWidgets('la vista giorno vuota mostra "Nessun appuntamento"',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CorpoCalendario(
            elementi: const [],
            giorno: DateTime(2026, 10, 24),
            settimana: false,
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
      ...elementiDaAppuntamenti([
        appuntamento(id: 'a9', data: '2026-10-30'),
      ]),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CorpoCalendario(
            elementi: elementi,
            giorno: DateTime(2026, 10, 24),
            settimana: false,
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
}
