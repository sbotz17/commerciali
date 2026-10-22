import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/ruolo.dart';
import 'package:commerciali_app/data/models/user_profile.dart';
import 'package:commerciali_app/features/impostazioni/utenti_screen.dart';

void main() {
  const amministratore = Ruolo(
    id: 'r1',
    nome: 'Amministratore',
    chiave: 'admin',
    descrizione: 'Accesso completo',
    scontoMax: 100,
    sistema: true,
  );
  const commerciale = Ruolo(
    id: 'r2',
    nome: 'Commerciale',
    chiave: 'commerciale',
    descrizione: 'Accesso operativo',
    scontoMax: 20,
    sistema: true,
  );

  const mario = UserProfile(
    id: 'u1',
    uid: 'u1',
    email: 'mario.rossi@example.it',
    nome: 'Mario Rossi',
    ruolo: 'admin',
  );
  const lucia = UserProfile(
    id: 'u2',
    uid: 'u2',
    email: 'lucia.bianchi@example.it',
    nome: 'Lucia Bianchi',
    ruolo: 'commerciale',
  );

  /// Monta [CorpoUtenti] in un'app minima, senza provider né Firebase.
  Future<void> mostraUtenti(
    WidgetTester tester, {
    List<UserProfile> utenti = const [mario, lucia],
    List<Ruolo> ruoli = const [amministratore, commerciale],
    bool? largo,
    void Function(UserProfile utente, String ruolo)? onCambiaRuolo,
    void Function(UserProfile utente)? onRimuovi,
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CorpoUtenti(
            utenti: utenti,
            ruoli: ruoli,
            largo: largo,
            onCambiaRuolo: onCambiaRuolo ?? (_, _) {},
            onRimuovi: onRimuovi ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('etichettaRuolo', () {
    const ruoli = [amministratore, commerciale];

    test('usa il nome del ruolo configurato', () {
      expect(etichettaRuolo('admin', ruoli), 'Amministratore');
      expect(etichettaRuolo('commerciale', ruoli), 'Commerciale');
    });

    test('accetta anche il nome del ruolo', () {
      expect(etichettaRuolo('Commerciale', ruoli), 'Commerciale');
    });

    test('chiave sconosciuta diventa leggibile', () {
      expect(etichettaRuolo('responsabile', ruoli), 'Responsabile');
    });

    test('chiave assente', () {
      expect(etichettaRuolo(null, ruoli), 'Ruolo non assegnato');
      expect(etichettaRuolo('   ', ruoli), 'Ruolo non assegnato');
    });
  });

  group('chiaviRuoloSelezionabili', () {
    test('salta le chiavi vuote', () {
      const senzaChiave = Ruolo(id: 'r3', nome: 'Ospite');
      expect(
        chiaviRuoloSelezionabili([amministratore, senzaChiave, commerciale]),
        ['admin', 'commerciale'],
      );
    });

    test('lista vuota senza ruoli', () {
      expect(chiaviRuoloSelezionabili(const []), isEmpty);
    });
  });

  group('chiaveRuoloCorrente', () {
    test('torna la chiave se selezionabile', () {
      expect(
        chiaveRuoloCorrente('commerciale', const [amministratore, commerciale]),
        'commerciale',
      );
    });

    test('torna null se la chiave non è fra le voci', () {
      expect(chiaveRuoloCorrente('admin', const []), isNull);
      expect(chiaveRuoloCorrente(null, const [amministratore]), isNull);
    });
  });

  group('emailVisualizzataUtente', () {
    test('usa l\'email quando c\'è', () {
      expect(emailVisualizzataUtente(mario), 'mario.rossi@example.it');
    });

    test('fallback senza email', () {
      expect(
        emailVisualizzataUtente(const UserProfile(id: 'u3', uid: 'u3')),
        'Email non disponibile',
      );
    });
  });

  group('messaggioErroreUtenti', () {
    test('permessi negati spiega il problema', () {
      final errore = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      expect(messaggioErroreUtenti(errore), contains('Non hai i permessi'));
    });

    test('errore generico invita a riprovare', () {
      expect(
        messaggioErroreUtenti(Exception('rete')),
        contains('connessione e riprova'),
      );
    });
  });

  group('CorpoUtenti', () {
    testWidgets('mostra lo stato vuoto senza membri', (tester) async {
      await mostraUtenti(tester, utenti: const []);

      expect(find.byKey(const Key('utenti-vuoto')), findsOneWidget);
      expect(find.text('Nessun utente'), findsOneWidget);
      expect(find.byKey(const Key('lista-utenti')), findsNothing);
    });

    testWidgets('mostra nome, email e ruolo in card', (tester) async {
      await mostraUtenti(tester, largo: false);

      expect(find.text('Mario Rossi'), findsOneWidget);
      expect(find.text('mario.rossi@example.it'), findsOneWidget);
      expect(find.byKey(const Key('lista-utenti')), findsOneWidget);
      expect(find.byKey(const ValueKey('utente-ruolo-u2')), findsOneWidget);
      // La tendina mostra il ruolo corrente risolto per chiave.
      expect(find.text('Commerciale'), findsOneWidget);
    });

    testWidgets('senza ruoli configurati mostra il ruolo corrente', (
      tester,
    ) async {
      await mostraUtenti(tester, ruoli: const [], largo: false);

      expect(
        find.byKey(const ValueKey('utente-ruolo-testo-u1')),
        findsOneWidget,
      );
      expect(find.text('Amministratore'), findsOneWidget);
      expect(find.byKey(const ValueKey('utente-ruolo-u2')), findsNothing);
    });

    testWidgets('cambiare ruolo chiama il callback', (tester) async {
      String? ruoloScelto;
      String? utenteScelto;
      await mostraUtenti(
        tester,
        largo: false,
        onCambiaRuolo: (utente, ruolo) {
          utenteScelto = utente.uid;
          ruoloScelto = ruolo;
        },
      );

      await tester.tap(find.byKey(const ValueKey('utente-ruolo-u2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amministratore').last);
      await tester.pumpAndSettle();

      expect(utenteScelto, 'u2');
      expect(ruoloScelto, 'admin');
    });

    testWidgets('rimozione chiama il callback', (tester) async {
      String? rimosso;
      await mostraUtenti(
        tester,
        largo: false,
        onRimuovi: (utente) => rimosso = utente.uid,
      );

      await tester.tap(find.byKey(const ValueKey('utente-rimuovi-u2')));
      await tester.pumpAndSettle();

      expect(rimosso, 'u2');
    });

    testWidgets('layout largo usa la tabella', (tester) async {
      await mostraUtenti(tester, largo: true);

      expect(find.byKey(const Key('tabella-utenti')), findsOneWidget);
      expect(find.byKey(const Key('lista-utenti')), findsNothing);
      expect(find.text('lucia.bianchi@example.it'), findsOneWidget);
    });
  });
}
