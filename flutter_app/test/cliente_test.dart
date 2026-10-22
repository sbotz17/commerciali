import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/cliente.dart';

void main() {
  group('Cliente.fromMap', () {
    test('legge tutti i campi', () {
      final cliente = Cliente.fromMap({
        'azienda_id': 'az-1',
        'tipo_cliente': 'azienda',
        'nome': 'ACME Srl',
        'referente': 'Mario Rossi',
        'email': 'mario@acme.it',
        'telefono': '02 123456',
        'piva': 'IT12345678901',
        'codice_fiscale': 'RSSMRA80A01F205X',
        'indirizzo': 'Via Roma',
        'civico': '10',
        'cap': '20100',
        'citta': 'Milano',
        'provincia': 'MI',
        'ateco': '62.01.00',
        'settore': 'software',
        'regione': 'lombardia',
        'note': 'Cliente storico',
      }, id: 'cl-1');

      expect(cliente.id, 'cl-1');
      expect(cliente.aziendaId, 'az-1');
      expect(cliente.tipoCliente, 'azienda');
      expect(cliente.nome, 'ACME Srl');
      expect(cliente.referente, 'Mario Rossi');
      expect(cliente.email, 'mario@acme.it');
      expect(cliente.telefono, '02 123456');
      expect(cliente.piva, 'IT12345678901');
      expect(cliente.codiceFiscale, 'RSSMRA80A01F205X');
      expect(cliente.indirizzo, 'Via Roma');
      expect(cliente.civico, '10');
      expect(cliente.cap, '20100');
      expect(cliente.citta, 'Milano');
      expect(cliente.provincia, 'MI');
      expect(cliente.ateco, '62.01.00');
      expect(cliente.settore, 'software');
      expect(cliente.regione, 'lombardia');
      expect(cliente.note, 'Cliente storico');
    });

    test('campi assenti valgono null, tipo_cliente default "azienda"', () {
      final cliente = Cliente.fromMap({}, id: 'cl-1');

      expect(cliente.id, 'cl-1');
      expect(cliente.aziendaId, isNull);
      expect(cliente.tipoCliente, 'azienda');
      expect(cliente.nome, isNull);
      expect(cliente.piva, isNull);
    });

    test('toMap serializza in snake_case senza id', () {
      final cliente = Cliente(
        id: 'cl-1',
        aziendaId: 'az-1',
        tipoCliente: 'privato',
        nome: 'Mario Rossi',
        piva: '12345678901',
        codiceFiscale: 'RSSMRA80A01F205X',
        note: 'note',
      );

      final map = cliente.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['azienda_id'], 'az-1');
      expect(map['tipo_cliente'], 'privato');
      expect(map['nome'], 'Mario Rossi');
      expect(map['piva'], '12345678901');
      expect(map['codice_fiscale'], 'RSSMRA80A01F205X');
    });
  });

  group('normalizzaPiva', () {
    test('maiuscola e rimuove il prefisso IT', () {
      expect(normalizzaPiva('it12345678901'), '12345678901');
      expect(normalizzaPiva('IT12345678901'), '12345678901');
    });

    test('fa trim degli spazi', () {
      expect(normalizzaPiva('  12345678901  '), '12345678901');
      expect(normalizzaPiva('  it 12345678901 '), '12345678901');
    });

    test('senza prefisso resta invariata (maiuscola)', () {
      expect(normalizzaPiva('12345678901'), '12345678901');
    });

    test('null o vuota vale null', () {
      expect(normalizzaPiva(null), isNull);
      expect(normalizzaPiva(''), isNull);
      expect(normalizzaPiva('   '), isNull);
      expect(normalizzaPiva('IT'), isNull);
    });
  });

  group('clienteDuplicato', () {
    final esistenti = <Cliente>[
      Cliente(id: '1', piva: '12345678901', nome: 'ACME Srl', codiceFiscale: 'AAAAAA00A00A000A'),
      Cliente(id: '2', nome: 'Beta Snc', codiceFiscale: 'BBBBBB00B00B000B'),
    ];

    test('trova per P.IVA (ignorando formato)', () {
      final candidato = Cliente(
        id: '',
        piva: 'IT12345678901',
        nome: 'Altro Nome',
      );

      expect(clienteDuplicato(candidato, esistenti)?.id, '1');
    });

    test('trova per nome esatto (case-insensitive)', () {
      final candidato = Cliente(id: '', nome: '  beta snc ');

      expect(clienteDuplicato(candidato, esistenti)?.id, '2');
    });

    test('trova per codice fiscale', () {
      final candidato = Cliente(
        id: '',
        nome: 'Nome Nuovo',
        codiceFiscale: 'bbbbbb00b00b000b',
      );

      expect(clienteDuplicato(candidato, esistenti)?.id, '2');
    });

    test('nessun duplicato restituisce null', () {
      final candidato = Cliente(
        id: '',
        piva: '99999999999',
        nome: 'Gamma Srl',
        codiceFiscale: 'CCCCCC00C00C000C',
      );

      expect(clienteDuplicato(candidato, esistenti), isNull);
    });

    test('P.IVA assente non blocca il confronto per nome', () {
      final candidato = Cliente(id: '', nome: 'acme srl');

      expect(clienteDuplicato(candidato, esistenti)?.id, '1');
    });
  });
}
