import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/preventivo.dart';
import 'package:commerciali_app/features/preventivi/preventivo_edit_screen.dart';

void main() {
  group('testoNumeroPreventivo', () {
    test('vuoto o null', () {
      expect(testoNumeroPreventivo(null), '');

    });

    test('interi e decimali italiani', () {
      expect(testoNumeroPreventivo(12), '12');
      expect(testoNumeroPreventivo(12.5), '12,5');
    });
  });

  group('scontoGlobaleEuroDaPercentuale', () {
    test('calcola lo sconto', () {
      expect(scontoGlobaleEuroDaPercentuale(100, 10), 10);
    });

    test('limita la percentuale tra 0 e 100', () {
      expect(scontoGlobaleEuroDaPercentuale(100, 150), 100);
      expect(scontoGlobaleEuroDaPercentuale(100, -5), 0);
    });
  });

  group('rigaPreventivoDaCampi', () {
    test('calcola totale riga con IVA di default', () {
      final riga = rigaPreventivoDaCampi(
        nome: 'Quadro elettrico',
        quantita: '2',
        prezzo: '100',
        scontoPerc: '0',
      );
      expect(riga.nome, 'Quadro elettrico');
      expect(riga.qty, 2);
      expect(riga.prezzo, 100);
      expect(riga.ivaPerc, 22);
      expect(totaleRiga(riga), 200);
    });

    test('IVA zero esplicito resta zero', () {
      final riga = rigaPreventivoDaCampi(
        nome: 'Esente',
        quantita: '1',
        prezzo: '50',
        ivaPerc: '0',
      );
      expect(riga.ivaPerc, 0);
    });
  });

  group('totaliEditorPreventivo', () {
    test('subtotale, IVA e totale', () {
      final righe = [
        rigaPreventivoDaCampi(
          nome: 'Voce',
          quantita: '2',
          prezzo: '100',
          scontoPerc: '0',
        ),
      ];
      final totali = totaliEditorPreventivo(righe);
      expect(totali.subtotale, 200);
      expect(totali.iva, 0);
      expect(totali.totaleIva, 200);
    });

    test('sconto generale in percentuale', () {
      final righe = [
        rigaPreventivoDaCampi(
          nome: 'Voce',
          quantita: '1',
          prezzo: '100',
          scontoPerc: '0',
        ),
      ];
      final totali = totaliEditorPreventivo(righe, scontoGenerale: '10');
      expect(totali.imponibile, 90);
      expect(totali.totaleIva, 90);
    });
  });

  group('payloadPreventivoDaEditor', () {
    final righe = [
      rigaPreventivoDaCampi(
        prodottoId: 'p1',
        codice: 'SW-001',
        um: 'pz',
        nome: 'Licenza annuale',
        quantita: '2',
        prezzo: '100',
        scontoPerc: '0',
      ),
    ];

    test('chiavi Firestore e dati generali ripuliti', () {
      final payload = payloadPreventivoDaEditor(
        clienteId: ' c1 ',
        clienteNome: ' ACME Srl ',
        stato: ' Inviato ',
        note: ' Nota ',
        righe: righe,
      );

      expect(
        payload.keys,
        containsAll(<String>[
          'cliente_id',
          'cliente_nome',
          'stato',
          'note',
          'sconto',
          'righe',
          'subtotale',
          'imp_sconto',
          'imponibile',
          'iva',
          'totale_iva',
        ]),
      );
      expect(payload['cliente_id'], 'c1');
      expect(payload['cliente_nome'], 'ACME Srl');
      expect(payload['stato'], 'inviato');
      expect(payload['note'], 'Nota');
      expect(payload['sconto'], 0);
    });

    test('cliente assente diventa null e stato vuoto diventa bozza', () {
      final payload = payloadPreventivoDaEditor(clienteId: '  ', stato: '  ');
      expect(payload['cliente_id'], isNull);
      expect(payload['cliente_nome'], '');
      expect(payload['stato'], 'bozza');
      expect(payload['righe'], isEmpty);
    });

    test('righe serializzate in camelCase', () {
      final payload = payloadPreventivoDaEditor(righe: righe);
      final serializzate = payload['righe'] as List<dynamic>;

      expect(serializzate, hasLength(1));
      final riga = serializzate.first as Map<String, dynamic>;
      expect(riga['prodottoId'], 'p1');
      expect(riga['codice'], 'SW-001');
      expect(riga['um'], 'pz');
      expect(riga['nome'], 'Licenza annuale');
      expect(riga['prezzo'], 100);
      expect(riga['qty'], 2);
      expect(riga['scontoPerc'], 0);
      expect(riga['scontoVal'], 0);
      expect(riga['ivaPerc'], 22);
    });

    test('totali senza sconto generale', () {
      final payload = payloadPreventivoDaEditor(righe: righe);
      expect(payload['subtotale'], 200);
      expect(payload['imp_sconto'], 0);
      expect(payload['imponibile'], 200);
      expect(payload['iva'], 0);
      expect(payload['totale_iva'], 200);
    });

    test('totali con sconto generale in percentuale', () {
      final payload = payloadPreventivoDaEditor(sconto: 10, righe: righe);
      expect(payload['sconto'], 10);
      expect(payload['subtotale'], 200);
      expect(payload['imp_sconto'], 20);
      expect(payload['imponibile'], 180);
      expect(payload['iva'], 0);
      expect(payload['totale_iva'], 180);
    });
  });

  group('datiServizioPreventivo', () {
    test('traduce le chiavi snake_case in camelCase', () {
      final dati = datiServizioPreventivo({
        'cliente_id': 'c1',
        'cliente_nome': 'ACME Srl',
        'stato': 'inviato',
        'note': 'Nota',
        'sconto': 10,
        'righe': [
          {'nome': 'Voce'},
        ],
        'subtotale': 200.0,
        'imp_sconto': 20.0,
        'imponibile': 180.0,
        'iva': 0.0,
        'totale_iva': 180.0,
      });

      expect(dati, {
        'clienteId': 'c1',
        'clienteNome': 'ACME Srl',
        'stato': 'inviato',
        'note': 'Nota',
        'sconto': 10,
        'righe': [
          {'nome': 'Voce'},
        ],
        'subtotale': 200.0,
        'impSconto': 20.0,
        'imponibile': 180.0,
        'iva': 0.0,
        'totaleIva': 180.0,
      });
    });

    test('chiavi mancanti restano null', () {
      final dati = datiServizioPreventivo({'note': 'Solo note'});
      expect(dati['clienteId'], isNull);
      expect(dati['sconto'], isNull);
      expect(dati['note'], 'Solo note');
    });
  });


  group('puoCreareRevisione', () {
    test('solo gli stati inviati/accettati/rifiutati', () {
      expect(puoCreareRevisione('inviato'), isTrue);
      expect(puoCreareRevisione('accettato'), isTrue);
      expect(puoCreareRevisione('rifiutato'), isTrue);
      expect(puoCreareRevisione('bozza'), isFalse);
      expect(puoCreareRevisione('revisionato'), isFalse);
    });
  });

  group('messaggioErroreCaricamentoPreventivo', () {
    test('errore generico in italiano', () {
      expect(
        messaggioErroreCaricamentoPreventivo(Exception('rete')),
        isNotEmpty,
      );
    });
  });
}
