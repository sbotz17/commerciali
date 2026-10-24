import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/notifica.dart';
import 'package:commerciali_app/features/notifiche/notifiche_screen.dart';

void main() {
  Notifica notifica({
    required String id,
    String? tipo,
    String? titolo,
    String? testo,
    String? lettaAt,
    String? createdAt,
    String? targetTipo,
    String? targetId,
  }) {
    return Notifica(
      id: id,
      tipo: tipo,
      titolo: titolo,
      testo: testo,
      lettaAt: lettaAt,
      createdAt: createdAt,
      targetTipo: targetTipo,
      targetId: targetId,
    );
  }

  group('contaNotificheNonLette', () {
    test('conta solo le notifiche con lettaAt assente o vuoto', () {
      final notifiche = [
        notifica(id: 'n-1'),
        notifica(id: 'n-2', lettaAt: ''),
        notifica(id: 'n-3', lettaAt: '   '),
        notifica(id: 'n-4', lettaAt: '2026-10-23T09:05:00Z'),
      ];

      expect(contaNotificheNonLette(notifiche), 3);
    });

    test('lista vuota restituisce zero', () {
      expect(contaNotificheNonLette(const []), 0);
    });

    test('tutte lette restituisce zero', () {
      expect(
        contaNotificheNonLette([
          notifica(id: 'n-1', lettaAt: '2026-10-23T09:05:00Z'),
          notifica(id: 'n-2', lettaAt: '2026-10-23T10:00:00Z'),
        ]),
        0,
      );
    });
  });

  group('etichettaTipoNotificaBreve', () {
    test('traduce i tipi noti', () {
      expect(etichettaTipoNotificaBreve('appuntamento'), 'Appuntamento');
      expect(etichettaTipoNotificaBreve('task'), 'Task');
      expect(etichettaTipoNotificaBreve('promemoria'), 'Promemoria');
      expect(etichettaTipoNotificaBreve('chat'), 'Chat');
      expect(etichettaTipoNotificaBreve('comunicazione'), 'Comunicazione');
    });

    test('fallback Generica per null, vuoto e valore sconosciuto', () {
      expect(etichettaTipoNotificaBreve(null), 'Generica');
      expect(etichettaTipoNotificaBreve(''), 'Generica');
      expect(etichettaTipoNotificaBreve('   '), 'Generica');
      expect(etichettaTipoNotificaBreve('sondaggio'), 'Generica');
    });

    test('normalizza spazi e maiuscole', () {
      expect(etichettaTipoNotificaBreve(' Task '), 'Task');
      expect(etichettaTipoNotificaBreve('CHAT'), 'Chat');
      expect(etichettaTipoNotificaBreve('Appuntamento'), 'Appuntamento');
    });
  });

  group('formattaDataOraNotifica', () {
    test('usa createdAt in formato italiano', () {
      expect(
        formattaDataOraNotifica(
          notifica(id: 'n-1', createdAt: '2026-10-23T09:05:00'),
        ),
        '23/10/2026 · 09:05',
      );
    });

    test('ripiega su inviataAt e poi programmataAt', () {
      final conInvio = Notifica(
        id: 'n-1',
        inviataAt: '2026-10-22T18:30:00',
        programmataAt: '2026-10-20T08:00:00',
      );
      final conProgramma = Notifica(
        id: 'n-2',
        programmataAt: '2026-10-21T07:15:00',
      );

      expect(formattaDataOraNotifica(conInvio), '22/10/2026 · 18:30');
      expect(formattaDataOraNotifica(conProgramma), '21/10/2026 · 07:15');
    });

    test('data assente o non valida diventa un trattino', () {
      expect(formattaDataOraNotifica(notifica(id: 'n-1')), '—');
      expect(
        formattaDataOraNotifica(notifica(id: 'n-2', createdAt: 'non-una-data')),
        '—',
      );
    });
  });

  group('rottaNotifica', () {
    test('mappa appuntamento, task e chat sulle rispettive sezioni', () {
      expect(
        rottaNotifica(notifica(id: 'n-1', tipo: 'appuntamento')),
        '/calendario',
      );
      expect(rottaNotifica(notifica(id: 'n-2', tipo: 'task')), '/task');
      expect(rottaNotifica(notifica(id: 'n-3', tipo: 'chat')), '/chat');
    });

    test('usa targetTipo quando tipo non ha una rotta', () {
      expect(
        rottaNotifica(
          notifica(id: 'n-1', tipo: 'promemoria', targetTipo: 'task'),
        ),
        '/task',
      );
    });

    test('apre l’appuntamento specifico quando c’è targetId', () {
      expect(
        rottaNotifica(
          notifica(id: 'n-1', tipo: 'appuntamento', targetId: 'app 1'),
        ),
        '/calendario?appuntamento=app+1',
      );
    });

    test('altri tipi restano nella schermata', () {
      expect(rottaNotifica(notifica(id: 'n-1', tipo: 'promemoria')), isNull);
      expect(rottaNotifica(notifica(id: 'n-2', tipo: 'comunicazione')), isNull);
      expect(rottaNotifica(notifica(id: 'n-3')), isNull);
    });
  });

  group('messaggioErroreNotifiche', () {
    test('spiega la mancanza di permessi', () {
      expect(
        messaggioErroreNotifiche(Exception('permission-denied')),
        contains('permessi'),
      );
    });

    test('distingue problemi di rete e errore generico', () {
      expect(
        messaggioErroreNotifiche(Exception('unavailable')),
        contains('Connessione assente'),
      );
      expect(
        messaggioErroreNotifiche(Exception('errore'), caricamento: true),
        'Impossibile caricare le notifiche. Riprova.',
      );
    });
  });

  group('CorpoNotifiche (senza Firebase)', () {
    Future<void> mostraCorpo(
      WidgetTester tester, {
      List<Notifica> notifiche = const [],
      bool caricamento = false,
      Object? errore,
      bool soloNonLette = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CorpoNotifiche(
              notifiche: notifiche,
              caricamento: caricamento,
              errore: errore,
              soloNonLette: soloNonLette,
              onRiprova: () {},
              onApri: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('mostra lo stato vuoto con la chiave notifiche-vuoto', (
      tester,
    ) async {
      await mostraCorpo(tester);

      expect(find.byKey(const Key('notifiche-vuoto')), findsOneWidget);
      expect(find.text('Nessuna notifica'), findsOneWidget);
    });

    testWidgets('lo stato vuoto cambia testo con il filtro Non lette', (
      tester,
    ) async {
      await mostraCorpo(tester, soloNonLette: true);

      expect(find.byKey(const Key('notifiche-vuoto')), findsOneWidget);
      expect(find.text('Nessuna notifica non letta'), findsOneWidget);
      expect(find.text('Hai letto tutte le notifiche.'), findsOneWidget);
    });

    testWidgets('mostra il caricamento con la chiave notifiche-caricamento', (
      tester,
    ) async {
      await mostraCorpo(tester, caricamento: true);

      expect(find.byKey(const Key('notifiche-caricamento')), findsOneWidget);
      expect(find.byKey(const Key('notifiche-vuoto')), findsNothing);
    });

    testWidgets('mostra l\'errore e il pulsante Riprova', (tester) async {
      await mostraCorpo(tester, errore: Exception('permission-denied'));

      expect(find.byKey(const Key('notifiche-errore')), findsOneWidget);
      expect(find.textContaining('permessi'), findsOneWidget);
      expect(find.text('Riprova'), findsOneWidget);
      expect(find.byKey(const Key('notifiche-riprova')), findsOneWidget);
    });

    testWidgets('mostra le voci e il punto solo sulle non lette', (
      tester,
    ) async {
      await mostraCorpo(
        tester,
        notifiche: [
          notifica(
            id: 'n-1',
            tipo: 'task',
            titolo: 'Richiamare Acme',
            testo: 'Il task è in scadenza',
            createdAt: '2026-10-23T09:05:00',
          ),
          notifica(
            id: 'n-2',
            tipo: 'chat',
            titolo: 'Nuovo messaggio',
            lettaAt: '2026-10-23T09:10:00',
            createdAt: '2026-10-22T18:30:00',
          ),
        ],
      );

      expect(find.byKey(const Key('notifica-n-1')), findsOneWidget);
      expect(find.byKey(const Key('notifica-n-2')), findsOneWidget);
      expect(find.text('Richiamare Acme'), findsOneWidget);
      expect(find.text('Nuovo messaggio'), findsOneWidget);
      expect(find.text('23/10/2026 · 09:05'), findsOneWidget);
      expect(find.byKey(const Key('notifica-punto-n-1')), findsOneWidget);
      expect(find.byKey(const Key('notifica-punto-n-2')), findsNothing);
    });
  });
}
