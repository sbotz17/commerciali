import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/features/auth/login_screen.dart';

void main() {
  group('validaEmail', () {
    test('null restituisce un errore', () {
      expect(validaEmail(null), isNotNull);
    });

    test('stringa vuota restituisce un errore', () {
      expect(validaEmail(''), isNotNull);
    });

    test('solo spazi restituisce un errore', () {
      expect(validaEmail('   '), isNotNull);
    });

    test('email senza chiocciola restituisce un errore', () {
      expect(validaEmail('mario.rossi'), isNotNull);
    });

    test('email senza dominio restituisce un errore', () {
      expect(validaEmail('mario@'), isNotNull);
    });

    test('email senza punto nel dominio restituisce un errore', () {
      expect(validaEmail('mario@example'), isNotNull);
    });

    test('email con spazi interni restituisce un errore', () {
      expect(validaEmail('mario rossi@example.it'), isNotNull);
    });

    test('email valida supera la validazione', () {
      expect(validaEmail('mario.rossi@example.it'), isNull);
    });

    test('gli spazi esterni vengono ignorati', () {
      expect(validaEmail('  mario.rossi@example.it  '), isNull);
    });
  });

  group('validaPassword', () {
    test('null restituisce un errore', () {
      expect(validaPassword(null), isNotNull);
    });

    test('stringa vuota restituisce un errore', () {
      expect(validaPassword(''), isNotNull);
    });

    test('una password non vuota supera la validazione', () {
      expect(validaPassword('segreta'), isNull);
    });

    test('anche un solo carattere è accettato', () {
      expect(validaPassword('x'), isNull);
    });
  });
}
