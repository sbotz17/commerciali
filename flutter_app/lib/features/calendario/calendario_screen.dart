// Calendario dell'agenda: appuntamenti e task uniti per giorno, settimana o
// mese. La vista predefinita è il calendario classico; l'elenco a card resta
// disponibile come alternativa.
//
// La schermata non introduce nuove letture dati: usa `getAppuntamenti`,
// `getTask` e `getUtenti` del servizio e riusa il form degli appuntamenti
// (`AppuntamentoFormScreen`) per la creazione. Le funzioni di conversione,
// raggruppamento e posizionamento sono pure e vivono in `calendario_logica.dart`;
// le viste classiche in `viste_calendario.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/appuntamento.dart';
import '../../data/models/task_item.dart';
import '../../data/models/user_profile.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';
import '../visite/visite_screen.dart' show dataIsoVisita, formattaDataVisita;
import 'appuntamento_form_screen.dart'
    show
        AppuntamentoFormScreen,
        messaggioErroreAppuntamenti,
        nomeUtenteAppuntamento,
        uriMapsIndirizzo;
import 'calendario_logica.dart';
import 'viste_calendario.dart';

export 'calendario_logica.dart';
export 'viste_calendario.dart';

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Calendario dell'agenda con viste giorno/settimana/mese (calendario classico
/// o card) e filtro operatore.
class CalendarioScreen extends ConsumerStatefulWidget {
  const CalendarioScreen({super.key, this.appuntamentoId});

  /// Id dell'appuntamento da aprire subito, usato dal tocco su una notifica
  /// di invito (`/calendario?appuntamento=...`).
  final String? appuntamentoId;

  @override
  ConsumerState<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends ConsumerState<CalendarioScreen> {
  late DateTime _giorno;
  VistaAgenda _vista = vistaAgendaPredefinita;
  StileAgenda _stile = stileAgendaPredefinito;
  String _operatoreId = '';
  bool _appuntamentoApertoDaNotifica = false;

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
    _apriAppuntamentoDaNotifica();
  }

