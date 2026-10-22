import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/prodotto.dart';
import 'package:commerciali_app/features/catalogo/catalogo_screen.dart';

/// Verifica le etichette del paniere usate nel catalogo: sottotitolo della
/// card con `Paniere: N sotto-prodotti` e colonna "Paniere" della tabella.
void main() {
  group('etichettaPaniere', () {
    test('senza sotto-prodotti è vuota', () {
      const prodotto = Prodotto(id: 'p1', nome: 'Consulenza');

      expect(etichettaPaniere(prodotto), '');
    });

    test('un solo sotto-prodotto usa il singolare', () {
      const prodotto = Prodotto(
        id: 'p1',
        nome: 'Paniere base',
        figliIds: ['p2'],
      );

      expect(etichettaPaniere(prodotto), 'Paniere: 1 sotto-prodotto');
    });

    test('due sotto-prodotti a prezzo zero', () {
      const prodotto = Prodotto(
        id: 'p1',
        nome: 'Paniere base',
        figliIds: ['p2', 'p3'],
        figliAZero: true,
      );

      expect(
        etichettaPaniere(prodotto),
        'Paniere: 2 sotto-prodotti · a prezzo zero',
      );
    });
  });

  group('etichettaFigli', () {
    test('senza figli mostra il trattino', () {
      const prodotto = Prodotto(id: 'p1', nome: 'Consulenza');

      expect(etichettaFigli(prodotto), '—');
    });

    test('un figlio usa il singolare', () {
      const prodotto = Prodotto(id: 'p1', figliIds: ['p2']);

      expect(etichettaFigli(prodotto), '1 figlio');
    });

    test('più figli usano il plurale', () {
      const prodotto = Prodotto(id: 'p1', figliIds: ['p2', 'p3']);

      expect(etichettaFigli(prodotto), '2 figli');
    });
  });
}
