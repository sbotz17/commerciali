import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/features/auth/reset_password_screen.dart';

void main() {
  group('validaNuovaPassword', () {
    test('null restituisce un errore', () {
      expect(validaNuovaPassword(null), isNotNull);
    });

    test('stringa vuota restituisce un errore', () {
      expect(validaNuovaPassword(''), isNotNull);
    });

    test('meno di 8 caratteri restituisce un errore', () {
      final errore = validaNuovaPassword('1234567');
      expect(errore, isNotNull);
      expect(errore, contains('8'));
    });

    test('8 caratteri superano la validazione', () {
      expect(validaNuovaPassword('12345678'), isNull);
    });

    test('più di 8 caratteri superano la validazione', () {
      expect(validaNuovaPassword('password-lunga'), isNull);
    });
  });

  group('validaConfermaPassword', () {
    test('null restituisce un errore', () {
      expect(validaConfermaPassword(null, 'password1'), isNotNull);
    });

    test('stringa vuota restituisce un errore', () {
      expect(validaConfermaPassword('', 'password1'), isNotNull);
    });

    test('valori diversi restituiscono un errore', () {
      expect(validaConfermaPassword('password2', 'password1'), isNotNull);
    });

    test('valori uguali superano la validazione', () {
      expect(validaConfermaPassword('password1', 'password1'), isNull);
    });
  });

  group('messaggioErroreReset', () {
    test('link scaduto', () {
      final messaggio = messaggioErroreReset(
        FirebaseAuthException(code: 'expired-action-code'),
      );
      expect(messaggio.toLowerCase(), contains('scaduto'));
    });

    test('link non valido o già usato', () {
      final messaggio = messaggioErroreReset(
        FirebaseAuthException(code: 'invalid-action-code'),
      );
      expect(messaggio.toLowerCase(), contains('non è valido'));
    });

    test('password troppo debole', () {
      final messaggio = messaggioErroreReset(
        FirebaseAuthException(code: 'weak-password'),
      );
      expect(messaggio.toLowerCase(), contains('debole'));
    });

    test('email non valida', () {
      final messaggio = messaggioErroreReset(
        FirebaseAuthException(code: 'invalid-email'),
      );
      expect(messaggio.toLowerCase(), contains('email'));
    });

    test('connessione assente', () {
      final messaggio = messaggioErroreReset(
        FirebaseAuthException(code: 'network-request-failed'),
      );
      expect(messaggio.toLowerCase(), contains('connessione'));
    });

    test('errore sconosciuto ha un messaggio generico', () {
      expect(messaggioErroreReset(Exception('altro')), isNotEmpty);
    });
  });
}
