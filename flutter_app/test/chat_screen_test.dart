import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/stanza_chat.dart';
import 'package:commerciali_app/data/models/user_profile.dart';
import 'package:commerciali_app/features/chat/chat_screen.dart';

/// Profilo utente minimo per i test delle funzioni pure.
UserProfile _utente({
  required String uid,
  String? nome,
  String? email,
  String? username,
  bool? attivo,
}) {
  return UserProfile(
    id: uid,
    uid: uid,
    nome: nome,
    email: email,
    username: username,
    attivo: attivo,
  );
}

void main() {
  group('utentiDisponibiliChat', () {
    test('tiene solo gli utenti attivi ed esclude l\'utente corrente', () {
      final utenti = [
        _utente(uid: 'u1', nome: 'Anna', attivo: true),
        _utente(uid: 'u2', nome: 'Bruno', attivo: false),
        _utente(uid: 'u3', nome: 'Carla'),
        _utente(uid: 'u4', nome: 'Dario', attivo: true),
      ];

      final disponibili = utentiDisponibiliChat(utenti, uidCorrente: 'u4');

      expect(disponibili.map((utente) => utente.uid), ['u1', 'u3']);
    });

    test('ordina per nome senza distinzione tra maiuscole e minuscole', () {
      final utenti = [
        _utente(uid: 'u1', nome: 'carla'),
        _utente(uid: 'u2', nome: 'Anna'),
        _utente(uid: 'u3', nome: 'bruno'),
      ];

      final disponibili = utentiDisponibiliChat(utenti, uidCorrente: 'x');

      expect(disponibili.map((utente) => utente.uid), ['u2', 'u3', 'u1']);
    });

    test('a parità di nome usa l\'uid come spareggio', () {
      final utenti = [
        _utente(uid: 'b', nome: 'Anna'),
        _utente(uid: 'a', nome: 'Anna'),
      ];

      final disponibili = utentiDisponibiliChat(utenti, uidCorrente: 'x');

      expect(disponibili.map((utente) => utente.uid), ['a', 'b']);
    });

    test('usa username o email quando il nome manca', () {
      final utenti = [
        _utente(uid: 'u1', username: 'zetico'),
        _utente(uid: 'u2', email: 'anna@example.com'),
        _utente(uid: 'u3', nome: 'Bruno'),
      ];

      final disponibili = utentiDisponibiliChat(utenti, uidCorrente: 'x');

      expect(disponibili.map((utente) => utente.uid), ['u2', 'u3', 'u1']);
    });

    test('non modifica la lista in ingresso', () {
      final utenti = [
        _utente(uid: 'u1', nome: 'Zeta'),
        _utente(uid: 'u2', nome: 'Alfa'),
      ];

      utentiDisponibiliChat(utenti, uidCorrente: 'x');

      expect(utenti.map((utente) => utente.uid), ['u1', 'u2']);
    });

    test('lista vuota: nessun disponibile', () {
      expect(utentiDisponibiliChat([], uidCorrente: 'x'), isEmpty);
    });
  });

  group('formattaDataOraStanzaChat', () {
    test('usa la data dell\'ultimo messaggio in formato italiano', () {
      final stanza = StanzaChat(
        id: 's1',
        ultimoMessaggioAt: DateTime(2026, 10, 24, 9, 5).toIso8601String(),
        updatedAt: DateTime(2026, 10, 20, 18).toIso8601String(),
      );

      expect(formattaDataOraStanzaChat(stanza), '24/10/2026 · 09:05');
    });

    test('ripiega su updatedAt e poi createdAt', () {
      final conUpdated = StanzaChat(
        id: 's1',
        updatedAt: DateTime(2026, 10, 20, 18, 30).toIso8601String(),
        createdAt: DateTime(2026, 10, 1, 8).toIso8601String(),
      );
      final conCreated = StanzaChat(
        id: 's2',
        createdAt: DateTime(2026, 10, 1, 8).toIso8601String(),
      );

      expect(formattaDataOraStanzaChat(conUpdated), '20/10/2026 · 18:30');
      expect(formattaDataOraStanzaChat(conCreated), '01/10/2026 · 08:00');
    });

    test('data assente o non valida: stringa vuota', () {
      expect(formattaDataOraStanzaChat(const StanzaChat(id: 's1')), '');
      expect(
        formattaDataOraStanzaChat(
          const StanzaChat(id: 's2', ultimoMessaggioAt: 'non-una-data'),
        ),
        '',
      );
    });
  });

  group('anteprimaStanzaChat', () {
    test('mostra l\'ultimo messaggio senza spazi ai bordi', () {
      expect(
        anteprimaStanzaChat(
          const StanzaChat(id: 's1', ultimoMessaggio: '  Ciao a tutti  '),
        ),
        'Ciao a tutti',
      );
    });

    test('senza messaggio mostra Nessun messaggio', () {
      expect(
        anteprimaStanzaChat(const StanzaChat(id: 's1')),
        'Nessun messaggio',
      );
      expect(
        anteprimaStanzaChat(const StanzaChat(id: 's2', ultimoMessaggio: '  ')),
        'Nessun messaggio',
      );
    });
  });

  group('CorpoChat', () {
    Future<void> mostra(
      WidgetTester tester,
      Widget corpo,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: corpo),
        ),
      );
      // Un solo frame: l'indicatore di caricamento anima all'infinito e
      // `pumpAndSettle` non tornerebbe mai.
      await tester.pump();
    }

    testWidgets('caricamento mostra l\'indicatore di attesa', (tester) async {
      await mostra(
        tester,
        const CorpoChat(
          stanze: [],
          uidCorrente: 'u1',
          caricamento: true,
        ),
      );

      expect(find.byKey(const Key('chat-caricamento')), findsOneWidget);
    });

    testWidgets('errore mostra l\'avviso e il pulsante Riprova',
        (tester) async {
      var riprove = 0;
      await mostra(
        tester,
        CorpoChat(
          stanze: const [],
          uidCorrente: 'u1',
          caricamento: false,
          errore: Exception('permission-denied'),
          onRiprova: () => riprove++,
        ),
      );

      expect(find.byKey(const Key('chat-errore')), findsOneWidget);
      expect(find.byKey(const Key('chat-vuoto')), findsNothing);

      await tester.tap(find.byKey(const Key('chat-riprova')));
      await tester.pumpAndSettle();

      expect(riprove, 1);
    });

    testWidgets('vuoto mostra lo stato Nessuna conversazione', (tester) async {
      await mostra(
        tester,
        const CorpoChat(
          stanze: [],
          uidCorrente: 'u1',
          caricamento: false,
        ),
      );

      expect(find.byKey(const Key('chat-vuoto')), findsOneWidget);
      expect(find.text('Nessuna conversazione'), findsOneWidget);
    });

    testWidgets('elenco mostra nome, anteprima e apre la stanza',
        (tester) async {
      StanzaChat? aperta;
      final stanze = [
        const StanzaChat(
          id: 's1',
          tipo: 'diretta',
          partecipantiUids: ['u1', 'u2'],
          ultimoMessaggio: 'Ci vediamo domani',
          ultimoMessaggioAt: '2026-10-24T09:05:00.000',
        ),
        const StanzaChat(
          id: 's2',
          tipo: 'gruppo',
          nome: 'Commerciali',
        ),
      ];

      await mostra(
        tester,
        CorpoChat(
          stanze: stanze,
          uidCorrente: 'u1',
          nomiUtenti: const {'u2': 'Bruno'},
          caricamento: false,
          onApri: (stanza) => aperta = stanza,
        ),
      );

      expect(find.byKey(const Key('chat-lista')), findsOneWidget);
      expect(find.text('Bruno'), findsOneWidget);
      expect(find.text('Ci vediamo domani'), findsOneWidget);
      expect(find.text('Commerciali'), findsOneWidget);
      expect(find.text('Nessun messaggio'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat-stanza-s1')));
      await tester.pumpAndSettle();

      expect(aperta?.id, 's1');
    });
  });
}
