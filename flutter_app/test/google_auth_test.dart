import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:commerciali_app/app.dart';
import 'package:commerciali_app/data/services/auth_service.dart';

void main() {
  group('messaggioErroreGoogle', () {
    test('popup-closed-by-user', () {
      expect(
        messaggioErroreGoogle(
          FirebaseAuthException(code: 'popup-closed-by-user'),
        ),
        'Accesso annullato. Riprova per accedere con Google.',
      );
    });

    test('cancelled-popup-request', () {
      expect(
        messaggioErroreGoogle(
          FirebaseAuthException(code: 'cancelled-popup-request'),
        ),
        'Operazione annullata. Riprova.',
      );
    });

    test('popup-blocked', () {
      expect(
        messaggioErroreGoogle(
          FirebaseAuthException(code: 'popup-blocked'),
        ),
        'Pop-up bloccato dal browser. Consenti i pop-up e riprova.',
      );
    });

    test('network-request-failed', () {
      expect(
        messaggioErroreGoogle(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        'Connessione assente. Controlla la rete e riprova.',
      );
    });

    test('account-exists-with-different-credential', () {
      expect(
        messaggioErroreGoogle(
          FirebaseAuthException(
            code: 'account-exists-with-different-credential',
          ),
        ),
        'Esiste già un account con questa email collegato a un altro metodo di accesso.',
      );
    });

    test('operation-not-allowed', () {
      expect(
        messaggioErroreGoogle(
          FirebaseAuthException(code: 'operation-not-allowed'),
        ),
        'Accesso con Google non disponibile.',
      );
    });

    test('user-disabled', () {
      expect(
        messaggioErroreGoogle(
          FirebaseAuthException(code: 'user-disabled'),
        ),
        'Utente disabilitato. Contatta l\'amministratore.',
      );
    });

    test('codice sconosciuto usa il messaggio di fallback', () {
      expect(
        messaggioErroreGoogle(
          FirebaseAuthException(code: 'errore-inatteso'),
        ),
        'Accesso con Google non riuscito. Riprova.',
      );
    });

    test('errore generico non Firebase usa il messaggio di rete', () {
      expect(
        messaggioErroreGoogle(Exception('errore generico')),
        'Accesso con Google non riuscito. Controlla la connessione e riprova.',
      );
    });

    test('GoogleSignInException canceled', () {
      expect(
        messaggioErroreGoogle(
          GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
        ),
        'Accesso annullato. Riprova per accedere con Google.',
      );
    });

    test('GoogleSignInException interrupted', () {
      expect(
        messaggioErroreGoogle(
          GoogleSignInException(code: GoogleSignInExceptionCode.interrupted),
        ),
        'Accesso interrotto. Riprova.',
      );
    });

    test('GoogleSignInException clientConfigurationError', () {
      expect(
        messaggioErroreGoogle(
          GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
          ),
        ),
        'Configurazione di Google non valida. Contatta l\'assistenza.',
      );
    });

    test('GoogleSignInException providerConfigurationError', () {
      expect(
        messaggioErroreGoogle(
          GoogleSignInException(
            code: GoogleSignInExceptionCode.providerConfigurationError,
          ),
        ),
        'Configurazione di Google non valida. Contatta l\'assistenza.',
      );
    });

    test('GoogleSignInException uiUnavailable', () {
      expect(
        messaggioErroreGoogle(
          GoogleSignInException(code: GoogleSignInExceptionCode.uiUnavailable),
        ),
        'Impossibile mostrare la schermata Google. Riprova.',
      );
    });

    test('GoogleSignInException userMismatch', () {
      expect(
        messaggioErroreGoogle(
          GoogleSignInException(code: GoogleSignInExceptionCode.userMismatch),
        ),
        'Account Google diverso da quello atteso. Riprova.',
      );
    });

    test('GoogleSignInException unknownError', () {
      expect(
        messaggioErroreGoogle(
          GoogleSignInException(code: GoogleSignInExceptionCode.unknownError),
        ),
        'Accesso con Google non riuscito. Riprova.',
      );
    });
  });

  testWidgets('il login mostra il pulsante Google e il testo di accesso',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CloserApp(initialLocation: '/login'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pulsante-google')), findsOneWidget);
    expect(find.text('Accedi con Google'), findsOneWidget);
  });
}
