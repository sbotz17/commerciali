// Calendario dell'agenda: appuntamenti e task uniti per giorno o settimana.
//
// La schermata non introduce nuove letture dati: usa `getAppuntamenti`,
// `getTask` e `getUtenti` del servizio e riusa il form degli appuntamenti
// (`AppuntamentoFormScreen`) per la creazione. Le funzioni di conversione e
// raggruppamento sono pure, così restano verificabili senza Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/appuntamento.dart';
import '../../data/models/task_item.dart';
import '../../data/models/user_profile.dart';
import '../../state/azienda_providers.dart';
import '../visite/visite_screen.dart'
    show dataIsoVisita, etichettaGiornoVisite, formattaDataVisita;
import 'appuntamento_form_screen.dart'
    show
        AppuntamentoFormScreen,
        messaggioErroreAppuntamenti,
        nomeUtenteAppuntamento,
        uriMapsIndirizzo;

// ---------------------------------------------------------------------------
// Funzioni pure: conversione, raggruppamento e date (verificabili senza
// Firebase né UI)
// ---------------------------------------------------------------------------

/// Tipo di voce dell'agenda: appuntamento o task.
const String tipoAppuntamento = 'appuntamento';
const String tipoTask = 'task';

/// Voce mostrata nel calendario, ricavata da un appuntamento o da un task.
class ElementoAgenda {
  const ElementoAgenda({
    required this.data,
    required this.titolo,
    required this.tipo,
    this.ora,
    this.appuntamento,
    this.task,
  });

  /// Giorno della voce in formato `YYYY-MM-DD`.
  final String data;

  /// Ora `HH:MM`, oppure `null` quando la voce non ha un orario.
  final String? ora;

  /// Titolo visibile (con fallback se il documento è senza titolo).
  final String titolo;

  /// `appuntamento` oppure `task`.
  final String tipo;

  /// Appuntamento di origine, se [tipo] è `appuntamento`.
  final Appuntamento? appuntamento;

  /// Task di origine, se [tipo] è `task`.
  final TaskItem? task;

  /// `true` se la voce è un appuntamento.
  bool get isAppuntamento => tipo == tipoAppuntamento;
}

/// Ora normalizzata `HH:MM`, oppure `null` se assente o non valida.
String? _oraElemento(String? ora) {
  final valore = ora?.trim() ?? '';
  if (valore.isEmpty) return null;
  final parti = valore.split(':');
  if (parti.length != 2) return valore;
  final ore = int.tryParse(parti[0]);
  final minuti = int.tryParse(parti[1]);
  if (ore == null || minuti == null) return valore;
  if (ore < 0 || ore > 23 || minuti < 0 || minuti > 59) return valore;
  return '${ore.toString().padLeft(2, '0')}:'
      '${minuti.toString().padLeft(2, '0')}';
}

/// Titolo con fallback per i documenti senza titolo.
String _titoloElemento(String? titolo, String fallback) {
  final valore = titolo?.trim() ?? '';
  return valore.isEmpty ? fallback : valore;
}

/// Converte gli appuntamenti in voci dell'agenda.
///
/// Gli appuntamenti senza `data` non possono essere collocati in un giorno e
/// vengono scartati; l'ordine di partenza è quello del servizio.
List<ElementoAgenda> elementiDaAppuntamenti(List<Appuntamento> appuntamenti) {
  final elementi = <ElementoAgenda>[];
  for (final appuntamento in appuntamenti) {
    final data = appuntamento.data?.trim() ?? '';
    if (data.isEmpty) continue;
    elementi.add(
      ElementoAgenda(
        data: data,
        ora: _oraElemento(appuntamento.ora),
        titolo: _titoloElemento(appuntamento.titolo, 'Appuntamento'),
        tipo: tipoAppuntamento,
        appuntamento: appuntamento,
      ),
    );
  }
  return elementi;
}

/// Converte i task in voci dell'agenda.
///
/// Solo i task con `scadenzaData` hanno un giorno: quelli senza scadenza sono
/// esclusi dal calendario.
List<ElementoAgenda> elementiDaTask(List<TaskItem> task) {
  final elementi = <ElementoAgenda>[];
  for (final voce in task) {
    final data = voce.scadenzaData?.trim() ?? '';
    if (data.isEmpty) continue;
    elementi.add(
      ElementoAgenda(
        data: data,
        ora: _oraElemento(voce.scadenzaOra),
        titolo: _titoloElemento(voce.titolo, 'Task'),
        tipo: tipoTask,
        task: voce,
      ),
    );
  }
  return elementi;
}

