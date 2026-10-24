import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../data/models/appuntamento.dart';
import '../../data/models/cliente.dart';
import '../../data/models/stanza_chat.dart';
import '../../data/models/user_profile.dart';
import '../../data/services/sp_service.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';
import '../clienti/clienti_screen.dart' show ClienteFormScreen;
import '../visite/visite_screen.dart'
    show
        dataIsoVisita,
        formattaDataVisita,
        normalizzaOraVisita,
        parseDataItaliana;
import 'dialogo_condivisione_appuntamento.dart';

// ---------------------------------------------------------------------------
// Funzioni pure: stati, validazioni, link Maps e messaggi (verificabili senza
// Firebase né UI)
// ---------------------------------------------------------------------------

/// Etichette italiane degli stati dell'appuntamento (chiavi Firestore).
const Map<String, String> statiAppuntamento = {
  'da_fare': 'Da fare',
  'fatto': 'Fatto',
  'annullato': 'Annullato',
};

/// Validazione del titolo: obbligatorio.
String? validaTitoloAppuntamento(String? valore) {
  final titolo = valore?.trim() ?? '';
  if (titolo.isEmpty) return 'Inserisci il titolo dell\'appuntamento';
  return null;
}

/// Validazione della data: obbligatoria e in formato italiano `gg/mm/aaaa`.
String? validaDataAppuntamento(String? valore) {
  if (parseDataItaliana(valore) == null) {
    return 'Inserisci una data valida (gg/mm/aaaa)';
  }
  return null;
}

/// Provider di call selezionabili nel form. `nessuna` è solo un valore UI.
const Map<String, String> providerCallAppuntamento = {
  'nessuna': 'Nessuna call',
  'google_meet': 'Google Meet',
  'teams': 'Microsoft Teams',
  'manuale': 'Altro link',
};

/// Validazione della call: se c'è un provider serve un link http/https valido.
///
/// Con provider `nessuna` (o assente) il link non è richiesto e viene ignorato.
String? validaCallAppuntamento(String? provider, String? link) {
  final p = (provider ?? '').trim();
  final testo = (link ?? '').trim();
  if (p.isEmpty || p == 'nessuna') {
    return null;
  }
  if (testo.isEmpty) {
    return 'Incolla il link della call o scegli "Nessuna call"';
  }
  final uri = Uri.tryParse(testo);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty) {
    return 'Inserisci un link valido (https://...)';
  }
  return null;
}

/// Colore del badge di stato della condivisione.
Color coloreStatoCondivisione(String stato) {
  switch (stato.trim().toLowerCase()) {
    case statoCondivisioneConfermato:
      return AppColors.accettato;
    case statoCondivisioneRifiutato:
      return AppColors.errore;
    case statoCondivisioneInAttesa:
      return AppColors.attesa;
    default:
      return AppColors.attesa;
  }
}

/// Link Google Maps per raggiungere [indirizzo], o `null` se è vuoto.
///
/// Il link usa lo schema `https` (mai schemi diversi da http/https) e la
/// destinazione viene codificata da [Uri], così spazi e caratteri speciali
/// non rompono l'URL.
Uri? uriMapsIndirizzo(String? indirizzo) {
  final destinazione = indirizzo?.trim() ?? '';
  if (destinazione.isEmpty) return null;
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': destinazione,
  });
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return uri;
}

