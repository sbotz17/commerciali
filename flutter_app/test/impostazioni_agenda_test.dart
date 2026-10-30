import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/services/sp_service.dart';

void main() {
  group('normalizzaImpostazioniAgenda', () {
    test('mappa vuota restituisce tutti i default', () {
      final risultato = normalizzaImpostazioniAgenda({});
      expect(risultato['fuso_orario'], 'Europe/Rome');
      expect(risultato['anticipo_min'], 1440);
      expect(risultato['orario_invio_cliente'], '18:00');
      expect(risultato['canale_cliente'], 'whatsapp');
      expect(risultato['slot_durata_min'], 60);
      expect(risultato['slot_finestra_giorni'], 14);
      expect(risultato['slot_scadenza_giorni'], 7);
      expect(risultato['allegati_max_kb'], 5120);
      expect(risultato['allegati_max'], 10);
      expect(risultato['maps_attivo'], isTrue);
    });

    test('override validi in snake_case', () {
      final risultato = normalizzaImpostazioniAgenda({
        'fuso_orario': 'Europe/Berlin',
        'anticipo_min': 60,
        'orario_invio_cliente': '09:30',
        'canale_cliente': 'email',
        'slot_durata_min': 30,
        'slot_finestra_giorni': 21,
        'slot_scadenza_giorni': 3,
        'allegati_max_kb': 2048,
        'allegati_max': 5,
        'maps_attivo': false,
      });
      expect(risultato['fuso_orario'], 'Europe/Berlin');
      expect(risultato['anticipo_min'], 60);
      expect(risultato['orario_invio_cliente'], '09:30');
      expect(risultato['canale_cliente'], 'email');
      expect(risultato['slot_durata_min'], 30);
      expect(risultato['slot_finestra_giorni'], 21);
      expect(risultato['slot_scadenza_giorni'], 3);
      expect(risultato['allegati_max_kb'], 2048);
      expect(risultato['allegati_max'], 5);
      expect(risultato['maps_attivo'], isFalse);
    });

    test('override validi in camelCase', () {
      final risultato = normalizzaImpostazioniAgenda({
        'fusoOrario': 'America/New_York',
        'anticipoMin': 90,
        'orarioInvioCliente': '08:15',
        'canaleCliente': 'sms',
        'slotDurataMin': 45,
        'slotFinestraGiorni': 10,
        'slotScadenzaGiorni': 5,
        'allegatiMaxKb': 1024,
        'allegatiMax': 3,
        'mapsAttivo': false,
      });
      expect(risultato['fuso_orario'], 'America/New_York');
      expect(risultato['anticipo_min'], 90);
      expect(risultato['orario_invio_cliente'], '08:15');
      expect(risultato['canale_cliente'], 'sms');
      expect(risultato['slot_durata_min'], 45);
      expect(risultato['slot_finestra_giorni'], 10);
      expect(risultato['slot_scadenza_giorni'], 5);
      expect(risultato['allegati_max_kb'], 1024);
      expect(risultato['allegati_max'], 3);
      expect(risultato['maps_attivo'], isFalse);
    });

    test('interi invalidi (zero, negativi, non numerici) ricadono sul default',
        () {
      final risultato = normalizzaImpostazioniAgenda({
        'anticipo_min': 0,
        'slot_durata_min': -5,
        'slot_finestra_giorni': 'abc',
        'slot_scadenza_giorni': 'tanti',
        'allegati_max_kb': -1,
        'allegati_max': 0,
      });
      expect(risultato['anticipo_min'], 1440);
      expect(risultato['slot_durata_min'], 60);
      expect(risultato['slot_finestra_giorni'], 14);
      expect(risultato['slot_scadenza_giorni'], 7);
      expect(risultato['allegati_max_kb'], 5120);
      expect(risultato['allegati_max'], 10);
    });

    test('orari invalidi ricadono sul default', () {
      final risultato = normalizzaImpostazioniAgenda({
        'orario_invio_cliente': '25:00',
      });
      expect(risultato['orario_invio_cliente'], '18:00');

      final risultato2 = normalizzaImpostazioniAgenda({
        'orarioInvioCliente': '9:30',
      });
      expect(risultato2['orario_invio_cliente'], '18:00');

      final risultato3 = normalizzaImpostazioniAgenda({
        'orario_invio_cliente': '',
      });
      expect(risultato3['orario_invio_cliente'], '18:00');
    });

    test('testuali vuoti e booleani non validi ricadono sul default', () {
      final risultato = normalizzaImpostazioniAgenda({
        'fuso_orario': '  ',
        'canale_cliente': '',
        'maps_attivo': 'sì',
      });
      expect(risultato['fuso_orario'], 'Europe/Rome');
      expect(risultato['canale_cliente'], 'whatsapp');
      expect(risultato['maps_attivo'], isTrue);
    });
  });
}
