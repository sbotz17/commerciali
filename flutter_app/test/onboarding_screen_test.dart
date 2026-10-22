import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/app.dart';
import 'package:commerciali_app/features/auth/onboarding_screen.dart';

/// Test della schermata di onboarding senza Firebase.
///
/// Il build non legge i provider: `SpService` e `FirebaseAuth` vengono
/// risolti solo al submit, quindi qui si possono verificare campi, validazione
/// e messaggi di errore.
void main() {
  Future<void> apriOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CloserApp(initialLocation: '/onboarding'),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('OnboardingScreen', () {
    testWidgets('mostra i campi e il pulsante di creazione', (tester) async {
      await apriOnboarding(tester);

      expect(find.text('Configura la tua azienda'), findsOneWidget);
      expect(find.text('Il tuo nome'), findsOneWidget);
      expect(find.text('Nome azienda'), findsOneWidget);
      expect(find.text('Crea azienda e inizia'), findsOneWidget);
    });

    testWidgets('i campi vuoti mostrano gli errori', (tester) async {
      await apriOnboarding(tester);

      await tester.tap(find.byKey(const Key('pulsante-crea-azienda')));
      await tester.pumpAndSettle();

      expect(find.text('Inserisci il tuo nome'), findsOneWidget);
      expect(find.text('Inserisci il nome dell\'azienda'), findsOneWidget);
      expect(find.text('Crea azienda e inizia'), findsOneWidget);
    });

    testWidgets('un nome di un solo carattere mostra l\'errore di lunghezza',
        (tester) async {
      await apriOnboarding(tester);

      await tester.enterText(find.byKey(const Key('campo-nome')), 'M');
      await tester.enterText(find.byKey(const Key('campo-azienda')), 'A');
      await tester.tap(find.byKey(const Key('pulsante-crea-azienda')));
      await tester.pumpAndSettle();

      expect(
        find.text('Il nome deve avere almeno 2 caratteri'),
        findsOneWidget,
      );
      expect(
        find.text('Il nome dell\'azienda deve avere almeno 2 caratteri'),
        findsOneWidget,
      );
    });
  });

  group('validaNomeUtente', () {
    test('null restituisce un errore', () {
      expect(validaNomeUtente(null), 'Inserisci il tuo nome');
    });

    test('stringa vuota restituisce un errore', () {
      expect(validaNomeUtente(''), 'Inserisci il tuo nome');
    });

    test('solo spazi restituisce un errore', () {
      expect(validaNomeUtente('   '), 'Inserisci il tuo nome');
    });

    test('un solo carattere è troppo corto', () {
      expect(
        validaNomeUtente('M'),
        'Il nome deve avere almeno 2 caratteri',
      );
    });

    test('un nome valido supera la validazione', () {
      expect(validaNomeUtente('Mario'), isNull);
    });

    test('gli spazi esterni vengono ignorati', () {
      expect(validaNomeUtente('  Mario  '), isNull);
    });
  });

  group('validaNomeAzienda', () {
    test('null restituisce un errore', () {
      expect(validaNomeAzienda(null), 'Inserisci il nome dell\'azienda');
    });

    test('stringa vuota restituisce un errore', () {
      expect(validaNomeAzienda(''), 'Inserisci il nome dell\'azienda');
    });

    test('solo spazi restituisce un errore', () {
      expect(validaNomeAzienda('  '), 'Inserisci il nome dell\'azienda');
    });

    test('un solo carattere è troppo corto', () {
      expect(
        validaNomeAzienda('A'),
        'Il nome dell\'azienda deve avere almeno 2 caratteri',
      );
    });

    test('un nome azienda valido supera la validazione', () {
      expect(validaNomeAzienda('Rossi Srl'), isNull);
    });

    test('gli spazi esterni vengono ignorati', () {
      expect(validaNomeAzienda('  Rossi Srl  '), isNull);
    });
  });

  group('messaggioErroreOnboarding', () {
    test('permessi mancanti', () {
      expect(
        messaggioErroreOnboarding(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        'Non hai i permessi per creare l\'azienda. Contatta l\'amministratore.',
      );
    });

    test('servizio non disponibile', () {
      expect(
        messaggioErroreOnboarding(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        'Connessione assente. Controlla la rete e riprova.',
      );
    });

    test('richiesta di rete fallita', () {
      expect(
        messaggioErroreOnboarding(
          FirebaseException(
            plugin: 'firebase_auth',
            code: 'network-request-failed',
          ),
        ),
        'Connessione assente. Controlla la rete e riprova.',
      );
    });

    test('sessione scaduta', () {
      expect(
        messaggioErroreOnboarding(
          FirebaseException(plugin: 'firebase_auth', code: 'unauthenticated'),
        ),
        'Sessione scaduta. Accedi di nuovo e riprova.',
      );
    });

    test('altro codice Firebase', () {
      expect(
        messaggioErroreOnboarding(
          FirebaseException(plugin: 'cloud_firestore', code: 'internal'),
        ),
        'Creazione non riuscita. Riprova.',
      );
    });

    test('errore non Firebase', () {
      expect(
        messaggioErroreOnboarding(Exception('rete assente')),
        'Creazione non riuscita. Controlla la connessione e riprova.',
      );
    });
  });
}
