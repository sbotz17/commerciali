import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/user_profile.dart';
import 'package:commerciali_app/features/bandi/import_bandi_screen.dart';
import 'package:commerciali_app/state/auth_providers.dart';

void main() {
  const profiloSemplice = UserProfile(
    id: 'u1',
    uid: 'u1',
    email: 'anna@example.it',
    nome: 'Anna Bianchi',
    ruolo: 'commerciale',
  );

  const profiloSuperAdmin = UserProfile(
    id: 'u2',
    uid: 'u2',
    email: 'mario@example.it',
    nome: 'Mario Rossi',
    ruolo: 'admin',
    superAdmin: true,
  );

  /// Monta la schermata con il profilo indicato, senza Firebase né rete.
  Future<void> mostraImportBandi(
    WidgetTester tester, {
    UserProfile? profilo = profiloSemplice,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) async => profilo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ImportBandiScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('messaggioErroreImportBandi', () {
    test('JSON non valido spiega di controllare il file', () {
      final messaggio = messaggioErroreImportBandi(
        const FormatException('Unexpected character'),
      );
      expect(messaggio, contains('non contiene un JSON valido'));
      expect(messaggio, contains('incentivi.gov.it'));
    });

    test('errore di rete o CORS suggerisce il file locale', () {
      final messaggio = messaggioErroreImportBandi(
        http.ClientException('Failed to fetch'),
      );
      expect(messaggio, contains('connessione'));
      expect(messaggio, contains('CORS'));
      expect(messaggio, contains('Scegli file JSON'));
    });

    test('permessi negati non espone dettagli tecnici', () {
      final errore = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      final messaggio = messaggioErroreImportBandi(errore);
      expect(messaggio, contains('Non hai i permessi'));
      expect(messaggio, contains('amministratore'));
    });

    test('rete Firestore invita a controllare la connessione', () {
      final errore = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      expect(
        messaggioErroreImportBandi(errore),
        contains('Connessione assente'),
      );
    });

    test('errore generico resta semplice', () {
      final messaggio = messaggioErroreImportBandi(Exception('imprevisto'));
      expect(messaggio, contains('Importazione non riuscita'));
    });

    test('messaggio pronto per l\'utente viene restituito così com\'è', () {
      expect(
        messaggioErroreImportBandi(
          const ImportBandiException('Il file non contiene bandi.'),
        ),
        'Il file non contiene bandi.',
      );
    });
  });

  group('ImportBandiScreen', () {
    testWidgets('senza super admin mostra Accesso riservato', (tester) async {
      await mostraImportBandi(tester, profilo: profiloSemplice);

      expect(find.text('Accesso riservato'), findsOneWidget);
      expect(
        find.byKey(const Key('import-bandi-riservato')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('import-bandi-url')), findsNothing);
      expect(find.byKey(const Key('import-bandi-url-avvia')), findsNothing);
      expect(find.byKey(const Key('import-bandi-file')), findsNothing);
    });

    testWidgets('senza profilo mostra Accesso riservato', (tester) async {
      await mostraImportBandi(tester, profilo: null);

      expect(find.text('Accesso riservato'), findsOneWidget);
      expect(find.byKey(const Key('import-bandi-url')), findsNothing);
    });

    testWidgets('il super admin vede URL, scelta file e link open data',
        (tester) async {
      await mostraImportBandi(tester, profilo: profiloSuperAdmin);

      expect(find.text('Importa bandi'), findsWidgets);
      expect(find.byKey(const Key('import-bandi-url')), findsOneWidget);
      expect(
        find.byKey(const Key('import-bandi-url-avvia')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('import-bandi-file')), findsOneWidget);
      expect(
        find.byKey(const Key('import-bandi-link-open-data')),
        findsOneWidget,
      );
      expect(find.text('Accesso riservato'), findsNothing);
    });

    testWidgets('con profilo ancora in caricamento mostra la rotella',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profiloFuturo = Completer<UserProfile?>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => profiloFuturo.future),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: ImportBandiScreen()),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('import-bandi-caricamento')),
        findsOneWidget,
      );

      profiloFuturo.complete(profiloSemplice);
      await tester.pumpAndSettle();

      expect(find.text('Accesso riservato'), findsOneWidget);
    });
  });
}
