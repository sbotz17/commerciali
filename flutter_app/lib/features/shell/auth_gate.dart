import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/stato_centrato.dart';
import '../../data/models/azienda.dart';
import '../../data/models/user_profile.dart';
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
/// - nessun utente → [LoginScreen];
/// - utente autenticato → [FirstRunGate], così la pagina introduttiva compare
///   subito dopo il login senza attendere profilo e aziende;
///   il contenuto interno è:
///   - caricamento di profilo o aziende → [SplashScreen];
///   - errore di lettura → messaggio con "Riprova";
///   - utente senza profilo o senza aziende → [OnboardingScreen];
///   - altrimenti → [AppShell] con il contenuto della rotta.
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

    // Se la sessione non è ancora pronta si mostra subito il login: evita di
    // restare bloccati sullo splash se lo stream di Auth tarda.
    final utente = sessione.asData?.value;
    if (utente == null) {
      return const LoginScreen();
    }

    // Utente autenticato: sincronizza l'azienda attiva con le sue aziende,
    // che possono arrivare dopo il login. Senza questo passaggio le scritture
    // partirebbero con `azienda_id` null (Firestore risponde permission denied).
    ref.watch(aziendaAttivaSyncProvider);

    final profilo = ref.watch(profileProvider);
    final aziende = ref.watch(aziendeUtenteProvider);

    // L'intro avvolge il contenuto appena c'è un utente: compare subito dopo
    // l'autenticazione e il child si aggiorna quando i provider risolvono.
    return FirstRunGate(child: _contenuto(ref, profilo, aziende));
  }

  Widget _contenuto(
    WidgetRef ref,
    AsyncValue<UserProfile?> profilo,
    AsyncValue<List<Azienda>> aziende,
  ) {
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

    return AppShell(percorso: percorso, child: child);
  }
}