/// Messaggio in italiano per gli errori di caricamento/salvataggio.
String messaggioErroreAppuntamenti(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per gestire gli appuntamenti. '
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

/// Nome del cliente per la tendina, con fallback per i documenti senza nome.
String nomeClienteAppuntamento(Cliente cliente) {
  final nome = cliente.nome?.trim() ?? '';
  return nome.isEmpty ? '(senza nome)' : nome;
}

/// Nome dell'utente per la tendina operatore, con fallback su username/email.
String nomeUtenteAppuntamento(UserProfile utente) {
  for (final valore in [utente.nome, utente.username, utente.email]) {
    final testo = valore?.trim() ?? '';
    if (testo.isNotEmpty) return testo;
  }
  return 'Utente';
}

/// Validazione dell'ora: facoltativa, ma se presente deve essere `HH:MM`.
String? _validaOraAppuntamento(String? valore) {
  final testo = valore?.trim() ?? '';
  if (testo.isEmpty) return null;
  if (normalizzaOraVisita(testo) == null) {
    return 'Inserisci un\'ora valida (HH:MM)';
  }
  return null;
}

/// Validazione della durata: intera e maggiore di zero.
String? _validaDurataAppuntamento(String? valore) {
  final minuti = int.tryParse(valore?.trim() ?? '');
  if (minuti == null) return 'Inserisci la durata in minuti';
  if (minuti <= 0) return 'La durata deve essere maggiore di zero';
  return null;
}

DateTime _soloGiorno(DateTime data) =>
    DateTime(data.year, data.month, data.day);

/// Giorno di un appuntamento esistente, ricavato da data e ora (o solo data).
DateTime? _giornoAppuntamento(Appuntamento? appuntamento) {
  if (appuntamento == null) return null;
  final combinata = dataOraAppuntamento(appuntamento);
  if (combinata != null) return _soloGiorno(combinata);
  final iso = DateTime.tryParse(appuntamento.data?.trim() ?? '');
  return iso == null ? null : _soloGiorno(iso);
}

/// Ora `HH:MM` di un testo già digitato; `null` se non è un'ora valida.
TimeOfDay? _oraDaTesto(String? testo) {
  final normalizzata = normalizzaOraVisita(testo);
  if (normalizzata == null) return null;
  final parti = normalizzata.split(':');
  return TimeOfDay(
    hour: int.tryParse(parti[0]) ?? 0,
    minute: int.tryParse(parti[1]) ?? 0,
  );
}

// ---------------------------------------------------------------------------
// Form
// ---------------------------------------------------------------------------

/// Form completo di un appuntamento, aperto a pagina intera (nuovo o modifica).
class AppuntamentoFormScreen extends ConsumerStatefulWidget {
  const AppuntamentoFormScreen({
    super.key,
    this.appuntamento,
    this.dataIniziale,
    this.oraIniziale,
  });

  /// Appuntamento da modificare; `null` per crearne uno nuovo.
  final Appuntamento? appuntamento;

  /// Giorno proposto per un nuovo appuntamento (default: oggi).
  final DateTime? dataIniziale;

  /// Ora `HH:MM` proposta per un nuovo appuntamento (default: vuota).
  final String? oraIniziale;

  @override
  ConsumerState<AppuntamentoFormScreen> createState() =>
      _AppuntamentoFormScreenState();
}

class _AppuntamentoFormScreenState
    extends ConsumerState<AppuntamentoFormScreen> {
  final _modulo = GlobalKey<FormState>();

  late final TextEditingController _titolo;
  late final TextEditingController _data;
  late final TextEditingController _ora;
  late final TextEditingController _durata;
  late final TextEditingController _luogo;
  late final TextEditingController _indirizzo;
  late final TextEditingController _note;
  late final TextEditingController _callUrl;

  late DateTime _dataScelta;
  late String _stato;
  late String _callProvider;
  String? _clienteId;
  String? _operatoreId;

  List<Cliente> _clienti = const [];
  List<UserProfile> _utenti = const [];
  List<StanzaChat> _gruppi = const [];
  List<String> _invitatiUids = const [];
  Map<String, dynamic> _conferme = const {};
  bool _caricamentoClienti = true;
  bool _caricamentoUtenti = true;
  bool _caricamentoGruppi = true;
  Object? _erroreClienti;

  /// Nomi degli utenti dell'azienda per il dialogo di condivisione.
  Map<String, String> get _nomiUtenti => {
    for (final utente in _utenti) utente.uid: nomeUtenteAppuntamento(utente),
  };

  /// Stato della condivisione calcolato dalle risposte presenti nel form.
  String get _statoCondivisione =>
      statoCondivisioneDaConferme(_invitatiUids, _conferme);

  bool _salvando = false;
  String? _errore;

  bool get _modifica => widget.appuntamento != null;

  @override
  void initState() {
    super.initState();
    final appuntamento = widget.appuntamento;

    _dataScelta =
        _giornoAppuntamento(appuntamento) ??
        _soloGiorno(widget.dataIniziale ?? DateTime.now());
    _titolo = TextEditingController(text: appuntamento?.titolo ?? '');
    _data = TextEditingController(text: formattaDataVisita(_dataScelta));
    _ora = TextEditingController(
      text: appuntamento?.ora ?? widget.oraIniziale ?? '',
    );
    _durata = TextEditingController(
      text: (appuntamento?.durataMin ?? 60).toString(),
    );
    _luogo = TextEditingController(text: appuntamento?.luogo ?? '');
    _indirizzo = TextEditingController(text: appuntamento?.indirizzo ?? '');
    _note = TextEditingController(text: appuntamento?.note ?? '');
    _callUrl = TextEditingController(text: appuntamento?.callUrl ?? '');

    _clienteId = appuntamento?.clienteId;
    _operatoreId = appuntamento?.operatoreId ?? _uidCorrente();
    _invitatiUids = [...?appuntamento?.invitatiUids];
    _conferme = Map<String, dynamic>.from(
      appuntamento?.conferme ?? const <String, dynamic>{},
    );

    final stato = (appuntamento?.stato ?? 'da_fare').trim().toLowerCase();
    _stato = statiAppuntamento.containsKey(stato) ? stato : 'da_fare';

    final provider = (appuntamento?.callProvider ?? '').trim();
    _callProvider = providerCallAppuntamento.containsKey(provider)
        ? provider
        : 'nessuna';

    _caricaDati();
  }

  @override
  void dispose() {
    _titolo.dispose();
    _data.dispose();
    _ora.dispose();
    _durata.dispose();
    _luogo.dispose();
    _indirizzo.dispose();
    _note.dispose();
    _callUrl.dispose();
    super.dispose();
  }

  /// Uid dell'utente autenticato, `null` se non disponibile.
  String? _uidCorrente() {
    try {
      return ref.read(firebaseAuthProvider).currentUser?.uid;
    } catch (_) {
      // Firebase non inizializzato (test, anteprima): nessun default.
      return null;
    }
  }

  /// Carica clienti, utenti e gruppi in parallelo.
  ///
  /// L'errore dei clienti blocca la tendina e mostra "Riprova"; l'errore degli
  /// utenti lascia la tendina operatore sul solo utente corrente. Senza gruppi
  /// resta disponibile la condivisione con le singole persone.
  Future<void> _caricaDati() async {
    setState(() {
      _caricamentoClienti = true;
      _caricamentoUtenti = true;
      _caricamentoGruppi = true;
      _erroreClienti = null;
    });

    Future<List<Cliente>>? clientiFuturo;
    Future<List<UserProfile>>? utentiFuturo;
    Future<List<StanzaChat>>? gruppiFuturo;
    Object? erroreAvvio;
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      clientiFuturo = servizio.getClienti();
      utentiFuturo = servizio.getUtenti();
      gruppiFuturo = servizio.getChatStanze();
    } catch (errore) {
      erroreAvvio = errore;
    }

    List<Cliente>? clienti;
    Object? erroreClienti = erroreAvvio;
    List<UserProfile>? utenti;
    List<StanzaChat>? gruppi;
    if (clientiFuturo != null) {
      try {
        clienti = await clientiFuturo;
      } catch (errore) {
        erroreClienti = errore;
      }
    }
    if (utentiFuturo != null) {
      try {
        utenti = await utentiFuturo;
      } catch (_) {
        // Senza elenco utenti resta l'operatore corrente (se noto).
      }
    }
    if (gruppiFuturo != null) {
      try {
        gruppi = await gruppiFuturo;
      } catch (_) {
        // Senza gruppi si invitano le singole persone.
      }
    }

    if (!mounted) return;
    setState(() {
      final clientiCaricati = clienti;
      final utentiCaricati = utenti;
      final gruppiCaricati = gruppi;
      if (clientiCaricati != null) _clienti = clientiCaricati;
      if (utentiCaricati != null) _utenti = utentiCaricati;
      if (gruppiCaricati != null) {
        _gruppi = gruppiCaricati.where((g) => g.tipo == 'gruppo').toList();
      }
      _erroreClienti = erroreClienti;
      _caricamentoClienti = false;
      _caricamentoUtenti = false;
      _caricamentoGruppi = false;
    });
  }

  Cliente? get _clienteSelezionato {
    for (final cliente in _clienti) {
      if (cliente.id == _clienteId) return cliente;
    }
    return null;
  }

  /// Voci della tendina cliente, compreso il cliente salvato se non è più in
  /// elenco (per non perdere il collegamento in modifica).
  Map<String, String> get _opzioniClienti {
    final opzioni = <String, String>{
      for (final cliente in _clienti)
        cliente.id: nomeClienteAppuntamento(cliente),
    };
    final id = _clienteId;
    if (id != null && id.isNotEmpty && !opzioni.containsKey(id)) {
      final nome = widget.appuntamento?.clienteNome?.trim() ?? '';
      opzioni[id] = nome.isEmpty ? 'Cliente non disponibile' : nome;
    }
    return opzioni;
  }

  /// Voci della tendina operatore, con l'utente corrente se non è in elenco.
  Map<String, String> get _opzioniOperatori {
    final opzioni = <String, String>{
      for (final utente in _utenti) utente.uid: nomeUtenteAppuntamento(utente),
    };
    final id = _operatoreId;
    if (id != null && id.isNotEmpty && !opzioni.containsKey(id)) {
      opzioni[id] = 'Utente corrente';
    }
    return opzioni;
  }

  /// Nome leggibile di un invitato, con uid come fallback.
  String _nomeInvitato(String uid) {
    for (final utente in _utenti) {
      if (utente.uid == uid) return nomeUtenteAppuntamento(utente);
    }
    return uid;
  }

  /// Apre il form cliente e seleziona subito il cliente appena creato.
  Future<void> _creaCliente() async {
    String? nuovoId;
    final salvato = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClienteFormScreen(onSalvato: (id) => nuovoId = id),
      ),
    );
    if (salvato != true || !mounted) return;
    final id = nuovoId?.trim() ?? '';
    if (id.isEmpty) return;
    setState(() => _clienteId = id);
    await _caricaDati();
  }

  /// Apre il dialogo per scegliere colleghi e gruppi da invitare.
  Future<void> _apriCondivisione() async {
    final scelti = await mostraDialogoCondivisioneAppuntamento(
      context,
      utenti: _nomiUtenti,
      gruppi: _gruppi,
      selezionati: _invitatiUids.toSet(),
      uidCorrente: _uidCorrente(),
    );
    if (scelti == null || !mounted) return;

    final corrente = _uidCorrente();
    final ammessi = _nomiUtenti.keys.toSet();
    if (corrente != null) ammessi.remove(corrente);
    final ordinati = [
      for (final uid in scelti)
        if (ammessi.contains(uid)) uid,
    ]..sort();
    setState(() {
      _invitatiUids = ordinati;
      _conferme = {
        for (final voce in _conferme.entries)
          if (ordinati.contains(voce.key)) voce.key: voce.value,
      };
    });
  }

  /// Toglie un invitato e la sua risposta.
  void _rimuoviInvitato(String uid) {
    setState(() {
      _invitatiUids = [
        for (final voce in _invitatiUids)
          if (voce != uid) voce,
      ];
      _conferme = {
        for (final voce in _conferme.entries)
          if (voce.key != uid) voce.key: voce.value,
      };
    });
  }

  Future<void> _scegliData() async {
    final iniziale = parseDataItaliana(_data.text) ?? _dataScelta;
    final scelta = await showDatePicker(
      context: context,
      initialDate: iniziale,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Scegli la data',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
      fieldLabelText: 'Data',
    );
    if (scelta == null || !mounted) return;
    final giorno = _soloGiorno(scelta);
    setState(() {
      _dataScelta = giorno;
      _data.text = formattaDataVisita(giorno);
    });
  }

  Future<void> _scegliOra() async {
    final scelta = await showTimePicker(
      context: context,
      initialTime:
          _oraDaTesto(_ora.text) ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Scegli l\'ora',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
      hourLabelText: 'Ore',
      minuteLabelText: 'Minuti',
      builder: (context, child) {
        final media = MediaQuery.of(context);
        if (media.alwaysUse24HourFormat) return child ?? const SizedBox();
        return MediaQuery(
          data: media.copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        );
      },
    );
    if (scelta == null || !mounted) return;
    setState(() {
      _ora.text =
          '${scelta.hour.toString().padLeft(2, '0')}:'
          '${scelta.minute.toString().padLeft(2, '0')}';
    });
  }

  /// Apre Google Maps sull'indirizzo inserito, se non è vuoto.
  /// Copia il link call negli appunti, se presente.
  Future<void> _copiaCall() async {
    final testo = _callUrl.text.trim();
    if (testo.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: testo));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Link call copiato')));
  }

  /// Apre il link call nel browser o nell'app esterna.
  Future<void> _apriCall() async {
    final testo = _callUrl.text.trim();
    final uri = Uri.tryParse(testo);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non è stato possibile aprire il link.')),
      );
    }
  }

  Future<void> _apriMaps() async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = uriMapsIndirizzo(_indirizzo.text);
    if (uri == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Inserisci un indirizzo per aprire Maps.'),
        ),
      );
      return;
    }
    try {
      final aperto = await launchUrl(uri);
      if (!aperto) throw Exception('Maps non aperto');
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Non è stato possibile aprire Google Maps.'),
        ),
      );
    }
  }

  Future<void> _salva() async {
    FocusScope.of(context).unfocus();
    setState(() => _errore = null);
    if (!(_modulo.currentState?.validate() ?? false)) return;

    final giorno = parseDataItaliana(_data.text);
    if (giorno == null) return;

    final appuntamento = widget.appuntamento;
    final cliente = _clienteSelezionato;
    final durata = int.tryParse(_durata.text.trim()) ?? 60;

    setState(() => _salvando = true);
    final nuoviInvitati = [
      for (final uid in _invitatiUids)
        if (!(appuntamento?.invitatiUids ?? const <String>[]).contains(uid))
          uid,
    ];
    final dati = <String, dynamic>{
      'titolo': _titolo.text,
      'tipo': appuntamento?.tipo ?? 'appuntamento',
      'data': dataIsoVisita(giorno),
      'ora': normalizzaOraVisita(_ora.text),
      'durata_min': durata,
      'cliente_id': _clienteId,
      'cliente_nome':
          cliente?.nome ?? (cliente == null ? appuntamento?.clienteNome : null),
      'operatore_id': _operatoreId,
      'luogo': _luogo.text,
      'indirizzo': _indirizzo.text,
      'note': _note.text,
      'stato': _stato,
      'invitati_uids': _invitatiUids,
      'conferme': _conferme,
      'stato_condivisione': _statoCondivisione,
      // Campi non gestiti dal form: preservati in modifica.
      'visita_id': appuntamento?.visitaId,
      'call_provider': _callProvider == 'nessuna' ? null : _callProvider,
      'call_url': _callUrl.text.trim().isEmpty ? null : _callUrl.text.trim(),
      'meeting_id': appuntamento?.meetingId,
      'google_event_id': appuntamento?.googleEventId,
      'outlook_event_id': appuntamento?.outlookEventId,
    };

    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final Map<String, dynamic> salvato;
      if (appuntamento != null) {
        salvato = await servizio.aggiornaAppuntamento(appuntamento.id, dati);
      } else {
        salvato = await servizio.inserisciAppuntamento(dati);
      }
      await _inviaInviti(servizio, salvato['id']?.toString(), nuoviInvitati);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreAppuntamenti(errore));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Invia la notifica di invito ai colleghi appena aggiunti.
  ///
  /// Un errore di notifica non annulla il salvataggio dell'appuntamento: gli
  /// inviti restano visibili nel dettaglio e possono essere confermati anche
  /// dal calendario.
  Future<void> _inviaInviti(
    SpService servizio,
    String? appuntamentoId,
    List<String> destinatari,
  ) async {
    final id = appuntamentoId?.trim() ?? '';
    if (id.isEmpty || destinatari.isEmpty) return;

    final titolo = _titolo.text.trim();
    final nome = titolo.isEmpty ? 'Appuntamento' : titolo;
    final giorno = dataIsoVisita(parseDataItaliana(_data.text) ?? _dataScelta);
    final data = DateTime.tryParse(giorno);
    final quando = data == null ? giorno : formattaDataVisita(data);
    final ora = normalizzaOraVisita(_ora.text);
    final cliente = _clienteSelezionato?.nome?.trim() ?? '';
    final testo = [
      'Invito per "$nome" il $quando${ora == null ? '' : ' alle $ora'}',
      if (cliente.isNotEmpty) 'Cliente: $cliente',
      'Apri il calendario e conferma la disponibilità.',
    ].join('. ');

    for (final uid in destinatari) {
      try {
        await servizio.creaNotifica(
          utenteUid: uid,
          tipo: 'appuntamento',
          titolo: 'Conferma disponibilità: $nome',
          testo: testo,
          targetTipo: 'appuntamento',
          targetId: id,
        );
      } catch (_) {
        // La notifica non deve impedire il salvataggio dell'appuntamento.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final opzioniClienti = _opzioniClienti;
    final opzioniOperatori = _opzioniOperatori;

    return Scaffold(
      appBar: AppBar(
        title: Text(_modifica ? 'Modifica appuntamento' : 'Nuovo appuntamento'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpazi.paginaTelefono),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _modulo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SezioneAppuntamento(
                      titolo: 'Appuntamento',
                      figli: [
                        TextFormField(
                          key: const Key('appuntamento-titolo'),
                          controller: _titolo,
                          enabled: !_salvando,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Titolo *',
                            hintText: 'Es. Visita commerciale',
                          ),
                          validator: validaTitoloAppuntamento,
                        ),
                        TextFormField(
                          key: const Key('appuntamento-data'),
                          controller: _data,
                          enabled: !_salvando,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9/]'),
                            ),
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Data *',
                            hintText: 'gg/mm/aaaa',
                            suffixIcon: IconButton(
                              key: const Key('appuntamento-scegli-data'),
                              tooltip: 'Scegli la data',
                              onPressed: _salvando ? null : _scegliData,
                              icon: const Icon(Icons.calendar_today_outlined),
                            ),
                          ),
                          validator: validaDataAppuntamento,
                        ),
                        TextFormField(
                          key: const Key('appuntamento-ora'),
                          controller: _ora,
                          enabled: !_salvando,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9:]'),
                            ),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Ora',
                            hintText: 'HH:MM',
                            suffixIcon: IconButton(
                              key: const Key('appuntamento-scegli-ora'),
                              tooltip: 'Scegli l\'ora',
                              onPressed: _salvando ? null : _scegliOra,
                              icon: const Icon(Icons.schedule_outlined),
                            ),
                          ),
                          validator: _validaOraAppuntamento,
                        ),
                        TextFormField(
                          key: const Key('appuntamento-durata'),
                          controller: _durata,
                          enabled: !_salvando,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Durata (minuti)',
                            hintText: '60',
                          ),
                          validator: _validaDurataAppuntamento,
                        ),
                        DropdownButtonFormField<String>(
                          key: const Key('appuntamento-stato'),
                          initialValue: _stato,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Stato'),
                          items: [
                            for (final voce in statiAppuntamento.entries)
                              DropdownMenuItem(
                                value: voce.key,
                                child: Text(voce.value),
                              ),
                          ],
                          onChanged: _salvando
                              ? null
                              : (valore) {
                                  if (valore == null) return;
                                  setState(() => _stato = valore);
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    _SezioneAppuntamento(
                      titolo: 'Partecipanti',
                      figli: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: const Key('appuntamento-cliente'),
                                initialValue: _clienteId ?? '',
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Cliente',
                                  helperText: _caricamentoClienti
                                      ? 'Caricamento clienti…'
                                      : null,
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('Nessun cliente'),
                                  ),
                                  for (final voce in opzioniClienti.entries)
                                    DropdownMenuItem(
                                      value: voce.key,
                                      child: Text(
                                        voce.value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: _salvando || _caricamentoClienti
                                    ? null
                                    : (valore) => setState(() {
                                        _clienteId =
                                            (valore == null || valore.isEmpty)
                                            ? null
                                            : valore;
                                      }),
                              ),
                            ),
                            const SizedBox(width: AppSpazi.xxs),
                            IconButton.filledTonal(
                              key: const Key('appuntamento-nuovo-cliente'),
                              tooltip: 'Nuovo cliente',
                              onPressed: _salvando ? null : _creaCliente,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        DropdownButtonFormField<String>(
                          key: const Key('appuntamento-operatore'),
                          initialValue: _operatoreId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Utente',
                            hintText: 'Scegli un utente',
                            helperText: _caricamentoUtenti
                                ? 'Caricamento utenti…'
                                : null,
                          ),
                          items: [
                            for (final voce in opzioniOperatori.entries)
                              DropdownMenuItem(
                                value: voce.key,
                                child: Text(
                                  voce.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _salvando || _caricamentoUtenti
                              ? null
                              : (valore) =>
                                    setState(() => _operatoreId = valore),
                        ),
                      ],
                      extra: [
                        if (_erroreClienti != null) ...[
                          AvvisoErrore(
                            key: const Key('errore-clienti-appuntamento'),
                            testo: messaggioErroreAppuntamenti(_erroreClienti!),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: const Key('riprova-clienti-appuntamento'),
                              onPressed: _salvando ? null : _caricaDati,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Riprova clienti'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    _SezioneAppuntamento(
                      titolo: 'Condivisione',
                      figli: const [],
                      extra: [
                        if (_invitatiUids.isEmpty)
                          Text(
                            'Nessun collega invitato. Puoi condividere '
                            'l\'appuntamento con una persona o un gruppo: '
                            'riceveranno una notifica e dovranno confermare.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          )
                        else ...[
                          Wrap(
                            spacing: AppSpazi.xs,
                            runSpacing: AppSpazi.xxs,
                            children: [
                              for (final uid in _invitatiUids)
                                InputChip(
                                  key: Key('appuntamento-invitato-$uid'),
                                  label: Text(_nomeInvitato(uid)),
                                  onDeleted: _salvando
                                      ? null
                                      : () => _rimuoviInvitato(uid),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpazi.xs),
                          Row(
                            children: [
                              Icon(
                                _statoCondivisione ==
                                        statoCondivisioneConfermato
                                    ? Icons.check_circle_outline
                                    : _statoCondivisione ==
                                          statoCondivisioneRifiutato
                                    ? Icons.cancel_outlined
                                    : Icons.hourglass_top,
                                size: 16,
                                color: coloreStatoCondivisione(
                                  _statoCondivisione,
                                ),
                              ),
                              const SizedBox(width: AppSpazi.xxs),
                              Text(
                                etichettaStatoCondivisione(_statoCondivisione),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: coloreStatoCondivisione(
                                        _statoCondivisione,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppSpazi.xs),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            key: const Key('appuntamento-condivisione'),
                            onPressed: _salvando || _caricamentoUtenti
                                ? null
                                : _apriCondivisione,
                            icon: _caricamentoUtenti || _caricamentoGruppi
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.group_add_outlined),
                            label: const Text('Scegli persone o gruppi'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    _SezioneAppuntamento(
                      titolo: 'Partecipanti',
                      figli: [
                        if (_invitatiUids.isEmpty)
                          Text(
                            'Nessun collega invitato.',
                            key: const Key('appuntamento-nessun-invitato'),
                            style: tema.textTheme.bodyMedium?.copyWith(
                              color: tema.colorScheme.onSurfaceVariant,
                            ),
                          )
                        else
                          Wrap(
                            spacing: AppSpazi.xs,
                            runSpacing: AppSpazi.xs,
                            children: [
                              for (final uid in _invitatiUids)
                                InputChip(
                                  key: Key('appuntamento-invitato-$uid'),
                                  label: Text(_nomeInvitato(uid)),
                                  onDeleted: _salvando
                                      ? null
                                      : () => _rimuoviInvitato(uid),
                                ),
                            ],
                          ),
                        const SizedBox(height: AppSpazi.xs),
                        OutlinedButton.icon(
                          key: const Key('appuntamento-condividi'),
                          onPressed: (_salvando || _caricamentoGruppi)
                              ? null
                              : _apriCondivisione,
                          icon: const Icon(Icons.group_add_outlined),
                          label: Text(
                            _caricamentoGruppi
                                ? 'Caricamento partecipanti…'
                                : 'Scegli partecipanti',
                          ),
                        ),
                        const SizedBox(height: AppSpazi.xxs),
                        Text(
                          'I colleghi invitati ricevono l’appuntamento nella '
                          'loro area e possono confermare o rifiutare.',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    _SezioneAppuntamento(
                      titolo: 'Call',
                      figli: [
                        DropdownButtonFormField<String>(
                          key: const Key('appuntamento-call-provider'),
                          initialValue: _callProvider,
                          decoration: const InputDecoration(
                            labelText: 'Tipo di call',
                            helperText: 'Puoi incollare un link Meet o Teams.',
                          ),
                          items: [
                            for (final voce in providerCallAppuntamento.entries)
                              DropdownMenuItem(
                                value: voce.key,
                                child: Text(voce.value),
                              ),
                          ],
                          onChanged: _salvando
                              ? null
                              : (valore) {
                                  if (valore == null) return;
                                  setState(() => _callProvider = valore);
                                },
                        ),
                        TextFormField(
                          key: const Key('appuntamento-call-url'),
                          controller: _callUrl,
                          enabled: !_salvando && _callProvider != 'nessuna',
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          validator: (valore) =>
                              validaCallAppuntamento(_callProvider, valore),
                          decoration: InputDecoration(
                            labelText: 'Link call',
                            hintText: 'https://meet.google.com/...',
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: const Key('appuntamento-call-copia'),
                                  tooltip: 'Copia link',
                                  onPressed: _salvando ? null : _copiaCall,
                                  icon: const Icon(Icons.copy_outlined),
                                ),
                                IconButton(
                                  key: const Key('appuntamento-call-apri'),
                                  tooltip: 'Apri link',
                                  onPressed: _salvando ? null : _apriCall,
                                  icon: const Icon(Icons.open_in_new),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    _SezioneAppuntamento(
                      titolo: 'Luogo e note',
                      figli: [
                        TextFormField(
                          key: const Key('appuntamento-luogo'),
                          controller: _luogo,
                          enabled: !_salvando,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Luogo',
                            hintText: 'Es. Sede del cliente',
                          ),
                        ),
                        TextFormField(
                          key: const Key('appuntamento-indirizzo'),
                          controller: _indirizzo,
                          enabled: !_salvando,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Indirizzo',
                            hintText: 'Es. Via Roma 1, Milano',
                            suffixIcon: IconButton(
                              key: const Key('appuntamento-maps'),
                              tooltip: 'Apri in Google Maps',
                              onPressed: _salvando ? null : _apriMaps,
                              icon: const Icon(Icons.directions_car_outlined),
                            ),
                          ),
                        ),
                      ],
                      extra: [
                        TextFormField(
                          key: const Key('appuntamento-note'),
                          controller: _note,
                          enabled: !_salvando,
                          minLines: 3,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(labelText: 'Note'),
                        ),
                      ],
                    ),
                    if (_errore != null) ...[
                      const SizedBox(height: AppSpazi.m),
                      AvvisoErrore(
                        key: const Key('appuntamento-errore'),
                        testo: _errore!,
                      ),
                    ],
                    const SizedBox(height: AppSpazi.l),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('annulla-appuntamento'),
                            onPressed: _salvando
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Annulla'),
                          ),
                        ),
                        const SizedBox(width: AppSpazi.s),
                        Expanded(
                          child: FilledButton(
                            key: const Key('salva-appuntamento'),
                            onPressed: _salvando ? null : _salva,
                            child: _salvando
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: AppSpazi.s),
                                      Text('Salvataggio…'),
                                    ],
                                  )
                                : Text(
                                    _modifica
                                        ? 'Salva modifiche'
                                        : 'Crea appuntamento',
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    Text(
                      'I campi contrassegnati con * sono obbligatori.',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card di sezione del form con titolo e campi su una o due colonne.
class _SezioneAppuntamento extends StatelessWidget {
  const _SezioneAppuntamento({
    required this.titolo,
    required this.figli,
    this.extra = const [],
  });

  final String titolo;
  final List<Widget> figli;

  /// Contenuti a piena larghezza sotto i campi (es. avviso d'errore).
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titolo.toUpperCase(),
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpazi.s),
            if (figli.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final doppia = constraints.maxWidth >= 520;
                  final larghezza = doppia
                      ? (constraints.maxWidth - AppSpazi.s) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: AppSpazi.s,
                    runSpacing: AppSpazi.s,
                    children: [
                      for (final figlio in figli)
                        SizedBox(width: larghezza, child: figlio),
                    ],
                  );
                },
              ),
            if (extra.isNotEmpty) ...[
              if (figli.isNotEmpty) const SizedBox(height: AppSpazi.s),
              ...extra,
            ],
          ],
        ),
      ),
    );
  }
}
