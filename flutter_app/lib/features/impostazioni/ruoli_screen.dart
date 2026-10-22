import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/ruolo.dart';
import '../../state/azienda_providers.dart';

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
/// Per ora è di sola lettura: mostra nome, descrizione, sconto massimo e
/// permessi di ogni ruolo. La modifica arriverà con un task successivo.
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

    return CorpoRuoli(ruoli: _ruoli, largo: largo);
  }
}

// ---------------------------------------------------------------------------
// Corpo puro (testabile senza provider)
// ---------------------------------------------------------------------------

/// Elenco ruoli senza provider, usato anche dai widget test.
class CorpoRuoli extends StatelessWidget {
  const CorpoRuoli({super.key, required this.ruoli, this.largo});

  final List<Ruolo> ruoli;

  /// Forza il layout largo (tabella); se `null` decide la larghezza.
  final bool? largo;

  @override
  Widget build(BuildContext context) {
    if (ruoli.isEmpty) {
      return const StatoCentrato(
        key: Key('ruoli-vuoto'),
        icona: Icons.manage_accounts_outlined,
        titolo: 'Nessun ruolo',
        sottotitolo: 'I ruoli di questa azienda non sono ancora configurati.',
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
        _NotaSolaLettura(),
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
        itemBuilder: (context, indice) => _CardRuolo(ruolo: ruoli[indice]),
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
            columns: const [
              DataColumn(label: Text('Ruolo')),
              DataColumn(label: Text('Descrizione')),
              DataColumn(label: Text('Sconto massimo')),
              DataColumn(label: Text('Permessi')),
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
                          Text(ruolo.nome.trim().isEmpty
                              ? 'Senza nome'
                              : ruolo.nome.trim()),
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
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nota che chiarisce il momento della funzione (sola lettura).
class _NotaSolaLettura extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outline,
          size: 16,
          color: tema.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpazi.xs),
        Expanded(
          child: Text(
            'Per ora i ruoli si possono solo consultare: la modifica '
            'arriverà in un prossimo aggiornamento.',
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

/// Card di un ruolo (telefono): nome, descrizione, sconto e permessi.
class _CardRuolo extends StatelessWidget {
  const _CardRuolo({required this.ruolo});

  final Ruolo ruolo;

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
                    ruolo.nome.trim().isEmpty
                        ? 'Senza nome'
                        : ruolo.nome.trim(),
                    style: tema.textTheme.titleSmall,
                  ),
                ),
                if (ruolo.sistema) _BadgeSistema(),
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
