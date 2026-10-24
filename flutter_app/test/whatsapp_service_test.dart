import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/services/sp_service.dart';

void main() {
  group('normalizzaNumeroWhatsapp', () {
    test('tiene solo le cifre', () {
      expect(normalizzaNumeroWhatsapp('+39 333 123-4567'), '393331234567');
      expect(normalizzaNumeroWhatsapp('  '), '');
      expect(normalizzaNumeroWhatsapp(null), '');
    });
  });

  group('uriInvioWhatsapp', () {
    test('aggiunge /send e toglie le barre finali', () {
      expect(
        uriInvioWhatsapp('https://wa.example.com/')?.toString(),
        'https://wa.example.com/send',
      );
      expect(
        uriInvioWhatsapp('https://wa.example.com/base///')?.toString(),
        'https://wa.example.com/base/send',
      );
    });

    test('rifiuta indirizzi vuoti o non http/https', () {
      expect(uriInvioWhatsapp(null), isNull);
      expect(uriInvioWhatsapp(''), isNull);
      expect(uriInvioWhatsapp('ftp://wa.example.com'), isNull);
      expect(uriInvioWhatsapp('non-un-url'), isNull);
    });
  });
}
