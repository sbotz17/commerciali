import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/messaggio_chat.dart';
import 'package:commerciali_app/data/models/stanza_chat.dart';
import 'package:commerciali_app/features/chat/chat_thread_screen.dart';

StanzaChat _stanza(List<String> partecipanti) {
  return StanzaChat(id: 'stanza-1', partecipantiUids: partecipanti);
}

MessaggioChat _messaggio({
  required String id,
  String? createdAt,
  String? testo,
  String tipo = 'testo',
  bool eliminato = false,
}) {
  return MessaggioChat(
    id: id,
    createdAt: createdAt,
    testo: testo,
    tipo: tipo,
    eliminato: eliminato,
  );
}

void main() {
  group('oraMessaggio', () {
    test('formatta l\'orario locale in HH:mm', () {
      final messaggio = _messaggio(
        id: 'm-1',
        createdAt: DateTime(2026, 10, 24, 9, 5).toIso8601String(),
      );

      expect(oraMessaggio(messaggio), '09:05');
    });

    test('createdAt nullo o non valido: stringa vuota', () {
      expect(oraMessaggio(_messaggio(id: 'm-1')), '');
      expect(
        oraMessaggio(_messaggio(id: 'm-2', createdAt: 'non-una-data')),
        '',
      );
    });
  });

  group('raggruppaMessaggiPerGiorno', () {
    test('ordina cronologicamente e raggruppa per giorno locale', () {
      final tarda = _messaggio(
        id: 'm-3',
        createdAt: DateTime(2026, 10, 24, 18, 30).toIso8601String(),
      );
      final prima = _messaggio(
        id: 'm-1',
        createdAt: DateTime(2026, 10, 23, 9, 0).toIso8601String(),
      );
      final seconda = _messaggio(
        id: 'm-2',
        createdAt: DateTime(2026, 10, 23, 12, 15).toIso8601String(),
      );
      final originale = [tarda, prima, seconda];

      final gruppi = raggruppaMessaggiPerGiorno(originale);

      expect(gruppi.length, 2);
      expect(gruppi[0].giorno, DateTime(2026, 10, 23));
      expect(gruppi[0].messaggi.map((m) => m.id), ['m-1', 'm-2']);
      expect(gruppi[1].giorno, DateTime(2026, 10, 24));
      expect(gruppi[1].messaggi.map((m) => m.id), ['m-3']);

      // La lista di ingresso non viene riordinata.
      expect(originale.map((m) => m.id), ['m-3', 'm-1', 'm-2']);
    });

    test('i messaggi senza data finiscono in un gruppo dedicato', () {
      final conData = _messaggio(
        id: 'm-2',
        createdAt: DateTime(2026, 10, 24, 8, 0).toIso8601String(),
      );
      final senzaData = _messaggio(id: 'm-1');

      final gruppi = raggruppaMessaggiPerGiorno([conData, senzaData]);

      expect(gruppi.length, 2);
      expect(gruppi.first.giorno, isNull);
      expect(gruppi.first.messaggi.single.id, 'm-1');
      expect(gruppi.last.giorno, DateTime(2026, 10, 24));
    });

    test('lista vuota: nessun gruppo', () {
      expect(raggruppaMessaggiPerGiorno([]), isEmpty);
    });
  });

  group('etichettaGiornoChat', () {
    final adesso = DateTime(2026, 10, 24, 15, 30);

    test('oggi e ieri', () {
      expect(
        etichettaGiornoChat(DateTime(2026, 10, 24), adesso: adesso),
        'Oggi',
      );
      expect(
        etichettaGiornoChat(DateTime(2026, 10, 23), adesso: adesso),
        'Ieri',
      );
    });

    test('altri giorni in formato italiano', () {
      expect(
        etichettaGiornoChat(DateTime(2026, 10, 20), adesso: adesso),
        '20/10/2026',
      );
    });

    test('giorno assente', () {
      expect(etichettaGiornoChat(null, adesso: adesso), 'Senza data');
    });
  });

  group('destinatariNotificaChat', () {
    test('esclude il mittente', () {
      final stanza = _stanza(['ana', 'bruno', 'carla']);

      expect(
        destinatariNotificaChat(stanza, mittenteUid: 'bruno'),
        ['ana', 'carla'],
      );
    });

    test('rimuove i duplicati mantenendo l\'ordine', () {
      final stanza = _stanza(['ana', 'bruno', 'ana', 'bruno']);

      expect(
        destinatariNotificaChat(stanza, mittenteUid: 'carla'),
        ['ana', 'bruno'],
      );
    });

    test('scarta gli uid vuoti o con soli spazi', () {
      final stanza = _stanza(['', '  ', 'ana', ' ', 'bruno']);

      expect(
        destinatariNotificaChat(stanza, mittenteUid: 'carla'),
        ['ana', 'bruno'],
      );
    });

    test('stanza senza partecipanti: nessun destinatario', () {
      expect(
        destinatariNotificaChat(_stanza([]), mittenteUid: 'ana'),
        isEmpty,
      );
    });

    test('chat diretta: solo l\'altro partecipante', () {
      final stanza = _stanza(['ana', 'bruno']);

      expect(destinatariNotificaChat(stanza, mittenteUid: 'ana'), ['bruno']);
    });

    test('mittente assente tra i partecipanti: li restituisce tutti', () {
      final stanza = _stanza(['ana', 'bruno']);

      expect(
        destinatariNotificaChat(stanza, mittenteUid: 'carla'),
        ['ana', 'bruno'],
      );
    });
  });
}
