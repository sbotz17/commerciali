import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/preventivo.dart';
import 'package:commerciali_app/features/preventivi/preventivo_edit_screen.dart';

void main() {
  group('etichettaPaniereRiga', () {
    test('null senza paniere', () {
      const riga = PreventivoRiga(nome: 'Licenza annuale');

      expect(etichettaPaniereRiga(riga), isNull);
    });

    test('stringa con paniere', () {
      const riga = PreventivoRiga(
        nome: 'Licenza annuale',
        paniereId: 'p-1',
        paniereNome: 'Suite gestionale',
      );

      expect(etichettaPaniereRiga(riga), 'Paniere: Suite gestionale');
    });

    test('stringa con spazi attorno al nome', () {
      const riga = PreventivoRiga(
        nome: 'Licenza annuale',
        paniereId: 'p-1',
        paniereNome: '  Suite gestionale  ',
      );

      expect(etichettaPaniereRiga(riga), 'Paniere: Suite gestionale');
    });
  });
}
