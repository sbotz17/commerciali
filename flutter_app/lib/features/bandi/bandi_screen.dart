import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/bando.dart';
import '../../state/azienda_providers.dart';

// ---------------------------------------------------------------------------
// Funzioni pure: stati, formati, filtri e messaggi (verificabili senza
// Firebase né UI)
// ---------------------------------------------------------------------------

/// Etichette italiane degli stati del bando (chiavi Firestore).
const Map<String, String> statiBando = {
  'attivo': 'Attivo',
  'in_scadenza': 'In scadenza',
  'permanente': 'Permanente',
  'scaduto': 'Scaduto',
};

/// Etichetta italiana dello [stato] del bando.
///
/// Lo stato assente o sconosciuto resta visibile così com'è (con `—` se
/// vuoto), per non nascondere dati importati da fonti diverse.
String etichettaStatoBando(String? stato) {
  final chiave = (stato ?? '').trim().toLowerCase();
  if (chiave.isEmpty) return '—';
  return statiBando[chiave] ?? chiave;
}

/// Colore del badge di stato, coerente con i colori semantici del tema.
Color coloreStatoBando(String? stato) {
  switch ((stato ?? '').trim().toLowerCase()) {
    case 'attivo':
      return AppColors.accettato;
    case 'in_scadenza':
      return AppColors.attesa;
    case 'permanente':
      return AppColors.primario;
    case 'scaduto':
      return AppColors.errore;
    default:
      return AppColors.attesa;
  }
}

/// Formatta una data Firestore `YYYY-MM-DD` come `gg/mm/aaaa`.
///
/// Le date assenti o non riconoscibili tornano `—`; un valore ISO con orario
/// (`2026-12-31T10:00:00Z`) usa solo la parte della data.
String formattaDataBando(String? data) {
  final valore = (data ?? '').trim();
  if (valore.isEmpty) return '—';
  final parti = valore.split('T').first.split('-');
  if (parti.length != 3) return valore;
  final anno = int.tryParse(parti[0]);
  final mese = int.tryParse(parti[1]);
  final giorno = int.tryParse(parti[2]);
  if (anno == null || mese == null || giorno == null) return valore;
  final meseTesto = mese.toString().padLeft(2, '0');
  final giornoTesto = giorno.toString().padLeft(2, '0');
  return '$giornoTesto/$meseTesto/$anno';
}

/// Importo in euro con formato italiano (`50.000 €`), `—` se assente.
String formattaImportoBando(num? importo) {
  if (importo == null) return '—';
  return NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
    decimalDigits: 0,
  ).format(importo);
}

/// Testo leggibile di un campo facoltativo, con `—` se vuoto.
String testoBando(String? valore) {
  final testo = (valore ?? '').trim();
  return testo.isEmpty ? '—' : testo;
}

/// Nome della regione con l'iniziale maiuscola (`lombardia` → `Lombardia`).
String etichettaRegione(String regione) {
  final testo = regione.trim();
  if (testo.isEmpty) return testo;
  return '${testo[0].toUpperCase()}${testo.substring(1)}';
}

/// Regioni citate dai bandi, senza duplicati e in ordine alfabetico.
List<String> regioniDisponibili(List<Bando> bandi) {
  final regioni = <String>{};
  for (final bando in bandi) {
    for (final regione in bando.regioni) {
      final testo = regione.trim();
      if (testo.isNotEmpty) regioni.add(etichettaRegione(testo));
    }
  }
  final elenco = regioni.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return elenco;
}

/// Stati presenti nei bandi caricati, nell'ordine di [statiBando].
List<String> statiDisponibili(List<Bando> bandi) {
  final presenti = {
    for (final bando in bandi) (bando.stato ?? '').trim().toLowerCase(),
  };
  final elenco = [
    for (final chiave in statiBando.keys)
      if (presenti.contains(chiave)) chiave,
  ];
  for (final chiave in presenti) {
    if (chiave.isNotEmpty && !elenco.contains(chiave)) elenco.add(chiave);
  }
  return elenco;
}

