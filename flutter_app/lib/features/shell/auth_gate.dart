import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/stato_centrato.dart';
import '../../splash_screen.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';
import '../auth/login_screen.dart';
import '../auth/onboarding_screen.dart';
import '../intro/first_run_gate.dart';
import 'app_shell.dart';

/// Cancello di autenticazione che avvolge le rotte della shell.
///
/// Decide cosa mostrare in base allo stato di autenticazione, senza redirect:
///
/// - caricamento di sessione, profilo o aziende → [SplashScreen];
/// - nessun utente → [LoginScreen];
/// - utente senza profilo o senza aziende → [OnboardingScreen];
/// - altrimenti → [AppShell] con il contenuto della rotta, avvolta da
///   [FirstRunGate] per la pagina introduttiva del primo avvio.
///
/// Non esegue chiamate a Firebase: legge solo i provider, così i test possono
/// sostituirli con `overrideWith`.
class AuthGate extends ConsumerWidget {
  const AuthGate({
    super.key,
    required this.percorso,
    required this.child,
  });

  /// Percorso corrente restituito da `go_router` (es. `/clienti`).
  final String percorso;

  /// Contenuto della rotta scelta dal router.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessione = ref.watch(authStateProvider);
    final profilo = ref.watch(profileProvider);
    final aziende = ref.watch(aziendeUtenteProvider);

    // Se la sessione non è ancora pronta si mostra subito il login: evita di
    // restare bloccati sullo splash se lo stream di Auth tarda.
    final utente = sessione.asData?.value;
    if (utente == null) {
      return const LoginScreen();
    }

    if (profilo.isLoading || aziende.isLoading) {
      return const SplashScreen();
    }

    // Errore di lettura di profilo o aziende: non è un utente "senza dati",
    // quindi non lo si manda in onboarding, si propone un nuovo tentativo.
    if (profilo.hasError || aziende.hasError) {
      return Scaffold(
        body: StatoCentrato(
          icona: Icons.cloud_off_outlined,
          titolo: 'Dati non disponibili',
          sottotitolo:
              'Non è stato possibile caricare il profilo o le aziende. '
              'Controlla la connessione e riprova.',
          azione: FilledButton.icon(
            key: const Key('auth-gate-riprova'),
            onPressed: () {
              ref.invalidate(profileProvider);
              ref.invalidate(aziendeUtenteProvider);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Riprova'),
          ),
        ),
      );
    }

    final profiloUtente = profilo.asData?.value;
    final elencoAziende = aziende.asData?.value ?? const [];
    if (profiloUtente == null || elencoAziende.isEmpty) {
      return const OnboardingScreen();
    }

    return FirstRunGate(child: AppShell(percorso: percorso, child: child));
  }
}
