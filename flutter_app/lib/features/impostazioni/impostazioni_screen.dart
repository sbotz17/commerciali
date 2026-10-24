import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/azienda.dart';
import '../../data/models/user_profile.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';

// ---------------------------------------------------------------------------
// Funzioni pure: testi e messaggi verificabili senza Firebase né UI
// ---------------------------------------------------------------------------

/// Nome da mostrare per il profilo: nome, poi username, poi email.
String nomeVisualizzatoProfilo(UserProfile? profilo) {
  if (profilo == null) return 'Utente';
  for (final valore in [profilo.nome, profilo.username, profilo.email]) {
    final testo = valore?.trim() ?? '';
    if (testo.isNotEmpty) return testo;
  }
  return 'Utente';
}

/// Iniziali del profilo per l'avatar (massimo due lettere).
String inizialiProfilo(UserProfile? profilo) {
  final nome = nomeVisualizzatoProfilo(profilo);
  final parole = nome
      .split(RegExp(r'\s+'))
      .where((parola) => parola.isNotEmpty)
      .toList();
  if (parole.isEmpty) return '?';
  if (parole.length == 1) {
    return parole.first.characters.take(1).toString().toUpperCase();
  }
  return '${parole.first.characters.take(1)}${parole[1].characters.take(1)}'
      .toUpperCase();
}

/// Ruolo leggibile del profilo, con fallback quando il campo è assente.
String ruoloVisualizzatoProfilo(UserProfile? profilo) {
  final ruolo = profilo?.ruolo?.trim() ?? '';
  return ruolo.isEmpty ? 'Ruolo non assegnato' : ruolo;
}

/// Messaggio in italiano per gli errori di caricamento delle impostazioni.
String messaggioErroreImpostazioni(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per vedere le impostazioni. '
            'Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      default:
        return 'Operazione non riuscita. Riprova.';
    }
  }
  return 'Operazione non riuscita. Controlla la connessione e riprova.';
}

// ---------------------------------------------------------------------------
// Schermata con provider
// ---------------------------------------------------------------------------

/// Schermata Impostazioni: profilo, azienda attiva, accessi e logout.
class ImpostazioniScreen extends ConsumerWidget {
  const ImpostazioniScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilo = ref.watch(profileProvider);
    final aziende = ref.watch(aziendeUtenteProvider);
    final aziendaAttivaId = ref.watch(aziendaAttivaProvider);

