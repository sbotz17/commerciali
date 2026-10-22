import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/ruolo.dart';
import '../../data/models/user_profile.dart';
import '../../state/azienda_providers.dart';
import 'impostazioni_screen.dart' show inizialiProfilo, nomeVisualizzatoProfilo;
import 'nuovo_utente_screen.dart';

// ---------------------------------------------------------------------------
// Funzioni pure: testi e messaggi verificabili senza Firebase né UI
// ---------------------------------------------------------------------------

/// Etichetta leggibile del ruolo salvato sulla membership.
///
/// Cerca il ruolo configurato per chiave (es. `admin` → "Amministratore"),
/// poi per nome; senza corrispondenza rende leggibile la chiave stessa.
String etichettaRuolo(String? chiave, List<Ruolo> ruoli) {
  final valore = chiave?.trim() ?? '';
  if (valore.isEmpty) return 'Ruolo non assegnato';

  for (final ruolo in ruoli) {
    if ((ruolo.chiave?.trim() ?? '') == valore) {
      final nome = ruolo.nome.trim();
      return nome.isEmpty ? _maiuscola(valore) : nome;
    }
  }
  for (final ruolo in ruoli) {
    if (ruolo.nome.trim().toLowerCase() == valore.toLowerCase()) {
      return ruolo.nome.trim();
    }
  }
  return _etichettaChiaveNota(valore);
}

/// Etichette italiane per le chiavi storiche, usate quando l'azienda non ha
/// ancora ruoli configurati in `ruoli`.
String _etichettaChiaveNota(String chiave) {
  switch (chiave.toLowerCase()) {
    case 'admin':
    case 'amministratore':
      return 'Amministratore';
    case 'commerciale':
      return 'Commerciale';
    case 'agente':
      return 'Agente';
    case 'viewer':
    case 'lettore':
      return 'Sola lettura';
    case 'super_admin':
      return 'Super amministratore';
    default:
      return _maiuscola(chiave);
  }
}

/// Chiavi dei ruoli selezionabili, senza duplicati e nell'ordine ricevuto.
List<String> chiaviRuoloSelezionabili(List<Ruolo> ruoli) {
  final chiavi = <String>{};
  for (final ruolo in ruoli) {
    final chiave = ruolo.chiave?.trim() ?? '';
    if (chiave.isNotEmpty) chiavi.add(chiave);
  }
  return chiavi.toList();
}

/// Chiave del ruolo corrente se è fra quelli selezionabili, altrimenti `null`.
///
/// Evita che la tendina riceva un valore che non compare fra le voci.
String? chiaveRuoloCorrente(String? chiave, List<Ruolo> ruoli) {
  final valore = chiave?.trim() ?? '';
  if (valore.isEmpty) return null;
  return chiaviRuoloSelezionabili(ruoli).contains(valore) ? valore : null;
}

/// Email da mostrare per l'utente, con fallback quando il campo è assente.
String emailVisualizzataUtente(UserProfile utente) {
  final email = utente.email?.trim() ?? '';
  return email.isEmpty ? 'Email non disponibile' : email;
}

