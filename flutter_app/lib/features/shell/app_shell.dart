import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../notifiche/campanella_notifiche.dart';

/// Struttura comune delle schermate applicative.
///
/// - sotto 600 px: `NavigationBar` con le voci principali e "Altro";
/// - da 600 px: `NavigationRail` con le stesse voci e pulsante "Altro".
///
/// "Altro" apre il `Drawer` con Catalogo, Visite e Impostazioni.
/// Nessuna logica di autenticazione o permessi: arriverà nei task successivi.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.percorso,
    required this.child,
  });

  /// Percorso corrente restituito da `go_router` (es. `/clienti`).
  final String percorso;
  final Widget child;

  static const List<_VoceNavigazione> _vociPrincipali = [
    _VoceNavigazione(
      etichetta: 'Dashboard',
      icona: Icons.dashboard_outlined,
      iconaSelezionata: Icons.dashboard,
      rotta: '/',
    ),
    _VoceNavigazione(
      etichetta: 'Clienti',
      icona: Icons.people_outline,
      iconaSelezionata: Icons.people,
      rotta: '/clienti',
    ),
    _VoceNavigazione(
      etichetta: 'Preventivi',
      icona: Icons.description_outlined,
      iconaSelezionata: Icons.description,
      rotta: '/preventivi',
    ),
    _VoceNavigazione(
      etichetta: 'Bandi',
      icona: Icons.campaign_outlined,
      iconaSelezionata: Icons.campaign,
      rotta: '/bandi',
    ),
    _VoceNavigazione(
      etichetta: 'Altro',
      icona: Icons.more_horiz,
      iconaSelezionata: Icons.more_horiz,
      rotta: '/altro',
    ),
  ];

  static const List<_VoceNavigazione> _vociSecondarie = [
    _VoceNavigazione(
      etichetta: 'Catalogo',
      icona: Icons.inventory_2_outlined,
      iconaSelezionata: Icons.inventory_2,
      rotta: '/catalogo',
    ),
    _VoceNavigazione(
      etichetta: 'Calendario',
      icona: Icons.calendar_month_outlined,
      iconaSelezionata: Icons.calendar_month,
      rotta: '/calendario',
    ),
    _VoceNavigazione(
      etichetta: 'Visite',
      icona: Icons.event_outlined,
      iconaSelezionata: Icons.event,
      rotta: '/visite',
    ),
    _VoceNavigazione(
      etichetta: 'Task',
      icona: Icons.task_alt,
      iconaSelezionata: Icons.task_alt,
      rotta: '/task',
    ),
    _VoceNavigazione(
      etichetta: 'Chat',
      icona: Icons.chat_bubble_outline,
      iconaSelezionata: Icons.chat_bubble,
      rotta: '/chat',
    ),
    _VoceNavigazione(
      etichetta: 'Notifiche',
      icona: Icons.notifications_none,
      iconaSelezionata: Icons.notifications,
      rotta: '/notifiche',
    ),
    _VoceNavigazione(
      etichetta: 'Impostazioni',
      icona: Icons.settings_outlined,
      iconaSelezionata: Icons.settings,
      rotta: '/impostazioni',
    ),
  ];

  static const Map<String, String> _titoli = {
    '/': 'Dashboard',
    '/clienti': 'Clienti',
    '/catalogo': 'Catalogo',
    '/preventivi': 'Preventivi',
    '/preventivi/nuovo': 'Nuovo preventivo',
    '/visite': 'Visite',
    '/task': 'Task',
    '/chat': 'Chat',
    '/calendario': 'Calendario',
    '/bandi': 'Bandi',
    '/bandi/importa': 'Importa bandi',
    '/notifiche': 'Notifiche',
    '/impostazioni': 'Impostazioni',
    '/impostazioni/utenti': 'Utenti',
    '/impostazioni/ruoli': 'Ruoli e permessi',
    '/impostazioni/licenze': 'Licenze',
    '/impostazioni/notifiche': 'Notifiche',
    '/impostazioni/agenda': 'Agenda',
    '/superadmin': 'Super admin',
  };

  String get _titolo {
    final esatto = _titoli[percorso];
    if (esatto != null) return esatto;

    final corrispondenze = _titoli.entries
        .where((voce) => voce.key != '/' && percorso.startsWith(voce.key))
        .toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    return corrispondenze.isEmpty ? 'Closer' : corrispondenze.first.value;
  }

  int get _indiceSelezionato {
    if (percorso == '/') return 0;
    if (percorso.startsWith('/clienti')) return 1;
    if (percorso.startsWith('/preventivi')) return 2;
    if (percorso.startsWith('/bandi')) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final telefono = constraints.maxWidth < AppBreakpoints.telefono;

        return Scaffold(
          key: scaffoldKey,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(_titolo),
            actions: const [CampanellaNotifiche()],
          ),
          drawer: _DrawerAltro(
            percorso: percorso,
            voci: _vociSecondarie,
          ),
          body: telefono
              ? child
              : Row(
                  children: [
                    _Rail(
                      indiceSelezionato: _indiceSelezionato,
                      onVoce: (indice) => _seleziona(
                        context,
                        indice,
                        () => scaffoldKey.currentState?.openDrawer(),
                      ),
                      onAltro: () => scaffoldKey.currentState?.openDrawer(),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: child),
                  ],
                ),
          bottomNavigationBar: telefono
              ? NavigationBar(
                  selectedIndex: _indiceSelezionato,
                  onDestinationSelected: (indice) => _seleziona(
                    context,
                    indice,
                    () => scaffoldKey.currentState?.openDrawer(),
                  ),
                  destinations: [
                    for (final voce in _vociPrincipali)
                      NavigationDestination(
                        icon: Icon(voce.icona),
                        selectedIcon: Icon(voce.iconaSelezionata),
                        label: voce.etichetta,
                      ),
                  ],
                )
              : null,
        );
      },
    );
  }

  void _seleziona(BuildContext context, int indice, VoidCallback apriAltro) {
    if (indice == _vociPrincipali.length - 1) {
      apriAltro();
      return;
    }
    context.go(_vociPrincipali[indice].rotta);
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.indiceSelezionato,
    required this.onVoce,
    required this.onAltro,
  });

  final int indiceSelezionato;
  final ValueChanged<int> onVoce;
  final VoidCallback onAltro;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: indiceSelezionato,
      labelType: NavigationRailLabelType.all,
      onDestinationSelected: onVoce,
      leading: const Padding(
        padding: EdgeInsets.only(top: AppSpazi.xs, bottom: AppSpazi.m),
        child: Icon(Icons.business_center_outlined),
      ),
      destinations: [
        for (final voce in AppShell._vociPrincipali)
          NavigationRailDestination(
            icon: Icon(voce.icona),
            selectedIcon: Icon(voce.iconaSelezionata),
            label: Text(voce.etichetta),
          ),
      ],
      trailing: Padding(
        padding: const EdgeInsets.only(bottom: AppSpazi.m),
        child: Tooltip(
          message: 'Altro',
          child: IconButton(
            onPressed: onAltro,
            icon: const Icon(Icons.more_horiz),
          ),
        ),
      ),
    );
  }
}

class _DrawerAltro extends StatelessWidget {
  const _DrawerAltro({
    required this.percorso,
    required this.voci,
  });

  final String percorso;
  final List<_VoceNavigazione> voci;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpazi.m,
                AppSpazi.l,
                AppSpazi.m,
                AppSpazi.m,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Closer', style: tema.textTheme.titleLarge),
                  const SizedBox(height: AppSpazi.xxs),
                  Text(
                    'Altro',
                    style: tema.textTheme.labelSmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            for (final voce in voci)
              ListTile(
                selected: percorso.startsWith(voce.rotta),
                leading: Icon(voce.icona),
                title: Text(voce.etichetta),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(voce.rotta);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _VoceNavigazione {
  const _VoceNavigazione({
    required this.etichetta,
    required this.icona,
    required this.iconaSelezionata,
    required this.rotta,
  });

  final String etichetta;
  final IconData icona;
  final IconData iconaSelezionata;
  final String rotta;
}