    if (profilo.isLoading || aziende.isLoading) {
      return const Center(
        key: Key('impostazioni-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (profilo.hasError) {
      return StatoCentrato(
        icona: Icons.cloud_off_outlined,
        titolo: 'Impostazioni non disponibili',
        sottotitolo: messaggioErroreImpostazioni(profilo.error!),
        azione: OutlinedButton.icon(
          key: const Key('impostazioni-riprova'),
          onPressed: () => ref.invalidate(profileProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    if (aziende.hasError) {
      return StatoCentrato(
        icona: Icons.cloud_off_outlined,
        titolo: 'Aziende non disponibili',
        sottotitolo: messaggioErroreImpostazioni(aziende.error!),
        azione: OutlinedButton.icon(
          key: const Key('impostazioni-riprova-aziende'),
          onPressed: () => ref.invalidate(aziendeUtenteProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    final datiProfilo = profilo.value;
    if (datiProfilo == null) {
      return StatoCentrato(
        icona: Icons.person_off_outlined,
        titolo: 'Profilo non disponibile',
        sottotitolo: 'Accedi di nuovo per vedere le impostazioni.',
        azione: FilledButton(
          key: const Key('impostazioni-vai-login'),
          onPressed: () => context.go('/login'),
          child: const Text('Vai al login'),
        ),
      );
    }

    final elencoAziende = aziende.value ?? const <Azienda>[];
    Azienda? aziendaAttiva;
    for (final azienda in elencoAziende) {
      if (azienda.id == aziendaAttivaId) {
        aziendaAttiva = azienda;
        break;
      }
    }
    final admin = datiProfilo.superAdmin || aziendaAttiva?.ruolo == 'admin';

    return CorpoImpostazioni(
      profilo: datiProfilo,
      aziende: elencoAziende,
      aziendaAttivaId: aziendaAttivaId,
      admin: admin,
      onCambiaAzienda: (id) =>
          ref.read(aziendaAttivaProvider.notifier).state = id,
      onLogout: () => _esci(context, ref),
      onVoce: (rotta) => context.go(rotta),
      onApriIntro: () => context.push('/intro'),
    );
  }

  /// Esegue il logout e torna al login anche se `signOut` fallisce.
  Future<void> _esci(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (_) {
      // La sessione locale va comunque chiusa: si prosegue verso il login.
    }
    if (!context.mounted) return;
    context.go('/login');
  }
}

// ---------------------------------------------------------------------------
// Corpo puro (testabile senza provider)
// ---------------------------------------------------------------------------

/// Corpo delle impostazioni senza provider, usato dai widget test.
class CorpoImpostazioni extends StatelessWidget {
  const CorpoImpostazioni({
    super.key,
    required this.profilo,
    required this.aziende,
    required this.aziendaAttivaId,
    required this.onCambiaAzienda,
    required this.onLogout,
    required this.onVoce,
    this.admin = true,
    this.onApriIntro,
  });

  final UserProfile? profilo;
  final List<Azienda> aziende;
  final String? aziendaAttivaId;

  /// Se `true` mostra anche le voci di amministrazione dell'azienda.
  /// Le impostazioni personali (notifiche e condivisione calendario) sono
  /// sempre visibili a tutti i ruoli.
  final bool admin;
  final void Function(String) onCambiaAzienda;
  final VoidCallback onLogout;
  final void Function(String rotta) onVoce;

  /// Apre la pagina "Come installare l'app" (`/intro`).
  final VoidCallback? onApriIntro;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largo = constraints.maxWidth >= AppBreakpoints.telefono;
        final orizzontale =
            largo ? AppSpazi.paginaDesktop : AppSpazi.paginaTelefono;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              key: const Key('impostazioni-lista'),
              padding: EdgeInsets.fromLTRB(
                orizzontale,
                orizzontale,
                orizzontale,
                orizzontale,
              ),
              children: [
                _CardProfilo(profilo: profilo),
                const SizedBox(height: AppSpazi.gapCard),
                _CardAzienda(
                  aziende: aziende,
                  aziendaAttivaId: aziendaAttivaId,
                  onCambiaAzienda: onCambiaAzienda,
                ),
                const SizedBox(height: AppSpazi.gapCard),
                _CardSezione(
                  chiave: const Key('impostazioni-app'),
                  titolo: 'Applicazione',
                  icona: Icons.install_mobile_outlined,
                  senzaPadding: true,
                  figli: [
                    _VoceAccesso(
                      chiave: const Key('impostazioni-voce-intro'),
                      icona: Icons.install_mobile_outlined,
                      titolo: 'Come installare l\'app',
                      sottotitolo: 'Aggiungi Closer al tuo dispositivo',
                      onTap: onApriIntro ?? () {},
                    ),
                  ],
                ),
                const SizedBox(height: AppSpazi.gapCard),
                _CardPersonale(onVoce: onVoce),
                if (admin) ...[
                  const SizedBox(height: AppSpazi.gapCard),
                  _CardAccessi(
                    superAdmin: profilo?.superAdmin == true,
                    onVoce: onVoce,
                  ),
                ],
                const SizedBox(height: AppSpazi.l),
                OutlinedButton.icon(
                  key: const Key('impostazioni-logout'),
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Esci dall\'account'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errore,
                    side: const BorderSide(color: AppColors.errore),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Card riepilogativa del profilo con avatar, nome, email e ruolo.
class _CardProfilo extends StatelessWidget {
  const _CardProfilo({required this.profilo});

  final UserProfile? profilo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final email = profilo?.email?.trim() ?? '';

    return Card(
      key: const Key('impostazioni-profilo'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: tema.colorScheme.primaryContainer,
              foregroundColor: tema.colorScheme.onPrimaryContainer,
              child: Text(
                inizialiProfilo(profilo),
                style: tema.textTheme.titleMedium?.copyWith(
                  color: tema.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpazi.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nomeVisualizzatoProfilo(profilo),
                    key: const Key('impostazioni-nome'),
                    style: tema.textTheme.titleMedium,
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: AppSpazi.xxs),
                    Text(
                      email,
                      key: const Key('impostazioni-email'),
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpazi.xs),
                  Wrap(
                    spacing: AppSpazi.xs,
                    runSpacing: AppSpazi.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        key: const Key('impostazioni-ruolo'),
                        label: Text(ruoloVisualizzatoProfilo(profilo)),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (profilo?.superAdmin == true)
                        Chip(
                          key: const Key('impostazioni-super-admin-badge'),
                          label: const Text('Super admin'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              AppColors.superAdmin.withValues(alpha: 0.12),
                          labelStyle: const TextStyle(
                            color: AppColors.superAdmin,
                            fontWeight: FontWeight.w600,
                          ),
                          side: const BorderSide(color: AppColors.superAdmin),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card dell'azienda attiva con tendina quando l'utente ne ha più di una.
class _CardAzienda extends StatelessWidget {
  const _CardAzienda({
    required this.aziende,
    required this.aziendaAttivaId,
    required this.onCambiaAzienda,
  });

  final List<Azienda> aziende;
  final String? aziendaAttivaId;
  final void Function(String) onCambiaAzienda;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final idValido = aziende.any((azienda) => azienda.id == aziendaAttivaId)
        ? aziendaAttivaId
        : null;

    return _CardSezione(
      chiave: const Key('impostazioni-azienda'),
      titolo: 'Azienda attiva',
      icona: Icons.business_outlined,
      figli: [
        if (aziende.isEmpty)
          Text(
            'Nessuna azienda associata al tuo profilo.',
            key: const Key('impostazioni-azienda-vuota'),
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          )
        else if (aziende.length == 1)
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 20),
              const SizedBox(width: AppSpazi.xs),
              Expanded(
                child: Text(
                  aziende.first.nome,
                  key: const Key('impostazioni-azienda-nome'),
                  style: tema.textTheme.bodyLarge,
                ),
              ),
            ],
          )
        else
          DropdownButtonFormField<String>(
            key: const Key('impostazioni-azienda-tendina'),
            initialValue: idValido ?? aziende.first.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Scegli azienda'),
            items: [
              for (final azienda in aziende)
                DropdownMenuItem(
                  value: azienda.id,
                  child: Text(
                    azienda.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              if (id != null) onCambiaAzienda(id);
            },
          ),
      ],
    );
  }
}

/// Impostazioni personali visibili a tutti i ruoli, anche al commerciale.
class _CardPersonale extends StatelessWidget {
  const _CardPersonale({required this.onVoce});

  final void Function(String rotta) onVoce;

  @override
  Widget build(BuildContext context) {
    return _CardSezione(
      chiave: const Key('impostazioni-personali'),
      titolo: 'Personale',
      icona: Icons.person_outline,
      senzaPadding: true,
      figli: [
        _VoceAccesso(
          chiave: const Key('impostazioni-voce-notifiche'),
          icona: Icons.notifications_outlined,
          titolo: 'Notifiche',
          sottotitolo: 'Canali, push, orari di silenzio e anteprima',
          onTap: () => onVoce('/impostazioni/notifiche'),
        ),
        const Divider(height: 1),
        _VoceAccesso(
          chiave: const Key('impostazioni-voce-condivisioni'),
          icona: Icons.share_outlined,
          titolo: 'Condivisione calendario',
          sottotitolo: 'Condividi i tuoi appuntamenti con i colleghi',
          onTap: () => onVoce('/impostazioni/condivisioni-calendario'),
        ),
      ],
    );
  }
}

/// Card con le voci di gestione: agenda, integrazioni, utenti, ruoli, licenze
/// e super admin.
class _CardAccessi extends StatelessWidget {
  const _CardAccessi({required this.superAdmin, required this.onVoce});

  final bool superAdmin;
  final void Function(String rotta) onVoce;

  @override
  Widget build(BuildContext context) {
    final voci = <Widget>[
      _VoceAccesso(
        chiave: const Key('impostazioni-voce-agenda'),
        icona: Icons.event_available_outlined,
        titolo: 'Calendario e agenda',
        sottotitolo: 'Orari di invio, template e slot prenotabili',
        onTap: () => onVoce('/impostazioni/agenda'),
      ),
      _VoceAccesso(
        chiave: const Key('impostazioni-voce-integrazioni'),
        icona: Icons.link,
        titolo: 'Calendario e integrazioni',
        sottotitolo: 'Google, Microsoft, email e WhatsApp',
        onTap: () => onVoce('/impostazioni/integrazioni'),
      ),
      _VoceAccesso(
        chiave: const Key('impostazioni-voce-utenti'),
        icona: Icons.people_outline,
        titolo: 'Utenti',
        sottotitolo: 'Invita e gestisci le persone dell\'azienda',
        onTap: () => onVoce('/impostazioni/utenti'),
      ),
      _VoceAccesso(
        chiave: const Key('impostazioni-voce-ruoli'),
        icona: Icons.manage_accounts_outlined,
        titolo: 'Ruoli e permessi',
        sottotitolo: 'Decidi cosa può fare ogni ruolo',
        onTap: () => onVoce('/impostazioni/ruoli'),
      ),
      _VoceAccesso(
        chiave: const Key('impostazioni-voce-licenze'),
        icona: Icons.workspace_premium_outlined,
        titolo: 'Licenze',
        sottotitolo: 'Piano attivo e limiti dell\'azienda',
        onTap: () => onVoce('/impostazioni/licenze'),
      ),
      if (superAdmin)
        _VoceAccesso(
          chiave: const Key('impostazioni-voce-importa-bandi'),
          icona: Icons.upload_file_outlined,
          titolo: 'Importa bandi',
          sottotitolo: 'Aggiorna i bandi da file JSON o URL',
          onTap: () => onVoce('/bandi/importa'),
        ),
      if (superAdmin)
        _VoceAccesso(
          chiave: const Key('impostazioni-voce-super-admin'),
          icona: Icons.admin_panel_settings_outlined,
          titolo: 'Super Admin',
          sottotitolo: 'Amministra tutte le aziende',
          colore: AppColors.superAdmin,
          onTap: () => onVoce('/superadmin'),
        ),
    ];

    return _CardSezione(
      chiave: const Key('impostazioni-accessi'),
      titolo: 'Accessi',
      icona: Icons.lock_outline,
      senzaPadding: true,
      figli: [
        for (var indice = 0; indice < voci.length; indice++) ...[
          if (indice > 0) const Divider(height: 1),
          voci[indice],
        ],
      ],
    );
  }
}

/// Voce di elenco della card accessi.
class _VoceAccesso extends StatelessWidget {
  const _VoceAccesso({
    required this.chiave,
    required this.icona,
    required this.titolo,
    required this.sottotitolo,
    required this.onTap,
    this.colore,
  });

  final Key chiave;
  final IconData icona;
  final String titolo;
  final String sottotitolo;
  final VoidCallback onTap;
  final Color? colore;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: chiave,
      leading: Icon(icona, color: colore),
      title: Text(titolo, style: TextStyle(color: colore)),
      subtitle: Text(sottotitolo),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Card di sezione con intestazione (icona + titolo) e contenuto.
class _CardSezione extends StatelessWidget {
  const _CardSezione({
    required this.chiave,
    required this.titolo,
    required this.icona,
    required this.figli,
    this.senzaPadding = false,
  });

  final Key chiave;
  final String titolo;
  final IconData icona;
  final List<Widget> figli;
  final bool senzaPadding;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final intestazione = Padding(
      padding: senzaPadding
          ? const EdgeInsets.fromLTRB(
              AppSpazi.internoCard,
              AppSpazi.internoCard,
              AppSpazi.internoCard,
              AppSpazi.xs,
            )
          : EdgeInsets.zero,
      child: Row(
        children: [
          Icon(icona, size: 20, color: tema.colorScheme.primary),
          const SizedBox(width: AppSpazi.xs),
          Expanded(
            child: Text(titolo, style: tema.textTheme.titleSmall),
          ),
        ],
      ),
    );

    final contenuto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        intestazione,
        if (!senzaPadding) const SizedBox(height: AppSpazi.s),
        ...figli,
      ],
    );

    return Card(
      key: chiave,
      child: senzaPadding
          ? contenuto
          : Padding(
              padding: const EdgeInsets.all(AppSpazi.internoCard),
              child: contenuto,
            ),
    );
  }
}
