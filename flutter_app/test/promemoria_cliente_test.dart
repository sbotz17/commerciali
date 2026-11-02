import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/appuntamento.dart';

void main() {
  Appuntamento appuntamento({
    String data = '2026-10-25',
    String? ora = '10:00',
    String? dataFine = '2026-10-25',
    String? oraFine = '11:00',
    bool tuttoIlGiorno = false,
  }) {
    return Appuntamento(
      id: 'a1',
      data: data,
      ora: ora,
      dataFine: dataFine,
      oraFine: oraFine,
      tuttoIlGiorno: tuttoIlGiorno,
    );
  }

  group('orarioAppuntamentoCambiato', () {
    test('un nuovo appuntamento richiede sempre l avviso', () {
      expect(
        orarioAppuntamentoCambiato(
          null,
          data: '2026-10-25',
          ora: '10:00',
          dataFine: '2026-10-25',
          oraFine: '11:00',
        ),
        isTrue,
      );
    });

    test('stesso orario non richiede un nuovo avviso', () {
      expect(
        orarioAppuntamentoCambiato(
          appuntamento(),
          data: '2026-10-25',
          ora: '10:00',
          dataFine: '2026-10-25',
          oraFine: '11:00',
        ),
        isFalse,
      );
    });

    test('cambia con data, ora, fine o tutto il giorno', () {
      final base = appuntamento();
      expect(
        orarioAppuntamentoCambiato(
          base,
          data: '2026-10-26',
          ora: '10:00',
          dataFine: '2026-10-26',
          oraFine: '11:00',
        ),
        isTrue,
      );
      expect(
        orarioAppuntamentoCambiato(
          base,
          data: '2026-10-25',
          ora: '10:30',
          dataFine: '2026-10-25',
          oraFine: '11:00',
        ),
        isTrue,
      );
      expect(
        orarioAppuntamentoCambiato(
          base,
          data: '2026-10-25',
          ora: '10:00',
          dataFine: '2026-10-25',
          oraFine: '12:00',
        ),
        isTrue,
      );
      expect(
        orarioAppuntamentoCambiato(
          base,
          data: '2026-10-25',
          ora: null,
          dataFine: '2026-10-25',
          oraFine: null,
          tuttoIlGiorno: true,
        ),
        isTrue,
      );
    });
  });

  group('normalizzaCanaliCliente', () {
    test('tiene solo whatsapp ed email, senza duplicati', () {
      expect(normalizzaCanaliCliente(['email', 'whatsapp', 'email', 'sms']), [
        'whatsapp',
        'email',
      ]);
    });

    test('campo assente restituisce entrambi i canali', () {
      expect(normalizzaCanaliCliente(null), ['whatsapp', 'email']);
    });

    test('lista vuota resta vuota', () {
      expect(normalizzaCanaliCliente(const []), isEmpty);
    });
  });

  group('etichettaPromemoriaCliente', () {
    test('mostra i canali inviati', () {
      expect(
        etichettaPromemoriaCliente({
          'canali': {
            'whatsapp': {'stato': 'inviato'},
            'email': {'stato': 'inviato'},
          },
        }),
        'Inviato su WhatsApp e Email',
      );
    });

    test('segnala i problemi senza nascondere gli invii', () {
      expect(
        etichettaPromemoriaCliente({
          'canali': {
            'whatsapp': {'stato': 'inviato'},
            'email': {'stato': 'non_configurata'},
          },
        }),
        'Inviato su WhatsApp · Email non configurata',
      );
    });

    test('senza invii elenca solo i problemi', () {
      expect(
        etichettaPromemoriaCliente({
          'canali': {
            'whatsapp': {'stato': 'senza_recapito'},
            'email': {'stato': 'errore'},
          },
        }),
        'Non inviato: WhatsApp senza recapito · Email non inviata',
      );
    });

    test('log assente o vuoto non produce testo', () {
      expect(etichettaPromemoriaCliente(null), '');
      expect(etichettaPromemoriaCliente(const {}), '');
    });
  });

  group('dataPromemoriaCliente', () {
    test('formatta la data ISO in italiano', () {
      final iso = DateTime(2026, 10, 25, 9, 5).toUtc().toIso8601String();
      final atteso = DateTime.parse(iso).toLocal();
      String due(int valore) => valore.toString().padLeft(2, '0');
      expect(
        dataPromemoriaCliente({'inviato_at': iso}),
        '${due(atteso.day)}/${due(atteso.month)}/${atteso.year} '
        '${due(atteso.hour)}:${due(atteso.minute)}',
      );
    });

    test('valore assente o non valido non produce testo', () {
      expect(dataPromemoriaCliente(const {}), '');
      expect(dataPromemoriaCliente({'inviato_at': 'ieri'}), '');
    });
  });
}
