import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/visita.dart';

void main() {
  group('Visita.fromMap', () {
    test('legge tutti i campi', () {
      final visita = Visita.fromMap({
        'azienda_id': 'az-1',
        'utente_id': 'u-1',
        'cliente_id': 'cl-1',
        'cliente_nome': 'ACME Srl',
        'telefono': '02 123456',
        'indirizzo': 'Via Roma 10, Milano',
        'data': '2026-10-22',
        'ora': '09:30',
        'ordine': 2,
        'stato': 'fatto',
        'note': 'Portare campioni',
        'visita_padre_id': 'v-0',
        'promemoria_min': 15,
        'promemoria_at': '2026-10-22T09:15:00Z',
        'promemoria_numero': '+393331234567',
        'promemoria_inviato_at': '2026-10-22T09:15:02Z',
      }, id: 'v-1');

      expect(visita.id, 'v-1');
      expect(visita.aziendaId, 'az-1');
      expect(visita.utenteId, 'u-1');
      expect(visita.clienteId, 'cl-1');
      expect(visita.clienteNome, 'ACME Srl');
      expect(visita.telefono, '02 123456');
      expect(visita.indirizzo, 'Via Roma 10, Milano');
      expect(visita.data, '2026-10-22');
      expect(visita.ora, '09:30');
      expect(visita.ordine, 2);
      expect(visita.stato, 'fatto');
      expect(visita.note, 'Portare campioni');
      expect(visita.visitaPadreId, 'v-0');
      expect(visita.promemoriaMin, 15);
      expect(visita.promemoriaAt, '2026-10-22T09:15:00Z');
      expect(visita.promemoriaNumero, '+393331234567');
      expect(visita.promemoriaInviatoAt, '2026-10-22T09:15:02Z');
    });

    test('campi assenti: default ordine 0 e stato da_fare, altri null', () {
      final visita = Visita.fromMap({}, id: 'v-1');

      expect(visita.id, 'v-1');
      expect(visita.aziendaId, isNull);
      expect(visita.utenteId, isNull);
      expect(visita.clienteId, isNull);
      expect(visita.clienteNome, isNull);
      expect(visita.data, isNull);
      expect(visita.ora, isNull);
      expect(visita.ordine, 0);
      expect(visita.stato, 'da_fare');
      expect(visita.note, isNull);
      expect(visita.visitaPadreId, isNull);
      expect(visita.promemoriaMin, isNull);
      expect(visita.promemoriaAt, isNull);
      expect(visita.promemoriaNumero, isNull);
      expect(visita.promemoriaInviatoAt, isNull);
    });

    test('ordine e promemoria_min numerici vengono convertiti a int', () {
      final visita = Visita.fromMap({
        'ordine': 3.0,
        'promemoria_min': 10.0,
      }, id: 'v-1');

      expect(visita.ordine, 3);
      expect(visita.promemoriaMin, 10);
    });

    test('data e ora sono stringhe YYYY-MM-DD e HH:MM', () {
      final visita = Visita.fromMap({
        'data': '2026-11-01',
        'ora': '14:45',
      }, id: 'v-1');

      expect(visita.data, '2026-11-01');
      expect(visita.ora, '14:45');
      expect(visita.data, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(visita.ora, matches(RegExp(r'^\d{2}:\d{2}$')));
    });
  });

  group('Visita.toMap', () {
    test('serializza in snake_case senza id', () {
      final visita = Visita(
        id: 'v-1',
        aziendaId: 'az-1',
        utenteId: 'u-1',
        clienteId: 'cl-1',
        clienteNome: 'ACME Srl',
        telefono: '02 123456',
        indirizzo: 'Via Roma 10, Milano',
        data: '2026-10-22',
        ora: '09:30',
        ordine: 2,
        stato: 'fatto',
        note: 'Portare campioni',
        visitaPadreId: 'v-0',
        promemoriaMin: 15,
        promemoriaAt: '2026-10-22T09:15:00Z',
        promemoriaNumero: '+393331234567',
        promemoriaInviatoAt: '2026-10-22T09:15:02Z',
      );

      final map = visita.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['azienda_id'], 'az-1');
      expect(map['utente_id'], 'u-1');
      expect(map['cliente_id'], 'cl-1');
      expect(map['cliente_nome'], 'ACME Srl');
      expect(map['telefono'], '02 123456');
      expect(map['indirizzo'], 'Via Roma 10, Milano');
      expect(map['data'], '2026-10-22');
      expect(map['ora'], '09:30');
      expect(map['ordine'], 2);
      expect(map['stato'], 'fatto');
      expect(map['note'], 'Portare campioni');
      expect(map['visita_padre_id'], 'v-0');
      expect(map['promemoria_min'], 15);
      expect(map['promemoria_at'], '2026-10-22T09:15:00Z');
      expect(map['promemoria_numero'], '+393331234567');
      expect(map['promemoria_inviato_at'], '2026-10-22T09:15:02Z');
    });

    test('round-trip fromMap(toMap(...)) conserva i valori', () {
      final originale = Visita(
        id: 'v-1',
        aziendaId: 'az-1',
        clienteId: 'cl-1',
        clienteNome: 'ACME Srl',
        data: '2026-10-22',
        ora: '09:30',
        ordine: 4,
        stato: 'da_fare',
        promemoriaMin: 30,
      );

      final ricostruita = Visita.fromMap(
        originale.toMap(),
        id: originale.id,
      );

      expect(ricostruita.aziendaId, originale.aziendaId);
      expect(ricostruita.clienteId, originale.clienteId);
      expect(ricostruita.clienteNome, originale.clienteNome);
      expect(ricostruita.data, originale.data);
      expect(ricostruita.ora, originale.ora);
      expect(ricostruita.ordine, originale.ordine);
      expect(ricostruita.stato, originale.stato);
      expect(ricostruita.promemoriaMin, originale.promemoriaMin);
    });
  });
}
