import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/avvisi.dart';
import 'package:commerciali_app/data/models/appuntamento.dart';
import 'package:commerciali_app/data/models/preventivo.dart';
import 'package:commerciali_app/data/models/task_item.dart';

void main() {
  group('task', () {
    test('produce avviso con anticipo e alla scadenza', () {
      final task = TaskItem(
        id: 't1',
        titolo: 'Preparare offerta',
        scadenzaData: '2026-10-27',
        scadenzaOra: '18:00',
        operatoreId: 'u1',
      );
      final avvisi = avvisiTask(task, utenteUid: 'u1');
      expect(avvisi, hasLength(2));

      final anticipo = avvisi.first;
      expect(anticipo.quando, DateTime(2026, 10, 26, 9));
      expect(anticipo.testo, contains('Preparare offerta'));
      expect(anticipo.testo, contains('27/10/2026 alle 18:00'));
      expect(anticipo.chiave, contains('task:t1:u1:'));

      final scadenza = avvisi.last;
      expect(scadenza.quando, DateTime(2026, 10, 27, 18));
      expect(scadenza.titolo, contains('da completare'));
    });

    test('senza ora usa le 09:00', () {
      final task = TaskItem(
        id: 't1',
        titolo: 'Richiamare cliente',
        scadenzaData: '2026-10-27',
        operatoreId: 'u1',
      );
      final scadenza = avvisiTask(task, utenteUid: 'u1').last;
      expect(scadenza.quando, DateTime(2026, 10, 27, 9));
    });

    test('non avvisa task completati o senza scadenza', () {
      expect(
        avvisiTask(
          TaskItem(id: 't1', titolo: 'Fatto', scadenzaData: '2026-10-27', stato: 'completato'),
          utenteUid: 'u1',
        ),
        isEmpty,
      );
      expect(
        avvisiTask(TaskItem(id: 't1', titolo: 'Senza data'), utenteUid: 'u1'),
        isEmpty,
      );
    });

    test('con anticipo zero resta solo l\'avviso alla scadenza', () {
      final task = TaskItem(
        id: 't1',
        titolo: 'Task',
        scadenzaData: '2026-10-27',
        scadenzaOra: '12:00',
      );
      final avvisi = avvisiTask(task, utenteUid: 'u1', anticipoGiorni: 0);
      expect(avvisi, hasLength(1));
      expect(avvisi.single.quando, DateTime(2026, 10, 27, 12));
    });
  });

  group('preventivo', () {
    test('produce avviso con anticipo e il giorno dopo la scadenza', () {
      final preventivo = Preventivo(
        id: 'p1',
        numero: 'PRV-0001',
        stato: 'inviato',
        validoFino: '2026-10-30',
      );
      final avvisi = avvisiPreventivo(
        preventivo,
        utenteUid: 'u1',
        anticipoGiorni: 3,
      );
      expect(avvisi, hasLength(2));
      expect(avvisi.first.quando, DateTime(2026, 10, 27, 9));
      expect(avvisi.first.testo, contains('PRV-0001'));
      expect(avvisi.last.quando, DateTime(2026, 10, 31, 9));
      expect(avvisi.last.testo, contains('scaduto'));
    });

    test('non avvisa preventivi accettati o senza validità', () {
      expect(
        avvisiPreventivo(
          Preventivo(id: 'p1', stato: 'accettato', validoFino: '2026-10-30'),
          utenteUid: 'u1',
        ),
        isEmpty,
      );
      expect(
        avvisiPreventivo(Preventivo(id: 'p1', stato: 'inviato'), utenteUid: 'u1'),
        isEmpty,
      );
    });

    test('preventivoScaduto usa il giorno di validità', () {
      final preventivo = Preventivo(
        id: 'p1',
        stato: 'inviato',
        validoFino: '2026-10-25',
      );
      expect(
        preventivoScaduto(preventivo, adesso: DateTime(2026, 10, 25, 18)),
        isFalse,
      );
      expect(
        preventivoScaduto(preventivo, adesso: DateTime(2026, 10, 26, 8)),
        isTrue,
      );
      expect(
        preventivoScaduto(
          Preventivo(id: 'p2', stato: 'accettato', validoFino: '2026-10-25'),
          adesso: DateTime(2026, 10, 26, 8),
        ),
        isFalse,
      );
    });
  });

  group('appuntamento', () {
    final domani = DateTime.now().add(const Duration(days: 1));
    final data = '${domani.year.toString().padLeft(4, '0')}-'
        '${domani.month.toString().padLeft(2, '0')}-'
        '${domani.day.toString().padLeft(2, '0')}';

    test('avvisa ogni destinatario con l\'anticipo configurato', () {
      final appuntamento = Appuntamento(
        id: 'a1',
        titolo: 'Visita cliente',
        data: data,
        ora: '10:00',
        notificaMin: 30,
      );
      final avvisi = avvisiAppuntamento(
        appuntamento,
        utenteUids: const ['u1', 'u2'],
        adesso: DateTime(domani.year, domani.month, domani.day, 8),
      );
      expect(avvisi, hasLength(2));
      expect(avvisi.first.quando, DateTime(domani.year, domani.month, domani.day, 9, 30));
      expect(avvisi.map((a) => a.utenteUid), containsAll(['u1', 'u2']));
    });

    test('non avvisa senza notifica o se annullato', () {
      expect(
        avvisiAppuntamento(
          Appuntamento(id: 'a1', titolo: 'Senza', data: data),
          utenteUids: const ['u1'],
        ),
        isEmpty,
      );
      expect(
        avvisiAppuntamento(
          Appuntamento(
            id: 'a1',
            titolo: 'Annullato',
            data: data,
            ora: '10:00',
            notificaMin: 30,
            stato: 'annullato',
          ),
          utenteUids: const ['u1'],
        ),
        isEmpty,
      );
    });

    test('un appuntamento privato non espone il titolo', () {
      final avvisi = avvisiAppuntamento(
        Appuntamento(
          id: 'a1',
          titolo: 'Segreto',
          data: data,
          ora: '10:00',
          notificaMin: 30,
          privato: true,
        ),
        utenteUids: const ['u1'],
        adesso: DateTime(domani.year, domani.month, domani.day, 8),
      );
      expect(avvisi.single.testo, isNot(contains('Segreto')));
      expect(avvisi.single.testo, contains('Impegno privato'));
    });
  });

  test('le finestre separano avvisi passati e futuri', () {
    final adesso = DateTime(2026, 10, 26, 10);
    final passato = AvvisoProgrammato(
      tipo: 'task',
      targetId: 't1',
      utenteUid: 'u1',
      titolo: 'Passato',
      testo: 'Testo',
      quando: DateTime(2026, 10, 25, 9),
    );
    final futuro = AvvisoProgrammato(
      tipo: 'task',
      targetId: 't1',
      utenteUid: 'u1',
      titolo: 'Futuro',
      testo: 'Testo',
      quando: DateTime(2026, 10, 27, 9),
    );
    final vecchio = AvvisoProgrammato(
      tipo: 'task',
      targetId: 't1',
      utenteUid: 'u1',
      titolo: 'Vecchio',
      testo: 'Testo',
      quando: DateTime(2026, 10, 1, 9),
    );
    expect(
      avvisiDaMostrare([passato, futuro, vecchio], adesso: adesso),
      [passato],
    );
    expect(avvisiDaRegistrare([passato, futuro], adesso: adesso), [futuro]);
  });

  test('anticipoDaMappa limita i valori anomali', () {
    expect(anticipoDaMappa({'anticipo_task_giorni': 3}, 'anticipo_task_giorni', 1), 3);
    expect(anticipoDaMappa({'anticipo_task_giorni': 'x'}, 'anticipo_task_giorni', 1), 1);
    expect(anticipoDaMappa({'anticipo_task_giorni': 99}, 'anticipo_task_giorni', 1), 30);
    expect(anticipoDaMappa(null, 'anticipo_task_giorni', 1), 1);
  });
}
