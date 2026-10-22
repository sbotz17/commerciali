import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/services/vies_service.dart';

/// Test del servizio VIES (solo funzioni pure: `ViesRisultato.fromJson` e
/// `normalizzaPivaVies`). Nessuna chiamata di rete.
void main() {
  group('ViesRisultato.fromJson', () {
    test('risposta valida', () {
      final risultato = ViesRisultato.fromJson({
        'ok': true,
        'valido': true,
        'piva': '00159560366',
        'name': 'Ferrari S.p.A.',
        'address': 'Via Abetone Inferiore 4, 41053 Maranello (MO)',
      });

      expect(risultato.valido, isTrue);
      expect(risultato.piva, '00159560366');
      expect(risultato.ragioneSociale, 'Ferrari S.p.A.');
      expect(
        risultato.indirizzo,
        'Via Abetone Inferiore 4, 41053 Maranello (MO)',
      );
      expect(risultato.errore, isNull);
    });

    test('risposta non valida', () {
      final risultato = ViesRisultato.fromJson({
        'ok': true,
        'valido': false,
        'piva': '12345678901',
        'name': '',
        'address': '',
      });

      expect(risultato.valido, isFalse);
      expect(risultato.piva, '12345678901');
      expect(risultato.ragioneSociale, isNull);
      expect(risultato.indirizzo, isNull);
      expect(risultato.errore, isNull);
    });

    test('risposta con errore', () {
      final risultato = ViesRisultato.fromJson({
        'ok': false,
        'error': 'Partita IVA italiana non valida: servono 11 cifre',
      });

      expect(risultato.valido, isFalse);
      expect(risultato.piva, '');
      expect(risultato.ragioneSociale, isNull);
      expect(risultato.indirizzo, isNull);
      expect(
        risultato.errore,
        'Partita IVA italiana non valida: servono 11 cifre',
      );
    });

    test('campi mancanti vengono normalizzati', () {
      final risultato = ViesRisultato.fromJson(const {});

      expect(risultato.valido, isFalse);
      expect(risultato.piva, '');
      expect(risultato.ragioneSociale, isNull);
      expect(risultato.indirizzo, isNull);
      expect(risultato.errore, isNull);
    });
  });

  group('normalizzaPivaVies', () {
    test('mantiene 11 cifre', () {
      expect(normalizzaPivaVies('00159560366'), '00159560366');
    });

    test('rimuove il prefisso IT (maiuscolo e minuscolo)', () {
      expect(normalizzaPivaVies('IT00159560366'), '00159560366');
      expect(normalizzaPivaVies('it00159560366'), '00159560366');
    });

    test('rimuove spazi e caratteri non numerici', () {
      expect(normalizzaPivaVies(' 0015 956 0366 '), '00159560366');
      expect(normalizzaPivaVies('IT 00159560366'), '00159560366');
    });

    test('valore vuoto o solo prefisso restituisce null', () {
      expect(normalizzaPivaVies(''), isNull);
      expect(normalizzaPivaVies('   '), isNull);
      expect(normalizzaPivaVies('IT'), isNull);
    });
  });
}
