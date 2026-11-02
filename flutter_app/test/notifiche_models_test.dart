import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/notifica.dart';
import 'package:commerciali_app/data/models/promemoria.dart';

void main() {
  group('Promemoria.fromMap', () {
    test('legge tutti i campi', () {
      final p = Promemoria.fromMap({
        'azienda_id': 'az-1',
        'riferito_a': 'appuntamento',
        'elemento_id': 'a-1',
        'destinatario_tipo': 'cliente',
        'canale': 'whatsapp',
        'destinatario': '+393331234567',
        'quando_at': '2026-10-23T09:00:00Z',
        'stato': 'inviato',
        'inviato_at': '2026-10-23T09:00:02Z',
        'tentativi': 1,
        'errore': null,
        'idempotenza_key': 'key-1',
        'created_at': '2026-10-20T10:00:00Z',
      }, id: 'p-1');

      expect(p.id, 'p-1');
      expect(p.aziendaId, 'az-1');
      expect(p.riferitoA, 'appuntamento');
      expect(p.elementoId, 'a-1');
      expect(p.destinatarioTipo, 'cliente');
      expect(p.canale, 'whatsapp');
      expect(p.destinatario, '+393331234567');
      expect(p.quandoAt, '2026-10-23T09:00:00Z');
      expect(p.stato, 'inviato');
      expect(p.inviatoAt, '2026-10-23T09:00:02Z');
      expect(p.tentativi, 1);
      expect(p.errore, isNull);
      expect(p.idempotenzaKey, 'key-1');
      expect(p.createdAt, '2026-10-20T10:00:00Z');
    });

    test('mappa vuota: default stato programmato e tentativi 0', () {
      final p = Promemoria.fromMap({}, id: 'p-1');

      expect(p.id, 'p-1');
      expect(p.aziendaId, isNull);
      expect(p.riferitoA, isNull);
      expect(p.elementoId, isNull);
      expect(p.destinatarioTipo, isNull);
      expect(p.canale, isNull);
      expect(p.destinatario, isNull);
      expect(p.quandoAt, isNull);
      expect(p.stato, 'programmato');
      expect(p.inviatoAt, isNull);
      expect(p.tentativi, 0);
      expect(p.errore, isNull);
      expect(p.idempotenzaKey, isNull);
      expect(p.createdAt, isNull);
    });

    test('tentativi numerico viene convertito a int', () {
      final p = Promemoria.fromMap({'tentativi': 2.0}, id: 'p-1');
      expect(p.tentativi, 2);
    });
  });

  group('Promemoria.toMap', () {
    test('serializza in snake_case senza id', () {
      final p = Promemoria(
        id: 'p-1',
        aziendaId: 'az-1',
        riferitoA: 'task',
        elementoId: 't-1',
        destinatarioTipo: 'operatore',
        canale: 'push',
        destinatario: 'uid-operatore',
        quandoAt: '2026-10-23T09:00:00Z',
        stato: 'in_elaborazione',
        inviatoAt: null,
        tentativi: 0,
        errore: null,
        idempotenzaKey: 'key-2',
        createdAt: '2026-10-20T10:00:00Z',
      );

      final map = p.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['azienda_id'], 'az-1');
      expect(map['riferito_a'], 'task');
      expect(map['elemento_id'], 't-1');
      expect(map['destinatario_tipo'], 'operatore');
      expect(map['canale'], 'push');
      expect(map['destinatario'], 'uid-operatore');
      expect(map['quando_at'], '2026-10-23T09:00:00Z');
      expect(map['stato'], 'in_elaborazione');
      expect(map['inviato_at'], isNull);
      expect(map['tentativi'], 0);
      expect(map['errore'], isNull);
      expect(map['idempotenza_key'], 'key-2');
      expect(map['created_at'], '2026-10-20T10:00:00Z');
    });

    test('round-trip fromMap(toMap(...)) conserva i valori', () {
      final originale = Promemoria(
        id: 'p-1',
        aziendaId: 'az-1',
        riferitoA: 'visita',
        elementoId: 'v-1',
        destinatarioTipo: 'cliente',
        canale: 'email',
        destinatario: 'cliente@example.com',
        quandoAt: '2026-10-23T09:00:00Z',
        stato: 'fallito',
        inviatoAt: '2026-10-23T09:00:03Z',
        tentativi: 3,
        errore: 'timeout',
        idempotenzaKey: 'key-3',
        createdAt: '2026-10-20T10:00:00Z',
      );

      final ricostruito = Promemoria.fromMap(originale.toMap(), id: originale.id);

      expect(ricostruito.id, originale.id);
      expect(ricostruito.aziendaId, originale.aziendaId);
      expect(ricostruito.riferitoA, originale.riferitoA);
      expect(ricostruito.elementoId, originale.elementoId);
      expect(ricostruito.destinatarioTipo, originale.destinatarioTipo);
      expect(ricostruito.canale, originale.canale);
      expect(ricostruito.destinatario, originale.destinatario);
      expect(ricostruito.quandoAt, originale.quandoAt);
      expect(ricostruito.stato, originale.stato);
      expect(ricostruito.inviatoAt, originale.inviatoAt);
      expect(ricostruito.tentativi, originale.tentativi);
      expect(ricostruito.errore, originale.errore);
      expect(ricostruito.idempotenzaKey, originale.idempotenzaKey);
      expect(ricostruito.createdAt, originale.createdAt);
    });
  });

  group('Notifica.fromMap', () {
    test('legge tutti i campi', () {
      final n = Notifica.fromMap({
        'azienda_id': 'az-1',
        'utente_uid': 'u-1',
        'mittente_uid': 'u-2',
        'tipo': 'appuntamento',
        'titolo': 'Promemoria appuntamento',
        'testo': 'Appuntamento domani alle 09:30',
        'target_tipo': 'appuntamento',
        'target_id': 'a-1',
        'canale': 'inapp',
        'stato': 'letta',
        'programmata_at': '2026-10-23T09:00:00Z',
        'inviata_at': '2026-10-23T09:00:02Z',
        'letta_at': '2026-10-23T09:05:00Z',
        'tentativi': 1,
        'errore': null,
        'idempotenza_key': 'key-1',
        'created_at': '2026-10-20T10:00:00Z',
      }, id: 'n-1');

      expect(n.id, 'n-1');
      expect(n.aziendaId, 'az-1');
      expect(n.utenteUid, 'u-1');
      expect(n.mittenteUid, 'u-2');
      expect(n.tipo, 'appuntamento');
      expect(n.titolo, 'Promemoria appuntamento');
      expect(n.testo, 'Appuntamento domani alle 09:30');
      expect(n.targetTipo, 'appuntamento');
      expect(n.targetId, 'a-1');
      expect(n.canale, 'inapp');
      expect(n.stato, 'letta');
      expect(n.programmataAt, '2026-10-23T09:00:00Z');
      expect(n.inviataAt, '2026-10-23T09:00:02Z');
      expect(n.lettaAt, '2026-10-23T09:05:00Z');
      expect(n.tentativi, 1);
      expect(n.errore, isNull);
      expect(n.idempotenzaKey, 'key-1');
      expect(n.createdAt, '2026-10-20T10:00:00Z');
    });

    test('mappa vuota: default stato programmata e tentativi 0', () {
      final n = Notifica.fromMap({}, id: 'n-1');

      expect(n.id, 'n-1');
      expect(n.aziendaId, isNull);
      expect(n.utenteUid, isNull);
      expect(n.mittenteUid, isNull);
      expect(n.tipo, isNull);
      expect(n.titolo, isNull);
      expect(n.testo, isNull);
      expect(n.targetTipo, isNull);
      expect(n.targetId, isNull);
      expect(n.canale, isNull);
      expect(n.stato, 'programmata');
      expect(n.programmataAt, isNull);
      expect(n.inviataAt, isNull);
      expect(n.lettaAt, isNull);
      expect(n.tentativi, 0);
      expect(n.errore, isNull);
      expect(n.idempotenzaKey, isNull);
      expect(n.createdAt, isNull);
    });

    test('tentativi numerico viene convertito a int', () {
      final n = Notifica.fromMap({'tentativi': 2.0}, id: 'n-1');
      expect(n.tentativi, 2);
    });
  });

  group('Notifica.toMap', () {
    test('serializza in snake_case senza id', () {
      final n = Notifica(
        id: 'n-1',
        aziendaId: 'az-1',
        utenteUid: 'u-1',
        mittenteUid: 'u-2',
        tipo: 'task',
        titolo: 'Task scaduto',
        testo: 'Il task è scaduto',
        targetTipo: 'task',
        targetId: 't-1',
        canale: 'push',
        stato: 'inviata',
        programmataAt: '2026-10-23T09:00:00Z',
        inviataAt: '2026-10-23T09:00:02Z',
        lettaAt: null,
        tentativi: 0,
        errore: null,
        idempotenzaKey: 'key-2',
        createdAt: '2026-10-20T10:00:00Z',
      );

      final map = n.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['azienda_id'], 'az-1');
      expect(map['utente_uid'], 'u-1');
      expect(map['mittente_uid'], 'u-2');
      expect(map['tipo'], 'task');
      expect(map['titolo'], 'Task scaduto');
      expect(map['testo'], 'Il task è scaduto');
      expect(map['target_tipo'], 'task');
      expect(map['target_id'], 't-1');
      expect(map['canale'], 'push');
      expect(map['stato'], 'inviata');
      expect(map['programmata_at'], '2026-10-23T09:00:00Z');
      expect(map['inviata_at'], '2026-10-23T09:00:02Z');
      expect(map['letta_at'], isNull);
      expect(map['tentativi'], 0);
      expect(map['errore'], isNull);
      expect(map['idempotenza_key'], 'key-2');
      expect(map['created_at'], '2026-10-20T10:00:00Z');
    });

    test('round-trip fromMap(toMap(...)) conserva i valori', () {
      final originale = Notifica(
        id: 'n-1',
        aziendaId: 'az-1',
        utenteUid: 'u-1',
        mittenteUid: 'u-2',
        tipo: 'promemoria',
        titolo: 'Promemoria',
        testo: 'Ricordati della visita',
        targetTipo: 'visita',
        targetId: 'v-1',
        canale: 'email',
        stato: 'fallita',
        programmataAt: '2026-10-23T09:00:00Z',
        inviataAt: '2026-10-23T09:00:03Z',
        lettaAt: '2026-10-23T09:05:00Z',
        tentativi: 2,
        errore: 'smtp error',
        idempotenzaKey: 'key-3',
        createdAt: '2026-10-20T10:00:00Z',
      );

      final ricostruito = Notifica.fromMap(originale.toMap(), id: originale.id);

      expect(ricostruito.id, originale.id);
      expect(ricostruito.aziendaId, originale.aziendaId);
      expect(ricostruito.utenteUid, originale.utenteUid);
      expect(ricostruito.mittenteUid, originale.mittenteUid);
      expect(ricostruito.tipo, originale.tipo);
      expect(ricostruito.titolo, originale.titolo);
      expect(ricostruito.testo, originale.testo);
      expect(ricostruito.targetTipo, originale.targetTipo);
      expect(ricostruito.targetId, originale.targetId);
      expect(ricostruito.canale, originale.canale);
      expect(ricostruito.stato, originale.stato);
      expect(ricostruito.programmataAt, originale.programmataAt);
      expect(ricostruito.inviataAt, originale.inviataAt);
      expect(ricostruito.lettaAt, originale.lettaAt);
      expect(ricostruito.tentativi, originale.tentativi);
      expect(ricostruito.errore, originale.errore);
      expect(ricostruito.idempotenzaKey, originale.idempotenzaKey);
      expect(ricostruito.createdAt, originale.createdAt);
    });
  });

  group('etichettaTipoNotifica', () {
    test('traduce i valori noti', () {
      expect(etichettaTipoNotifica('appuntamento'), 'Appuntamento');
      expect(etichettaTipoNotifica('task'), 'Task');
      expect(etichettaTipoNotifica('promemoria'), 'Promemoria');
      expect(etichettaTipoNotifica('chat'), 'Chat');
      expect(etichettaTipoNotifica('comunicazione'), 'Comunicazione');
    });

    test('fallback per null/empty e valore sconosciuto', () {
      expect(etichettaTipoNotifica(null), 'Non definita');
      expect(etichettaTipoNotifica(''), 'Non definita');
      expect(etichettaTipoNotifica('sondaggio'), 'sondaggio');
    });
  });

  group('etichettaCanaleNotifica', () {
    test('traduce i valori noti', () {
      expect(etichettaCanaleNotifica('inapp'), 'In app');
      expect(etichettaCanaleNotifica('push'), 'Push');
      expect(etichettaCanaleNotifica('whatsapp'), 'WhatsApp');
      expect(etichettaCanaleNotifica('email'), 'Email');
    });

    test('fallback per null/empty e valore sconosciuto', () {
      expect(etichettaCanaleNotifica(null), 'Non definito');
      expect(etichettaCanaleNotifica(''), 'Non definito');
      expect(etichettaCanaleNotifica('sms'), 'sms');
    });
  });

  group('notificaNonLetta', () {
    test('true quando lettaAt è null o vuoto', () {
      expect(notificaNonLetta(Notifica(id: 'n-1')), isTrue);
      expect(notificaNonLetta(Notifica(id: 'n-1', lettaAt: '')), isTrue);
      expect(notificaNonLetta(Notifica(id: 'n-1', lettaAt: '   ')), isTrue);
    });

    test('false quando lettaAt è valorizzata', () {
      expect(
        notificaNonLetta(
            Notifica(id: 'n-1', lettaAt: '2026-10-23T09:05:00Z')),
        isFalse,
      );
    });
  });
}
