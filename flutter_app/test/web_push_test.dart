import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/services/web_push_service.dart';

void main() {
  group('EsitoPush', () {
    test('legge una sottoscrizione completa', () {
      final esito = EsitoPush.daJson({
        'ok': true,
        'endpoint': 'https://push.example/abc',
        'p256dh': 'p256dh-key',
        'auth': 'auth-key',
        'userAgent': 'Chrome',
      });

      expect(esito.ok, isTrue);
      expect(esito.completa, isTrue);
      expect(esito.endpoint, 'https://push.example/abc');
      expect(esito.p256dh, 'p256dh-key');
      expect(esito.auth, 'auth-key');
      expect(esito.messaggio, 'Notifiche attivate su questo dispositivo.');
    });

    test('rifiuta una risposta incompleta', () {
      final esito = EsitoPush.daJson({
        'ok': true,
        'endpoint': 'https://push.example/abc',
      });

      expect(esito.ok, isTrue);
      expect(esito.completa, isFalse);
    });

    test('riporta l’errore del browser', () {
      final esito = EsitoPush.daJson({
        'ok': false,
        'errore': 'Permesso notifiche negato.',
      });

      expect(esito.completa, isFalse);
      expect(esito.messaggio, 'Permesso notifiche negato.');
    });

    test('messaggio di fallback senza errore', () {
      final esito = EsitoPush.daJson({'ok': false});

      expect(
        esito.messaggio,
        'Non è stato possibile attivare le notifiche.',
      );
    });
  });

  test('su VM lo stub non supporta il push', () {
    const servizio = WebPushService();
    expect(servizio.supportato, isFalse);
  });
}
