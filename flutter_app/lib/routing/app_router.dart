import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/placeholder_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/catalogo/catalogo_screen.dart';
import '../features/clienti/clienti_screen.dart';
import '../features/preventivi/preventivi_screen.dart';
import '../features/shell/app_shell.dart';

/// Costruisce il router dell'app.
///
/// Login è reale (F05); le altre schermate sono ancora segnaposto e i flussi
/// arriveranno con i task successivi. Login, recupero password e onboarding
/// restano fuori dalla shell, tutte le altre rotte usano la navigazione
/// responsive.
GoRouter creaAppRouter({String initialLocation = '/'}) {
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
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(percorso: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const PlaceholderScreen(icona: Icons.dashboard_outlined),
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
            builder: (context, state) =>
                const PlaceholderScreen(icona: Icons.note_add_outlined),
          ),
          GoRoute(
            path: '/visite',
            builder: (context, state) =>
                const PlaceholderScreen(icona: Icons.event_outlined),
          ),
          GoRoute(
            path: '/bandi',
            builder: (context, state) =>
                const PlaceholderScreen(icona: Icons.campaign_outlined),
          ),
          GoRoute(
            path: '/impostazioni',
            builder: (context, state) =>
                const PlaceholderScreen(icona: Icons.settings_outlined),
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
