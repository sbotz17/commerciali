// Campanella delle notifiche mostrata nella `AppBar` della shell.
//
// Mostra l'icona con il numero delle notifiche non lette e apre `/notifiche`.
// Senza Firebase (test widget, ProviderScope assente) il servizio non è
// leggibile: in quel caso resta solo la campanella, senza errori in schermata.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/notifica.dart';
import '../../state/azienda_providers.dart';
import 'notifiche_screen.dart';

/// Pulsante con la campanella e il badge delle notifiche non lette.
class CampanellaNotifiche extends ConsumerWidget {
  const CampanellaNotifiche({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Stream<List<Notifica>>? flusso;
    try {
      flusso = ref.watch(spServiceProvider).notificheStream();
    } catch (_) {
      // Nessun provider/Firebase disponibile: si mostra solo la campanella.
      flusso = null;
    }

    if (flusso == null) return _Campanella(nonLette: 0);

    return StreamBuilder<List<Notifica>>(
      stream: flusso,
      builder: (context, snapshot) {
        // In errore (es. permessi) la campanella resta, senza badge.
        final notifiche = snapshot.hasError ? const <Notifica>[] : snapshot.data;
        return _Campanella(
          nonLette: notifiche == null ? 0 : contaNotificheNonLette(notifiche),
        );
      },
    );
  }
}

/// Icona della campanella con badge quando ci sono notifiche non lette.
class _Campanella extends StatelessWidget {
  const _Campanella({required this.nonLette});

  final int nonLette;

  @override
  Widget build(BuildContext context) {
    final pulsante = IconButton(
      key: const Key('campanella-notifiche'),
      tooltip: 'Notifiche',
      onPressed: () => context.go('/notifiche'),
      icon: const Icon(Icons.notifications_none),
    );

    if (nonLette <= 0) return pulsante;

    return Badge(
      key: const Key('campanella-notifiche-badge'),
      label: Text('$nonLette'),
      child: pulsante,
    );
  }
}