  @override
  void didUpdateWidget(covariant CalendarioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appuntamentoId != widget.appuntamentoId) {
      _appuntamentoApertoDaNotifica = false;
      _apriAppuntamentoDaNotifica();
    }
  }

  /// Apre il dettaglio dell'appuntamento indicato dal tocco su una notifica.
  ///
  /// Parte solo una volta per id: dopo una risposta o una ricarica il dialogo
  /// non si riapre da solo.
  void _apriAppuntamentoDaNotifica() {
    final id = widget.appuntamentoId?.trim() ?? '';
    if (id.isEmpty || _appuntamentoApertoDaNotifica || _caricamento) return;

    Appuntamento? trovato;
    for (final appuntamento in _appuntamenti) {
      if (appuntamento.id == id) {
        trovato = appuntamento;
        break;
      }
    }
    if (trovato == null) return;

    final elementi = elementiDaAppuntamenti([trovato]);
    if (elementi.isEmpty) return;
    _appuntamentoApertoDaNotifica = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _apriDettaglio(elementi.first);
    });
  }

  /// Nomi degli operatori per le card, con uid come fallback.
  Map<String, String> get _nomiOperatori => {
    for (final utente in _utenti) utente.uid: nomeUtenteAppuntamento(utente),
  };

  /// Uid dell'utente corrente, `null` se Firebase non è disponibile.
  String? get _uidCorrente {
    try {
      return ref.read(firebaseAuthProvider).currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

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
    return [...elementiDaAppuntamenti(appuntamenti), ...elementiDaTask(task)];
  }

  void _sposta(int verso) {
    setState(() {
      _giorno = spostaPeriodo(_vista, _giorno, verso);
    });
  }

  void _vaiAOggi() {
    final oggi = DateTime.now();
    setState(() => _giorno = DateTime(oggi.year, oggi.month, oggi.day));
  }

  /// Apre il giorno selezionato nella vista giornaliera.
  void _apriGiorno(DateTime giorno) {
    setState(() {
      _giorno = DateTime(giorno.year, giorno.month, giorno.day);
      _vista = VistaAgenda.giorno;
    });
  }

  /// Apre il form di un nuovo appuntamento con data (e ora) già impostate.
  Future<void> _apriNuovoAppuntamento({DateTime? giorno, String? ora}) async {
    final salvato = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppuntamentoFormScreen(
          dataIniziale: giorno ?? _giorno,
          oraIniziale: ora,
        ),
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
        uidCorrente: _uidCorrente,
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
    } else if (azione == azioneConfermaInvitoVoce ||
        azione == azioneRifiutaInvitoVoce) {
      await _rispondiInvito(
        appuntamento,
        disponibile: azione == azioneConfermaInvitoVoce,
      );
    }
  }

  /// Registra la conferma o il rifiuto dell'utente e ricarica l'agenda.
  Future<void> _rispondiInvito(
    Appuntamento appuntamento, {
    required bool disponibile,
  }) async {
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      await servizio.rispondiInvitoAppuntamento(
        appuntamento.id,
        disponibile: disponibile,
        nomeRispondente: _nomiOperatori[_uidCorrente] ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            disponibile
                ? 'Disponibilità confermata'
                : 'Disponibilità non confermata',
          ),
        ),
      );
      await _carica();
    } catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messaggioErroreAppuntamenti(errore))),
      );
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
        content: Text('L\'appuntamento $nome verrà eliminato definitivamente.'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Appuntamento eliminato')));
      await _carica();
    } catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messaggioErroreAppuntamenti(errore))),
      );
    }
  }

  /// Testo del periodo: giorno singolo, intervallo lunedì–domenica o mese.
  String get _etichettaPeriodo => etichettaPeriodo(_vista, _giorno);

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
                vista: _vista,
                stile: _stile,
                operatoreId: _operatoreId,
                operatori: {
                  for (final utente in _utenti)
                    utente.uid: nomeUtenteAppuntamento(utente),
                },
                onPrecedente: () => _sposta(-1),
                onSuccessivo: () => _sposta(1),
                onOggi: _vaiAOggi,
                onVista: (vista) => setState(() => _vista = vista),
                onStile: (stile) => setState(() => _stile = stile),
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
                  vista: _vista,
                  aCard: _stile == StileAgenda.card,
                  caricamento: _caricamento,
                  errore: _errore,
                  nomiOperatori: _nomiOperatori,
                  onRiprova: _carica,
                  onTapVoce: _apriDettaglio,
                  onTapGiorno: _apriGiorno,
                  onTapVuoto: (giorno, ora) =>
                      _apriNuovoAppuntamento(giorno: giorno, ora: ora),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Barra con navigazione del periodo, scelta della vista, filtro operatore e
/// pulsante "Nuovo appuntamento".
class _BarraCalendario extends StatelessWidget {
  const _BarraCalendario({
    required this.riga,
    required this.etichettaPeriodo,
    required this.vista,
    required this.stile,
    required this.operatoreId,
    required this.operatori,
    required this.onPrecedente,
    required this.onSuccessivo,
    required this.onOggi,
    required this.onVista,
    required this.onStile,
    required this.onOperatore,
    required this.onNuovo,
  });

  final bool riga;
  final String etichettaPeriodo;
  final VistaAgenda vista;
  final StileAgenda stile;
  final String operatoreId;
  final Map<String, String> operatori;
  final VoidCallback onPrecedente;
  final VoidCallback onSuccessivo;
  final VoidCallback onOggi;
  final ValueChanged<VistaAgenda> onVista;
  final ValueChanged<StileAgenda> onStile;
  final ValueChanged<String> onOperatore;
  final VoidCallback onNuovo;

  String get _tooltipPrecedente => switch (vista) {
    VistaAgenda.giorno => 'Giorno precedente',
    VistaAgenda.settimana => 'Settimana precedente',
    VistaAgenda.mese => 'Mese precedente',
  };

