import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/prodotto.dart';
import 'package:commerciali_app/features/preventivi/preventivo_edit_screen.dart';

void main() {
  group('rigaConProdotto', () {
    test('compila i campi del prodotto e conserva quantità e sconto', () {
      final riga = rigaPreventivoDaCampi(
        prodottoId: 'vecchio',
        codice: 'OLD-1',
        um: 'kg',
        paniereId: 'paniere-1',
        paniereNome: 'Paniere vecchio',
        nome: 'Voce manuale',
        quantita: '2',
        prezzo: '10',
        scontoPerc: '10',
        ivaPerc: '22',
      );
      const prodotto = Prodotto(id: 'p1', nome: 'Trapano', prezzo: 55.5);

      final compilata = rigaConProdotto(riga, prodotto);

      expect(compilata.prodottoId, 'p1');
      expect(compilata.nome, 'Trapano');
      expect(compilata.prezzo, 55.5);
      expect(compilata.um, 'pz');
      expect(compilata.codice, isNull);
      expect(compilata.paniereId, isNull);
      expect(compilata.paniereNome, isNull);
      expect(compilata.qty, 2);
      expect(compilata.scontoPerc, 10);
      expect(compilata.ivaPerc, 22);
    });

    test('prodotto senza prezzo e senza nome lascia prezzo a zero', () {
      final riga = rigaPreventivoDaCampi(quantita: '1', prezzo: '12');
      const prodotto = Prodotto(id: 'p2');

      final compilata = rigaConProdotto(riga, prodotto);

      expect(compilata.prodottoId, 'p2');
      expect(compilata.nome, isNull);
      expect(compilata.prezzo, 0);
      expect(compilata.um, 'pz');
      expect(compilata.qty, 1);
    });
  });
}
