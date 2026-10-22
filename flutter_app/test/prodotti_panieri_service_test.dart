import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/services/sp_service.dart';

void main() {
  group('sanificaFigliIds', () {
    test('lista normale → ordine preservato', () {
      expect(
        sanificaFigliIds(['a', 'b', 'c']),
        ['a', 'b', 'c'],
      );
    });

    test('duplicati eliminati, ordine preservato', () {
      expect(
        sanificaFigliIds(['a', 'b', 'a', 'c', 'b']),
        ['a', 'b', 'c'],
      );
    });

    test('escludiId rimosso (self)', () {
      expect(
        sanificaFigliIds(['a', 'self', 'b'], escludiId: 'self'),
        ['a', 'b'],
      );
    });

    test('valori null/non stringa/vuoti filtrati', () {
      expect(
        sanificaFigliIds(['a', null, 42, '', '  ', 'b', true, 'a']),
        ['a', 'b'],
      );
    });

    test('valore non lista → lista vuota', () {
      expect(sanificaFigliIds(null), isEmpty);
      expect(sanificaFigliIds('non-lista'), isEmpty);
    });

    test('stringhe con spazi → trim', () {
      expect(
        sanificaFigliIds(['  a  ', ' b ']),
        ['a', 'b'],
      );
    });
  });
}