  String get _tooltipSuccessivo => switch (vista) {
    VistaAgenda.giorno => 'Giorno successivo',
    VistaAgenda.settimana => 'Settimana successiva',
    VistaAgenda.mese => 'Mese successivo',
  };

  @override
  Widget build(BuildContext context) {
    final navigazione = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('calendario-precedente'),
          tooltip: _tooltipPrecedente,
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
          tooltip: _tooltipSuccessivo,
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

    final selettoreVista = SegmentedButton<VistaAgenda>(
      key: const Key('calendario-vista'),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: VistaAgenda.giorno, label: Text('Giorno')),
        ButtonSegment(value: VistaAgenda.settimana, label: Text('Settimana')),
        ButtonSegment(value: VistaAgenda.mese, label: Text('Mese')),
      ],
      selected: {vista},
      onSelectionChanged: (selezione) => onVista(selezione.first),
    );

    final selettoreStile = SegmentedButton<StileAgenda>(
      key: const Key('calendario-stile'),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: StileAgenda.calendario,
          label: Text('Calendario'),
          icon: Icon(Icons.calendar_view_month_outlined),
        ),
        ButtonSegment(
          value: StileAgenda.card,
          label: Text('Card'),
          icon: Icon(Icons.view_agenda_outlined),
        ),
      ],
      selected: {stile},
      onSelectionChanged: (selezione) => onStile(selezione.first),
    );

    final filtro = SizedBox(
      width: 210,
      child: DropdownButtonFormField<String>(
        key: const Key('calendario-operatore'),
        initialValue: operatoreId,
        isExpanded: true,
        isDense: true,
        decoration: const InputDecoration(labelText: 'Utente', isDense: true),
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

    final pulsanteNuovo = IconButton.filled(
      key: const Key('calendario-nuovo-appuntamento'),
      tooltip: 'Nuovo appuntamento',
      onPressed: onNuovo,
      icon: const Icon(Icons.add),
      visualDensity: VisualDensity.compact,
    );

    final gruppoStile = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        selettoreStile,
        const SizedBox(width: AppSpazi.xxs),
        pulsanteNuovo,
      ],
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
            children: [selettoreVista, gruppoStile, filtro],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            navigazione,
            const SizedBox(width: AppSpazi.xs),
            pulsanteOggi,
          ],
        ),
        const SizedBox(height: AppSpazi.xs),
        Wrap(
          spacing: AppSpazi.s,
          runSpacing: AppSpazi.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [selettoreVista, gruppoStile, filtro],
        ),
      ],
    );
  }
}

/// Corpo del calendario: stati caricamento/errore/vuoto e viste classiche
/// (giorno, settimana, mese) o elenco a card.
///
/// È pubblico e senza provider per poter essere verificato con un widget test
/// senza Firebase.
class CorpoCalendario extends StatelessWidget {
  const CorpoCalendario({
    super.key,
    required this.elementi,
    required this.giorno,
    required this.vista,
    required this.aCard,
    required this.caricamento,
    required this.onRiprova,
    this.errore,
    this.nomiOperatori = const {},
    this.onTapVoce,
    this.onTapGiorno,
    this.onTapVuoto,
  });

  final List<ElementoAgenda> elementi;
  final DateTime giorno;
  final VistaAgenda vista;

  /// `true` per l'elenco a card, `false` per il calendario classico.
  final bool aCard;
  final bool caricamento;
  final Object? errore;
  final Map<String, String> nomiOperatori;
  final VoidCallback onRiprova;

  /// Azione al tocco di una voce; `null` disabilita l'apertura del dettaglio.
  final ValueChanged<ElementoAgenda>? onTapVoce;

  /// Passaggio al giorno selezionato da una vista più ampia.
  final ValueChanged<DateTime>? onTapGiorno;

  /// Tocco su uno spazio vuoto della griglia: giorno e ora proposti.
  final void Function(DateTime giorno, String ora)? onTapVuoto;

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