/// Filtra i bandi per testo, stato e regione.
///
/// - [testo] cerca (senza distinzione tra maiuscole) in titolo e descrizione;
/// - [stato] è una chiave Firestore (`attivo`, `in_scadenza`, …) o vuota per
///   tutti;
/// - [regione] confronta le regioni del bando; i bandi aperti a tutte le
///   regioni (`tutteRegioni`) restano visibili con qualsiasi filtro.
List<Bando> filtraBandi(
  List<Bando> bandi, {
  String testo = '',
  String stato = '',
  String regione = '',
}) {
  final cerca = testo.trim().toLowerCase();
  final statoCercato = stato.trim().toLowerCase();
  final regioneCercata = regione.trim().toLowerCase();

  return bandi.where((bando) {
    final titolo = (bando.titolo ?? '').toLowerCase();
    final descrizione = (bando.descrizione ?? '').toLowerCase();
    final okTesto =
        cerca.isEmpty || titolo.contains(cerca) || descrizione.contains(cerca);

    final okStato = statoCercato.isEmpty ||
        (bando.stato ?? '').trim().toLowerCase() == statoCercato;

    final regioni = bando.regioni.map((r) => r.trim().toLowerCase());
    final okRegione = regioneCercata.isEmpty ||
        bando.tutteRegioni ||
        regioni.contains(regioneCercata);

    return okTesto && okStato && okRegione;
  }).toList();
}

/// `true` se il bando ha una scadenza entro i prossimi [giorni] giorni.
///
/// Serve solo a evidenziare le scadenze vicine; le date non valide o assenti
/// non sono considerate imminenti.
bool scadenzaImminente(
  Bando bando, {
  DateTime? oggi,
  int giorni = 30,
}) {
  final data = _dataBando(bando.dataChiusura);
  if (data == null) return false;
  final riferimento = oggi ?? DateTime.now();
  final inizio = DateTime(riferimento.year, riferimento.month, riferimento.day);
  final differenza = data.difference(inizio).inDays;
  return differenza >= 0 && differenza <= giorni;
}

/// Interpreta una data Firestore `YYYY-MM-DD`; `null` se non valida.
DateTime? _dataBando(String? valore) {
  final testo = (valore ?? '').trim();
  if (testo.isEmpty) return null;
  final parti = testo.split('T').first.split('-');
  if (parti.length != 3) return null;
  final anno = int.tryParse(parti[0]);
  final mese = int.tryParse(parti[1]);
  final giorno = int.tryParse(parti[2]);
  if (anno == null || mese == null || giorno == null) return null;
  final data = DateTime(anno, mese, giorno);
  if (data.year != anno || data.month != mese || data.day != giorno) {
    return null;
  }
  return data;
}

/// Link ufficiale apribile (solo `http`/`https`), `null` se assente o non
/// valido.
Uri? uriUfficialeBando(Bando bando) {
  final testo = (bando.linkUfficiale ?? '').trim();
  if (testo.isEmpty) return null;
  final uri = Uri.tryParse(testo);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri;
}

/// Messaggio in italiano per gli errori di caricamento dei bandi.
String messaggioErroreBandi(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per consultare i bandi. '
            'Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      default:
        return 'Bandi non disponibili. Riprova.';
    }
  }
  return 'Bandi non disponibili. Controlla la connessione e riprova.';
}

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Elenco pubblico dei bandi: ricerca, filtri e dettaglio.
class BandiScreen extends ConsumerStatefulWidget {
  const BandiScreen({super.key});

  @override
  ConsumerState<BandiScreen> createState() => _BandiScreenState();
}

class _BandiScreenState extends ConsumerState<BandiScreen> {
  final _ricerca = TextEditingController();

  List<Bando> _bandi = const [];
  bool _caricamento = true;
  Object? _errore;

  /// Stato selezionato (chiave Firestore); stringa vuota = tutti.
  String _filtroStato = '';

  /// Regione selezionata; stringa vuota = tutte.
  String _filtroRegione = '';

