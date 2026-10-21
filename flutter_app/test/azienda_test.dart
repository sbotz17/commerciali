import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/azienda.dart';

void main() {
  group('Azienda.fromMap', () {
    test('legge i campi base', () {
      final azienda = Azienda.fromMap({
        'nome': 'ACME Srl',
        'logo': 'https://example.com/logo.png',
        'ruolo': 'admin',
        'whatsapp_attivo': true,
      }, id: 'az-1');

      expect(azienda.id, 'az-1');
      expect(azienda.nome, 'ACME Srl');
      expect(azienda.logo, 'https://example.com/logo.png');
      expect(azienda.ruolo, 'admin');
      expect(azienda.whatsappAttivo, isTrue);
    });

    test('nome assente vale "Azienda"', () {
      final azienda = Azienda.fromMap({}, id: 'az-1');

      expect(azienda.nome, 'Azienda');
    });

    test('ruolo assente vale "commerciale"', () {
      final azienda = Azienda.fromMap({'nome': 'ACME'}, id: 'az-1');

      expect(azienda.ruolo, 'commerciale');
    });

    test('logo assente vale null', () {
      final azienda = Azienda.fromMap({'nome': 'ACME'}, id: 'az-1');

      expect(azienda.logo, isNull);
    });

    test('whatsapp_attivo false esplicito', () {
      final azienda = Azienda.fromMap({
        'nome': 'ACME',
        'whatsapp_attivo': false,
      }, id: 'az-1');

      expect(azienda.whatsappAttivo, isFalse);
    });

    test('whatsapp_attivo assente vale false', () {
      final azienda = Azienda.fromMap({'nome': 'ACME'}, id: 'az-1');

      expect(azienda.whatsappAttivo, isFalse);
    });
  });
}