/// Chiave di ordinamento dell'ora: le voci senza ora finiscono in fondo.
String _chiaveOra(ElementoAgenda elemento) => elemento.ora ?? '99:99';

/// Raggruppa le voci per giorno (`YYYY-MM-DD`).
///
/// Le chiavi sono ordinate per data crescente e, dentro ogni giorno, le voci
/// sono ordinate per ora (senza ora in fondo) e poi per titolo.
Map<String, List<ElementoAgenda>> raggruppaPerGiorno(
  List<ElementoAgenda> elementi,
) {
  final gruppi = <String, List<ElementoAgenda>>{};
  for (final elemento in elementi) {
    final data = elemento.data.trim();
    if (data.isEmpty) continue;
    gruppi.putIfAbsent(data, () => <ElementoAgenda>[]).add(elemento);
  }

  final giorni = gruppi.keys.toList()..sort();
  final risultato = <String, List<ElementoAgenda>>{};
  for (final giorno in giorni) {
    final voci = gruppi[giorno]!;
    voci.sort((a, b) {
      final cmpOra = _chiaveOra(a).compareTo(_chiaveOra(b));
      if (cmpOra != 0) return cmpOra;
      return a.titolo.toLowerCase().compareTo(b.titolo.toLowerCase());
    });
    risultato[giorno] = voci;
  }
  return risultato;
}

/// I sette giorni (lunedì → domenica) della settimana che contiene [giorno].
List<DateTime> giorniSettimana(DateTime giorno) {
  final base = DateTime(giorno.year, giorno.month, giorno.day);
  final lunedi = base.subtract(Duration(days: base.weekday - 1));
  return [
    for (var indice = 0; indice < 7; indice++)
      DateTime(lunedi.year, lunedi.month, lunedi.day + indice),
  ];
}

/// Etichetta del giorno: "Oggi", "Domani" (o "Ieri") oppure `gg/mm/aaaa`.
///
/// [oggi] serve ai test per fissare il riferimento; in app è la data corrente.
String etichettaGiorno(DateTime giorno, {DateTime? oggi}) =>
    etichettaGiornoVisite(giorno, oggi: oggi);

/// Etichetta italiana dello stato di un task (`Completato`/`Da fare`).
String etichettaStatoTask(String? stato) {
  final chiave = stato?.trim().toLowerCase() ?? '';
  return chiave == 'completato' ? 'Completato' : 'Da fare';
}

/// Etichetta dello stato della voce, coerente con il suo tipo.
String etichettaStatoElemento(ElementoAgenda elemento) {
  if (elemento.isAppuntamento) {
    return etichettaStatoAppuntamento(elemento.appuntamento?.stato);
  }
  return etichettaStatoTask(elemento.task?.stato);
}

/// Colore del badge di stato della voce.
Color coloreStatoElemento(ElementoAgenda elemento) {
  final stato = elemento.isAppuntamento
      ? (elemento.appuntamento?.stato ?? '')
      : (elemento.task?.stato ?? '');
  switch (stato.trim().toLowerCase()) {
    case 'fatto':
    case 'completato':
      return AppColors.accettato;
    case 'annullato':
      return AppColors.errore;
    default:
      return AppColors.attesa;
  }
}

/// Riga secondaria della card: cliente e operatore, con `—` se assenti.
String dettaglioElemento(
  ElementoAgenda elemento,
  Map<String, String> nomiOperatori,
) {
  final parti = <String>[];
  final cliente = (elemento.appuntamento?.clienteNome ??
          elemento.task?.clienteNome ??
          '')
      .trim();
  if (cliente.isNotEmpty) parti.add(cliente);

  final operatoreId = (elemento.appuntamento?.operatoreId ??
          elemento.task?.operatoreId ??
          '')
      .trim();
  final operatore = nomiOperatori[operatoreId]?.trim() ?? '';
  if (operatore.isNotEmpty) parti.add(operatore);

  return parti.isEmpty ? '—' : parti.join(' · ');
}

