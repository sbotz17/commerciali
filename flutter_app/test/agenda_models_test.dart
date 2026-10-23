import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/appuntamento.dart';
import 'package:commerciali_app/data/models/task_item.dart';

void main() {
  group('Appuntamento.fromMap', () {
    test('legge tutti i campi', () {
      final a = Appuntamento.fromMap({
        'azienda_id': 'az-1',
        'titolo': 'Visita ACME',
        'tipo': 'visita',
        'data': '2026-10-22',
        'ora': '09:30',
        'durata_min': 45,
        'cliente_id': 'cl-1',
        'cliente_nome': 'ACME Srl',
        'operatore_id': 'op-1',
        'luogo': 'Sede cliente',
        'indirizzo': 'Via Roma 10, Milano',
        'note': 'Portare campioni',
        'stato': 'fatto',
        'visita_id': 'v-1',
        'call_provider': 'google_meet',
        'call_url': 'https://meet.example.com/abc',
        'meeting_id': 'meet-1',
        'google_event_id': 'gcal-1',
        'outlook_event_id': 'outlook-1',
        'created_by': 'u-1',
        'created_at': '2026-10-01T10:00:00Z',
        'updated_at': '2026-10-02T11:00:00Z',
      }, id: 'a-1');

      expect(a.id, 'a-1');
      expect(a.aziendaId, 'az-1');
      expect(a.titolo, 'Visita ACME');
      expect(a.tipo, 'visita');
      expect(a.data, '2026-10-22');
      expect(a.ora, '09:30');
      expect(a.durataMin, 45);
      expect(a.clienteId, 'cl-1');
      expect(a.clienteNome, 'ACME Srl');
      expect(a.operatoreId, 'op-1');
      expect(a.luogo, 'Sede cliente');
      expect(a.indirizzo, 'Via Roma 10, Milano');
      expect(a.note, 'Portare campioni');
      expect(a.stato, 'fatto');
      expect(a.visitaId, 'v-1');
      expect(a.callProvider, 'google_meet');
      expect(a.callUrl, 'https://meet.example.com/abc');
      expect(a.meetingId, 'meet-1');
      expect(a.googleEventId, 'gcal-1');
      expect(a.outlookEventId, 'outlook-1');
      expect(a.createdBy, 'u-1');
      expect(a.createdAt, '2026-10-01T10:00:00Z');
      expect(a.updatedAt, '2026-10-02T11:00:00Z');
    });

    test('campi assenti: default tipo, durata 60 e stato da_fare', () {
      final a = Appuntamento.fromMap({}, id: 'a-1');

      expect(a.id, 'a-1');
      expect(a.aziendaId, isNull);
      expect(a.titolo, isNull);
      expect(a.tipo, 'appuntamento');
      expect(a.data, isNull);
      expect(a.ora, isNull);
      expect(a.durataMin, 60);
      expect(a.clienteId, isNull);
      expect(a.clienteNome, isNull);
      expect(a.operatoreId, isNull);
      expect(a.luogo, isNull);
      expect(a.indirizzo, isNull);
      expect(a.note, isNull);
      expect(a.stato, 'da_fare');
      expect(a.visitaId, isNull);
      expect(a.callProvider, isNull);
      expect(a.callUrl, isNull);
      expect(a.meetingId, isNull);
      expect(a.googleEventId, isNull);
      expect(a.outlookEventId, isNull);
      expect(a.createdBy, isNull);
      expect(a.createdAt, isNull);
      expect(a.updatedAt, isNull);
    });

    test('durata_min numerico viene convertito a int', () {
      final a = Appuntamento.fromMap({'durata_min': 30.0}, id: 'a-1');
      expect(a.durataMin, 30);
    });
  });

  group('Appuntamento.toMap', () {
    test('serializza in snake_case senza id', () {
      final a = Appuntamento(
        id: 'a-1',
        aziendaId: 'az-1',
        titolo: 'Visita ACME',
        tipo: 'visita',
        data: '2026-10-22',
        ora: '09:30',
        durataMin: 45,
        clienteId: 'cl-1',
        clienteNome: 'ACME Srl',
        operatoreId: 'op-1',
        luogo: 'Sede cliente',
        indirizzo: 'Via Roma 10, Milano',
        note: 'Portare campioni',
        stato: 'fatto',
        visitaId: 'v-1',
        callProvider: 'google_meet',
        callUrl: 'https://meet.example.com/abc',
        meetingId: 'meet-1',
        googleEventId: 'gcal-1',
        outlookEventId: 'outlook-1',
        createdBy: 'u-1',
        createdAt: '2026-10-01T10:00:00Z',
        updatedAt: '2026-10-02T11:00:00Z',
      );

      final map = a.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['azienda_id'], 'az-1');
      expect(map['titolo'], 'Visita ACME');
      expect(map['tipo'], 'visita');
      expect(map['data'], '2026-10-22');
      expect(map['ora'], '09:30');
      expect(map['durata_min'], 45);
      expect(map['cliente_id'], 'cl-1');
      expect(map['cliente_nome'], 'ACME Srl');
      expect(map['operatore_id'], 'op-1');
      expect(map['luogo'], 'Sede cliente');
      expect(map['indirizzo'], 'Via Roma 10, Milano');
      expect(map['note'], 'Portare campioni');
      expect(map['stato'], 'fatto');
      expect(map['visita_id'], 'v-1');
      expect(map['call_provider'], 'google_meet');
      expect(map['call_url'], 'https://meet.example.com/abc');
      expect(map['meeting_id'], 'meet-1');
      expect(map['google_event_id'], 'gcal-1');
      expect(map['outlook_event_id'], 'outlook-1');
      expect(map['created_by'], 'u-1');
      expect(map['created_at'], '2026-10-01T10:00:00Z');
      expect(map['updated_at'], '2026-10-02T11:00:00Z');
    });

    test('round-trip fromMap(toMap(...)) conserva i valori', () {
      final originale = Appuntamento(
        id: 'a-1',
        aziendaId: 'az-1',
        titolo: 'Visita ACME',
        tipo: 'visita',
        data: '2026-10-22',
        ora: '09:30',
        durataMin: 45,
        clienteId: 'cl-1',
        clienteNome: 'ACME Srl',
        operatoreId: 'op-1',
        luogo: 'Sede cliente',
        indirizzo: 'Via Roma 10, Milano',
        note: 'Portare campioni',
        stato: 'fatto',
        visitaId: 'v-1',
        callProvider: 'teams',
        callUrl: 'https://teams.example.com/xyz',
        meetingId: 'meet-2',
        googleEventId: 'gcal-2',
        outlookEventId: 'outlook-2',
        createdBy: 'u-1',
        createdAt: '2026-10-01T10:00:00Z',
        updatedAt: '2026-10-02T11:00:00Z',
      );

      final ricostruito =
          Appuntamento.fromMap(originale.toMap(), id: originale.id);

      expect(ricostruito.id, originale.id);
      expect(ricostruito.aziendaId, originale.aziendaId);
      expect(ricostruito.titolo, originale.titolo);
      expect(ricostruito.tipo, originale.tipo);
      expect(ricostruito.data, originale.data);
      expect(ricostruito.ora, originale.ora);
      expect(ricostruito.durataMin, originale.durataMin);
      expect(ricostruito.clienteId, originale.clienteId);
      expect(ricostruito.clienteNome, originale.clienteNome);
      expect(ricostruito.operatoreId, originale.operatoreId);
      expect(ricostruito.luogo, originale.luogo);
      expect(ricostruito.indirizzo, originale.indirizzo);
      expect(ricostruito.note, originale.note);
      expect(ricostruito.stato, originale.stato);
      expect(ricostruito.visitaId, originale.visitaId);
      expect(ricostruito.callProvider, originale.callProvider);
      expect(ricostruito.callUrl, originale.callUrl);
      expect(ricostruito.meetingId, originale.meetingId);
      expect(ricostruito.googleEventId, originale.googleEventId);
      expect(ricostruito.outlookEventId, originale.outlookEventId);
      expect(ricostruito.createdBy, originale.createdBy);
      expect(ricostruito.createdAt, originale.createdAt);
      expect(ricostruito.updatedAt, originale.updatedAt);
    });
  });

  group('TaskItem.fromMap', () {
    test('legge tutti i campi', () {
      final t = TaskItem.fromMap({
        'azienda_id': 'az-1',
        'titolo': 'Inviare preventivo',
        'descrizione': 'Spedire il preventivo rivisto',
        'scadenza_data': '2026-10-23',
        'scadenza_ora': '17:00',
        'operatore_id': 'op-1',
        'priorita': 'urgente',
        'stato': 'completato',
        'cliente_id': 'cl-1',
        'cliente_nome': 'ACME Srl',
        'appuntamento_id': 'a-1',
        'note': 'Richiamare prima',
        'completato_da': 'u-2',
        'completato_at': '2026-10-23T16:00:00Z',
        'created_by': 'u-1',
        'created_at': '2026-10-20T10:00:00Z',
        'updated_at': '2026-10-23T16:00:00Z',
      }, id: 't-1');

      expect(t.id, 't-1');
      expect(t.aziendaId, 'az-1');
      expect(t.titolo, 'Inviare preventivo');
      expect(t.descrizione, 'Spedire il preventivo rivisto');
      expect(t.scadenzaData, '2026-10-23');
      expect(t.scadenzaOra, '17:00');
      expect(t.operatoreId, 'op-1');
      expect(t.priorita, 'urgente');
      expect(t.stato, 'completato');
      expect(t.clienteId, 'cl-1');
      expect(t.clienteNome, 'ACME Srl');
      expect(t.appuntamentoId, 'a-1');
      expect(t.note, 'Richiamare prima');
      expect(t.completatoDa, 'u-2');
      expect(t.completatoAt, '2026-10-23T16:00:00Z');
      expect(t.createdBy, 'u-1');
      expect(t.createdAt, '2026-10-20T10:00:00Z');
      expect(t.updatedAt, '2026-10-23T16:00:00Z');
    });

    test('campi assenti: default priorita normale e stato aperto', () {
      final t = TaskItem.fromMap({}, id: 't-1');

      expect(t.id, 't-1');
      expect(t.aziendaId, isNull);
      expect(t.titolo, isNull);
      expect(t.descrizione, isNull);
      expect(t.scadenzaData, isNull);
      expect(t.scadenzaOra, isNull);
      expect(t.operatoreId, isNull);
      expect(t.priorita, 'normale');
      expect(t.stato, 'aperto');
      expect(t.clienteId, isNull);
      expect(t.clienteNome, isNull);
      expect(t.appuntamentoId, isNull);
      expect(t.note, isNull);
      expect(t.completatoDa, isNull);
      expect(t.completatoAt, isNull);
      expect(t.createdBy, isNull);
      expect(t.createdAt, isNull);
      expect(t.updatedAt, isNull);
    });
  });

  group('TaskItem.toMap', () {
    test('serializza in snake_case senza id', () {
      final t = TaskItem(
        id: 't-1',
        aziendaId: 'az-1',
        titolo: 'Inviare preventivo',
        descrizione: 'Spedire il preventivo rivisto',
        scadenzaData: '2026-10-23',
        scadenzaOra: '17:00',
        operatoreId: 'op-1',
        priorita: 'urgente',
        stato: 'completato',
        clienteId: 'cl-1',
        clienteNome: 'ACME Srl',
        appuntamentoId: 'a-1',
        note: 'Richiamare prima',
        completatoDa: 'u-2',
        completatoAt: '2026-10-23T16:00:00Z',
        createdBy: 'u-1',
        createdAt: '2026-10-20T10:00:00Z',
        updatedAt: '2026-10-23T16:00:00Z',
      );

      final map = t.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['azienda_id'], 'az-1');
      expect(map['titolo'], 'Inviare preventivo');
      expect(map['descrizione'], 'Spedire il preventivo rivisto');
      expect(map['scadenza_data'], '2026-10-23');
      expect(map['scadenza_ora'], '17:00');
      expect(map['operatore_id'], 'op-1');
      expect(map['priorita'], 'urgente');
      expect(map['stato'], 'completato');
      expect(map['cliente_id'], 'cl-1');
      expect(map['cliente_nome'], 'ACME Srl');
      expect(map['appuntamento_id'], 'a-1');
      expect(map['note'], 'Richiamare prima');
      expect(map['completato_da'], 'u-2');
      expect(map['completato_at'], '2026-10-23T16:00:00Z');
      expect(map['created_by'], 'u-1');
      expect(map['created_at'], '2026-10-20T10:00:00Z');
      expect(map['updated_at'], '2026-10-23T16:00:00Z');
    });

    test('round-trip fromMap(toMap(...)) conserva i valori', () {
      final originale = TaskItem(
        id: 't-1',
        aziendaId: 'az-1',
        titolo: 'Inviare preventivo',
        descrizione: 'Spedire il preventivo rivisto',
        scadenzaData: '2026-10-23',
        scadenzaOra: '17:00',
        operatoreId: 'op-1',
        priorita: 'urgente',
        stato: 'completato',
        clienteId: 'cl-1',
        clienteNome: 'ACME Srl',
        appuntamentoId: 'a-1',
        note: 'Richiamare prima',
        completatoDa: 'u-2',
        completatoAt: '2026-10-23T16:00:00Z',
        createdBy: 'u-1',
        createdAt: '2026-10-20T10:00:00Z',
        updatedAt: '2026-10-23T16:00:00Z',
      );

      final ricostruito = TaskItem.fromMap(originale.toMap(), id: originale.id);

      expect(ricostruito.id, originale.id);
      expect(ricostruito.aziendaId, originale.aziendaId);
      expect(ricostruito.titolo, originale.titolo);
      expect(ricostruito.descrizione, originale.descrizione);
      expect(ricostruito.scadenzaData, originale.scadenzaData);
      expect(ricostruito.scadenzaOra, originale.scadenzaOra);
      expect(ricostruito.operatoreId, originale.operatoreId);
      expect(ricostruito.priorita, originale.priorita);
      expect(ricostruito.stato, originale.stato);
      expect(ricostruito.clienteId, originale.clienteId);
      expect(ricostruito.clienteNome, originale.clienteNome);
      expect(ricostruito.appuntamentoId, originale.appuntamentoId);
      expect(ricostruito.note, originale.note);
      expect(ricostruito.completatoDa, originale.completatoDa);
      expect(ricostruito.completatoAt, originale.completatoAt);
      expect(ricostruito.createdBy, originale.createdBy);
      expect(ricostruito.createdAt, originale.createdAt);
      expect(ricostruito.updatedAt, originale.updatedAt);
    });
  });

  group('dataOraAppuntamento', () {
    test('combina data e ora valide', () {
      final a = Appuntamento(id: 'a-1', data: '2026-10-22', ora: '09:30');
      final dt = dataOraAppuntamento(a);
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 10);
      expect(dt.day, 22);
      expect(dt.hour, 9);
      expect(dt.minute, 30);
    });

    test('ritorna null se data o ora mancanti', () {
      expect(dataOraAppuntamento(Appuntamento(id: 'a-1')), isNull);
      expect(
        dataOraAppuntamento(Appuntamento(id: 'a-1', data: '2026-10-22')),
        isNull,
      );
      expect(
        dataOraAppuntamento(Appuntamento(id: 'a-1', ora: '09:30')),
        isNull,
      );
    });

    test('ritorna null per formati o valori non validi', () {
      expect(
        dataOraAppuntamento(
            Appuntamento(id: 'a-1', data: '22/10/2026', ora: '09:30')),
        isNull,
      );
      expect(
        dataOraAppuntamento(
            Appuntamento(id: 'a-1', data: '2026-02-30', ora: '09:30')),
        isNull,
      );
      expect(
        dataOraAppuntamento(
            Appuntamento(id: 'a-1', data: '2026-10-22', ora: '25:00')),
        isNull,
      );
    });
  });

  group('dataOraTask', () {
    test('combina scadenzaData e scadenzaOra valide', () {
      final t =
          TaskItem(id: 't-1', scadenzaData: '2026-12-31', scadenzaOra: '23:59');
      final dt = dataOraTask(t);
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 12);
      expect(dt.day, 31);
      expect(dt.hour, 23);
      expect(dt.minute, 59);
    });

    test('ritorna null se scadenza mancante o non valida', () {
      expect(dataOraTask(TaskItem(id: 't-1')), isNull);
      expect(
        dataOraTask(TaskItem(id: 't-1', scadenzaData: '2026-12-31')),
        isNull,
      );
      expect(
        dataOraTask(
            TaskItem(id: 't-1', scadenzaData: '31/12/2026', scadenzaOra: '23:59')),
        isNull,
      );
    });
  });

  group('etichettaStatoAppuntamento', () {
    test('traduce i valori noti', () {
      expect(etichettaStatoAppuntamento('da_fare'), 'Da fare');
      expect(etichettaStatoAppuntamento('fatto'), 'Fatto');
      expect(etichettaStatoAppuntamento('annullato'), 'Annullato');
    });

    test('fallback leggibile per null/empty e valore sconosciuto', () {
      expect(etichettaStatoAppuntamento(null), 'Sconosciuto');
      expect(etichettaStatoAppuntamento(''), 'Sconosciuto');
      expect(etichettaStatoAppuntamento('sospeso'), 'sospeso');
    });
  });

  group('etichettaPrioritaTask', () {
    test('traduce i valori noti', () {
      expect(etichettaPrioritaTask('normale'), 'Normale');
      expect(etichettaPrioritaTask('urgente'), 'Urgente');
    });

    test('fallback leggibile per null/empty e valore sconosciuto', () {
      expect(etichettaPrioritaTask(null), 'Non definita');
      expect(etichettaPrioritaTask(''), 'Non definita');
      expect(etichettaPrioritaTask('alta'), 'alta');
    });
  });
}
