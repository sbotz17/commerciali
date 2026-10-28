import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/preventivo.dart';

void main() {
  group('PreventivoRiga.fromMap / toMap', () {
    test('legge tutti i campi', () {
      final riga = PreventivoRiga.fromMap({
        'prodottoId': 'p-1',
        'codice': 'SW-001',
        'nome': 'Gestione magazzino',
        'prezzo': 1200,
        'immagine': 'https://example.com/p1.png',
        'qty': 2,
        'um': 'pz',
        'scontoPerc': 10,
        'scontoVal': 240,
        'ivaPerc': 22,
      });

      expect(riga.prodottoId, 'p-1');
      expect(riga.codice, 'SW-001');
      expect(riga.nome, 'Gestione magazzino');
      expect(riga.prezzo, 1200);
      expect(riga.immagine, 'https://example.com/p1.png');
      expect(riga.qty, 2);
      expect(riga.um, 'pz');
      expect(riga.scontoPerc, 10);
      expect(riga.scontoVal, 240);
      expect(riga.ivaPerc, 22);
    });

    test('campi assenti: default numerici e ivaPerc 22', () {
      final riga = PreventivoRiga.fromMap({});

      expect(riga.prodottoId, isNull);
      expect(riga.nome, isNull);
      expect(riga.prezzo, 0);
      expect(riga.qty, 0);
      expect(riga.scontoPerc, 0);
      expect(riga.scontoVal, 0);
      expect(riga.ivaPerc, 22);
    });

    test('toMap serializza in camelCase (come la vecchia app)', () {
      final riga = PreventivoRiga(
        prodottoId: 'p-2',
        nome: 'Licenza',
        prezzo: 99.9,
        qty: 3,
        scontoPerc: 5,
        scontoVal: 15,
        ivaPerc: 22,
      );

      final map = riga.toMap();

      expect(map['prodottoId'], 'p-2');
      expect(map['nome'], 'Licenza');
      expect(map['prezzo'], 99.9);
      expect(map['qty'], 3);
      expect(map['scontoPerc'], 5);
      expect(map['scontoVal'], 15);
      expect(map['ivaPerc'], 22);
    });
  });

  group('Preventivo.fromMap', () {
    test('legge tutti i campi, incluse le righe', () {
      final preventivo = Preventivo.fromMap({
        'azienda_id': 'az-1',
        'cliente_id': 'cl-1',
        'cliente_nome': 'ACME Srl',
        'utente_id': 'u-1',
        'numero': 'PRV-0042',
        'revisione': 1,
        'righe': [
          {'prodottoId': 'p-1', 'nome': 'A', 'prezzo': 10, 'qty': 2},
          {'prodottoId': 'p-2', 'nome': 'B', 'prezzo': 5, 'qty': 1, 'scontoVal': 1},
        ],
        'sconto': 10,
        'note': 'Valido 30 giorni',
        'subtotale': 24,
        'imp_sconto': 2.4,
        'imponibile': 21.6,
        'iva': 4.75,
        'totale_iva': 26.35,
        'stato': 'inviato',
        'created_at': '2026-10-22T10:00:00.000Z',
      }, id: 'prv-1');

      expect(preventivo.id, 'prv-1');
      expect(preventivo.aziendaId, 'az-1');
      expect(preventivo.clienteId, 'cl-1');
      expect(preventivo.clienteNome, 'ACME Srl');
      expect(preventivo.utenteId, 'u-1');
      expect(preventivo.numero, 'PRV-0042');
      expect(preventivo.revisione, 1);
      expect(preventivo.righe, hasLength(2));
      expect(preventivo.righe.first.nome, 'A');
      expect(preventivo.righe.last.scontoVal, 1);
      expect(preventivo.sconto, 10);
      expect(preventivo.note, 'Valido 30 giorni');
      expect(preventivo.subtotale, 24);
      expect(preventivo.impSconto, 2.4);
      expect(preventivo.imponibile, 21.6);
      expect(preventivo.iva, 4.75);
      expect(preventivo.totaleIva, 26.35);
      expect(preventivo.stato, 'inviato');
      expect(preventivo.createdAt, '2026-10-22T10:00:00.000Z');
    });

    test('campi assenti: default revisione 0, stato bozza, totali 0', () {
      final preventivo = Preventivo.fromMap({}, id: 'prv-1');

      expect(preventivo.id, 'prv-1');
      expect(preventivo.aziendaId, isNull);
      expect(preventivo.clienteId, isNull);
      expect(preventivo.clienteNome, isNull);
      expect(preventivo.utenteId, isNull);
      expect(preventivo.numero, isNull);
      expect(preventivo.revisione, 0);
      expect(preventivo.righe, isEmpty);
      expect(preventivo.sconto, 0);
      expect(preventivo.note, isNull);
      expect(preventivo.subtotale, 0);
      expect(preventivo.impSconto, 0);
      expect(preventivo.imponibile, 0);
      expect(preventivo.iva, 0);
      expect(preventivo.totaleIva, 0);
      expect(preventivo.stato, 'bozza');
      expect(preventivo.createdAt, isNull);
    });

    test('righe non valide vengono ignorate', () {
      final preventivo = Preventivo.fromMap({
        'righe': ['non-una-mappa', 42, {'nome': 'Valida'}],
      }, id: 'prv-1');

      expect(preventivo.righe, hasLength(1));
      expect(preventivo.righe.single.nome, 'Valida');
    });

    test('toMap serializza in snake_case senza id', () {
      final preventivo = Preventivo(
        id: 'prv-1',
        aziendaId: 'az-1',
        clienteId: 'cl-1',
        clienteNome: 'ACME Srl',
        utenteId: 'u-1',
        numero: 'PRV-0001',
        revisione: 0,
        righe: const [
          PreventivoRiga(nome: 'A', prezzo: 10, qty: 2),
        ],
        sconto: 0,
        note: 'note',
        subtotale: 20,
        impSconto: 0,
        imponibile: 20,
        iva: 0,
        totaleIva: 20,
        stato: 'bozza',
        createdAt: '2026-10-22T10:00:00.000Z',
      );

      final map = preventivo.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['azienda_id'], 'az-1');
      expect(map['cliente_id'], 'cl-1');
      expect(map['cliente_nome'], 'ACME Srl');
      expect(map['utente_id'], 'u-1');
      expect(map['numero'], 'PRV-0001');
      expect(map['revisione'], 0);
      expect(map['righe'], hasLength(1));
      expect(map['righe'].first['nome'], 'A');
      expect(map['subtotale'], 20);
      expect(map['imp_sconto'], 0);
      expect(map['totale_iva'], 20);
      expect(map['stato'], 'bozza');
      expect(map['created_at'], '2026-10-22T10:00:00.000Z');
    });
  });

  group('calcolo totali', () {
    const righe = [
      PreventivoRiga(prezzo: 100, qty: 2, scontoVal: 0),
      PreventivoRiga(prezzo: 50, qty: 1, scontoVal: 10),
    ];

    test('totaleRiga = prezzo * qty - scontoVal', () {
      expect(totaleRiga(righe[0]), 200.0);
      expect(totaleRiga(righe[1]), 40.0);
    });

    test('senza sconto globale e senza IVA', () {
      final t = calcolaTotali(righe);

      expect(t.subtotale, 240.0);
      expect(t.impSconto, 0.0);
      expect(t.imponibile, 240.0);
      expect(t.iva, 0.0);
      expect(t.totaleIva, 240.0);
    });

    test('con sconto globale in euro', () {
      final t = calcolaTotali(righe, scontoGlobaleEuro: 40);

      expect(t.subtotale, 240.0);
      expect(t.impSconto, 40.0);
      expect(t.imponibile, 200.0);
      expect(t.iva, 0.0);
      expect(t.totaleIva, 200.0);
    });

    test('con IVA inclusa (fattore 22%)', () {
      final t = calcolaTotali(righe, ivaInclusa: true);

      expect(t.subtotale, 240.0);
      expect(t.impSconto, 0.0);
      expect(t.imponibile, closeTo(240 / 1.22, 1e-9));
      expect(t.iva, closeTo(240 - (240 / 1.22), 1e-9));
      expect(t.totaleIva, 240.0);
    });

    test('sconto globale oltre il subtotale viene limitato', () {
      final t = calcolaTotali(righe, scontoGlobaleEuro: 999);

      expect(t.impSconto, 240.0);
      expect(t.imponibile, 0.0);
      expect(t.iva, 0.0);
      expect(t.totaleIva, 0.0);
    });

    test('sconto globale negativo viene azzerato', () {
      final t = calcolaTotali(righe, scontoGlobaleEuro: -10);

      expect(t.impSconto, 0.0);
      expect(t.totaleIva, 240.0);
    });

    test('nessuna riga → tutti i totali a zero', () {
      final t = calcolaTotali(const []);

      expect(t.subtotale, 0.0);
      expect(t.impSconto, 0.0);
      expect(t.imponibile, 0.0);
      expect(t.iva, 0.0);
      expect(t.totaleIva, 0.0);
    });
  });

  group('numero e revisione', () {
    test('formatoNumeroPreventivo con 4 cifre', () {
      expect(formatoNumeroPreventivo(1), 'PRV-0001');
      expect(formatoNumeroPreventivo(12), 'PRV-0012');
      expect(formatoNumeroPreventivo(9999), 'PRV-9999');
    });

    test('formatoNumeroPreventivo oltre le 4 cifre non tronca', () {
      expect(formatoNumeroPreventivo(10000), 'PRV-10000');
    });

    test('numeroBasePreventivo rimuove il suffisso -R', () {
      expect(numeroBasePreventivo('PRV-0001-R1'), 'PRV-0001');
      expect(numeroBasePreventivo('PRV-0001-R12'), 'PRV-0001');
      expect(numeroBasePreventivo('PRV-0001'), 'PRV-0001');
    });

    test('numeroBasePreventivo senza suffisso resta invariato (anche vuoto)', () {
      expect(numeroBasePreventivo('PRV-0001'), 'PRV-0001');
      expect(numeroBasePreventivo(''), '');
    });

    test('numeroRevisione compone {base}-R{n}', () {
      expect(numeroRevisione('PRV-0001', 1), 'PRV-0001-R1');
      expect(numeroRevisione('PRV-0001', 12), 'PRV-0001-R12');
    });
  });

  group('validità del preventivo', () {
    test('legge e normalizza valido_fino', () {
      final preventivo = Preventivo.fromMap({
        'numero': 'PRV-0001',
        'stato': 'inviato',
        'valido_fino': '2026-10-30',
      }, id: 'p1');
      expect(preventivo.validoFino, '2026-10-30');
      expect(preventivo.toMap()['valido_fino'], '2026-10-30');
    });

    test('un valore non valido resta null', () {
      final preventivo = Preventivo.fromMap({
        'valido_fino': 'domani',
      }, id: 'p1');
      expect(preventivo.validoFino, isNull);
    });

    test('i documenti vecchi senza validità restano leggibili', () {
      final preventivo = Preventivo.fromMap({'numero': 'PRV-0002'}, id: 'p2');
      expect(preventivo.validoFino, isNull);
      expect(preventivo.stato, 'bozza');
    });
  });
}
