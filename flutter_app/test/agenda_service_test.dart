import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/appuntamento.dart';
import 'package:commerciali_app/data/models/task_item.dart';
import 'package:commerciali_app/data/services/sp_service.dart';

void main() {
  group('filtraAppuntamenti', () {
    final lista = [
      Appuntamento(
        id: 'a1',
        data: '2026-10-20',
        ora: '09:00',
        operatoreId: 'op-1',
      ),
      Appuntamento(
        id: 'a2',
        data: '2026-10-21',
        ora: '10:00',
        operatoreId: 'op-1',
      ),
      Appuntamento(
        id: 'a3',
        data: '2026-10-22',
        ora: '11:00',
        operatoreId: 'op-2',
      ),
      Appuntamento(
        id: 'a4',
        data: '2026-10-23',
        ora: '12:00',
        operatoreId: 'op-1',
      ),
    ];

    test('senza filtri restituisce tutti gli elementi', () {
      final risultato = filtraAppuntamenti(lista);
      expect(risultato.map((a) => a.id).toList(), ['a1', 'a2', 'a3', 'a4']);
    });

    test('filtra per intervallo di date (estremi inclusivi)', () {
      final risultato = filtraAppuntamenti(
        lista,
        dal: DateTime(2026, 10, 21),
        al: DateTime(2026, 10, 22, 23, 59),
      );
      expect(risultato.map((a) => a.id).toList(), ['a2', 'a3']);
    });

    test('filtra per operatore', () {
      final risultato = filtraAppuntamenti(lista, operatoreId: 'op-1');
      expect(risultato.map((a) => a.id).toList(), ['a1', 'a2', 'a4']);
    });

    test('filtra per intervallo e operatore insieme', () {
      final risultato = filtraAppuntamenti(
        lista,
        dal: DateTime(2026, 10, 20),
        al: DateTime(2026, 10, 22),
        operatoreId: 'op-1',
      );
      expect(risultato.map((a) => a.id).toList(), ['a1', 'a2']);
    });

    test('esclude gli appuntamenti senza data/ora valida se c\'è intervallo',
        () {
      final senzaData = [
        Appuntamento(id: 'x1', data: '2026-10-21', ora: '09:00'),
        Appuntamento(id: 'x2'), // nessuna data
        Appuntamento(id: 'x3', data: '2026-10-21'), // nessuna ora
      ];
      final risultato = filtraAppuntamenti(
        senzaData,
        dal: DateTime(2026, 10, 20),
        al: DateTime(2026, 10, 22),
      );
      expect(risultato.map((a) => a.id).toList(), ['x1']);
    });
  });

  group('filtraTask', () {
    final lista = [
      TaskItem(id: 't1', stato: 'aperto', operatoreId: 'op-1'),
      TaskItem(id: 't2', stato: 'completato', operatoreId: 'op-1'),
      TaskItem(id: 't3', stato: 'aperto', operatoreId: 'op-2'),
      TaskItem(id: 't4', stato: 'completato', operatoreId: 'op-2'),
    ];

    test('senza filtri restituisce tutti i task', () {
      final risultato = filtraTask(lista);
      expect(risultato.map((t) => t.id).toList(), ['t1', 't2', 't3', 't4']);
    });

    test('soloAperti tiene solo i task aperti', () {
      final risultato = filtraTask(lista, soloAperti: true);
      expect(risultato.map((t) => t.id).toList(), ['t1', 't3']);
    });

    test('filtra per operatore', () {
      final risultato = filtraTask(lista, operatoreId: 'op-1');
      expect(risultato.map((t) => t.id).toList(), ['t1', 't2']);
    });

    test('filtra per operatore e solo aperti insieme', () {
      final risultato =
          filtraTask(lista, soloAperti: true, operatoreId: 'op-2');
      expect(risultato.map((t) => t.id).toList(), ['t3']);
    });
  });

  group('ordinaTask', () {
    final task = [
      // scadenza 2026-10-21 09:00, normale
      TaskItem(
        id: 't1',
        scadenzaData: '2026-10-21',
        scadenzaOra: '09:00',
        priorita: 'normale',
      ),
      // scadenza 2026-10-20 09:00, normale
      TaskItem(
        id: 't2',
        scadenzaData: '2026-10-20',
        scadenzaOra: '09:00',
        priorita: 'normale',
      ),
      // stessa scadenza di t2 ma urgente
      TaskItem(
        id: 't3',
        scadenzaData: '2026-10-20',
        scadenzaOra: '09:00',
        priorita: 'urgente',
      ),
      // senza scadenza, urgente
      TaskItem(id: 't4', priorita: 'urgente'),
      // senza scadenza, normale
      TaskItem(id: 't5', priorita: 'normale'),
    ];

    test('ordina per scadenza crescente, senza scadenza in fondo', () {
      final risultato = ordinaTask(task);
      expect(
        risultato.map((t) => t.id).toList(),
        ['t3', 't2', 't1', 't4', 't5'],
      );
    });

    test('a parità di scadenza mette prima l\'urgente', () {
      final risultato = ordinaTask(task);
      final ids = risultato.map((t) => t.id).toList();
      // t3 (urgente) precede t2 (normale) pur avendo la stessa scadenza
      expect(ids.indexOf('t3'), lessThan(ids.indexOf('t2')));
    });

    test('non muta la lista in ingresso', () {
      final prima = task.map((t) => t.id).toList();
      ordinaTask(task);
      expect(task.map((t) => t.id).toList(), prima);
    });
  });
}