/// Data e ora della voce in formato italiano: `gg/mm/aaaa · HH:MM`.
///
/// Se l'ora manca resta la sola data; se la data non è interpretabile si
/// mostra il valore originale.
String etichettaDataOraElemento(ElementoAgenda elemento) {
  final grezza = elemento.data.trim();
  final iso = DateTime.tryParse(grezza);
  final data = iso == null ? grezza : formattaDataVisita(iso);
  final ora = elemento.ora;
  return ora == null ? data : '$data · $ora';
}

/// Azioni restituite dal dialogo di dettaglio della voce.
const String azioneModificaVoce = 'modifica';
const String azioneEliminaVoce = 'elimina';
const String azioneApriTaskVoce = 'apri-task';

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Calendario dell'agenda con vista giorno/settimana e filtro operatore.
class CalendarioScreen extends ConsumerStatefulWidget {
  const CalendarioScreen({super.key});

  @override
  ConsumerState<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends ConsumerState<CalendarioScreen> {
  late DateTime _giorno;
  bool _settimana = false;
  String _operatoreId = '';

  List<Appuntamento> _appuntamenti = const [];
  List<TaskItem> _task = const [];
  List<UserProfile> _utenti = const [];

  bool _caricamento = true;
  Object? _errore;

  @override
  void initState() {
    super.initState();
    final oggi = DateTime.now();
    _giorno = DateTime(oggi.year, oggi.month, oggi.day);
    _carica();
  }

  /// Carica appuntamenti, task e utenti in parallelo.
  ///
  /// L'errore su appuntamenti o task blocca l'elenco con "Riprova"; l'errore
  /// sugli utenti lascia il filtro operatore sul solo "Tutti".
  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });

    Future<List<Appuntamento>>? appuntamentiFuturo;
    Future<List<TaskItem>>? taskFuturo;
    Future<List<UserProfile>>? utentiFuturo;
    Object? erroreAvvio;
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      appuntamentiFuturo = servizio.getAppuntamenti();
      taskFuturo = servizio.getTask();
      utentiFuturo = servizio.getUtenti();
    } catch (errore) {
      erroreAvvio = errore;
    }

    List<Appuntamento>? appuntamenti;
    List<TaskItem>? task;
    Object? errore;
    if (appuntamentiFuturo != null && taskFuturo != null) {
      try {
        final risultati = await Future.wait<Object>([
          appuntamentiFuturo,
          taskFuturo,
        ]);
        appuntamenti = risultati[0] as List<Appuntamento>;
        task = risultati[1] as List<TaskItem>;
      } catch (e) {
        errore = e;
      }
    } else {
      errore = erroreAvvio;
    }

    List<UserProfile>? utenti;
    if (utentiFuturo != null) {
      try {
        utenti = await utentiFuturo;
      } catch (_) {
        // Senza elenco utenti il filtro resta su "Tutti".
      }
    }

    if (!mounted) return;
    setState(() {
      final appuntamentiCaricati = appuntamenti;
      if (appuntamentiCaricati != null) _appuntamenti = appuntamentiCaricati;
      final taskCaricati = task;
      if (taskCaricati != null) _task = taskCaricati;
      final utentiCaricati = utenti;
      if (utentiCaricati != null) _utenti = utentiCaricati;
      _errore = errore;
      _caricamento = false;
    });
  }

  /// Nomi degli operatori per le card, con uid come fallback.
  Map<String, String> get _nomiOperatori => {
        for (final utente in _utenti)
          utente.uid: nomeUtenteAppuntamento(utente),
      };

  /// Voci di tutti i giorni, filtrate per operatore.
  List<ElementoAgenda> get _elementi {
    final operatore = _operatoreId;
    final appuntamenti = operatore.isEmpty
        ? _appuntamenti
        : _appuntamenti
            .where((appuntamento) => appuntamento.operatoreId == operatore)
            .toList();
    final task = operatore.isEmpty
        ? _task
        : _task.where((voce) => voce.operatoreId == operatore).toList();
    return [
      ...elementiDaAppuntamenti(appuntamenti),
      ...elementiDaTask(task),
    ];
  }

  void _sposta(int giorni) {
    setState(() {
      _giorno = DateTime(_giorno.year, _giorno.month, _giorno.day + giorni);
    });
  }

  void _vaiAOggi() {
    final oggi = DateTime.now();
    setState(() => _giorno = DateTime(oggi.year, oggi.month, oggi.day));
  }

  Future<void> _apriNuovoAppuntamento() async {
    final salvato = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppuntamentoFormScreen(dataIniziale: _giorno),
      ),
    );
    if (salvato == true) await _carica();
  }

  /// Apre il dettaglio della voce e gestisce l'azione scelta.
  Future<void> _apriDettaglio(ElementoAgenda elemento) async {
    final azione = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoElemento(
        elemento: elemento,
        nomiOperatori: _nomiOperatori,
      ),
    );
    if (!mounted || azione == null) return;

    if (azione == azioneApriTaskVoce) {
      context.go('/task');
      return;
    }

    final appuntamento = elemento.appuntamento;
    if (appuntamento == null) return;
    if (azione == azioneModificaVoce) {
      await _modificaAppuntamento(appuntamento);
    } else if (azione == azioneEliminaVoce) {
      await _eliminaAppuntamento(appuntamento);
    }
  }

  /// Apre il form in modifica e ricarica se il salvataggio è andato a buon fine.
  Future<void> _modificaAppuntamento(Appuntamento appuntamento) async {
    final salvato = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppuntamentoFormScreen(appuntamento: appuntamento),
      ),
    );
    if (salvato == true) await _carica();
  }

  /// Chiede conferma, elimina l'appuntamento e ricarica l'agenda.
  Future<void> _eliminaAppuntamento(Appuntamento appuntamento) async {
    final titolo = appuntamento.titolo?.trim() ?? '';
    final nome = titolo.isEmpty ? 'l\'appuntamento' : '"$titolo"';
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('calendario-conferma-elimina'),
        title: const Text('Eliminare l\'appuntamento?'),
        content: Text(
          'L\'appuntamento $nome verrà eliminato definitivamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const Key('calendario-conferma-elimina-si'),
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
      await servizio.eliminaAppuntamento(appuntamento.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appuntamento eliminato')),
      );
      await _carica();
    } catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messaggioErroreAppuntamenti(errore))),
      );
    }
  }

  /// Testo del periodo: giorno singolo oppure intervallo lunedì–domenica.
  String get _etichettaPeriodo {
    if (!_settimana) return etichettaGiorno(_giorno);
    final giorni = giorniSettimana(_giorno);
    return '${formattaDataVisita(giorni.first)} – '
        '${formattaDataVisita(giorni.last)}';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(aziendaAttivaProvider, (precedente, attuale) {
      if (precedente != attuale) _carica();
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final riga = constraints.maxWidth >= AppBreakpoints.tablet;
        final orizzontale = constraints.maxWidth >= AppBreakpoints.telefono
            ? AppSpazi.paginaDesktop
            : AppSpazi.paginaTelefono;

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                orizzontale,
                orizzontale,
                orizzontale,
                AppSpazi.s,
              ),
              child: _BarraCalendario(
                riga: riga,
                etichettaPeriodo: _etichettaPeriodo,
                settimana: _settimana,
                operatoreId: _operatoreId,
                operatori: {
                  for (final utente in _utenti)
                    utente.uid: nomeUtenteAppuntamento(utente),
                },
                onPrecedente: () => _sposta(_settimana ? -7 : -1),
                onSuccessivo: () => _sposta(_settimana ? 7 : 1),
                onOggi: _vaiAOggi,
                onVista: (settimana) =>
                    setState(() => _settimana = settimana),
                onOperatore: (operatore) =>
                    setState(() => _operatoreId = operatore),
                onNuovo: _apriNuovoAppuntamento,
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
                child: CorpoCalendario(
                  elementi: _elementi,
                  giorno: _giorno,
                  settimana: _settimana,
                  caricamento: _caricamento,
                  errore: _errore,
                  nomiOperatori: _nomiOperatori,
                  onRiprova: _carica,
                  onTapVoce: _apriDettaglio,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Barra con navigazione del periodo, vista, filtro operatore e pulsante
/// "Nuovo appuntamento".
class _BarraCalendario extends StatelessWidget {
  const _BarraCalendario({
    required this.riga,
    required this.etichettaPeriodo,
    required this.settimana,
    required this.operatoreId,
    required this.operatori,
    required this.onPrecedente,
    required this.onSuccessivo,
    required this.onOggi,
    required this.onVista,
    required this.onOperatore,
    required this.onNuovo,
  });

  final bool riga;
  final String etichettaPeriodo;
  final bool settimana;
  final String operatoreId;
  final Map<String, String> operatori;
  final VoidCallback onPrecedente;
  final VoidCallback onSuccessivo;
  final VoidCallback onOggi;
  final ValueChanged<bool> onVista;
  final ValueChanged<String> onOperatore;
  final VoidCallback onNuovo;

  @override
  Widget build(BuildContext context) {
    final navigazione = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('calendario-precedente'),
          tooltip: settimana ? 'Settimana precedente' : 'Giorno precedente',
          onPressed: onPrecedente,
          icon: const Icon(Icons.chevron_left),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 130),
          child: Text(
            etichettaPeriodo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        IconButton(
          key: const Key('calendario-successivo'),
          tooltip: settimana ? 'Settimana successiva' : 'Giorno successivo',
          onPressed: onSuccessivo,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );

    final pulsanteOggi = TextButton(
      key: const Key('calendario-oggi'),
      onPressed: onOggi,
      child: const Text('Oggi'),
    );

    final vista = SegmentedButton<bool>(
      key: const Key('calendario-vista'),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: false,
          label: Text('Giorno'),
          icon: Icon(Icons.view_agenda_outlined),
        ),
        ButtonSegment(
          value: true,
          label: Text('Settimana'),
          icon: Icon(Icons.view_week_outlined),
        ),
      ],
      selected: {settimana},
      onSelectionChanged: (selezione) => onVista(selezione.first),
    );

    final filtro = SizedBox(
      width: 210,
      child: DropdownButtonFormField<String>(
        key: const Key('calendario-operatore'),
        initialValue: operatoreId,
        isExpanded: true,
        isDense: true,
        decoration: const InputDecoration(
          labelText: 'Operatore',
          isDense: true,
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Tutti')),
          for (final voce in operatori.entries)
            DropdownMenuItem(
              value: voce.key,
              child: Text(
                voce.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (valore) => onOperatore(valore ?? ''),
      ),
    );

    final pulsanteNuovo = FilledButton.icon(
      key: const Key('calendario-nuovo-appuntamento'),
      onPressed: onNuovo,
      icon: const Icon(Icons.add),
      label: const Text('Nuovo appuntamento'),
    );

    if (!riga) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Center(child: navigazione)),
              pulsanteOggi,
            ],
          ),
          const SizedBox(height: AppSpazi.xs),
          Wrap(
            spacing: AppSpazi.xs,
            runSpacing: AppSpazi.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [vista, filtro, pulsanteNuovo],
          ),
        ],
      );
    }

    return Row(
      children: [
        navigazione,
        const SizedBox(width: AppSpazi.xs),
        pulsanteOggi,
        const Spacer(),
        vista,
        const SizedBox(width: AppSpazi.xs),
        filtro,
        const SizedBox(width: AppSpazi.xs),
        pulsanteNuovo,
      ],
    );
  }
}

