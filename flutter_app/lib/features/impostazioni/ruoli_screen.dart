import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/ruolo.dart';
import '../../state/azienda_providers.dart';
import 'ruolo_form_screen.dart';

// ---------------------------------------------------------------------------
// Funzioni pure: etichette e riepiloghi verificabili senza Firebase né UI
// ---------------------------------------------------------------------------

/// Nomi italiani delle aree di permesso della vecchia app.
const Map<String, String> etichetteAreePermesso = {
  'dashboard': 'Dashboard',
  'listino': 'Listino',
  'gestione_prodotti': 'Gestione prodotti',
  'preventivi_propri': 'Preventivi propri',
  'preventivi_tutti': 'Preventivi di tutti',
  'approva_preventivi': 'Approvazione preventivi',
  'clienti': 'Clienti',
  'bandi': 'Bandi',
  'gestione_categorie': 'Gestione categorie',
  'gestione_utenti': 'Gestione utenti',
  'gestione_ruoli': 'Gestione ruoli',
  'impostazioni': 'Impostazioni',
};

/// Etichetta italiana dell'area di permesso; per le chiavi sconosciute
/// rende leggibile la chiave (`note_interne` → "Note interne").
String etichettaAreaPermesso(String chiave) {
  final area = chiave.trim();
  if (area.isEmpty) return 'Area';
  final nota = etichetteAreePermesso[area];
  if (nota != null) return nota;
  final parole = area.split('_').where((parola) => parola.isNotEmpty).toList();
  if (parole.isEmpty) return 'Area';
  return _maiuscola(parole.join(' '));
}

/// Etichetta del livello di permesso (`lettura`, `scrittura`, `entrambi`).
String etichettaLivelloPermesso(dynamic valore) {
  final testo = (valore?.toString() ?? '').trim().toLowerCase();
  switch (testo) {
    case 'lettura':
      return 'Sola lettura';
    case 'scrittura':
      return 'Sola scrittura';
    case 'entrambi':
      return 'Lettura e scrittura';
    case '':
      return 'Nessuno';
    default:
      return _maiuscola(testo);
  }
}

/// Righe "Area: livello" dei permessi, ordinate per etichetta dell'area.
List<String> etichettePermessi(Map<String, dynamic> permessi) {
  final chiavi = permessi.keys.where((chiave) => chiave.trim().isNotEmpty).toList()
    ..sort(
      (a, b) => etichettaAreaPermesso(a)
          .toLowerCase()
          .compareTo(etichettaAreaPermesso(b).toLowerCase()),
    );
  return [
    for (final chiave in chiavi)
      '${etichettaAreaPermesso(chiave)}: ${etichettaLivelloPermesso(permessi[chiave])}',
  ];
}

/// Riepilogo breve dei permessi di un ruolo, per la lista.
///
/// Es. "9 aree in lettura e scrittura · 3 in sola lettura"; senza permessi
/// "Nessun permesso configurato".
String riepilogoPermessi(Map<String, dynamic> permessi) {
  if (permessi.isEmpty) return 'Nessun permesso configurato';

  var entrambi = 0;
  var lettura = 0;
  var scrittura = 0;
  var altri = 0;
  for (final valore in permessi.values) {
    switch ((valore?.toString() ?? '').trim().toLowerCase()) {
      case 'entrambi':
        entrambi++;
      case 'lettura':
        lettura++;
      case 'scrittura':
        scrittura++;
      default:
        altri++;
    }
  }

  final parti = <String>[
    if (entrambi > 0) '$entrambi ${entrambi == 1 ? 'area' : 'aree'} '
        'in lettura e scrittura',
    if (lettura > 0) '$lettura in sola lettura',
    if (scrittura > 0) '$scrittura in sola scrittura',
    if (altri > 0) '$altri senza livello',
  ];
  return parti.join(' · ');
}

/// Nome del ruolo, con fallback quando il campo è assente o vuoto.
String nomeVisualizzatoRuolo(Ruolo ruolo) {
  final nome = ruolo.nome.trim();
  return nome.isEmpty ? 'Senza nome' : nome;
}

/// Descrizione del ruolo, con fallback quando il campo è assente.
String descrizioneRuolo(Ruolo ruolo) {
  final descrizione = ruolo.descrizione?.trim() ?? '';
  return descrizione.isEmpty ? 'Nessuna descrizione' : descrizione;
}

/// Sconto massimo in formato italiano (`20%`), `Nessuno sconto` se zero.
String etichettaScontoMassimo(int scontoMax) {
  if (scontoMax <= 0) return 'Nessuno sconto';
  final numero = NumberFormat.decimalPattern('it_IT').format(scontoMax);
  return 'Fino al $numero%';
}

