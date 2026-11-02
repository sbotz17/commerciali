import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/stanza_chat.dart';
import 'package:commerciali_app/data/services/sp_service.dart';

void main() {
  group('ordinaStanzeChat', () {
    test('ordina per updatedAt discendente', () {
      final stanze = [
        StanzaChat(id: 's-1', updatedAt: '2026-10-20T10:00:00Z'),
        StanzaChat(id: 's-2', updatedAt: '2026-10-24T09:00:00Z'),
        StanzaChat(id: 's-3', updatedAt: '2026-10-22T08:00:00Z'),
      ];

      final risultato = ordinaStanzeChat(stanze);

      expect(risultato.map((s) => s.id), ['s-2', 's-3', 's-1']);
    });

    test('le stanze senza updatedAt finiscono in fondo', () {
      final stanze = [
        StanzaChat(id: 'senza-data'),
        StanzaChat(id: 'con-data', updatedAt: '2026-10-23T09:00:00Z'),
        StanzaChat(id: 'senza-data-2'),
      ];

      final risultato = ordinaStanzeChat(stanze);

      expect(risultato.map((s) => s.id),
          ['con-data', 'senza-data', 'senza-data-2']);
    });

    test('lista vuota resta vuota', () {
      expect(ordinaStanzeChat([]), isEmpty);
    });

    test('non muta la lista originale', () {
      final stanze = [
        StanzaChat(id: 'vecchia', updatedAt: '2026-10-20T10:00:00Z'),
        StanzaChat(id: 'recente', updatedAt: '2026-10-23T09:00:00Z'),
        StanzaChat(id: 'senza-data'),
      ];
      final originale = [...stanze];

      ordinaStanzeChat(stanze);

      expect(
        stanze.map((s) => s.id),
        originale.map((s) => s.id),
      );
    });
  });
}
