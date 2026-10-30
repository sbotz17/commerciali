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
import '../../data/models/allegato.dart';
import '../../data/models/cliente.dart';
import '../../data/models/appuntamento.dart';
import '../../data/models/task_item.dart';
import '../../data/models/user_profile.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';
import '../clienti/clienti_screen.dart' show ClienteFormScreen;
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
    final (dal, al) = _intervalloPeriodo();
    return [
      ...elementiDaAppuntamenti(appuntamenti, dal: dal, al: al),
      ...elementiDaTask(task),
    ];
  }

  /// Primo e ultimo giorno del periodo mostrato, per espandere le ripetizioni.
  (DateTime, DateTime) _intervalloPeriodo() {
    switch (_vista) {
      case VistaAgenda.giorno:
        return (_giorno, _giorno);
      case VistaAgenda.settimana:
        final giorni = giorniSettimana(_giorno);
        return (giorni.first, giorni.last);
      case VistaAgenda.mese:
        final giorni = giorniGrigliaMese(_giorno);
        return (giorni.first, giorni.last);
    }
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
    final esito = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => AppuntamentoFormScreen(
          dataIniziale: giorno ?? _giorno,
          oraIniziale: ora,
        ),
      ),
    );
    if (esito?['salvato'] == true) {
      await _carica();
      _mostraMessaggioAvvisoCliente(esito?['messaggio']);
    }
  }

  /// Mostra l'esito dell'avviso al cliente dopo il ritorno dal form.
  void _mostraMessaggioAvvisoCliente(Object? messaggio) {
    final testo = messaggio?.toString().trim() ?? '';
    if (testo.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }

  /// Apre il dettaglio della voce e gestisce l'azione scelta.
  Future<void> _apriDettaglio(ElementoAgenda elemento) async {
    var allegati = const <Allegato>[];
    final appuntamentoPerAllegati = elemento.appuntamento;
    if (appuntamentoPerAllegati != null) {
      try {
        final servizio = ref.read(spServiceProvider);
        servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
        allegati = await servizio.getAllegati(appuntamentoPerAllegati.id);
      } catch (_) {
        // Il dettaglio resta disponibile anche senza allegati.
      }
    }
    Cliente? cliente;
    final appuntamento = elemento.appuntamento;
    final clienteId = appuntamento?.clienteId?.trim() ?? '';
    if (appuntamento != null &&
        clienteId.isNotEmpty &&
        puoVedereDettagliAppuntamento(appuntamento, _uidCorrente)) {
      try {
        final servizio = ref.read(spServiceProvider);
        servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
        cliente = await servizio.getCliente(clienteId);
      } catch (_) {
        // Il dettaglio resta disponibile anche senza i dati del cliente.
      }
    }
    if (!mounted) return;
    final azione = await showDialog<String>(
      context: context,
      builder: (_) => DettaglioElementoDialog(
        elemento: elemento,
        nomiOperatori: _nomiOperatori,
        uidCorrente: _uidCorrente,
        cliente: cliente,
        allegati: allegati,
        onApriAllegato: _apriAllegatoDaDettaglio,
      ),
    );
    if (!mounted || azione == null) return;

    if (azione == azioneApriTaskVoce) {
      context.go('/task');
      return;
    }

    if (appuntamento == null) return;
    if (azione == azioneModificaVoce) {
      await _modificaAppuntamento(appuntamento);
    } else if (azione == azioneEliminaVoce) {
      await _eliminaAppuntamento(appuntamento);
    } else if (azione == azioneModificaClienteVoce) {
      if (cliente != null) await _modificaCliente(cliente, appuntamento);
    } else if (azione == azioneInviaPromemoriaClienteVoce) {
      await _inviaPromemoriaCliente(appuntamento, cliente);
    } else if (azione == azioneConfermaInvitoVoce ||
        azione == azioneRifiutaInvitoVoce) {
      await _rispondiInvito(
        appuntamento,
        disponibile: azione == azioneConfermaInvitoVoce,
      );
    }
  }

  /// Apre il cliente collegato, salva e aggiorna il nome denormalizzato
  /// nell'appuntamento.
  Future<void> _modificaCliente(
    Cliente cliente,
    Appuntamento appuntamento,
  ) async {
    final salvato = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ClienteFormScreen(cliente: cliente)),
    );
    if (salvato != true || !mounted) return;

    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final aggiornato = await servizio.getCliente(cliente.id);
      if (aggiornato != null &&
          ((aggiornato.nome ?? '').trim() !=
                  (appuntamento.clienteNome ?? '').trim() ||
              (aggiornato.telefono ?? '').trim() !=
                  (appuntamento.clienteTelefono ?? '').trim() ||
              (aggiornato.email ?? '').trim() !=
                  (appuntamento.clienteEmail ?? '').trim())) {
        await servizio.aggiornaContattiClienteAppuntamento(
          appuntamento.id,
          nome: aggiornato.nome,
          telefono: aggiornato.telefono,
          email: aggiornato.email,
        );
      }
      await _carica();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cliente aggiornato')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente non aggiornato. Riprova.')),
      );
    }
  }

  /// Invia di nuovo il promemoria al cliente, senza aspettare un cambio di data.
  ///
  /// Il Worker ricompone il testo dal documento e applica comunque il limite di
  /// frequenza; `forza` serve solo a superare il blocco "già inviato" per lo
  /// stesso orario.
  Future<void> _inviaPromemoriaCliente(
    Appuntamento appuntamento,
    Cliente? cliente,
  ) async {
    final telefono = (appuntamento.clienteTelefono ?? '').trim().isNotEmpty
        ? appuntamento.clienteTelefono!.trim()
        : (cliente?.telefono ?? '').trim();
    final email = (appuntamento.clienteEmail ?? '').trim().isNotEmpty
        ? appuntamento.clienteEmail!.trim()
        : (cliente?.email ?? '').trim();
    final canali = <String>[
      if (appuntamento.canaliCliente.contains('whatsapp') &&
          telefono.isNotEmpty)
        'whatsapp',
      if (appuntamento.canaliCliente.contains('email') && email.isNotEmpty)
        'email',
    ];
    if (canali.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nessun canale con recapito: controlla telefono, email e canali '
            'dell\'appuntamento.',
          ),
        ),
      );
      return;
    }
    final destinatario = canali.contains('whatsapp') ? telefono : email;
    final conferma = await showDialog<bool>(
      context: context,
      builder: (dialogoContext) => AlertDialog(
        title: const Text('Inviare il promemoria?'),
        content: Text(
          'Il cliente riceverà un messaggio su '
          '${canali.map((canale) => canale == 'whatsapp' ? 'WhatsApp' : 'Email').join(' e ')}'
          '${destinatario.isEmpty ? '' : ' ($destinatario)'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogoContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const Key('calendario-conferma-invio-promemoria'),
            onPressed: () => Navigator.of(dialogoContext).pop(true),
            child: const Text('Invia'),
          ),
        ],
      ),
    );
    if (conferma != true || !mounted) return;
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final esito = await servizio.inviaPromemoriaCliente(
        appuntamentoId: appuntamento.id,
        canali: canali,
        modifica: false,
        forza: true,
      );
      if (!mounted) return;
      final risultati = esito['risultati'];
      final etichetta = etichettaPromemoriaCliente(
        risultati is Map ? {'canali': risultati} : null,
      );
      final saltato = (esito['saltato'] ?? '').toString();
      final messaggio = switch (saltato) {
        'passato' => 'Promemoria non inviato: l\'appuntamento è nel passato.',
        'disattivato' =>
          'Promemoria non inviato: l\'avviso al cliente è disattivato.',
        'gia_inviato' => 'Promemoria già inviato per questo orario.',
        'in_corso' => 'Invio già in corso. Attendi qualche secondo.',
        'nessun_canale' => 'Nessun canale selezionato per il cliente.',
        _ =>
          etichetta.isEmpty
              ? 'Promemoria cliente non inviato.'
              : 'Promemoria cliente: $etichetta',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(messaggio)));
      await _carica();
    } catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Promemoria non inviato: ${errore is StateError ? errore.message : 'riprova.'}',
          ),
        ),
      );
    }
  }

  Future<void> _apriAllegatoDaDettaglio(Allegato allegato) async {
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final link = await servizio.linkAllegato(allegato);
      if (link == null) throw StateError('Link non disponibile');
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire l\'allegato.')),
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
    final esito = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => AppuntamentoFormScreen(appuntamento: appuntamento),
      ),
    );
    if (esito?['salvato'] == true) {
      await _carica();
      _mostraMessaggioAvvisoCliente(esito?['messaggio']);
    }
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
      await servizio.annullaPromemoria(appuntamento.id);
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
                  uidCorrente: _uidCorrente,
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
    this.uidCorrente,
    this.onTapVoce,
    this.onTapGiorno,
    this.onTapVuoto,
  });

  final List<ElementoAgenda> elementi;
  final DateTime giorno;
  final VistaAgenda vista;
  final String? uidCorrente;

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
          uidCorrente: uidCorrente,
          onTapVoce: onTapVoce,
        ),
        VistaAgenda.settimana => _VistaSettimanaCard(
          elementi: voci,
          giorno: giorno,
          nomiOperatori: nomiOperatori,
          uidCorrente: uidCorrente,
          onTapVoce: onTapVoce,
        ),
        VistaAgenda.mese => _VistaMeseCard(
          elementi: voci,
          mese: giorno,
          nomiOperatori: nomiOperatori,
          uidCorrente: uidCorrente,
          onTapVoce: onTapVoce,
        ),
      };
    }

    return switch (vista) {
      VistaAgenda.giorno => VistaGrigliaOraria(
        giorni: [giorno],
        elementi: elementi,
        nomiOperatori: nomiOperatori,
        uidCorrente: uidCorrente,
        onTapVoce: onTapVoce,
        onTapVuoto: onTapVuoto,
        onTapGiorno: onTapGiorno,
      ),
      VistaAgenda.settimana => VistaGrigliaOraria(
        giorni: giorniSettimana(giorno),
        elementi: elementi,
        nomiOperatori: nomiOperatori,
        uidCorrente: uidCorrente,
        onTapVoce: onTapVoce,
        onTapVuoto: onTapVuoto,
        onTapGiorno: onTapGiorno,
      ),
      VistaAgenda.mese => VistaMeseCalendario(
        mese: giorno,
        elementi: elementi,
        uidCorrente: uidCorrente,
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
    this.uidCorrente,
    this.onTapVoce,
  });

  final List<ElementoAgenda> elementi;
  final DateTime giorno;
  final Map<String, String> nomiOperatori;
  final String? uidCorrente;
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
        uidCorrente: uidCorrente,
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
    this.uidCorrente,
    this.onTapVoce,
  });

  final List<ElementoAgenda> elementi;
  final DateTime giorno;
  final Map<String, String> nomiOperatori;
  final String? uidCorrente;
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
            uidCorrente: uidCorrente,
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
    this.uidCorrente,
    this.onTapVoce,
  });

  final List<ElementoAgenda> elementi;
  final DateTime mese;
  final Map<String, String> nomiOperatori;
  final String? uidCorrente;
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
              uidCorrente: uidCorrente,
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
    this.uidCorrente,
    this.onTap,
  });

  final ElementoAgenda elemento;
  final Map<String, String> nomiOperatori;
  final String? uidCorrente;
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
                width: 64,
                child: Text(
                  etichettaOrarioElemento(elemento),
                  maxLines: 2,
                  style: elemento.appuntamento?.tuttoIlGiorno == true
                      ? tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        )
                      : tema.textTheme.titleSmall,
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
                      titoloVisibileElemento(elemento, uidCorrente),
                      style: tema.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpazi.xxs),
                    Text(
                      dettaglioVisibileElemento(
                        elemento,
                        nomiOperatori,
                        uidCorrente,
                      ),
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
/// Su telefono il contenuto scorre e le azioni sono impilate a tutta
/// larghezza; da tablet in su restano su una riga allineata a destra.
///
/// Le azioni che cambiano i dati tornano al chiamante con uno dei valori
/// `azioneModificaVoce`, `azioneEliminaVoce`, `azioneApriTaskVoce`,
/// `azioneModificaClienteVoce`; i link esterni (Maps e call) vengono aperti
/// qui.
class DettaglioElementoDialog extends StatelessWidget {
  const DettaglioElementoDialog({
    super.key,
    required this.elemento,
    required this.nomiOperatori,
    this.uidCorrente,
    this.cliente,
    this.allegati = const [],
    this.onApriAllegato,
  });

  final ElementoAgenda elemento;
  final Map<String, String> nomiOperatori;
  final String? uidCorrente;
  final Cliente? cliente;
  final List<Allegato> allegati;
  final ValueChanged<Allegato>? onApriAllegato;

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
    final dettagliVisibili = puoVedereDettagliAppuntamento(
      appuntamento,
      uidCorrente,
    );

    final indirizzo = dettagliVisibili
        ? (appuntamento?.indirizzo?.trim() ?? '')
        : '';
    final maps = indirizzo.isEmpty ? null : uriMapsIndirizzo(indirizzo);
    final callUrl = dettagliVisibili
        ? (appuntamento?.callUrl?.trim() ?? '')
        : '';
    final luogo = dettagliVisibili ? (appuntamento?.luogo?.trim() ?? '') : '';
    final descrizione = dettagliVisibili
        ? (task?.descrizione?.trim() ?? '')
        : '';
    final note = dettagliVisibili
        ? (appuntamento?.note ?? task?.note ?? '').trim()
        : '';

    final stretto = MediaQuery.sizeOf(context).width < AppBreakpoints.telefono;
    final invitati = appuntamento?.invitatiUids ?? const <String>[];
    final condivisione =
        appuntamento?.statoCondivisione ?? statoCondivisioneNonCondiviso;
    final invitato = uidCorrente != null && invitati.contains(uidCorrente);
    String nomeInvitato(String uid) {
      final nome = (nomiOperatori[uid] ?? '').trim();
      return nome.isEmpty ? uid : nome;
    }

    final avvisoCliente = etichettaPromemoriaCliente(
      appuntamento?.promemoriaCliente,
    );
    final telefonoAvviso =
        (appuntamento?.clienteTelefono ?? '').trim().isNotEmpty
        ? appuntamento!.clienteTelefono!.trim()
        : (cliente?.telefono ?? '').trim();
    final emailAvviso = (appuntamento?.clienteEmail ?? '').trim().isNotEmpty
        ? appuntamento!.clienteEmail!.trim()
        : (cliente?.email ?? '').trim();
    final canaliConRecapito = <String>[
      if (appuntamento?.canaliCliente.contains('whatsapp') == true &&
          telefonoAvviso.isNotEmpty)
        'whatsapp',
      if (appuntamento?.canaliCliente.contains('email') == true &&
          emailAvviso.isNotEmpty)
        'email',
    ];
    final puoInviarePromemoria =
        dettagliVisibili &&
        appuntamento?.avvisaCliente == true &&
        canaliConRecapito.isNotEmpty;
    final dataAvvisoCliente = dataPromemoriaCliente(
      appuntamento?.promemoriaCliente,
    );

    final panoramica = <Widget>[
      if (appuntamento?.privato == true)
        _RigaDettaglio(
          etichetta: 'Privacy',
          valore: dettagliVisibili
              ? 'Appuntamento privato'
              : 'Dettagli visibili solo al creatore e all\'utente assegnato',
        ),
      if (dettagliVisibili)
        _RigaDettaglio(
          etichetta: 'Cliente e utente',
          valore: dettaglioElemento(elemento, nomiOperatori),
        ),
      if (dettagliVisibili && avvisoCliente.isNotEmpty)
        _RigaDettaglio(
          etichetta: 'Promemoria cliente',
          valore: dataAvvisoCliente.isEmpty
              ? avvisoCliente
              : '$avvisoCliente · $dataAvvisoCliente',
        ),
      if (puoInviarePromemoria)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('calendario-invia-promemoria-cliente'),
            onPressed: () =>
                Navigator.of(context).pop(azioneInviaPromemoriaClienteVoce),
            icon: const Icon(Icons.send_outlined, size: 18),
            label: Text(
              avvisoCliente.isEmpty
                  ? 'Invia promemoria al cliente'
                  : 'Invia di nuovo',
            ),
          ),
        ),
      if (dettagliVisibili && appuntamento != null) ...[
        _RigaDettaglio(
          etichetta: 'Ripetizione',
          valore: etichettaRipetizione(appuntamento.ripetizione),
        ),
        _RigaDettaglio(
          etichetta: 'Notifica',
          valore: etichettaNotificaAppuntamento(appuntamento.notificaMin),
        ),
      ],
    ];

    final dettagli = <Widget>[
      if (luogo.isNotEmpty) _RigaDettaglio(etichetta: 'Luogo', valore: luogo),
      if (indirizzo.isNotEmpty)
        _RigaDettaglio(etichetta: 'Indirizzo', valore: indirizzo),
      if (maps != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('calendario-maps'),
            onPressed: () => _apriLink(context, maps, 'Google Maps'),
            icon: const Icon(Icons.directions_outlined, size: 18),
            label: const Text('Apri in Google Maps'),
          ),
        ),
      if (callUrl.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('calendario-call'),
            onPressed: () =>
                _apriLink(context, Uri.tryParse(callUrl), 'la call'),
            icon: const Icon(Icons.videocam_outlined, size: 18),
            label: const Text('Apri call'),
          ),
        ),
      if (descrizione.isNotEmpty)
        _RigaDettaglio(etichetta: 'Descrizione', valore: descrizione),
      if (note.isNotEmpty) _RigaDettaglio(etichetta: 'Note', valore: note),
    ];

    final contenutiCliente = <Widget>[
      if (dettagliVisibili && cliente != null) ...[
        if (cliente!.tipoCliente.trim().isNotEmpty)
          _RigaDettaglio(
            etichetta: 'Tipo',
            valore: cliente!.tipoCliente.trim(),
          ),
        if ((cliente!.nome ?? '').trim().isNotEmpty)
          _RigaDettaglio(etichetta: 'Nome', valore: cliente!.nome!.trim()),
        if ((cliente!.referente ?? '').trim().isNotEmpty)
          _RigaDettaglio(
            etichetta: 'Referente',
            valore: cliente!.referente!.trim(),
          ),
        if ((cliente!.telefono ?? '').trim().isNotEmpty)
          _RigaDettaglio(
            etichetta: 'Telefono',
            valore: cliente!.telefono!.trim(),
          ),
        if ((cliente!.email ?? '').trim().isNotEmpty)
          _RigaDettaglio(etichetta: 'Email', valore: cliente!.email!.trim()),
        if ((cliente!.piva ?? '').trim().isNotEmpty)
          _RigaDettaglio(etichetta: 'P.IVA', valore: cliente!.piva!.trim()),
        if ((cliente!.codiceFiscale ?? '').trim().isNotEmpty)
          _RigaDettaglio(
            etichetta: 'Codice fiscale',
            valore: cliente!.codiceFiscale!.trim(),
          ),
        if (indirizzoCliente(cliente!).isNotEmpty)
          _RigaDettaglio(
            etichetta: 'Indirizzo',
            valore: indirizzoCliente(cliente!),
          ),
        if ((cliente!.settore ?? '').trim().isNotEmpty)
          _RigaDettaglio(
            etichetta: 'Settore',
            valore: cliente!.settore!.trim(),
          ),
        if ((cliente!.ateco ?? '').trim().isNotEmpty)
          _RigaDettaglio(etichetta: 'ATECO', valore: cliente!.ateco!.trim()),
        if ((cliente!.regione ?? '').trim().isNotEmpty)
          _RigaDettaglio(
            etichetta: 'Regione',
            valore: cliente!.regione!.trim(),
          ),
        if ((cliente!.note ?? '').trim().isNotEmpty)
          _RigaDettaglio(
            etichetta: 'Note cliente',
            valore: cliente!.note!.trim(),
          ),
        const SizedBox(height: AppSpazi.xs),
        OutlinedButton.icon(
          key: const Key('calendario-modifica-cliente'),
          onPressed: () => Navigator.of(context).pop(azioneModificaClienteVoce),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Modifica cliente'),
        ),
      ],
    ];

    // Azioni raggruppate: prima la risposta all'invito, poi la gestione
    // dell'appuntamento. Su telefono i gruppi restano vicini; su schermo
    // largo le azioni principali stanno a destra.
    final azioniRisposta = <Widget>[];
    final azioniProprietario = <Widget>[];
    final azioniPrincipali = <Widget>[];
    final azioniSecondarie = <Widget>[];
    final coloreErrore = Theme.of(context).colorScheme.error;

    if (invitato) {
      final conferma = FilledButton.icon(
        key: const Key('calendario-conferma-invito'),
        onPressed: () => Navigator.of(context).pop(azioneConfermaInvitoVoce),
        icon: const Icon(Icons.check),
        label: const Text('Confermo'),
      );
      azioniRisposta.add(conferma);
      azioniPrincipali.add(conferma);

      final rifiuta = OutlinedButton.icon(
        key: const Key('calendario-rifiuta-invito'),
        style: OutlinedButton.styleFrom(
          foregroundColor: coloreErrore,
          side: BorderSide(color: coloreErrore),
        ),
        onPressed: () => Navigator.of(context).pop(azioneRifiutaInvitoVoce),
        icon: const Icon(Icons.close),
        label: const Text('Non disponibile'),
      );
      azioniRisposta.add(rifiuta);
      azioniSecondarie.add(rifiuta);
    }

    if (dettagliVisibili && elemento.isAppuntamento) {
      final modifica = FilledButton.tonalIcon(
        key: const Key('calendario-modifica'),
        onPressed: () => Navigator.of(context).pop(azioneModificaVoce),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Modifica'),
      );
      azioniProprietario.add(modifica);
      azioniPrincipali.add(modifica);

      final elimina = TextButton.icon(
        key: const Key('calendario-elimina'),
        style: TextButton.styleFrom(foregroundColor: coloreErrore),
        onPressed: () => Navigator.of(context).pop(azioneEliminaVoce),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Elimina'),
      );
      azioniProprietario.add(elimina);
      azioniSecondarie.add(elimina);
    } else if (dettagliVisibili) {
      final apriTask = FilledButton.tonalIcon(
        key: const Key('calendario-apri-task'),
        onPressed: () => Navigator.of(context).pop(azioneApriTaskVoce),
        icon: const Icon(Icons.open_in_new),
        label: const Text('Apri Task'),
      );
      azioniProprietario.add(apriTask);
      azioniPrincipali.add(apriTask);
    }

    final tutteLeAzioni = stretto
        ? [...azioniRisposta, ...azioniProprietario]
        : [...azioniSecondarie, ...azioniPrincipali];
    final barraAzioni = tutteLeAzioni.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpazi.m,
              AppSpazi.s,
              AppSpazi.m,
              AppSpazi.m,
            ),
            child: stretto
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < tutteLeAzioni.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpazi.xs),
                        tutteLeAzioni[i],
                      ],
                    ],
                  )
                : Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpazi.s,
                    runSpacing: AppSpazi.xs,
                    children: [
                      if (azioniSecondarie.isNotEmpty)
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: AppSpazi.xs,
                          runSpacing: AppSpazi.xs,
                          children: azioniSecondarie,
                        ),
                      if (azioniPrincipali.isNotEmpty)
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: AppSpazi.xs,
                          runSpacing: AppSpazi.xs,
                          children: azioniPrincipali,
                        ),
                    ],
                  ),
          );

    final larghezzaDialogo = (MediaQuery.sizeOf(context).width - 24).clamp(
      280.0,
      560.0,
    );

    return Dialog(
      key: const Key('calendario-dettaglio'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: larghezzaDialogo,
          maxHeight: MediaQuery.sizeOf(context).height - 32,
        ),
        child: SizedBox(
          key: const Key('calendario-dettaglio-contenuto'),
          width: larghezzaDialogo,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpazi.m,
                  AppSpazi.s,
                  AppSpazi.xs,
                  AppSpazi.s,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dettagliVisibili
                                ? elemento.titolo
                                : 'Impegno privato',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpazi.xxs),
                          Text(
                            '${etichettaDataOraElemento(elemento)} · '
                            '${etichettaStatoElemento(elemento)}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('calendario-chiudi'),
                      tooltip: 'Chiudi',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpazi.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (panoramica.isNotEmpty)
                        _SezioneDettaglio(
                          titolo: 'Panoramica',
                          children: panoramica,
                        ),
                      if (contenutiCliente.isNotEmpty) ...[
                        const SizedBox(height: AppSpazi.m),
                        _SezioneDettaglio(
                          titolo: 'Cliente',
                          children: contenutiCliente,
                        ),
                      ],
                      if (dettagliVisibili && invitati.isNotEmpty) ...[
                        const SizedBox(height: AppSpazi.m),
                        _SezioneDettaglio(
                          titolo: 'Condivisione',
                          children: [
                            _RigaDettaglio(
                              etichetta: 'Stato',
                              valore: etichettaStatoCondivisione(condivisione),
                            ),
                            for (final uid in invitati)
                              _RigaInvitato(
                                nome: nomeInvitato(uid),
                                stato: rispostaInvito(
                                  appuntamento?.conferme ?? const {},
                                  uid,
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (dettagli.isNotEmpty) ...[
                        const SizedBox(height: AppSpazi.m),
                        _SezioneDettaglio(
                          titolo: 'Dettagli',
                          children: dettagli,
                        ),
                      ],
                      if (dettagliVisibili && allegati.isNotEmpty) ...[
                        const SizedBox(height: AppSpazi.m),
                        _SezioneDettaglio(
                          titolo: 'Allegati',
                          children: [
                            Wrap(
                              spacing: AppSpazi.xs,
                              runSpacing: AppSpazi.xs,
                              children: [
                                for (final allegato in allegati)
                                  ActionChip(
                                    key: Key(
                                      'calendario-allegato-${allegato.id}',
                                    ),
                                    avatar: Icon(
                                      allegato.immagine
                                          ? Icons.image_outlined
                                          : allegato.video
                                          ? Icons.videocam_outlined
                                          : Icons.attach_file,
                                      size: 16,
                                    ),
                                    label: Text(allegato.nome),
                                    onPressed: onApriAllegato == null
                                        ? null
                                        : () => onApriAllegato!(allegato),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (barraAzioni != null) ...[
                const Divider(height: 1),
                barraAzioni,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Indirizzo completo del cliente, con le parti presenti.
String indirizzoCliente(Cliente cliente) {
  final parti =
      [
            cliente.indirizzo,
            cliente.civico,
            cliente.cap,
            cliente.citta,
            cliente.provincia,
          ]
          .where((parte) => (parte ?? '').trim().isNotEmpty)
          .map((parte) => parte!.trim());
  return parti.join(', ');
}

/// Sezione del dettaglio con titolo e contenuto, su sfondo leggero.
class _SezioneDettaglio extends StatelessWidget {
  const _SezioneDettaglio({required this.titolo, required this.children});

  final String titolo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpazi.s),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRaggi.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titolo, style: tema.textTheme.titleSmall),
          const SizedBox(height: AppSpazi.xs),
          ...children,
        ],
      ),
    );
  }
}

/// Riga di un invitato con lo stato della sua risposta.
class _RigaInvitato extends StatelessWidget {
  const _RigaInvitato({required this.nome, required this.stato});

  final String nome;
  final String? stato;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final confermato = stato == 'confermato';
    final rifiutato = stato == 'rifiutato';
    final colore = confermato
        ? tema.colorScheme.primary
        : rifiutato
        ? tema.colorScheme.error
        : tema.colorScheme.onSurfaceVariant;
    final icona = confermato
        ? Icons.check_circle_outline
        : rifiutato
        ? Icons.cancel_outlined
        : Icons.schedule;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpazi.xs),
      child: Row(
        children: [
          Icon(icona, size: 18, color: colore),
          const SizedBox(width: AppSpazi.xs),
          Expanded(child: Text(nome, style: tema.textTheme.bodyMedium)),
          const SizedBox(width: AppSpazi.xs),
          Text(
            etichettaRispostaInvito(stato),
            style: tema.textTheme.labelMedium?.copyWith(color: colore),
          ),
        ],
      ),
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