/// Messaggio in italiano per gli errori di caricamento dei ruoli.
String messaggioErroreRuoli(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per vedere i ruoli. '
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

/// Schermata Ruoli e permessi dell'azienda attiva.
///
/// Mostra nome, descrizione, sconto massimo e permessi di ogni ruolo e
/// permette di crearne, modificarne o eliminarne uno; i ruoli di sistema
/// (`sistema`) restano presenti e non si eliminano.
class RuoliScreen extends ConsumerStatefulWidget {
  const RuoliScreen({super.key});

  @override
  ConsumerState<RuoliScreen> createState() => _RuoliScreenState();
}

class _RuoliScreenState extends ConsumerState<RuoliScreen> {
  List<Ruolo> _ruoli = const [];
  bool _caricamento = true;
  Object? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  /// Passa l'azienda attiva al servizio e carica i ruoli.
  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final ruoli = await servizio.getRuoli();
      if (!mounted) return;
      setState(() {
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

  /// Apre il form del ruolo (nuovo se [ruolo] è `null`) e ricarica se salvato.
  Future<void> _apriRuolo({Ruolo? ruolo}) async {
    final salvato = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RuoloFormScreen(ruolo: ruolo)),
    );
    if (salvato != true || !mounted) return;
    await _carica();
  }

  /// Chiede conferma ed elimina il ruolo; i ruoli di sistema non si eliminano.
  Future<void> _eliminaRuolo(Ruolo ruolo) async {
    if (ruolo.sistema) return;
    if (ref.read(aziendaAttivaProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nessuna azienda attiva. Seleziona un\'azienda e riprova.',
          ),
        ),
      );
      return;
    }

    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('dialog-elimina-ruolo'),
        title: const Text('Eliminare il ruolo?'),
        content: Text(
          'Il ruolo "${nomeVisualizzatoRuolo(ruolo)}" verrà eliminato '
          'definitivamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const Key('conferma-elimina-ruolo'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (conferma != true || !mounted) return;

    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      await servizio.eliminaRuolo(ruolo.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruolo eliminato')),
      );
      await _carica();
    } catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messaggioErroreRuoli(errore))),
      );
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
        key: Key('ruoli-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (_errore != null) {
      return StatoCentrato(
        icona: Icons.cloud_off_outlined,
        titolo: 'Ruoli non disponibili',
        sottotitolo: messaggioErroreRuoli(_errore!),
        azione: OutlinedButton.icon(
          key: const Key('ruoli-riprova'),
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
                'Ruoli e permessi',
                key: const Key('ruoli-titolo'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: AppSpazi.s),
            FilledButton.icon(
              key: const Key('ruoli-nuovo'),
              onPressed: () => _apriRuolo(),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo ruolo'),
            ),
          ],
        ),
        const SizedBox(height: AppSpazi.s),
        Expanded(
          child: CorpoRuoli(
            ruoli: _ruoli,
            largo: largo,
            onModifica: (ruolo) => _apriRuolo(ruolo: ruolo),
            onElimina: _eliminaRuolo,
            onNuovo: () => _apriRuolo(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Corpo puro (testabile senza provider)
// ---------------------------------------------------------------------------

/// Elenco ruoli senza provider, usato anche dai widget test.
class CorpoRuoli extends StatelessWidget {
  const CorpoRuoli({
    super.key,
    required this.ruoli,
    this.largo,
    this.onModifica,
    this.onElimina,
    this.onNuovo,
  });

  final List<Ruolo> ruoli;

  /// Forza il layout largo (tabella); se `null` decide la larghezza.
  final bool? largo;

  /// Azioni facoltative: senza callback l'elenco resta di sola consultazione.
  final ValueChanged<Ruolo>? onModifica;
  final ValueChanged<Ruolo>? onElimina;
  final VoidCallback? onNuovo;

  bool get _conAzioni => onModifica != null || onElimina != null;

  @override
  Widget build(BuildContext context) {
    if (ruoli.isEmpty) {
      return StatoCentrato(
        key: const Key('ruoli-vuoto'),
        icona: Icons.manage_accounts_outlined,
        titolo: 'Nessun ruolo',
        sottotitolo: onNuovo == null
            ? 'I ruoli di questa azienda non sono ancora configurati.'
            : 'I ruoli di questa azienda non sono ancora configurati. '
                'Creane uno con il pulsante "Nuovo ruolo".',
        azione: onNuovo == null
            ? null
            : FilledButton.icon(
                key: const Key('ruoli-nuovo-vuoto'),
                onPressed: onNuovo,
                icon: const Icon(Icons.add),
                label: const Text('Nuovo ruolo'),
              ),
      );
    }

    final body = largo != null
        ? _lista(largo!)
        : LayoutBuilder(
            builder: (context, constraints) =>
                _lista(constraints.maxWidth >= AppBreakpoints.telefono),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NotaRuoli(),
        const SizedBox(height: AppSpazi.s),
        Expanded(child: body),
      ],
    );
  }

  Widget _lista(bool largo) {
    if (!largo) {
      return ListView.separated(
        key: const Key('lista-ruoli'),
        padding: const EdgeInsets.only(bottom: AppSpazi.l),
        itemCount: ruoli.length,
        separatorBuilder: (context, indice) =>
            const SizedBox(height: AppSpazi.xs),
        itemBuilder: (context, indice) => _CardRuolo(
          ruolo: ruoli[indice],
          onModifica: onModifica,
          onElimina: onElimina,
        ),
      );
    }

    return SingleChildScrollView(
      key: const Key('tabella-ruoli-scroll'),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            key: const Key('tabella-ruoli'),
            showCheckboxColumn: false,
            columns: [
              const DataColumn(label: Text('Ruolo')),
              const DataColumn(label: Text('Descrizione')),
              const DataColumn(label: Text('Sconto massimo')),
              const DataColumn(label: Text('Permessi')),
              if (_conAzioni) const DataColumn(label: Text('Azioni')),
            ],
            rows: [
              for (final ruolo in ruoli)
                DataRow(
                  key: ValueKey('ruolo-${ruolo.id}'),
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(nomeVisualizzatoRuolo(ruolo)),
                          if (ruolo.sistema) ...[
                            const SizedBox(width: AppSpazi.xs),
                            _BadgeSistema(),
                          ],
                        ],
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Text(descrizioneRuolo(ruolo)),
                      ),
                    ),
                    DataCell(Text(etichettaScontoMassimo(ruolo.scontoMax))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpazi.xs,
                          ),
                          child: _PermessiRuolo(ruolo: ruolo),
                        ),
                      ),
                    ),
                    if (_conAzioni)
                      DataCell(
                        _MenuRuolo(
                          key: ValueKey('ruolo-menu-${ruolo.id}'),
                          sistema: ruolo.sistema,
                          onModifica: onModifica == null
                              ? null
                              : () => onModifica!(ruolo),
                          onElimina: onElimina == null
                              ? null
                              : () => onElimina!(ruolo),
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

/// Nota che spiega a cosa serve la schermata.
class _NotaRuoli extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 16,
          color: tema.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpazi.xs),
        Expanded(
          child: Text(
            'Gestisci ruoli e permessi dell\'azienda.',
            key: const Key('ruoli-sola-lettura'),
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Menu a tre puntini del ruolo: "Elimina" non è disponibile per i ruoli di
/// sistema.
class _MenuRuolo extends StatelessWidget {
  const _MenuRuolo({
    super.key,
    required this.sistema,
    this.onModifica,
    this.onElimina,
  });

  final bool sistema;
  final VoidCallback? onModifica;
  final VoidCallback? onElimina;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Azioni',
      onSelected: (azione) {
        if (azione == 'modifica') onModifica?.call();
        if (azione == 'elimina') onElimina?.call();
      },
      itemBuilder: (context) => [
        if (onModifica != null)
          const PopupMenuItem(value: 'modifica', child: Text('Modifica')),
        if (onElimina != null)
          PopupMenuItem(
            value: 'elimina',
            enabled: !sistema,
            child: const Text('Elimina'),
          ),
      ],
    );
  }
}

/// Card di un ruolo (telefono): nome, descrizione, sconto e permessi.
class _CardRuolo extends StatelessWidget {
  const _CardRuolo({
    required this.ruolo,
    this.onModifica,
    this.onElimina,
  });

  final Ruolo ruolo;
  final ValueChanged<Ruolo>? onModifica;
  final ValueChanged<Ruolo>? onElimina;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      key: ValueKey('ruolo-${ruolo.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    nomeVisualizzatoRuolo(ruolo),
                    style: tema.textTheme.titleSmall,
                  ),
                ),
                if (ruolo.sistema) _BadgeSistema(),
                if (onModifica != null || onElimina != null)
                  _MenuRuolo(
                    key: ValueKey('ruolo-menu-${ruolo.id}'),
                    sistema: ruolo.sistema,
                    onModifica:
                        onModifica == null ? null : () => onModifica!(ruolo),
                    onElimina:
                        onElimina == null ? null : () => onElimina!(ruolo),
                  ),
              ],
            ),
            const SizedBox(height: AppSpazi.xxs),
            Text(
              descrizioneRuolo(ruolo),
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpazi.s),
            Row(
              children: [
                const Icon(Icons.percent, size: 18),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  child: Text(
                    'Sconto massimo: ${etichettaScontoMassimo(ruolo.scontoMax)}',
                    style: tema.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpazi.s),
            Text(
              riepilogoPermessi(ruolo.permessi),
              key: ValueKey('ruolo-riepilogo-${ruolo.id}'),
              style: tema.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpazi.xs),
            _PermessiRuolo(ruolo: ruolo),
          ],
        ),
      ),
    );
  }
}

/// Permessi del ruolo come chip "Area: livello".
class _PermessiRuolo extends StatelessWidget {
  const _PermessiRuolo({required this.ruolo});

  final Ruolo ruolo;

  @override
  Widget build(BuildContext context) {
    final voci = etichettePermessi(ruolo.permessi);
    if (voci.isEmpty) {
      return Text(
        'Nessun permesso configurato',
        key: ValueKey('ruolo-permessi-vuoti-${ruolo.id}'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }

    return Wrap(
      key: ValueKey('ruolo-permessi-${ruolo.id}'),
      spacing: AppSpazi.xs,
      runSpacing: AppSpazi.xxs,
      children: [
        for (final voce in voci)
          Chip(
            label: Text(voce),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}

/// Etichetta dei ruoli di sistema (non eliminabili).
class _BadgeSistema extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Chip(
      label: const Text('Di sistema'),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
