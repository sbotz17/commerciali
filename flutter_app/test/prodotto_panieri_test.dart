import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/prodotto.dart';

void main() {
  group('Prodotto panieri', () {
    test('round-trip toMap/fromMap con figli e flag', () {
      final prodotto = Prodotto(
        id: 'p-1',
        aziendaId: 'az-1',
        nome: 'Paniere',
        codice: 'PRD-100',
        figliIds: const ['figlio-1', 'figlio-2'],
        figliAZero: true,
      );

      final map = prodotto.toMap();

      expect(map['figli_ids'], ['figlio-1', 'figlio-2']);
      expect(map['figli_a_zero'], isTrue);
      expect(map['codice'], 'PRD-100');

      final ricostruito = Prodotto.fromMap(map, id: 'p-1');

      expect(ricostruito.figliIds, ['figlio-1', 'figlio-2']);
      expect(ricostruito.figliAZero, isTrue);
      expect(ricostruito.codice, 'PRD-100');
    });

    test('mappa vecchia senza campi → default', () {
      final prodotto = Prodotto.fromMap({
        'nome': 'Prodotto vecchio',
      }, id: 'p-2');

      expect(prodotto.figliIds, isEmpty);
      expect(prodotto.figliAZero, isFalse);
    });

    test('figli_ids con valori non stringa/vuoti → filtrati', () {
      final prodotto = Prodotto.fromMap({
        'figli_ids': ['figlio-1', '', '  ', 42, null, 'figlio-3'],
      }, id: 'p-3');

      expect(prodotto.figliIds, ['figlio-1', 'figlio-3']);
    });
  });
}
