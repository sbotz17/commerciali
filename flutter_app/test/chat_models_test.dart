import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/messaggio_chat.dart';
import 'package:commerciali_app/data/models/stanza_chat.dart';

void main() {
  group('StanzaChat.fromMap', () {
    test('legge tutti i campi', () {
      final s = StanzaChat.fromMap({
        'azienda_id': 'az-1',
        'tipo': 'gruppo',
        'nome': 'Commerciali',
        'partecipanti_uids': ['u-1', 'u-2', 'u-3'],
        'creatore_uid': 'u-1',
        'ultimo_messaggio': 'Ciao',
        'ultimo_messaggio_at': '2026-10-24T10:00:00Z',
        'created_at': '2026-10-20T10:00:00Z',
        'updated_at': '2026-10-24T10:00:05Z',
      }, id: 's-1');

      expect(s.id, 's-1');
      expect(s.aziendaId, 'az-1');
      expect(s.tipo, 'gruppo');
      expect(s.nome, 'Commerciali');
      expect(s.partecipantiUids, ['u-1', 'u-2', 'u-3']);
      expect(s.creatoreUid, 'u-1');
      expect(s.ultimoMessaggio, 'Ciao');
      expect(s.ultimoMessaggioAt, '2026-10-24T10:00:00Z');
      expect(s.createdAt, '2026-10-20T10:00:00Z');
      expect(s.updatedAt, '2026-10-24T10:00:05Z');
    });

    test('mappa vuota: default tipo diretta e partecipanti vuoti', () {
      final s = StanzaChat.fromMap({}, id: 's-1');

      expect(s.id, 's-1');
      expect(s.aziendaId, isNull);
      expect(s.tipo, 'diretta');
      expect(s.nome, isNull);
      expect(s.partecipantiUids, isEmpty);
      expect(s.creatoreUid, isNull);
      expect(s.ultimoMessaggio, isNull);
      expect(s.ultimoMessaggioAt, isNull);
      expect(s.createdAt, isNull);
      expect(s.updatedAt, isNull);
    });
  });

  group('StanzaChat.toMap', () {
    test('serializza in snake_case senza id', () {
      final s = StanzaChat(
        id: 's-1',
        aziendaId: 'az-1',
        tipo: 'diretta',
        nome: null,
        partecipantiUids: const ['u-1', 'u-2'],
        creatoreUid: 'u-1',
        ultimoMessaggio: 'Ciao',
        ultimoMessaggioAt: '2026-10-24T10:00:00Z',
        createdAt: '2026-10-20T10:00:00Z',
        updatedAt: null,
      );

      final map = s.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['azienda_id'], 'az-1');
      expect(map['tipo'], 'diretta');
      expect(map['nome'], isNull);
      expect(map['partecipanti_uids'], ['u-1', 'u-2']);
      expect(map['creatore_uid'], 'u-1');
      expect(map['ultimo_messaggio'], 'Ciao');
      expect(map['ultimo_messaggio_at'], '2026-10-24T10:00:00Z');
      expect(map['created_at'], '2026-10-20T10:00:00Z');
      expect(map['updated_at'], isNull);
    });

    test('round-trip fromMap(toMap(...)) conserva i valori', () {
      final originale = StanzaChat(
        id: 's-1',
        aziendaId: 'az-1',
        tipo: 'gruppo',
        nome: 'Commerciali',
        partecipantiUids: const ['u-1', 'u-2', 'u-3'],
        creatoreUid: 'u-1',
        ultimoMessaggio: 'Ciao',
        ultimoMessaggioAt: '2026-10-24T10:00:00Z',
        createdAt: '2026-10-20T10:00:00Z',
        updatedAt: '2026-10-24T10:00:05Z',
      );

      final ricostruito =
          StanzaChat.fromMap(originale.toMap(), id: originale.id);

      expect(ricostruito.id, originale.id);
      expect(ricostruito.aziendaId, originale.aziendaId);
      expect(ricostruito.tipo, originale.tipo);
      expect(ricostruito.nome, originale.nome);
      expect(ricostruito.partecipantiUids, originale.partecipantiUids);
      expect(ricostruito.creatoreUid, originale.creatoreUid);
      expect(ricostruito.ultimoMessaggio, originale.ultimoMessaggio);
      expect(ricostruito.ultimoMessaggioAt, originale.ultimoMessaggioAt);
      expect(ricostruito.createdAt, originale.createdAt);
      expect(ricostruito.updatedAt, originale.updatedAt);
    });
  });

  group('MessaggioChat.fromMap', () {
    test('legge tutti i campi', () {
      final m = MessaggioChat.fromMap({
        'mittente_uid': 'u-1',
        'testo': 'Ciao',
        'tipo': 'testo',
        'image_key': null,
        'created_at': '2026-10-24T10:00:00Z',
        'eliminato': false,
        'idempotenza_key': 'key-1',
      }, id: 'm-1');

      expect(m.id, 'm-1');
      expect(m.mittenteUid, 'u-1');
      expect(m.testo, 'Ciao');
      expect(m.tipo, 'testo');
      expect(m.imageKey, isNull);
      expect(m.createdAt, '2026-10-24T10:00:00Z');
      expect(m.eliminato, isFalse);
      expect(m.idempotenzaKey, 'key-1');
    });

    test('mappa vuota: default tipo testo e eliminato false', () {
      final m = MessaggioChat.fromMap({}, id: 'm-1');

      expect(m.id, 'm-1');
      expect(m.mittenteUid, isNull);
      expect(m.testo, isNull);
      expect(m.tipo, 'testo');
      expect(m.imageKey, isNull);
      expect(m.createdAt, isNull);
      expect(m.eliminato, isFalse);
      expect(m.idempotenzaKey, isNull);
    });
  });

  group('MessaggioChat.toMap', () {
    test('serializza in snake_case senza id', () {
      final m = MessaggioChat(
        id: 'm-1',
        mittenteUid: 'u-1',
        testo: 'Ciao',
        tipo: 'immagine',
        imageKey: 'img/1.jpg',
        createdAt: '2026-10-24T10:00:00Z',
        eliminato: true,
        idempotenzaKey: 'key-2',
      );

      final map = m.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['mittente_uid'], 'u-1');
      expect(map['testo'], 'Ciao');
      expect(map['tipo'], 'immagine');
      expect(map['image_key'], 'img/1.jpg');
      expect(map['created_at'], '2026-10-24T10:00:00Z');
      expect(map['eliminato'], isTrue);
      expect(map['idempotenza_key'], 'key-2');
    });

    test('round-trip fromMap(toMap(...)) conserva i valori', () {
      final originale = MessaggioChat(
        id: 'm-1',
        mittenteUid: 'u-1',
        testo: 'Ciao',
        tipo: 'testo',
        imageKey: null,
        createdAt: '2026-10-24T10:00:00Z',
        eliminato: false,
        idempotenzaKey: 'key-3',
      );

      final ricostruito =
          MessaggioChat.fromMap(originale.toMap(), id: originale.id);

      expect(ricostruito.id, originale.id);
      expect(ricostruito.mittenteUid, originale.mittenteUid);
      expect(ricostruito.testo, originale.testo);
      expect(ricostruito.tipo, originale.tipo);
      expect(ricostruito.imageKey, originale.imageKey);
      expect(ricostruito.createdAt, originale.createdAt);
      expect(ricostruito.eliminato, originale.eliminato);
      expect(ricostruito.idempotenzaKey, originale.idempotenzaKey);
    });
  });

  group('idChatDiretta', () {
    test('ordina gli uid e produce id deterministico', () {
      expect(idChatDiretta('az-1', 'u-b', 'u-a'),
          'diretta_az-1_u-a_u-b');
      expect(idChatDiretta('az-1', 'u-a', 'u-b'),
          'diretta_az-1_u-a_u-b');
    });

    test('uid uguali: ordine stabile', () {
      expect(idChatDiretta('az-1', 'u-a', 'u-a'), 'diretta_az-1_u-a_u-a');
    });
  });

  group('anteprimaMessaggio', () {
    test('messaggio eliminato', () {
      expect(
        anteprimaMessaggio(MessaggioChat(id: 'm-1', eliminato: true)),
        'Messaggio eliminato',
      );
    });

    test('messaggio immagine', () {
      expect(
        anteprimaMessaggio(MessaggioChat(id: 'm-1', tipo: 'immagine')),
        '[Immagine]',
      );
    });

    test('testo corto restituito integralmente', () {
      expect(
        anteprimaMessaggio(MessaggioChat(id: 'm-1', testo: 'Ciao')),
        'Ciao',
      );
    });

    test('testo troncato a 80 caratteri', () {
      final lungo = 'a' * 120;
      final anteprima = anteprimaMessaggio(MessaggioChat(id: 'm-1', testo: lungo));
      expect(anteprima.length, 80);
      expect(anteprima, lungo.substring(0, 80));
    });

    test('testo vuoto o nullo: Nuovo messaggio', () {
      expect(
        anteprimaMessaggio(MessaggioChat(id: 'm-1', testo: null)),
        'Nuovo messaggio',
      );
      expect(
        anteprimaMessaggio(MessaggioChat(id: 'm-1', testo: '   ')),
        'Nuovo messaggio',
      );
    });
  });

  group('nomeStanzaChat', () {
    test("diretta: mostra il nome dell'altro partecipante", () {
      final s = StanzaChat(
        id: 's-1',
        tipo: 'diretta',
        partecipantiUids: const ['u-1', 'u-2'],
      );
      expect(
        nomeStanzaChat(s, uidCorrente: 'u-1', nomiUtenti: {'u-2': 'Mario'}),
        'Mario',
      );
    });

    test("diretta: mostra l'uid se il nome non è noto", () {
      final s = StanzaChat(
        id: 's-1',
        tipo: 'diretta',
        partecipantiUids: const ['u-1', 'u-2'],
      );
      expect(nomeStanzaChat(s, uidCorrente: 'u-1'), 'u-2');
    });

    test('diretta: funziona in entrambi gli ordini', () {
      final s = StanzaChat(
        id: 's-1',
        tipo: 'diretta',
        partecipantiUids: const ['u-2', 'u-1'],
      );
      expect(
        nomeStanzaChat(s, uidCorrente: 'u-1', nomiUtenti: {'u-2': 'Mario'}),
        'Mario',
      );
    });

    test('gruppo: mostra il nome della stanza', () {
      final s = StanzaChat(
        id: 's-1',
        tipo: 'gruppo',
        nome: 'Commerciali',
        partecipantiUids: const ['u-1', 'u-2'],
      );
      expect(nomeStanzaChat(s, uidCorrente: 'u-1'), 'Commerciali');
    });

    test('gruppo senza nome: fallback Gruppo', () {
      final s = StanzaChat(
        id: 's-1',
        tipo: 'gruppo',
        partecipantiUids: const ['u-1', 'u-2'],
      );
      expect(nomeStanzaChat(s, uidCorrente: 'u-1'), 'Gruppo');
    });
  });
}
