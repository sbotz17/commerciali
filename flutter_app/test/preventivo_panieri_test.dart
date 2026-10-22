import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/preventivo.dart';

void main() {
  group('PreventivoRiga paniere', () {
    test('round-trip con paniere', () {
      final riga = PreventivoRiga.fromMap({
        'prodottoId': null,
        'codice': null,
        'nome': 'Pacchetto Office',
        'prezzo': 450,
        'immagine': null,
        'qty': 1,
        'um': 'pz',
        'scontoPerc': 0,
        'scontoVal': 0,
        'ivaPerc': 22,
        'paniereId': 'pan-1',
        'paniereNome': 'Pacchetto Office',
      });

      expect(riga.paniereId, 'pan-1');
      expect(riga.paniereNome, 'Pacchetto Office');

      final map = riga.toMap();
      expect(map['paniereId'], 'pan-1');
      expect(map['paniereNome'], 'Pacchetto Office');

      // Il round-trip conserva i campi paniere.
      final riga2 = PreventivoRiga.fromMap(map);
      expect(riga2.paniereId, 'pan-1');
      expect(riga2.paniereNome, 'Pacchetto Office');
      expect(riga2.nome, 'Pacchetto Office');
      expect(riga2.prezzo, 450);
    });

    test('riga vecchia senza paniere → null', () {
      final riga = PreventivoRiga.fromMap({
        'prodottoId': 'p-1',
        'nome': 'Prodotto',
        'prezzo': 10,
        'qty': 2,
      });

      expect(riga.paniereId, isNull);
      expect(riga.paniereNome, isNull);

      final map = riga.toMap();
      expect(map['paniereId'], isNull);
      expect(map['paniereNome'], isNull);
    });

    test('copyWith cambia qty/paniere ma conserva nome/prezzo', () {
      final riga = PreventivoRiga(
        nome: 'Pacchetto Office',
        prezzo: 450,
        qty: 1,
        paniereId: 'pan-1',
        paniereNome: 'Pacchetto Office',
      );

      final copia = riga.copyWith(
        qty: 3,
        paniereId: 'pan-2',
        paniereNome: 'Pacchetto Avanzato',
      );

      expect(copia.qty, 3);
      expect(copia.paniereId, 'pan-2');
      expect(copia.paniereNome, 'Pacchetto Avanzato');
      // Nome e prezzo conservati (non passati a copyWith).
      expect(copia.nome, 'Pacchetto Office');
      expect(copia.prezzo, 450);
      // L'originale resta invariato.
      expect(riga.qty, 1);
      expect(riga.prezzo, 450);
      expect(riga.paniereId, 'pan-1');
      expect(riga.paniereNome, 'Pacchetto Office');
    });

    test('copyWith senza argomenti restituisce una copia identica', () {
      final riga = PreventivoRiga(
        nome: 'Pacchetto Office',
        prezzo: 450,
        qty: 1,
        paniereId: 'pan-1',
        paniereNome: 'Pacchetto Office',
      );

      final copia = riga.copyWith();

      expect(copia.nome, riga.nome);
      expect(copia.prezzo, riga.prezzo);
      expect(copia.qty, riga.qty);
      expect(copia.paniereId, riga.paniereId);
      expect(copia.paniereNome, riga.paniereNome);
    });
  });
}
