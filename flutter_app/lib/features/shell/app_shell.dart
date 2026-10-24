import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../notifiche/campanella_notifiche.dart';

/// Struttura comune delle schermate applicative.
///
/// - sotto 600 px: `NavigationBar` con quattro voci principali e "Altro";
/// - da 600 px: `NavigationRail` con tutte le pagine e la rotella Impostazioni
///   in fondo.
///
/// Su telefono "Altro" apre il `Drawer` con le pagine secondarie e Impostazioni.
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

  /// Voci della barra inferiore su telefono: le quattro principali più
  /// "Altro", perché dieci voci non entrano in una `NavigationBar`.
  static const List<_VoceNavigazione> _vociTelefono = [
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

  /// Voci del drawer "Altro" su telefono. Impostazioni resta qui perché sul
  /// telefono non c'è una barra laterale con la rotella.
  static const List<_VoceNavigazione> _vociDrawerTelefono = [
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

  /// Barra laterale desktop/tablet: tutte le pagine tranne Impostazioni, che
  /// vive in fondo con l'icona a rotella.
  static const List<_VoceNavigazione> _vociLaterali = [
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
      etichetta: 'Catalogo',
      icona: Icons.inventory_2_outlined,
      iconaSelezionata: Icons.inventory_2,
      rotta: '/catalogo',
    ),
    _VoceNavigazione(
      etichetta: 'Preventivi',
      icona: Icons.description_outlined,
      iconaSelezionata: Icons.description,
      rotta: '/preventivi',
    ),
    _VoceNavigazione(
      etichetta: 'Visite',
      icona: Icons.event_outlined,
      iconaSelezionata: Icons.event,
      rotta: '/visite',
    ),
    _VoceNavigazione(
      etichetta: 'Calendario',
      icona: Icons.calendar_month_outlined,
      iconaSelezionata: Icons.calendar_month,
      rotta: '/calendario',
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
      etichetta: 'Bandi',
      icona: Icons.campaign_outlined,
      iconaSelezionata: Icons.campaign,
      rotta: '/bandi',
    ),
    _VoceNavigazione(
      etichetta: 'Notifiche',
      icona: Icons.notifications_none,
      iconaSelezionata: Icons.notifications,
      rotta: '/notifiche',
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
    '/impostazioni/integrazioni': 'Calendario e integrazioni',
    '/impostazioni/condivisioni-calendario': 'Condivisione calendario',
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

  /// Indice della voce che corrisponde al percorso, `null` se nessuna.
  int? _indiceIn(List<_VoceNavigazione> voci) {
    final esatto = voci.indexWhere((voce) => voce.rotta == percorso);
    if (esatto >= 0) return esatto;
    for (var i = 0; i < voci.length; i++) {
      final rotta = voci[i].rotta;
      if (rotta != '/' && percorso.startsWith(rotta)) return i;
    }
    return null;
  }

  /// Su telefono le rotte non principali finiscono tutte in "Altro".
  int get _indiceTelefono {
    final indice = _indiceIn(_vociTelefono);
    return indice ?? _vociTelefono.length - 1;
  }

  int? get _indiceLaterale => _indiceIn(_vociLaterali);

  bool get _impostazioniSelezionate => percorso.startsWith('/impostazioni');

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
          drawer: telefono
              ? _DrawerAltro(
                  percorso: percorso,
                  voci: _vociDrawerTelefono,
                )
              : null,
          body: telefono
              ? child
              : Row(
                  children: [
                    _Rail(
                      voci: _vociLaterali,
                      indiceSelezionato: _indiceLaterale,
                      impostazioniSelezionate: _impostazioniSelezionate,
                      onVoce: (indice) =>
                          context.go(_vociLaterali[indice].rotta),
                      onImpostazioni: () => context.go('/impostazioni'),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: child),
                  ],
                ),
          bottomNavigationBar: telefono
              ? NavigationBar(
                  selectedIndex: _indiceTelefono,
                  onDestinationSelected: (indice) {
                    if (indice == _vociTelefono.length - 1) {
                      scaffoldKey.currentState?.openDrawer();
                      return;
                    }
                    context.go(_vociTelefono[indice].rotta);
                  },
                  destinations: [
                    for (final voce in _vociTelefono)
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
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.voci,
    required this.indiceSelezionato,
    required this.impostazioniSelezionate,
    required this.onVoce,
    required this.onImpostazioni,
  });

  final List<_VoceNavigazione> voci;
  final int? indiceSelezionato;
  final bool impostazioniSelezionate;
  final ValueChanged<int> onVoce;
  final VoidCallback onImpostazioni;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: indiceSelezionato,
      labelType: NavigationRailLabelType.all,
      scrollable: true,
      onDestinationSelected: onVoce,
      leading: const Padding(
        padding: EdgeInsets.only(top: AppSpazi.xs, bottom: AppSpazi.m),
        child: Icon(Icons.business_center_outlined),
      ),
      destinations: [
        for (final voce in voci)
          NavigationRailDestination(
            icon: Icon(voce.icona),
            selectedIcon: Icon(voce.iconaSelezionata),
            label: Text(voce.etichetta),
          ),
      ],
      trailing: Padding(
        padding: const EdgeInsets.only(bottom: AppSpazi.m),
        child: Tooltip(
          message: 'Impostazioni',
          child: IconButton(
            key: const Key('rail-impostazioni'),
            onPressed: onImpostazioni,
            icon: Icon(
              impostazioniSelezionate
                  ? Icons.settings
                  : Icons.settings_outlined,
            ),
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
