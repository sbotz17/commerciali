import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/core/ui/placeholder_screen.dart';
import 'package:commerciali_app/data/models/azienda.dart';
import 'package:commerciali_app/data/models/user_profile.dart';
import 'package:commerciali_app/features/auth/login_screen.dart';
import 'package:commerciali_app/features/auth/onboarding_screen.dart';
import 'package:commerciali_app/features/intro/first_run_gate.dart';
import 'package:commerciali_app/features/shell/app_shell.dart';
import 'package:commerciali_app/features/shell/auth_gate.dart';
import 'package:commerciali_app/state/auth_providers.dart';
import 'package:commerciali_app/state/azienda_providers.dart';

/// Utente Firebase finto: serve solo a distinguere "loggato" da "non loggato",
/// quindi l'unico membro usato (`email`) è implementato davvero.
class _UtenteFinto implements User {
  _UtenteFinto({this.email});

  @override
  final String? email;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    // La pagina introduttiva non deve bloccare i test della shell.
    SharedPreferences.setMockInitialValues({chiaveIntroVista: true});
  });

  Future<void> mostraGate(
    WidgetTester tester, {
    User? utente,
    UserProfile? profilo,
    List<Azienda> aziende = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(utente)),
          profileProvider.overrideWith((ref) async => profilo),
          aziendeUtenteProvider.overrideWith((ref) async => aziende),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AuthGate(
            percorso: '/clienti',
            child: const PlaceholderScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AuthGate', () {
    testWidgets('senza utente mostra il login', (tester) async {
      await mostraGate(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('utente senza profilo mostra l\'onboarding', (tester) async {
      await mostraGate(tester, utente: _UtenteFinto(email: 'anna@example.it'));

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('utente con profilo e aziende mostra la shell', (tester) async {
      await mostraGate(
        tester,
        utente: _UtenteFinto(email: 'anna@example.it'),
        profilo: const UserProfile(
          id: 'u1',
          uid: 'u1',
          email: 'anna@example.it',
          nome: 'Anna',
        ),
        aziende: const [Azienda(id: 'a1', nome: 'Acme S.r.l.')],
      );

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(PlaceholderScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });
}
