import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/placeholder_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/catalogo/catalogo_screen.dart';
import '../features/clienti/clienti_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/impostazioni/impostazioni_screen.dart';
import '../features/intro/intro_screen.dart';
import '../features/preventivi/preventivo_edit_screen.dart';
import '../features/preventivi/preventivi_screen.dart';
import '../features/shell/auth_gate.dart';
import '../features/visite/visite_screen.dart';

/// Costruisce il router dell'app.
///
/// Login è reale (F05); le altre schermate sono ancora segnaposto e i flussi
/// arriveranno con i task successivi. Login, recupero password e onboarding
/// restano fuori dalla shell, tutte le altre rotte usano la navigazione
/// responsive.
GoRouter creaAppRouter({String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordScreen(oobCode: state.uri.queryParameters['oobCode']),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Pagina introduttiva all'installazione, fuori dalla shell: si apre dalle
      // impostazioni e si chiude tornando indietro.
      GoRoute(
        path: '/intro',
        builder: (context, state) => IntroScreen(onFine: () => context.pop()),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AuthGate(percorso: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/clienti',
            builder: (context, state) => const ClientiScreen(),
          ),
          GoRoute(
            path: '/catalogo',
            builder: (context, state) => const CatalogoScreen(),
          ),
          GoRoute(
            path: '/preventivi',
            builder: (context, state) => const PreventiviScreen(),
          ),
          GoRoute(
            path: '/preventivi/nuovo',
            builder: (context, state) => const PreventivoEditScreen(),
          ),
          // L'editor apre per ora un preventivo vuoto: il caricamento per id
          // (con numero e revisione) arriva in F12b-2.
          GoRoute(
            path: '/preventivi/:id',
            builder: (context, state) => PreventivoEditScreen(
              preventivoId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            path: '/visite',
            builder: (context, state) => const VisiteScreen(),
          ),
          GoRoute(
            path: '/bandi',
            builder: (context, state) =>
                const PlaceholderScreen(icona: Icons.campaign_outlined),
          ),
          GoRoute(
            path: '/impostazioni',
            builder: (context, state) => const ImpostazioniScreen(),
          ),
          GoRoute(
            path: '/impostazioni/utenti',
            builder: (context, state) =>
                const PlaceholderScreen(icona: Icons.people_outline),
          ),
          GoRoute(
            path: '/impostazioni/ruoli',
            builder: (context, state) =>
                const PlaceholderScreen(icona: Icons.manage_accounts_outlined),
          ),
          GoRoute(
            path: '/impostazioni/licenze',
            builder: (context, state) => const PlaceholderScreen(
              icona: Icons.workspace_premium_outlined,
            ),
          ),
          GoRoute(
            path: '/superadmin',
            builder: (context, state) => const PlaceholderScreen(
              icona: Icons.admin_panel_settings_outlined,
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        _PaginaAutonoma(titolo: 'Pagina non trovata', icona: Icons.search_off),
  );
}

/// Pagina fuori shell (login, reset, onboarding) con titolo in `AppBar`.
class _PaginaAutonoma extends StatelessWidget {
  const _PaginaAutonoma({required this.titolo, required this.icona});

  final String titolo;
  final IconData icona;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titolo)),
      body: PlaceholderScreen(icona: icona),
    );
  }
}