    if (aCard) {
      final voci = elementiNelPeriodo(elementi, vista, giorno);
      if (voci.isEmpty) {
        return const StatoCentrato(
          key: Key('calendario-vuoto'),
          icona: Icons.calendar_today_outlined,
          titolo: 'Nessun appuntamento',
          sottotitolo:
              'Non ci sono appuntamenti né task per questo periodo. Usa "Nuovo '
              'appuntamento" per aggiungerne uno.',
        );
      }

      return switch (vista) {
        VistaAgenda.giorno => _VistaGiornoCard(
          elementi: voci,
          giorno: giorno,
          nomiOperatori: nomiOperatori,
          onTapVoce: onTapVoce,
        ),
        VistaAgenda.settimana => _VistaSettimanaCard(
          elementi: voci,
          giorno: giorno,
          nomiOperatori: nomiOperatori,
          onTapVoce: onTapVoce,
        ),
        VistaAgenda.mese => _VistaMeseCard(
          elementi: voci,
          mese: giorno,
          nomiOperatori: nomiOperatori,
          onTapVoce: onTapVoce,
        ),
      };
    }

    return switch (vista) {
      VistaAgenda.giorno => VistaGrigliaOraria(
        giorni: [giorno],
        elementi: elementi,
        nomiOperatori: nomiOperatori,
        onTapVoce: onTapVoce,
        onTapVuoto: onTapVuoto,
        onTapGiorno: onTapGiorno,
      ),
      VistaAgenda.settimana => VistaGrigliaOraria(
        giorni: giorniSettimana(giorno),
        elementi: elementi,
        nomiOperatori: nomiOperatori,
        onTapVoce: onTapVoce,
        onTapVuoto: onTapVuoto,
        onTapGiorno: onTapGiorno,
      ),
      VistaAgenda.mese => VistaMeseCalendario(
        mese: giorno,
        elementi: elementi,
        onTapVoce: onTapVoce,
        onTapGiorno: onTapGiorno,
      ),
    };
  }
}

/// Vista giorno a elenco cronologico di card.
class _VistaGiornoCard extends StatelessWidget {
  const _VistaGiornoCard({
    required this.elementi,
    required this.giorno,
    required this.nomiOperatori,
    this.onTapVoce,
  });

  final List<ElementoAgenda> elementi;
  final DateTime giorno;
  final Map<String, String> nomiOperatori;
  final ValueChanged<ElementoAgenda>? onTapVoce;

