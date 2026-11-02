import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/task_item.dart';
import 'package:commerciali_app/features/task/task_screen.dart';

/// Test delle funzioni pure della schermata Task.
///
/// Lo stato vuoto `task-vuoto` non è verificabile qui: `TaskScreen` carica i
/// dati dal `SpService`, che richiede Firebase inizializzato (nei test l'elenco
/// mostrerebbe l'errore di caricamento). Restano quindi verificati filtri e
/// raggruppamento per periodo, che sono tutta la logica della lista.
void main() {
  TaskItem task({
    required String id,
    String? titolo = 'Richiamare Acme',
    String? scadenzaData,
    String? scadenzaOra,
    String? operatoreId,
    String stato = 'aperto',
    String priorita = 'normale',
  }) {
    return TaskItem(
      id: id,
      titolo: titolo,
      scadenzaData: scadenzaData,
      scadenzaOra: scadenzaOra,
      operatoreId: operatoreId,
      stato: stato,
      priorita: priorita,
    );
  }

  List<String> ids(List<TaskItem> elenco) => elenco.map((t) => t.id).toList();

  group('filtraTaskVisibili', () {
    final elenco = [
      task(
        id: 'acme',
        titolo: 'Richiamare ACME',
        scadenzaData: '2026-10-26',
        scadenzaOra: '09:00',
        operatoreId: 'u1',
      ),
      task(
        id: 'beta',
        titolo: 'Preparare offerta Beta',
        scadenzaData: '2026-10-24',
        scadenzaOra: '10:00',
        operatoreId: 'u2',
      ),
      task(
        id: 'chiuso',
        titolo: 'Inviare contratto',
        scadenzaData: '2026-10-23',
        scadenzaOra: '11:00',
        operatoreId: 'u1',
        stato: 'completato',
      ),
      task(id: 'senza-data', titolo: 'Aggiornare listino', operatoreId: 'u2'),
    ];

    test('senza filtri restituisce tutto ordinato per scadenza', () {
      expect(ids(filtraTaskVisibili(elenco)), [
        'chiuso',
        'beta',
        'acme',
        'senza-data',
      ]);
    });

    test('cerca nel titolo senza distinzione tra maiuscole e minuscole', () {
      expect(ids(filtraTaskVisibili(elenco, testo: 'acme')), ['acme']);
      expect(ids(filtraTaskVisibili(elenco, testo: '  OFFERTA ')), ['beta']);
    });

    test('una ricerca senza risultati restituisce una lista vuota', () {
      expect(filtraTaskVisibili(elenco, testo: 'inesistente'), isEmpty);
    });

    test('filtra per operatore assegnato', () {
      expect(ids(filtraTaskVisibili(elenco, operatoreId: 'u1')), [
        'chiuso',
        'acme',
      ]);
      expect(ids(filtraTaskVisibili(elenco, operatoreId: 'u2')), [
        'beta',
        'senza-data',
      ]);
    });

    test('un operatore vuoto non filtra', () {
      expect(
        filtraTaskVisibili(elenco, operatoreId: '   ').length,
        elenco.length,
      );
    });

    test('soloAperti esclude i task completati', () {
      expect(ids(filtraTaskVisibili(elenco, soloAperti: true)), [
        'beta',
        'acme',
        'senza-data',
      ]);
    });

    test('i filtri si combinano in AND', () {
      expect(
        ids(
          filtraTaskVisibili(
            elenco,
            soloAperti: true,
            operatoreId: 'u1',
            testo: 'richiamare',
          ),
        ),
        ['acme'],
      );
      expect(
        filtraTaskVisibili(
          elenco,
          soloAperti: true,
          operatoreId: 'u1',
          testo: 'contratto',
        ),
        isEmpty,
      );
    });

    test('non modifica la lista in ingresso', () {
      final originale = [...elenco];
      filtraTaskVisibili(elenco, soloAperti: true);
      expect(ids(elenco), ids(originale));
    });
  });

  group('raggruppaTaskPerPeriodo', () {
    // 24 ottobre 2026 è un sabato: la settimana corrente finisce domenica 25.
    final oggi = DateTime(2026, 10, 24);

    setUp(() {
      expect(oggi.weekday, DateTime.saturday);
    });

    test('tutte le sezioni sono presenti, anche se vuote e nell\'ordine',
        () {
      final gruppi = raggruppaTaskPerPeriodo(const [], oggi: oggi);

      expect(gruppi.keys.toList(), periodiTask);
      expect(periodiTask, [
        'In ritardo',
        'Oggi',
        'Questa settimana',
        'Più avanti',
        'Senza scadenza',
        'Completati',
      ]);
      for (final periodo in periodiTask) {
        expect(gruppi[periodo], isEmpty, reason: periodo);
      }
    });

    test('smista le date fisse nel periodo giusto', () {
      final gruppi = raggruppaTaskPerPeriodo(
        [
          task(id: 'ritardo', scadenzaData: '2026-10-23'),
          task(id: 'oggi', scadenzaData: '2026-10-24'),
          task(id: 'settimana', scadenzaData: '2026-10-25'),
          task(id: 'avanti', scadenzaData: '2026-10-26'),
          task(id: 'senza'),
          task(id: 'completato', scadenzaData: '2026-10-20', stato: 'completato'),
        ],
        oggi: oggi,
      );

      expect(ids(gruppi['In ritardo']!), ['ritardo']);
      expect(ids(gruppi['Oggi']!), ['oggi']);
      expect(ids(gruppi['Questa settimana']!), ['settimana']);
      expect(ids(gruppi['Più avanti']!), ['avanti']);
      expect(ids(gruppi['Senza scadenza']!), ['senza']);
      expect(ids(gruppi['Completati']!), ['completato']);
    });

    test('un completato finisce in Completati qualunque sia la scadenza', () {
      final gruppi = raggruppaTaskPerPeriodo(
        [
          task(id: 'futuro', scadenzaData: '2026-12-01', scadenzaOra: '09:00', stato: 'completato'),
          task(id: 'passato', scadenzaData: '2025-01-01', scadenzaOra: '09:00', stato: 'completato'),
          task(id: 'senza', stato: 'completato'),
        ],
        oggi: oggi,
      );

      expect(ids(gruppi['Completati']!), ['passato', 'futuro', 'senza']);
      expect(gruppi['In ritardo'], isEmpty);
      expect(gruppi['Più avanti'], isEmpty);
      expect(gruppi['Senza scadenza'], isEmpty);
    });

    test('scadenza assente o non valida finisce in Senza scadenza', () {
      final gruppi = raggruppaTaskPerPeriodo(
        [
          task(id: 'assente'),
          task(id: 'vuota', scadenzaData: '  '),
          task(id: 'testo', scadenzaData: 'domani'),
          task(id: 'impossibile', scadenzaData: '2026-02-30'),
        ],
        oggi: oggi,
      );

      expect(
        ids(gruppi['Senza scadenza']!).toSet(),
        {'assente', 'vuota', 'testo', 'impossibile'},
      );
    });

    test('dentro al gruppo i task sono ordinati per scadenza', () {
      final gruppi = raggruppaTaskPerPeriodo(
        [
          task(id: 'tardi', scadenzaData: '2026-11-20', scadenzaOra: '09:00'),
          task(id: 'presto', scadenzaData: '2026-11-02', scadenzaOra: '09:00'),
          task(id: 'urgente', scadenzaData: '2026-11-02', scadenzaOra: '09:00', priorita: 'urgente'),
        ],
        oggi: oggi,
      );

      expect(ids(gruppi['Più avanti']!), ['urgente', 'presto', 'tardi']);
    });

    test('il riferimento predefinito è oggi (nessuna eccezione)', () {
      final gruppi = raggruppaTaskPerPeriodo([task(id: 'a')]);
      expect(ids(gruppi['Senza scadenza']!), ['a']);
    });
  });
}
