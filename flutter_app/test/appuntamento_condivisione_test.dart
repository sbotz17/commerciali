import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/appuntamento.dart';
import 'package:commerciali_app/data/models/stanza_chat.dart';
import 'package:commerciali_app/features/calendario/dialogo_condivisione_appuntamento.dart';

void main() {
  group('Appuntamento — condivisione', () {
    test('documenti vecchi restano non condivisi', () {
      final appuntamento = Appuntamento.fromMap({
        'titolo': 'Visita',
        'data': '2026-10-24',
      }, id: 'a1');

      expect(appuntamento.invitatiUids, isEmpty);
      expect(appuntamento.conferme, isEmpty);
      expect(appuntamento.statoCondivisione, statoCondivisioneNonCondiviso);
      expect(appuntamento.inAttesaDiConferma, isFalse);
    });

    test('legge invitati, conferme e stato', () {
      final appuntamento = Appuntamento.fromMap({
        'invitati_uids': ['u1', 'u1', '', 'u2'],
        'conferme': {
          'u1': {'stato': 'confermato', 'at': '2026-10-24T10:00:00Z'},
        },
        'stato_condivisione': statoCondivisioneConfermato,
      }, id: 'a1');

      expect(appuntamento.invitatiUids, ['u1', 'u2']);
      expect(appuntamento.conferme['u1'], isA<Map>());
      expect(appuntamento.statoCondivisione, statoCondivisioneConfermato);
      expect(appuntamento.inAttesaDiConferma, isFalse);
    });

    test('toMap include i campi di condivisione', () {
      final mappa = Appuntamento(
        id: 'a1',
        invitatiUids: const ['u1'],
        conferme: const {
          'u1': {'stato': 'rifiutato'},
        },
        statoCondivisione: statoCondivisioneRifiutato,
      ).toMap();

      expect(mappa['invitati_uids'], ['u1']);
      expect(mappa['stato_condivisione'], statoCondivisioneRifiutato);
      expect(mappa['conferme'], isA<Map>());
    });
  });

  group('statoCondivisioneDaConferme', () {
    test('nessun invitato non condiviso', () {
      expect(
        statoCondivisioneDaConferme(const [], const {}),
        statoCondivisioneNonCondiviso,
      );
    });

    test('nessuna risposta è in attesa', () {
      expect(
        statoCondivisioneDaConferme(const ['u1', 'u2'], const {}),
        statoCondivisioneInAttesa,
      );
    });

    test('una conferma rende l’appuntamento confermato', () {
      expect(
        statoCondivisioneDaConferme(
          const ['u1', 'u2'],
          const {
            'u1': {'stato': 'confermato'},
          },
        ),
        statoCondivisioneConfermato,
      );
    });

    test('tutti i rifiuti rendono l’appuntamento non disponibile', () {
      expect(
        statoCondivisioneDaConferme(
          const ['u1', 'u2'],
          const {
            'u1': {'stato': 'rifiutato'},
            'u2': {'stato': 'rifiutato'},
          },
        ),
        statoCondivisioneRifiutato,
      );
    });

    test('un rifiuto con altri in attesa resta in attesa', () {
      expect(
        statoCondivisioneDaConferme(
          const ['u1', 'u2'],
          const {
            'u1': {'stato': 'rifiutato'},
          },
        ),
        statoCondivisioneInAttesa,
      );
    });
  });

  group('etichette risposte', () {
    test('stato condivisione e risposta singola', () {
      expect(
        etichettaStatoCondivisione(statoCondivisioneInAttesa),
        'In attesa di conferma',
      );
      expect(
        etichettaStatoCondivisione(statoCondivisioneConfermato),
        'Confermato',
      );
      expect(
        etichettaStatoCondivisione(statoCondivisioneRifiutato),
        'Non disponibile',
      );
      expect(etichettaRispostaInvito(null), 'In attesa');
      expect(etichettaRispostaInvito('confermato'), 'Confermato');
      expect(etichettaRispostaInvito('rifiutato'), 'Non disponibile');
    });

    test('rispostaInvito legge sia mappe sia stringhe', () {
      expect(rispostaInvito(const {}, 'u1'), isNull);
      expect(
        rispostaInvito(const {
          'u1': {'stato': 'confermato'},
        }, 'u1'),
        'confermato',
      );
      expect(rispostaInvito(const {'u1': 'rifiutato'}, 'u1'), 'rifiutato');
      expect(rispostaInvito(const {'u1': 'altro'}, 'u1'), isNull);
    });
  });

  group('gruppi di condivisione', () {
    const utenti = {'u1': 'Anna', 'u2': 'Bruno', 'u3': 'Carla'};
    const gruppo = StanzaChat(
      id: 'g1',
      tipo: 'gruppo',
      nome: 'Squadra Nord',
      partecipantiUids: ['u1', 'u2', 'esterno'],
    );
    const diretta = StanzaChat(
      id: 'd1',
      tipo: 'diretta',
      partecipantiUids: ['u1', 'u2'],
    );

    test(
      'membriGruppoInvitabili tiene solo i membri attivi e non l’utente',
      () {
        expect(membriGruppoInvitabili(gruppo, utenti, escludiUid: 'u1'), [
          'u2',
        ]);
        expect(membriGruppoInvitabili(gruppo, utenti), ['u1', 'u2']);
      },
    );

    test('gruppiCondivisibili ignora dirette e gruppi vuoti', () {
      const vuoto = StanzaChat(
        id: 'g2',
        tipo: 'gruppo',
        nome: 'Vuoto',
        partecipantiUids: ['u1'],
      );
      final risultato = gruppiCondivisibili(
        [gruppo, diretta, vuoto],
        utenti,
        escludiUid: 'u1',
      );
      expect(risultato.map((g) => g.id), ['g1']);
    });
  });
}
