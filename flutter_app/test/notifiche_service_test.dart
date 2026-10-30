import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/notifica.dart';
import 'package:commerciali_app/data/services/sp_service.dart';

void main() {
  group('filtraNotificheNonLette', () {
    test('tiene solo le notifiche con lettaAt null o vuoto', () {
      final notifiche = [
        Notifica(id: 'n-1'),
        Notifica(id: 'n-2', lettaAt: ''),
        Notifica(id: 'n-3', lettaAt: '   '),
        Notifica(id: 'n-4', lettaAt: '2026-10-23T09:05:00Z'),
      ];

      final risultato = filtraNotificheNonLette(notifiche);

      expect(risultato.map((n) => n.id), ['n-1', 'n-2', 'n-3']);
    });

    test('lista vuota resta vuota', () {
      expect(filtraNotificheNonLette([]), isEmpty);
    });

    test('tutte lette: risultato vuoto', () {
      final notifiche = [
        Notifica(id: 'n-1', lettaAt: '2026-10-23T09:05:00Z'),
        Notifica(id: 'n-2', lettaAt: '2026-10-23T10:00:00Z'),
      ];

      expect(filtraNotificheNonLette(notifiche), isEmpty);
    });
  });

  group('ordinaNotifiche', () {
    test('ordina per createdAt discendente', () {
      final notifiche = [
        Notifica(id: 'vecchia', createdAt: '2026-10-20T10:00:00Z'),
        Notifica(id: 'recente', createdAt: '2026-10-23T09:00:00Z'),
        Notifica(id: 'media', createdAt: '2026-10-22T08:00:00Z'),
      ];

      final risultato = ordinaNotifiche(notifiche);

      expect(risultato.map((n) => n.id), ['recente', 'media', 'vecchia']);
    });

    test('le notifiche senza createdAt finiscono in fondo', () {
      final notifiche = [
        Notifica(id: 'senza-data'),
        Notifica(id: 'con-data', createdAt: '2026-10-23T09:00:00Z'),
        Notifica(id: 'senza-data-2'),
      ];

      final risultato = ordinaNotifiche(notifiche);

      expect(risultato.map((n) => n.id),
          ['con-data', 'senza-data', 'senza-data-2']);
    });

    test('non muta la lista originale', () {
      final notifiche = [
        Notifica(id: 'vecchia', createdAt: '2026-10-20T10:00:00Z'),
        Notifica(id: 'recente', createdAt: '2026-10-23T09:00:00Z'),
      ];
      final originale = [...notifiche];

      ordinaNotifiche(notifiche);

      expect(notifiche.map((n) => n.id), originale.map((n) => n.id));
    });
  });
}