/// Messaggio in italiano per gli errori di caricamento e modifica utenti.
String messaggioErroreUtenti(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per gestire gli utenti. '
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

String _maiuscola(String valore) {
  if (valore.isEmpty) return valore;
  return '${valore[0].toUpperCase()}${valore.substring(1)}';
}

// ---------------------------------------------------------------------------
// Schermata con provider
// ---------------------------------------------------------------------------

/// Schermata Utenti: membri dell'azienda attiva, creazione, cambio ruolo e
/// rimozione. La creazione account usa una sessione Firebase secondaria per
/// non perdere la sessione dell'amministratore.
class UtentiScreen extends ConsumerStatefulWidget {
  const UtentiScreen({super.key});

  @override
  ConsumerState<UtentiScreen> createState() => _UtentiScreenState();
}

class _UtentiScreenState extends ConsumerState<UtentiScreen> {
  List<UserProfile> _utenti = const [];
  List<Ruolo> _ruoli = const [];
  bool _caricamento = true;
  Object? _errore;

  /// Uid del membro con un'operazione in corso (tendina e rimozione spente).
  String? _inCorso;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  /// Passa l'azienda attiva al servizio e carica utenti e ruoli in parallelo.
  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final utentiFuturi = servizio.getUtenti();
      final ruoliFuturi = servizio.getRuoli();
      final utenti = await utentiFuturi;
      final ruoli = await ruoliFuturi;
      if (!mounted) return;
      setState(() {
        _utenti = utenti;
        _ruoli = ruoli;
        _caricamento = false;
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _errore = errore;
        _caricamento = false;
      });
    }
  }

  /// Apre il form di creazione e ricarica l'elenco se l'utente è stato creato.
  Future<void> _apriNuovoUtente() async {
    final creato = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => NuovoUtenteScreen(ruoli: _ruoli),
      ),
    );
    if (creato == true && mounted) await _carica();
  }

  /// Chiede conferma e aggiorna il ruolo del membro.
  Future<void> _cambiaRuolo(UserProfile utente, String nuovoRuolo) async {
    final etichetta = etichettaRuolo(nuovoRuolo, _ruoli);
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('dialog-cambia-ruolo'),
        title: const Text('Cambiare il ruolo?'),
        content: Text(
          '${nomeVisualizzatoProfilo(utente)} avrà il ruolo "$etichetta".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const Key('conferma-cambia-ruolo'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    if (conferma != true || !mounted) return;

    setState(() => _inCorso = utente.uid);
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      await servizio.aggiornaRuoloUtente(utente.uid, nuovoRuolo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ruolo aggiornato: $etichetta')),
      );
      await _carica();
    } catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messaggioErroreUtenti(errore))),
      );
    } finally {
      if (mounted) setState(() => _inCorso = null);
    }
  }

  /// Chiede conferma e rimuove il membro dall'azienda attiva.
  Future<void> _rimuovi(UserProfile utente) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('dialog-rimuovi-membro'),
        title: const Text('Rimuovere il membro?'),
        content: Text(
          '${nomeVisualizzatoProfilo(utente)} non farà più parte '
          'dell\'azienda e non vedrà più i suoi dati.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const Key('conferma-rimuovi-membro'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (conferma != true || !mounted) return;

    setState(() => _inCorso = utente.uid);
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      await servizio.eliminaMembro(utente.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membro rimosso dall\'azienda')),
      );
      await _carica();
    } catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messaggioErroreUtenti(errore))),
      );
    } finally {
      if (mounted) setState(() => _inCorso = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(aziendaAttivaProvider, (precedente, attuale) {
      if (precedente != attuale) _carica();
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final largo = constraints.maxWidth >= AppBreakpoints.telefono;
        final orizzontale =
            largo ? AppSpazi.paginaDesktop : AppSpazi.paginaTelefono;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            orizzontale,
            orizzontale,
            orizzontale,
            orizzontale,
          ),
          child: _contenuto(largo),
        );
      },
    );
  }

  Widget _contenuto(bool largo) {
    if (_caricamento) {
      return const Center(
        key: Key('utenti-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (_errore != null) {
      return StatoCentrato(
        icona: Icons.cloud_off_outlined,
        titolo: 'Utenti non disponibili',
        sottotitolo: messaggioErroreUtenti(_errore!),
        azione: OutlinedButton.icon(
          key: const Key('utenti-riprova'),
          onPressed: _carica,
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Utenti',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: AppSpazi.s),
            FilledButton.icon(
              key: const Key('utenti-nuovo'),
              onPressed: _apriNuovoUtente,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nuovo utente'),
            ),
          ],
        ),
        const SizedBox(height: AppSpazi.s),
        Expanded(
          child: CorpoUtenti(
            utenti: _utenti,
            ruoli: _ruoli,
            inCorso: _inCorso,
            onCambiaRuolo: _cambiaRuolo,
            onRimuovi: _rimuovi,
            largo: largo,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Corpo puro (testabile senza provider)
// ---------------------------------------------------------------------------

/// Elenco membri senza provider, usato anche dai widget test.
class CorpoUtenti extends StatelessWidget {
  const CorpoUtenti({
    super.key,
    required this.utenti,
    required this.ruoli,
    required this.onCambiaRuolo,
    required this.onRimuovi,
    this.inCorso,
    this.largo,
  });

  final List<UserProfile> utenti;
  final List<Ruolo> ruoli;
  final void Function(UserProfile utente, String ruolo) onCambiaRuolo;
  final void Function(UserProfile utente) onRimuovi;

  /// Uid del membro con un'operazione in corso.
  final String? inCorso;

  /// Forza il layout largo (tabella); se `null` decide la larghezza.
  final bool? largo;

  @override
  Widget build(BuildContext context) {
    if (utenti.isEmpty) {
      return const StatoCentrato(
        key: Key('utenti-vuoto'),
        icona: Icons.people_outline,
        titolo: 'Nessun utente',
        sottotitolo: 'Non ci sono persone collegate a questa azienda.',
      );
    }

    if (largo != null) return _lista(largo!);

    return LayoutBuilder(
      builder: (context, constraints) =>
          _lista(constraints.maxWidth >= AppBreakpoints.telefono),
    );
  }

  Widget _lista(bool largo) {
    if (!largo) {
      return ListView.separated(
        key: const Key('lista-utenti'),
        padding: const EdgeInsets.only(bottom: AppSpazi.l),
        itemCount: utenti.length,
        separatorBuilder: (context, indice) =>
            const SizedBox(height: AppSpazi.xs),
        itemBuilder: (context, indice) {
          final utente = utenti[indice];
          return _CardUtente(
            utente: utente,
            ruoli: ruoli,
            inCorso: inCorso == utente.uid,
            onCambiaRuolo: (ruolo) => onCambiaRuolo(utente, ruolo),
            onRimuovi: () => onRimuovi(utente),
          );
        },
      );
    }

    return SingleChildScrollView(
      key: const Key('tabella-utenti-scroll'),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            key: const Key('tabella-utenti'),
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('Nome')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Ruolo')),
              DataColumn(label: Text('')),
            ],
            rows: [
              for (final utente in utenti)
                DataRow(
                  key: ValueKey('utente-${utente.uid}'),
                  cells: [
                    DataCell(Text(nomeVisualizzatoProfilo(utente))),
                    DataCell(Text(emailVisualizzataUtente(utente))),
                    DataCell(
                      SizedBox(
                        width: 240,
                        child: _TendinaRuolo(
                          utente: utente,
                          ruoli: ruoli,
                          disabilitata: inCorso == utente.uid,
                          onCambia: (ruolo) => onCambiaRuolo(utente, ruolo),
                        ),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        key: ValueKey('utente-rimuovi-${utente.uid}'),
                        tooltip: 'Rimuovi membro',
                        onPressed: inCorso == utente.uid
                            ? null
                            : () => onRimuovi(utente),
                        icon: const Icon(Icons.person_remove_outlined),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card di un membro (telefono): nome, email, ruolo e rimozione.
class _CardUtente extends StatelessWidget {
  const _CardUtente({
    required this.utente,
    required this.ruoli,
    required this.inCorso,
    required this.onCambiaRuolo,
    required this.onRimuovi,
  });

  final UserProfile utente;
  final List<Ruolo> ruoli;
  final bool inCorso;
  final void Function(String ruolo) onCambiaRuolo;
  final VoidCallback onRimuovi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      key: ValueKey('utente-${utente.uid}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: tema.colorScheme.primaryContainer,
                  foregroundColor: tema.colorScheme.onPrimaryContainer,
                  child: Text(
                    inizialiProfilo(utente),
                    style: tema.textTheme.labelLarge?.copyWith(
                      color: tema.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpazi.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomeVisualizzatoProfilo(utente),
                        style: tema.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpazi.xxs),
                      Text(
                        emailVisualizzataUtente(utente),
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('utente-rimuovi-${utente.uid}'),
                  tooltip: 'Rimuovi membro',
                  onPressed: inCorso ? null : onRimuovi,
                  icon: const Icon(Icons.person_remove_outlined),
                ),
              ],
            ),
            const SizedBox(height: AppSpazi.s),
            _TendinaRuolo(
              utente: utente,
              ruoli: ruoli,
              disabilitata: inCorso,
              onCambia: onCambiaRuolo,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tendina del ruolo, controllata dal ruolo salvato sulla membership.
///
/// Se i ruoli non sono configurati mostra il solo ruolo corrente in chiaro:
/// nessuna scrittura possibile senza voci su cui scegliere.
class _TendinaRuolo extends StatelessWidget {
  const _TendinaRuolo({
    required this.utente,
    required this.ruoli,
    required this.disabilitata,
    required this.onCambia,
  });

  final UserProfile utente;
  final List<Ruolo> ruoli;
  final bool disabilitata;
  final void Function(String ruolo) onCambia;

  @override
  Widget build(BuildContext context) {
    final disponibili = chiaviRuoloSelezionabili(ruoli);
    final corrente = chiaveRuoloCorrente(utente.ruolo, ruoli);

    if (disponibili.isEmpty) {
      return Row(
        key: ValueKey('utente-ruolo-testo-${utente.uid}'),
        children: [
          const Icon(Icons.badge_outlined, size: 18),
          const SizedBox(width: AppSpazi.xs),
          Expanded(child: Text(etichettaRuolo(utente.ruolo, ruoli))),
        ],
      );
    }

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Ruolo',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: ValueKey('utente-ruolo-${utente.uid}'),
          value: corrente,
          isExpanded: true,
          isDense: true,
          hint: Text(etichettaRuolo(utente.ruolo, ruoli)),
          items: [
            for (final chiave in disponibili)
              DropdownMenuItem(
                value: chiave,
                child: Text(
                  etichettaRuolo(chiave, ruoli),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: disabilitata
              ? null
              : (chiave) {
                  if (chiave == null || chiave == corrente) return;
                  onCambia(chiave);
                },
        ),
      ),
    );
  }
}