/// Corpo del calendario: stati caricamento/errore/vuoto e viste giorno e
/// settimana.
///
/// È pubblico e senza provider per poter essere verificato con un widget test
/// senza Firebase.
class CorpoCalendario extends StatelessWidget {
  const CorpoCalendario({
    super.key,
    required this.elementi,
    required this.giorno,
    required this.caricamento,
    required this.onRiprova,
    required this.settimana,
    this.errore,
    this.nomiOperatori = const {},
    this.onTapVoce,
  });

  final List<ElementoAgenda> elementi;
  final DateTime giorno;
  final bool settimana;
  final bool caricamento;
  final Object? errore;
  final Map<String, String> nomiOperatori;
  final VoidCallback onRiprova;

  /// Azione al tocco di una voce; `null` disabilita l'apertura del dettaglio.
  final ValueChanged<ElementoAgenda>? onTapVoce;

  @override
  Widget build(BuildContext context) {
    if (caricamento) {
      return const Center(
        key: Key('calendario-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (errore != null) {
      return StatoCentrato(
        icona: Icons.cloud_off_outlined,
        titolo: 'Agenda non disponibile',
        sottotitolo: messaggioErroreAppuntamenti(errore!),
        azione: OutlinedButton.icon(
          key: const Key('calendario-riprova'),
          onPressed: onRiprova,
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    final gruppi = raggruppaPerGiorno(elementi);

    if (settimana) {
      return _VistaSettimana(
        giorni: giorniSettimana(giorno),
        gruppi: gruppi,
        nomiOperatori: nomiOperatori,
        onTapVoce: onTapVoce,
      );
    }

    final voci = gruppi[dataIsoVisita(giorno)] ?? const <ElementoAgenda>[];
    if (voci.isEmpty) {
      return const StatoCentrato(
        key: Key('calendario-vuoto'),
        icona: Icons.calendar_today_outlined,
        titolo: 'Nessun appuntamento',
        sottotitolo:
            'Non ci sono appuntamenti né task per questo giorno. Usa "Nuovo '
            'appuntamento" per aggiungerne uno.',
      );
    }

    return ListView.separated(
      key: const Key('calendario-giorno'),
      padding: const EdgeInsets.only(bottom: AppSpazi.l),
      itemCount: voci.length,
      separatorBuilder: (context, indice) =>
          const SizedBox(height: AppSpazi.xs),
      itemBuilder: (context, indice) => _CardElemento(
        elemento: voci[indice],
        nomiOperatori: nomiOperatori,
        onTap: onTapVoce,
      ),
    );
  }
}

/// Vista settimanale: una sezione per giorno, da lunedì a domenica.
class _VistaSettimana extends StatelessWidget {
  const _VistaSettimana({
    required this.giorni,
    required this.gruppi,
    required this.nomiOperatori,
    this.onTapVoce,
  });

  final List<DateTime> giorni;
  final Map<String, List<ElementoAgenda>> gruppi;
  final Map<String, String> nomiOperatori;
  final ValueChanged<ElementoAgenda>? onTapVoce;

  static const List<String> _nomiGiorni = [
    'Lunedì',
    'Martedì',
    'Mercoledì',
    'Giovedì',
    'Venerdì',
    'Sabato',
    'Domenica',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('calendario-settimana'),
      padding: const EdgeInsets.only(bottom: AppSpazi.l),
      children: [
        for (final giorno in giorni) ..._sezione(context, giorno),
      ],
    );
  }

  /// Intestazione del giorno e sue voci (o "Nessun appuntamento").
  List<Widget> _sezione(BuildContext context, DateTime giorno) {
    final tema = Theme.of(context);
    final voci = gruppi[dataIsoVisita(giorno)] ?? const <ElementoAgenda>[];

    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpazi.xs),
        child: Row(
          children: [
            Text(
              _nomiGiorni[giorno.weekday - 1],
              style: tema.textTheme.titleSmall,
            ),
            const SizedBox(width: AppSpazi.xs),
            Text(
              '${etichettaGiorno(giorno)} · ${formattaDataVisita(giorno)}',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      if (voci.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpazi.s),
          child: Text(
            'Nessun appuntamento',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        )
      else ...[
        for (final voce in voci) ...[
          _CardElemento(
            elemento: voce,
            nomiOperatori: nomiOperatori,
            onTap: onTapVoce,
          ),
          const SizedBox(height: AppSpazi.xs),
        ],
        const SizedBox(height: AppSpazi.s),
      ],
    ];
  }
}

/// Card di una voce dell'agenda: ora, titolo, cliente/operatore, icona e stato.
class _CardElemento extends StatelessWidget {
  const _CardElemento({
    required this.elemento,
    required this.nomiOperatori,
    this.onTap,
  });

  final ElementoAgenda elemento;
  final Map<String, String> nomiOperatori;
  final ValueChanged<ElementoAgenda>? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore = coloreStatoElemento(elemento);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(elemento),
        child: Padding(
          padding: const EdgeInsets.all(AppSpazi.m),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  elemento.ora ?? '—',
                  style: tema.textTheme.titleSmall,
                ),
              ),
              Icon(
                elemento.isAppuntamento
                    ? Icons.event_outlined
                    : Icons.task_alt_outlined,
                size: 20,
                color: tema.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpazi.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      elemento.titolo,
                      style: tema.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpazi.xxs),
                    Text(
                      dettaglioElemento(elemento, nomiOperatori),
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpazi.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpazi.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colore.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRaggi.chip),
                ),
                child: Text(
                  etichettaStatoElemento(elemento),
                  style: tema.textTheme.labelSmall?.copyWith(color: colore),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dettaglio di una voce dell'agenda, con le azioni disponibili.
///
/// Le azioni che cambiano i dati tornano al chiamante con uno dei valori
/// `azioneModificaVoce`, `azioneEliminaVoce`, `azioneApriTaskVoce`; i link
/// esterni (Maps e call) vengono aperti qui.
class _DialogoElemento extends StatelessWidget {
  const _DialogoElemento({
    required this.elemento,
    required this.nomiOperatori,
  });

  final ElementoAgenda elemento;
  final Map<String, String> nomiOperatori;

  /// Apre [uri] nel browser/app esterna, con messaggio italiano in caso di
  /// errore.
  Future<void> _apriLink(
    BuildContext context,
    Uri? uri,
    String descrizione,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      messenger.showSnackBar(
        SnackBar(content: Text('Link non valido per $descrizione.')),
      );
      return;
    }
    try {
      final aperto = await launchUrl(uri);
      if (!aperto) throw Exception('Link non aperto');
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Non è stato possibile aprire $descrizione.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appuntamento = elemento.appuntamento;
    final task = elemento.task;

    final indirizzo = appuntamento?.indirizzo?.trim() ?? '';
    final maps = indirizzo.isEmpty ? null : uriMapsIndirizzo(indirizzo);
    final callUrl = appuntamento?.callUrl?.trim() ?? '';
    final luogo = appuntamento?.luogo?.trim() ?? '';
    final descrizione = task?.descrizione?.trim() ?? '';
    final note = (appuntamento?.note ?? task?.note ?? '').trim();

    return AlertDialog(
      key: const Key('calendario-dettaglio'),
      title: Text(elemento.titolo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RigaDettaglio(
              etichetta: 'Data e ora',
              valore: etichettaDataOraElemento(elemento),
            ),
            _RigaDettaglio(
              etichetta: 'Stato',
              valore: etichettaStatoElemento(elemento),
            ),
            _RigaDettaglio(
              etichetta: 'Cliente e operatore',
              valore: dettaglioElemento(elemento, nomiOperatori),
            ),
            if (luogo.isNotEmpty)
              _RigaDettaglio(etichetta: 'Luogo', valore: luogo),
            if (indirizzo.isNotEmpty)
              _RigaDettaglio(etichetta: 'Indirizzo', valore: indirizzo),
            if (descrizione.isNotEmpty)
              _RigaDettaglio(etichetta: 'Descrizione', valore: descrizione),
            if (note.isNotEmpty)
              _RigaDettaglio(etichetta: 'Note', valore: note),
          ],
        ),
      ),
      actions: [
        if (maps != null)
          TextButton.icon(
            key: const Key('calendario-maps'),
            onPressed: () => _apriLink(context, maps, 'Google Maps'),
            icon: const Icon(Icons.directions_outlined),
            label: const Text('Apri in Google Maps'),
          ),
        if (callUrl.isNotEmpty)
          TextButton.icon(
            key: const Key('calendario-call'),
            onPressed: () => _apriLink(
              context,
              Uri.tryParse(callUrl),
              'la call',
            ),
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Apri call'),
          ),
        if (elemento.isAppuntamento) ...[
          OutlinedButton(
            key: const Key('calendario-modifica'),
            onPressed: () => Navigator.of(context).pop(azioneModificaVoce),
            child: const Text('Modifica'),
          ),
          TextButton(
            key: const Key('calendario-elimina'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(azioneEliminaVoce),
            child: const Text('Elimina'),
          ),
        ] else
          FilledButton.tonalIcon(
            key: const Key('calendario-apri-task'),
            onPressed: () => Navigator.of(context).pop(azioneApriTaskVoce),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Apri Task'),
          ),
        TextButton(
          key: const Key('calendario-chiudi'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Chiudi'),
        ),
      ],
    );
  }
}

/// Riga etichetta/valore del dialogo di dettaglio.
class _RigaDettaglio extends StatelessWidget {
  const _RigaDettaglio({required this.etichetta, required this.valore});

  final String etichetta;
  final String valore;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpazi.xs),
      child: Text.rich(
        TextSpan(
          text: '$etichetta: ',
          style: tema.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          children: [
            TextSpan(
              text: valore,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

