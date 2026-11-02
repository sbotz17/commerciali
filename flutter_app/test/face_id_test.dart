// Accesso con Face ID (passkey): messaggi, pulsante nel login e gestione in
// Impostazioni. La richiesta di Face ID vera la fa il sistema (WebAuthn): qui
// si prova la logica dell'app con un servizio finto.
import 'package:commerciali_app/data/services/passkey_service.dart';
import 'package:commerciali_app/features/auth/login_screen.dart';
import 'package:commerciali_app/features/impostazioni/accesso_face_id_card.dart';
import 'package:commerciali_app/state/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeys/exceptions.dart';

class _PasskeysFinte extends PasskeyService {
  _PasskeysFinte({this.si = true, this.errore, List<PasskeyInfo>? iniziali})
      : passkeys = [...?iniziali];

  final bool si;
  final Object? errore;
  final List<PasskeyInfo> passkeys;
  int accessi = 0;
  int registrazioni = 0;

  @override
  Future<bool> disponibile() async => si;

  @override
  Future<void> accedi() async {
    accessi++;
    if (errore != null) throw errore!;
  }

  @override
  Future<void> registra() async {
    registrazioni++;
    if (errore != null) throw errore!;
    passkeys.add(PasskeyInfo(
      id: 'p${passkeys.length + 1}',
      nome: 'iPhone',
      creato: DateTime(2026, 10, 25),
    ));
  }

  @override
  Future<List<PasskeyInfo>> elenco() async => passkeys;

  @override
  Future<void> rimuovi(String id) async {
    passkeys.removeWhere((p) => p.id == id);
  }
}

Widget _app(Widget child, _PasskeysFinte passkeys) => ProviderScope(
      overrides: [passkeyServiceProvider.overrideWithValue(passkeys)],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('messaggi di Face ID', () {
    test('annullato dall’utente', () {
      expect(
        messaggioErrorePasskey(PasskeyAuthCancelledException()),
        'Accesso con Face ID annullato.',
      );
    });

    test('nessuna passkey su questo dispositivo', () {
      expect(
        messaggioErrorePasskey(NoCredentialsAvailableException()),
        contains('Nessun accesso con Face ID'),
      );
    });

    test('dispositivo che non lo supporta', () {
      expect(
        messaggioErrorePasskey(PasskeyUnsupportedException()),
        contains('non supporta Face ID'),
      );
    });

    test('errore sconosciuto: nessun dettaglio tecnico', () {
      final messaggio = messaggioErrorePasskey(StateError('stack interno'));
      expect(messaggio, isNot(contains('stack interno')));
      expect(messaggio, contains('Non è stato possibile usare Face ID'));
    });
  });

  group('login', () {
    testWidgets('mostra “Entra con Face ID” solo se supportato', (tester) async {
      await tester.pumpWidget(
        _app(const LoginScreen(), _PasskeysFinte(si: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Entra con Face ID'), findsOneWidget);
    });

    testWidgets('senza supporto il pulsante non compare', (tester) async {
      await tester.pumpWidget(
        _app(const LoginScreen(), _PasskeysFinte(si: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Entra con Face ID'), findsNothing);
      expect(find.text('Accedi'), findsOneWidget);
    });

    testWidgets('annullando Face ID resta sul login con un messaggio chiaro',
        (tester) async {
      final finte = _PasskeysFinte(
        si: true,
        errore: PasskeyAuthCancelledException(),
      );
      await tester.pumpWidget(_app(const LoginScreen(), finte));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entra con Face ID'));
      await tester.pumpAndSettle();
      expect(finte.accessi, 1);
      expect(find.text('Accesso con Face ID annullato.'), findsOneWidget);
      expect(find.text('Accedi'), findsOneWidget);
    });
  });

  group('Impostazioni → Accesso con Face ID', () {
    testWidgets('senza supporto spiega dove si usa, senza pulsante',
        (tester) async {
      await tester.pumpWidget(
        _app(const AccessoFaceIdCard(), _PasskeysFinte(si: false)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Disponibile nella web app'), findsOneWidget);
      expect(find.text('Attiva Face ID'), findsNothing);
    });

    testWidgets('nessun accesso attivo: mostra il pulsante per attivarlo',
        (tester) async {
      await tester.pumpWidget(
        _app(const AccessoFaceIdCard(), _PasskeysFinte()),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Nessun accesso con Face ID attivo su questo account.'),
        findsOneWidget,
      );
      expect(find.text('Attiva Face ID'), findsOneWidget);
    });

    testWidgets('attivazione: la passkey compare nell’elenco', (tester) async {
      final finte = _PasskeysFinte();
      await tester.pumpWidget(_app(const AccessoFaceIdCard(), finte));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attiva Face ID'));
      await tester.pumpAndSettle();
      expect(finte.registrazioni, 1);
      expect(find.text('iPhone'), findsOneWidget);
      expect(find.textContaining('Accesso con Face ID attivato'), findsOneWidget);
    });

    testWidgets('con una passkey attiva mostra nome e data', (tester) async {
      final finte = _PasskeysFinte(iniziali: [
        PasskeyInfo(
          id: 'p1',
          nome: 'iPhone',
          creato: DateTime(2026, 10, 25),
        ),
      ]);
      await tester.pumpWidget(_app(const AccessoFaceIdCard(), finte));
      await tester.pumpAndSettle();
      expect(find.text('iPhone'), findsOneWidget);
      expect(find.textContaining('25/10/2026'), findsOneWidget);
    });
  });
}