  @override
  Widget build(BuildContext context) {
    final gruppi = raggruppaPerGiorno(elementi);
    final voci = gruppi[dataIsoVisita(giorno)] ?? const <ElementoAgenda>[];

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

/// Vista settimanale a card: una sezione per giorno, da lunedì a domenica.
class _VistaSettimanaCard extends StatelessWidget {
  const _VistaSettimanaCard({
    required this.elementi,
    required this.giorno,
    required this.nomiOperatori,
    this.onTapVoce,
  });

  final List<ElementoAgenda> elementi;
  final DateTime giorno;
  final Map<String, String> nomiOperatori;
  final ValueChanged<ElementoAgenda>? onTapVoce;

  @override
  Widget build(BuildContext context) {
    final gruppi = raggruppaPerGiorno(elementi);

    return ListView(
      key: const Key('calendario-settimana'),
      padding: const EdgeInsets.only(bottom: AppSpazi.l),
      children: [
        for (final voce in giorniSettimana(giorno))
          ..._sezione(context, voce, gruppi[dataIsoVisita(voce)] ?? const []),
      ],
    );
  }

  /// Intestazione del giorno e sue voci (o "Nessun appuntamento").
  List<Widget> _sezione(
    BuildContext context,
    DateTime giorno,
    List<ElementoAgenda> voci,
  ) {
    final tema = Theme.of(context);

    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpazi.xs),
        child: Row(
          children: [
            Text(
              nomiGiorni[giorno.weekday - 1],
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

/// Vista mensile a card: i giorni del mese che hanno delle voci.
class _VistaMeseCard extends StatelessWidget {
  const _VistaMeseCard({
    required this.elementi,
    required this.mese,
    required this.nomiOperatori,
    this.onTapVoce,
  });

  final List<ElementoAgenda> elementi;
  final DateTime mese;
  final Map<String, String> nomiOperatori;
  final ValueChanged<ElementoAgenda>? onTapVoce;

  @override
  Widget build(BuildContext context) {
    final gruppi = raggruppaPerGiorno(elementi);
    final tema = Theme.of(context);

    return ListView(
      key: const Key('calendario-mese-card'),
      padding: const EdgeInsets.only(bottom: AppSpazi.l),
      children: [
        for (final gruppo in gruppi.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpazi.xs),
            child: Row(
              children: [
                Text(
                  _intestazioneGiorno(gruppo.key),
                  style: tema.textTheme.titleSmall,
                ),
                const SizedBox(width: AppSpazi.xs),
                Text(
                  '${gruppo.value.length} '
                  '${gruppo.value.length == 1 ? 'voce' : 'voci'}',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (final voce in gruppo.value) ...[
            _CardElemento(
              elemento: voce,
              nomiOperatori: nomiOperatori,
              onTap: onTapVoce,
            ),
            const SizedBox(height: AppSpazi.xs),
          ],
          const SizedBox(height: AppSpazi.s),
        ],
      ],
    );
  }

  /// "Venerdì 24/10/2026" per l'intestazione della sezione.
  String _intestazioneGiorno(String data) {
    final iso = DateTime.tryParse(data);
    if (iso == null) return data;
    return '${nomiGiorni[iso.weekday - 1]} ${formattaDataVisita(iso)}';
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  if (etichettaCondivisioneElemento(elemento) != null) ...[
                    const SizedBox(height: AppSpazi.xxs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpazi.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: coloreCondivisioneElemento(elemento)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRaggi.chip),
                      ),
                      child: Text(
                        etichettaCondivisioneElemento(elemento)!,
                        style: tema.textTheme.labelSmall?.copyWith(
                          color: coloreCondivisioneElemento(elemento),
                        ),
                      ),
                    ),
                  ],
                ],
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
    this.uidCorrente,
  });

  final ElementoAgenda elemento;
  final Map<String, String> nomiOperatori;
  final String? uidCorrente;

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
        SnackBar(content: Text('Non è stato possibile aprire $descrizione.')),
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

    final invitati = appuntamento?.invitatiUids ?? const <String>[];
    final condivisione =
        appuntamento?.statoCondivisione ?? statoCondivisioneNonCondiviso;
    final invitato = uidCorrente != null && invitati.contains(uidCorrente);
    final risposteInvitati = [
      for (final uid in invitati)
        '${(nomiOperatori[uid] ?? '').trim().isEmpty ? uid : nomiOperatori[uid]}: '
            '${etichettaRispostaInvito(rispostaInvito(appuntamento?.conferme ?? const {}, uid))}',
    ].join('\n');

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
              etichetta: 'Cliente e utente',
              valore: dettaglioElemento(elemento, nomiOperatori),
            ),
            if (invitati.isNotEmpty) ...[
              _RigaDettaglio(
                etichetta: 'Condivisione',
                valore: etichettaStatoCondivisione(condivisione),
              ),
              _RigaDettaglio(etichetta: 'Invitati', valore: risposteInvitati),
            ],
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
            onPressed: () =>
                _apriLink(context, Uri.tryParse(callUrl), 'la call'),
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Apri call'),
          ),
        if (invitato) ...[
          FilledButton.icon(
            key: const Key('calendario-conferma-invito'),
            onPressed: () =>
                Navigator.of(context).pop(azioneConfermaInvitoVoce),
            icon: const Icon(Icons.check),
            label: const Text('Confermo'),
          ),
          TextButton.icon(
            key: const Key('calendario-rifiuta-invito'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(azioneRifiutaInvitoVoce),
            icon: const Icon(Icons.close),
            label: const Text('Non disponibile'),
          ),
        ],
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
