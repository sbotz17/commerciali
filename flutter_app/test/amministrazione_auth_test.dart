import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/services/auth_service.dart';

void main() {
  group('normalizzaEmailAmministrazione', () {
    test('applica trim e lowercase', () {
      expect(
        normalizzaEmailAmministrazione('  Mario.Rossi@Example.IT  '),
        'mario.rossi@example.it',
      );
    });

    test('una email già normalizzata resta invariata', () {
      expect(
        normalizzaEmailAmministrazione('mario.rossi@example.it'),
        'mario.rossi@example.it',
      );
    });

    test('una stringa vuota resta vuota', () {
      expect(normalizzaEmailAmministrazione(''), '');
    });

    test('gli spazi interni non vengono toccati', () {
      expect(
        normalizzaEmailAmministrazione('  mario rossi@example.it '),
        'mario rossi@example.it',
      );
    });
  });

  group('validaPasswordTemporanea', () {
    test('null restituisce un errore', () {
      expect(validaPasswordTemporanea(null), isNotNull);
    });

    test('stringa vuota restituisce un errore', () {
      expect(validaPasswordTemporanea(''), isNotNull);
    });

    test('solo spazi restituisce un errore', () {
      expect(validaPasswordTemporanea('   '), isNotNull);
    });

    test('password di 7 caratteri restituisce un errore', () {
      expect(validaPasswordTemporanea('1234567'), isNotNull);
    });

    test('password di 8 caratteri è valida', () {
      expect(validaPasswordTemporanea('12345678'), isNull);
    });

    test('password più lunga di 8 caratteri è valida', () {
      expect(validaPasswordTemporanea('password-lunga'), isNull);
    });
  });
}