  bool get _filtriAttivi =>
      _ricerca.text.trim().isNotEmpty ||
      _filtroStato.isNotEmpty ||
      _filtroRegione.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _ricerca.addListener(_aggiornaRicerca);
    _caricaBandi();
  }

  @override
  void dispose() {
    _ricerca.removeListener(_aggiornaRicerca);
    _ricerca.dispose();
    super.dispose();
  }

  void _aggiornaRicerca() => setState(() {});

  /// Legge i bandi pubblici (nessuna scrittura, nessuna azienda richiesta).
  Future<void> _caricaBandi() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final bandi = await ref.read(spServiceProvider).getBandi();
      if (!mounted) return;
      setState(() {
        _bandi = bandi;
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

  void _azzeraFiltri() {
    _ricerca.clear();
    setState(() {
      _filtroStato = '';
      _filtroRegione = '';
    });
  }

  /// Mostra il dettaglio del bando in un dialogo.
  Future<void> _apriDettaglio(Bando bando) async {
    await showDialog<void>(
      context: context,
      builder: (context) => BandoDettaglioDialog(bando: bando),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largo = constraints.maxWidth >= AppBreakpoints.telefono;
        final orizzontale =
            largo ? AppSpazi.paginaDesktop : AppSpazi.paginaTelefono;

        final filtrati = filtraBandi(
          _bandi,
          testo: _ricerca.text,
          stato: _filtroStato,
          regione: _filtroRegione,
        );

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                orizzontale,
                orizzontale,
                orizzontale,
                AppSpazi.s,
              ),
              child: _BarraBandi(
                largo: largo,
                controller: _ricerca,
                stati: statiDisponibili(_bandi),
                regioni: regioniDisponibili(_bandi),
                filtroStato: _filtroStato,
                filtroRegione: _filtroRegione,
                onStato: (valore) => setState(() => _filtroStato = valore),
                onRegione: (valore) => setState(() => _filtroRegione = valore),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  orizzontale,
                  0,
                  orizzontale,
                  orizzontale,
                ),
                child: ElencoBandi(
                  bandi: filtrati,
                  caricamento: _caricamento,
                  errore: _errore,
                  largo: largo,
                  filtriAttivi: _filtriAttivi,
                  onRiprova: _caricaBandi,
                  onAzzeraFiltri: _azzeraFiltri,
                  onApri: _apriDettaglio,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Barra di ricerca e filtri (stato e regione se presenti nei dati).
class _BarraBandi extends StatelessWidget {
  const _BarraBandi({
    required this.largo,
    required this.controller,
    required this.stati,
    required this.regioni,
    required this.filtroStato,
    required this.filtroRegione,
    required this.onStato,
    required this.onRegione,
  });

  final bool largo;
  final TextEditingController controller;
  final List<String> stati;
  final List<String> regioni;
  final String filtroStato;
  final String filtroRegione;
  final ValueChanged<String> onStato;
  final ValueChanged<String> onRegione;

  @override
  Widget build(BuildContext context) {
    final campoRicerca = TextField(
      key: const Key('bandi-ricerca'),
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cerca per titolo o descrizione',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                key: const Key('bandi-azzera-ricerca'),
                tooltip: 'Azzera ricerca',
                onPressed: controller.clear,
                icon: const Icon(Icons.close),
              ),
      ),
    );

    // `initialValue` non si aggiorna da solo: la chiave cambia con la
    // selezione così la tendina resta allineata allo stato corrente.
    final tendinaStato = DropdownButtonFormField<String>(
      key: ValueKey('bandi-filtro-stato-$filtroStato'),
      initialValue: filtroStato,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Stato'),
      items: [
        const DropdownMenuItem(value: '', child: Text('Tutti gli stati')),
        for (final stato in stati)
          DropdownMenuItem(
            value: stato,
            child: Text(etichettaStatoBando(stato)),
          ),
      ],
      onChanged: (valore) => onStato(valore ?? ''),
    );

    final tendinaRegione = DropdownButtonFormField<String>(
      key: ValueKey('bandi-filtro-regione-$filtroRegione'),
      initialValue: filtroRegione,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Regione'),
      items: [
        const DropdownMenuItem(value: '', child: Text('Tutte le regioni')),
        for (final regione in regioni)
          DropdownMenuItem(
            value: regione,
            child: Text(
              regione,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (valore) => onRegione(valore ?? ''),
    );

    if (!largo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          campoRicerca,
          const SizedBox(height: AppSpazi.xs),
          Row(
            children: [
              Expanded(child: tendinaStato),
              if (regioni.isNotEmpty) ...[
                const SizedBox(width: AppSpazi.xs),
                Expanded(child: tendinaRegione),
              ],
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: campoRicerca),
        const SizedBox(width: AppSpazi.s),
        SizedBox(width: 200, child: tendinaStato),
        if (regioni.isNotEmpty) ...[
          const SizedBox(width: AppSpazi.s),
          SizedBox(width: 220, child: tendinaRegione),
        ],
      ],
    );
  }
}

/// Corpo della lista: stati caricamento/errore/vuoto e lista responsive.
///
/// È pubblico e senza provider per poter essere verificato con un widget test
/// senza Firebase.
class ElencoBandi extends StatelessWidget {
  const ElencoBandi({
    super.key,
    required this.bandi,
    required this.onRiprova,
    required this.onApri,
    this.caricamento = false,
    this.errore,
    this.largo = false,
    this.filtriAttivi = false,
    this.onAzzeraFiltri,
  });

  final List<Bando> bandi;
  final bool caricamento;
  final Object? errore;
  final bool largo;
  final bool filtriAttivi;
  final VoidCallback onRiprova;
  final VoidCallback? onAzzeraFiltri;
  final ValueChanged<Bando> onApri;

  @override
  Widget build(BuildContext context) {
    if (caricamento) {
      return const Center(
        key: Key('bandi-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (errore != null) {
      return StatoCentrato(
        icona: Icons.cloud_off_outlined,
        titolo: 'Bandi non disponibili',
        sottotitolo: messaggioErroreBandi(errore!),
        azione: OutlinedButton.icon(
          key: const Key('bandi-riprova'),
          onPressed: onRiprova,
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    if (bandi.isEmpty) {
      if (filtriAttivi) {
        return StatoCentrato(
          icona: Icons.search_off,
          titolo: 'Nessun bando trovato',
          sottotitolo: 'Prova a cambiare i termini di ricerca o i filtri.',
          azione: TextButton.icon(
            key: const Key('bandi-azzera-filtri'),
            onPressed: onAzzeraFiltri,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Azzera filtri'),
          ),
        );
      }
      return const StatoCentrato(
        icona: Icons.campaign_outlined,
        titolo: 'Nessun bando',
        sottotitolo:
            'Al momento non ci sono bandi pubblicati. Riprova più tardi.',
      );
    }

    return largo
        ? _TabellaBandi(bandi: bandi, onApri: onApri)
        : _ListaBandi(bandi: bandi, onApri: onApri);
  }
}

/// Badge colorato con l'etichetta dello stato del bando.
class BadgeStatoBando extends StatelessWidget {
  const BadgeStatoBando({super.key, required this.stato});

  final String? stato;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore = coloreStatoBando(stato);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpazi.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colore.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRaggi.chip),
      ),
      child: Text(
        etichettaStatoBando(stato),
        style: tema.textTheme.labelSmall?.copyWith(color: colore),
      ),
    );
  }
}

/// Riepilogo della scadenza: data e avviso se entro 30 giorni.
class _ScadenzaBando extends StatelessWidget {
  const _ScadenzaBando({required this.bando});

  final Bando bando;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final imminente = scadenzaImminente(bando);
    final colore = imminente
        ? AppColors.attesa
        : tema.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event_outlined, size: 16, color: colore),
        const SizedBox(width: AppSpazi.xxs),
        Text(
          formattaDataBando(bando.dataChiusura),
          style: tema.textTheme.bodySmall?.copyWith(color: colore),
        ),
      ],
    );
  }
}

/// Titolo del bando con `—` se assente.
String titoloBando(Bando bando) {
  final titolo = (bando.titolo ?? '').trim();
  return titolo.isEmpty ? 'Bando senza titolo' : titolo;
}

/// Fonte del bando, con `—` se assente.
String fonteBando(Bando bando) {
  final fonte = (bando.fonte ?? '').trim();
  return fonte.isEmpty ? '—' : fonte;
}

/// Elenco a card (telefono).
class _ListaBandi extends StatelessWidget {
  const _ListaBandi({required this.bandi, required this.onApri});

  final List<Bando> bandi;
  final ValueChanged<Bando> onApri;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListView.separated(
      key: const Key('lista-bandi'),
      padding: const EdgeInsets.only(bottom: AppSpazi.l),
      itemCount: bandi.length,
      separatorBuilder: (context, indice) =>
          const SizedBox(height: AppSpazi.xs),
      itemBuilder: (context, indice) {
        final bando = bandi[indice];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('bando-${bando.id}'),
            onTap: () => onApri(bando),
            child: Padding(
              padding: const EdgeInsets.all(AppSpazi.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          titoloBando(bando),
                          style: tema.textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpazi.xs),
                      BadgeStatoBando(stato: bando.stato),
                    ],
                  ),
                  const SizedBox(height: AppSpazi.xs),
                  Wrap(
                    spacing: AppSpazi.m,
                    runSpacing: AppSpazi.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _ScadenzaBando(bando: bando),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.source_outlined,
                            size: 16,
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpazi.xxs),
                          Text(
                            fonteBando(bando),
                            style: tema.textTheme.bodySmall?.copyWith(
                              color: tema.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Elenco tabellare (da 600 px in su).
class _TabellaBandi extends StatelessWidget {
  const _TabellaBandi({required this.bandi, required this.onApri});

  final List<Bando> bandi;
  final ValueChanged<Bando> onApri;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          key: const Key('tabella-bandi'),
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Titolo')),
            DataColumn(label: Text('Scadenza')),
            DataColumn(label: Text('Stato')),
            DataColumn(label: Text('Fonte')),
          ],
          rows: [
            for (final bando in bandi)
              DataRow(
                key: ValueKey('bando-${bando.id}'),
                onSelectChanged: (_) => onApri(bando),
                cells: [
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Text(
                        titoloBando(bando),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(_ScadenzaBando(bando: bando)),
                  DataCell(BadgeStatoBando(stato: bando.stato)),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        fonteBando(bando),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dettaglio
// ---------------------------------------------------------------------------

/// Dettaglio del bando in dialogo: descrizione, importi, requisiti e link.
class BandoDettaglioDialog extends StatelessWidget {
  const BandoDettaglioDialog({super.key, required this.bando});

  final Bando bando;

  Future<void> _apriLink(BuildContext context) async {
    final uri = uriUfficialeBando(bando);
    if (uri == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final aperto = await launchUrl(uri);
      if (!aperto) throw Exception('link non aperto');
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Non è stato possibile aprire il link ufficiale.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final uri = uriUfficialeBando(bando);

    return AlertDialog(
      key: const Key('dialog-bando'),
      title: Text(titoloBando(bando)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: AppSpazi.xs,
                runSpacing: AppSpazi.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  BadgeStatoBando(stato: bando.stato),
                  if (scadenzaImminente(bando))
                    Text(
                      'Scade il ${formattaDataBando(bando.dataChiusura)}',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: AppColors.attesa,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpazi.m),
              Text(
                (bando.descrizione ?? '').trim().isEmpty
                    ? 'Nessuna descrizione disponibile.'
                    : bando.descrizione!.trim(),
                style: tema.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpazi.m),
              _RigaDettaglio(
                etichetta: 'Scadenza',
                valore: formattaDataBando(bando.dataChiusura),
              ),
              _RigaDettaglio(
                etichetta: 'Apertura',
                valore: formattaDataBando(bando.dataApertura),
              ),
              _RigaDettaglio(
                etichetta: 'Agevolazione',
                valore: _testoAgevolazione(bando),
              ),
              _RigaDettaglio(
                etichetta: 'Stanziamento',
                valore: formattaImportoBando(bando.stanziamento),
              ),
              _RigaDettaglio(
                etichetta: 'Soggetto concedente',
                valore: testoBando(bando.soggettoConcedente),
              ),
              _RigaDettaglio(
                etichetta: 'Fonte',
                valore: testoBando(bando.fonte),
              ),
              _RigaDettaglio(
                etichetta: 'Regioni',
                valore: bando.tutteRegioni || bando.regioni.isEmpty
                    ? 'Tutte le regioni'
                    : bando.regioni.map(etichettaRegione).join(', '),
              ),
              if (bando.formaAgevolazione.isNotEmpty)
                _RigaDettaglio(
                  etichetta: 'Forma',
                  valore: bando.formaAgevolazione.join(', '),
                ),
              if (bando.dimensioni.isNotEmpty)
                _RigaDettaglio(
                  etichetta: 'Beneficiari',
                  valore: bando.dimensioni.join(', '),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('chiudi-bando'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Chiudi'),
        ),
        if (uri != null)
          FilledButton.icon(
            key: const Key('apri-link-bando'),
            onPressed: () => _apriLink(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Apri link ufficiale'),
          ),
      ],
    );
  }

  /// "Da 5.000 € a 50.000 €" oppure il solo limite disponibile.
  String _testoAgevolazione(Bando bando) {
    final minimo = bando.agevolazioneMin;
    final massimo = bando.agevolazioneMax;
    if (minimo == null && massimo == null) return '—';
    if (minimo != null && massimo != null) {
      return 'Da ${formattaImportoBando(minimo)} '
          'a ${formattaImportoBando(massimo)}';
    }
    if (massimo != null) return 'Fino a ${formattaImportoBando(massimo)}';
    return 'Da ${formattaImportoBando(minimo)}';
  }
}

/// Riga "etichetta: valore" del dettaglio bando.
class _RigaDettaglio extends StatelessWidget {
  const _RigaDettaglio({required this.etichetta, required this.valore});

  final String etichetta;
  final String valore;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpazi.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              etichetta,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(valore, style: tema.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
