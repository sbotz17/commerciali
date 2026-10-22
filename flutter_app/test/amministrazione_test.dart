import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/licenza.dart';
import 'package:commerciali_app/data/models/ruolo.dart';

void main() {
  group('Ruolo.fromMap', () {
    test('legge i campi base', () {
      final ruolo = Ruolo.fromMap({
        'azienda_id': 'az-1',
        'nome': 'Amministratore',
        'chiave': 'admin',
        'descrizione': 'Accesso completo',
        'sconto_max': 100,
        'permessi': {'clienti': 'entrambi', 'preventivi_propri': 'entrambi'},
        'sistema': true,
      }, id: 'r-1');

      expect(ruolo.id, 'r-1');
      expect(ruolo.aziendaId, 'az-1');
      expect(ruolo.nome, 'Amministratore');
      expect(ruolo.chiave, 'admin');
      expect(ruolo.descrizione, 'Accesso completo');
      expect(ruolo.scontoMax, 100);
      expect(ruolo.sistema, isTrue);
    });

    test('legge la mappa dei permessi', () {
      final ruolo = Ruolo.fromMap({
        'nome': 'Commerciale',
        'permessi': {
          'dashboard': 'lettura',
          'listino': 'lettura',
          'clienti': 'entrambi',
        },
      }, id: 'r-2');

      expect(ruolo.permessi, {
        'dashboard': 'lettura',
        'listino': 'lettura',
        'clienti': 'entrambi',
      });
    });

    test('sconto_max assente vale 0', () {
      final ruolo = Ruolo.fromMap({'nome': 'Commerciale'}, id: 'r-3');

      expect(ruolo.scontoMax, 0);
    });

    test('sistema assente vale false', () {
      final ruolo = Ruolo.fromMap({'nome': 'Commerciale'}, id: 'r-4');

      expect(ruolo.sistema, isFalse);
    });

    test('permessi assenti valgono mappa vuota', () {
      final ruolo = Ruolo.fromMap({'nome': 'Commerciale'}, id: 'r-5');

      expect(ruolo.permessi, isEmpty);
    });

    test('nome, chiave e descrizione assenti valgono vuoto/null', () {
      final ruolo = Ruolo.fromMap({}, id: 'r-6');

      expect(ruolo.nome, '');
      expect(ruolo.chiave, isNull);
      expect(ruolo.descrizione, isNull);
    });
  });

  group('Licenza.fromMap', () {
    test('legge i campi base e le date', () {
      final licenza = Licenza.fromMap({
        'azienda_id': 'az-1',
        'piano': 'base',
        'stato': 'attiva',
        'data_inizio': '2026-10-22',
        'data_fine': '2027-10-22',
        'max_utenti': 5,
        'max_preventivi': 100,
        'note': 'rinnovo annuale',
      }, id: 'az-1');

      expect(licenza.id, 'az-1');
      expect(licenza.aziendaId, 'az-1');
      expect(licenza.piano, 'base');
      expect(licenza.stato, 'attiva');
      expect(licenza.dataInizio, '2026-10-22');
      expect(licenza.dataFine, '2027-10-22');
      expect(licenza.maxUtenti, 5);
      expect(licenza.maxPreventivi, 100);
      expect(licenza.note, 'rinnovo annuale');
    });

    test('piano e stato assenti valgono trial/attiva', () {
      final licenza = Licenza.fromMap({}, id: 'az-1');

      expect(licenza.piano, 'trial');
      expect(licenza.stato, 'attiva');
    });

    test('date assenti valgono null', () {
      final licenza = Licenza.fromMap({
        'data_inizio': '2026-10-22',
      }, id: 'az-1');

      expect(licenza.dataInizio, '2026-10-22');
      expect(licenza.dataFine, isNull);
    });

    test('max_utenti e max_preventivi assenti valgono null', () {
      final licenza = Licenza.fromMap({
        'max_utenti': 3,
      }, id: 'az-1');

      expect(licenza.maxUtenti, 3);
      expect(licenza.maxPreventivi, isNull);
    });

    test('azienda_id assente coincide con l\'id documento', () {
      final licenza = Licenza.fromMap({}, id: 'az-9');

      expect(licenza.id, 'az-9');
      expect(licenza.aziendaId, 'az-9');
    });
  });
}
