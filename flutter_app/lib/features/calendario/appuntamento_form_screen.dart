import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../data/models/allegato.dart';
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

/// Data di fine dell'appuntamento esistente, o `null` per i documenti vecchi.
DateTime? _dataFineAppuntamento(Appuntamento? appuntamento) {
  if (appuntamento == null) return null;
  final esplicita = DateTime.tryParse(appuntamento.dataFine?.trim() ?? '');
  if (esplicita != null) return _soloGiorno(esplicita);
  if (appuntamento.tuttoIlGiorno) {
    final inizio = DateTime.tryParse(appuntamento.data?.trim() ?? '');
    return inizio == null ? null : _soloGiorno(inizio);
  }
  final fine = fineAppuntamento(appuntamento);
  return fine == null ? null : _soloGiorno(fine);
}

/// Aggiunge [minuti] a un'ora `HH:MM`, restituendo `HH:MM` (o stringa vuota).
String _aggiungiMinutiAllOra(String? ora, int minuti) {
  final normalizzata = normalizzaOraVisita(ora);
  if (normalizzata == null) return '';
  final parti = normalizzata.split(':');
  final base = DateTime(
    2000,
    1,
    1,
    int.tryParse(parti[0]) ?? 0,
    int.tryParse(parti[1]) ?? 0,
  );
  final risultato = base.add(Duration(minutes: minuti));
  return '${risultato.hour.toString().padLeft(2, '0')}:'
      '${risultato.minute.toString().padLeft(2, '0')}';
}

DateTime? _combinaDataOraForm(DateTime data, String? ora) {
  final normalizzata = normalizzaOraVisita(ora);
  if (normalizzata == null) return null;
  final parti = normalizzata.split(':');
  return DateTime(
    data.year,
    data.month,
    data.day,
    int.tryParse(parti[0]) ?? 0,
    int.tryParse(parti[1]) ?? 0,
  );
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
  late final TextEditingController _dataFine;
  late final TextEditingController _oraFine;
  late final TextEditingController _intervalloRipetizione;
  late final TextEditingController _notificaPersonalizzata;
  late final TextEditingController _luogo;
  late final TextEditingController _indirizzo;
  late final TextEditingController _note;
  late final TextEditingController _callUrl;

  late DateTime _dataScelta;
  late DateTime _dataFineScelta;
  late String _stato;
  late String _callProvider;
  String? _clienteId;
  String? _operatoreId;
  bool _tuttoIlGiorno = false;
  bool _privato = false;
  String _ripetizioneTipo = ripetizioneMai;
  Set<int> _giorniRipetizione = {};
  String _notificaScelta = 'nessuna';

  List<Cliente> _clienti = const [];
  List<UserProfile> _utenti = const [];
  List<StanzaChat> _gruppi = const [];
  List<String> _invitatiUids = const [];
  Map<String, dynamic> _conferme = const {};
  List<Allegato> _allegati = const [];
  final List<PlatformFile> _allegatiNuovi = [];
  bool _caricamentoAllegati = false;
  String? _erroreAllegati;
  String? _idCreato;
  bool _invitiInviati = false;
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
    _dataFineScelta = _dataFineAppuntamento(appuntamento) ?? _dataScelta;
    _tuttoIlGiorno = appuntamento?.tuttoIlGiorno == true;
    _privato = appuntamento?.privato == true;
    _ripetizioneTipo = (appuntamento?.ripetizione['tipo'] ?? ripetizioneMai)
        .toString();
    _giorniRipetizione = giorniRipetizione(appuntamento?.ripetizione).toSet();
    if (_giorniRipetizione.isEmpty) {
      _giorniRipetizione = {_dataScelta.weekday};
    }
    final notificaMin = appuntamento?.notificaMin;
    if (notificaMin == null) {
      _notificaScelta = 'nessuna';
    } else if (const {0, 5, 10, 15, 30}.contains(notificaMin)) {
      _notificaScelta = '$notificaMin';
    } else {
      _notificaScelta = 'personalizzata';
    }
    _notificaPersonalizzata = TextEditingController(
      text:
          notificaMin == null || const {0, 5, 10, 15, 30}.contains(notificaMin)
          ? ''
          : '$notificaMin',
    );
    _intervalloRipetizione = TextEditingController(
      text: (appuntamento?.ripetizione['intervallo_settimane'] ?? 1).toString(),
    );
    _titolo = TextEditingController(text: appuntamento?.titolo ?? '');
    _data = TextEditingController(text: formattaDataVisita(_dataScelta));
    final oraIniziale = appuntamento?.ora ?? widget.oraIniziale ?? '09:00';
    _ora = TextEditingController(text: _tuttoIlGiorno ? '' : oraIniziale);
    final minutiFine = appuntamento?.durataMin ?? 60;
    final oraFine =
        appuntamento?.oraFine ??
        _aggiungiMinutiAllOra(oraIniziale, minutiFine <= 0 ? 60 : minutiFine);
    _oraFine = TextEditingController(text: _tuttoIlGiorno ? '' : oraFine);
    if (!_tuttoIlGiorno &&
        appuntamento?.dataFine == null &&
        appuntamento?.oraFine == null &&
        oraFine.isNotEmpty &&
        oraIniziale.isNotEmpty &&
        oraFine.compareTo(oraIniziale) <= 0) {
      _dataFineScelta = DateTime(
        _dataScelta.year,
        _dataScelta.month,
        _dataScelta.day + 1,
      );
    }
    _dataFine = TextEditingController(
      text: formattaDataVisita(_dataFineScelta),
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
    if (_modifica) _caricaAllegati();
  }

  @override
  void dispose() {
    _titolo.dispose();
    _data.dispose();
    _ora.dispose();
    _dataFine.dispose();
    _oraFine.dispose();
    _intervalloRipetizione.dispose();
    _notificaPersonalizzata.dispose();
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

  Future<void> _caricaAllegati() async {
    final appuntamento = widget.appuntamento;
    if (appuntamento == null) return;
    setState(() {
      _caricamentoAllegati = true;
      _erroreAllegati = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final allegati = await servizio.getAllegati(appuntamento.id);
      if (!mounted) return;
      setState(() {
        _allegati = allegati;
        _caricamentoAllegati = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _caricamentoAllegati = false;
        _erroreAllegati = 'Allegati non disponibili. Riprova.';
      });
    }
  }

  Future<void> _scegliAllegati() async {
    final risultato = await FilePicker.pickFiles(type: FileType.any);
    if (risultato.isEmpty || !mounted) return;
    const limite = 10 * 1024 * 1024;
    final aggiunti = <PlatformFile>[];
    for (final file in risultato) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _erroreAllegati = 'Impossibile leggere ${file.name}.');
        continue;
      }
      if (bytes.length > limite) {
        setState(
          () => _erroreAllegati = '${file.name} supera il limite di 10 MB.',
        );
        continue;
      }
      aggiunti.add(file);
    }
    if (!mounted) return;
    setState(() {
      _allegatiNuovi.addAll(aggiunti);
      if (aggiunti.isNotEmpty) _erroreAllegati = null;
    });
  }

  Future<void> _apriAllegato(Allegato allegato) async {
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final link = await servizio.linkAllegato(allegato);
      if (link == null) throw StateError('Link non disponibile');
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      setState(() => _erroreAllegati = 'Impossibile aprire l\'allegato.');
    }
  }

  Future<void> _eliminaAllegato(Allegato allegato) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare l\'allegato?'),
        content: Text('"${allegato.nome}" verrà rimosso definitivamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
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
      await servizio.eliminaAllegato(allegato);
      if (!mounted) return;
      setState(() {
        _allegati = [
          for (final voce in _allegati)
            if (voce.id != allegato.id) voce,
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _erroreAllegati = 'Eliminazione non riuscita.');
    }
  }

  Future<void> _aggiornaPromemoria(
    SpService servizio,
    String appuntamentoId, {
    required int? notificaMin,
    required DateTime giorno,
    required DateTime giornoFine,
    required String? oraInizio,
    required String? oraFine,
    required bool tuttoIlGiorno,
    required Map<String, dynamic> ripetizione,
  }) async {
    servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
    if (notificaMin == null) {
      await servizio.annullaPromemoria(appuntamentoId);
      return;
    }

    final modello = Appuntamento(
      id: appuntamentoId,
      titolo: _titolo.text,
      data: dataIsoVisita(giorno),
      ora: oraInizio,
      dataFine: dataIsoVisita(giornoFine),
      oraFine: oraFine,
      tuttoIlGiorno: tuttoIlGiorno,
      ripetizione: ripetizione,
      notificaMin: notificaMin,
      privato: _privato,
    );
    final adesso = DateTime.now();
    final fine = adesso.add(const Duration(days: 90));
    final giorni = occorrenzeAppuntamento(modello, dal: adesso, al: fine);
    final titolo = _privato
        ? 'Impegno privato'
        : (_titolo.text.trim().isEmpty ? 'Appuntamento' : _titolo.text.trim());
    final destinatari = <String>{
      if (_uidCorrente()?.trim().isNotEmpty == true) _uidCorrente()!,
      if (_operatoreId?.trim().isNotEmpty == true) _operatoreId!,
      ..._invitatiUids,
    };
    final occorrenze = <({String dueAt, String testo})>[];
    for (final occorrenza in giorni.take(30)) {
      final inizio = tuttoIlGiorno
          ? DateTime(occorrenza.year, occorrenza.month, occorrenza.day, 9)
          : _combinaDataOraForm(occorrenza, oraInizio);
      if (inizio == null) continue;
      final due = inizio.subtract(Duration(minutes: notificaMin));
      if (!due.isAfter(adesso)) continue;
      final orario = tuttoIlGiorno
          ? ' (tutto il giorno)'
          : ' alle ${oraInizio ?? ''}';
      occorrenze.add((
        dueAt: due.toIso8601String(),
        testo:
            'Closer · Promemoria\n"$titolo" il '
            '${formattaDataVisita(occorrenza)}$orario.',
      ));
    }
    if (occorrenze.isEmpty || destinatari.isEmpty) {
      await servizio.annullaPromemoria(appuntamentoId);
      return;
    }
    await servizio.registraPromemoria(
      appuntamentoId: appuntamentoId,
      occorrenze: occorrenze,
      utenteUids: destinatari.toList(),
    );
  }

  Future<bool> _caricaAllegatiNuovi(SpService servizio, String id) async {
    if (_allegatiNuovi.isEmpty) return true;
    final errori = <String>[];
    for (final file in [..._allegatiNuovi]) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        errori.add(file.name);
        continue;
      }
      final mime = _mimeDaNome(file.name);
      try {
        final allegato = await servizio.caricaAllegato(
          elementoId: id,
          bytes: bytes,
          nome: file.name,
          mime: mime,
        );
        if (!mounted) return false;
        setState(() {
          _allegati = [..._allegati, allegato];
          _allegatiNuovi.remove(file);
        });
      } catch (_) {
        errori.add(file.name);
      }
    }
    if (errori.isEmpty) return true;
    if (mounted) {
      setState(
        () => _erroreAllegati =
            'Alcuni allegati non sono stati caricati: ${errori.join(', ')}.',
      );
    }
    return false;
  }

  String _mimeDaNome(String nome) {
    final estensione = nome.split('.').last.toLowerCase();
    const mappa = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'webm': 'video/webm',
      'pdf': 'application/pdf',
      'eml': 'message/rfc822',
    };
    return mappa[estensione] ?? 'application/octet-stream';
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
      final fine = parseDataItaliana(_dataFine.text);
      if (fine == null || fine.isBefore(giorno)) {
        _dataFineScelta = giorno;
        _dataFine.text = formattaDataVisita(giorno);
      }
    });
  }

  Future<void> _scegliDataFine() async {
    final iniziale = parseDataItaliana(_dataFine.text) ?? _dataFineScelta;
    final scelta = await showDatePicker(
      context: context,
      initialDate: iniziale,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Scegli la data di fine',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
      fieldLabelText: 'Data fine',
    );
    if (scelta == null || !mounted) return;
    final giorno = _soloGiorno(scelta);
    setState(() {
      _dataFineScelta = giorno;
      _dataFine.text = formattaDataVisita(giorno);
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
    final ora =
        '${scelta.hour.toString().padLeft(2, '0')}:'
        '${scelta.minute.toString().padLeft(2, '0')}';
    setState(() {
      _ora.text = ora;
      final fine = normalizzaOraVisita(_oraFine.text);
      if (fine == null || fine.compareTo(ora) <= 0) {
        final nuovaFine = _aggiungiMinutiAllOra(ora, 60);
        _oraFine.text = nuovaFine;
        if (nuovaFine.isNotEmpty && nuovaFine.compareTo(ora) <= 0) {
          _dataFineScelta = DateTime(
            _dataScelta.year,
            _dataScelta.month,
            _dataScelta.day + 1,
          );
          _dataFine.text = formattaDataVisita(_dataFineScelta);
        }
      }
    });
  }

  Future<void> _scegliOraFine() async {
    final scelta = await showTimePicker(
      context: context,
      initialTime:
          _oraDaTesto(_oraFine.text) ??
          _oraDaTesto(_aggiungiMinutiAllOra(_ora.text, 60)) ??
          const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Scegli l\'ora di fine',
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
      _oraFine.text =
          '${scelta.hour.toString().padLeft(2, '0')}:'
          '${scelta.minute.toString().padLeft(2, '0')}';
    });
  }

  void _cambiaTuttoIlGiorno(bool valore) {
    setState(() {
      _tuttoIlGiorno = valore;
      if (valore) {
        _ora.clear();
        _oraFine.clear();
      } else {
        if (_ora.text.trim().isEmpty) _ora.text = '09:00';
        if (_oraFine.text.trim().isEmpty) {
          _oraFine.text = _aggiungiMinutiAllOra(_ora.text, 60);
        }
        final inizio = parseDataItaliana(_data.text);
        final fine = parseDataItaliana(_dataFine.text);
        if (inizio != null && (fine == null || fine.isBefore(inizio))) {
          _dataFineScelta = inizio;
          _dataFine.text = formattaDataVisita(inizio);
        }
      }
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
    final giornoFine = parseDataItaliana(_dataFine.text);
    if (giorno == null || giornoFine == null) return;

    final oraInizio = _tuttoIlGiorno ? null : normalizzaOraVisita(_ora.text);
    final oraFine = _tuttoIlGiorno ? null : normalizzaOraVisita(_oraFine.text);
    DateTime? inizio;
    DateTime? fine;
    if (!_tuttoIlGiorno) {
      inizio = _combinaDataOraForm(giorno, oraInizio);
      fine = _combinaDataOraForm(giornoFine, oraFine);
      if (inizio == null || fine == null) {
        setState(() => _errore = 'Inserisci un\'ora valida per inizio e fine.');
        return;
      }
      if (!fine.isAfter(inizio)) {
        setState(
          () => _errore = 'L\'ora di fine deve essere successiva all\'inizio.',
        );
        return;
      }
    } else if (giornoFine.isBefore(giorno)) {
      setState(() => _errore = 'La data di fine non può precedere l\'inizio.');
      return;
    }

    if ((_ripetizioneTipo == ripetizioneSettimanale ||
            _ripetizioneTipo == ripetizioneBisettimanale ||
            _ripetizioneTipo == ripetizionePersonalizzata) &&
        _giorniRipetizione.isEmpty) {
      setState(() => _errore = 'Seleziona almeno un giorno della settimana.');
      return;
    }
    final intervalloRipetizione =
        int.tryParse(_intervalloRipetizione.text.trim()) ?? 1;
    if (_ripetizioneTipo == ripetizionePersonalizzata &&
        (intervalloRipetizione < 1 || intervalloRipetizione > 52)) {
      setState(
        () => _errore = 'L\'intervallo deve essere tra 1 e 52 settimane.',
      );
      return;
    }

    int? notificaMin;
    if (_notificaScelta == 'personalizzata') {
      notificaMin = int.tryParse(_notificaPersonalizzata.text.trim());
      if (notificaMin == null || notificaMin < 0) {
        setState(() => _errore = 'Inserisci i minuti della notifica.');
        return;
      }
    } else if (_notificaScelta != 'nessuna') {
      notificaMin = int.tryParse(_notificaScelta);
    }

    final appuntamento = widget.appuntamento;
    final cliente = _clienteSelezionato;
    final durata = _tuttoIlGiorno
        ? (giornoFine.difference(giorno).inDays + 1) * 24 * 60
        : fine!.difference(inizio!).inMinutes;

    final ripetizione = <String, dynamic>{
      'tipo': _ripetizioneTipo,
      'giorni_settimana': [
        for (final giorno in _giorniRipetizione.toList()..sort()) giorno,
      ],
      'intervallo_settimane': intervalloRipetizione.clamp(1, 52),
    };

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
      'ora': oraInizio,
      'data_fine': dataIsoVisita(giornoFine),
      'ora_fine': oraFine,
      'tutto_il_giorno': _tuttoIlGiorno,
      'durata_min': durata,
      'ripetizione': ripetizione,
      'notifica_min': notificaMin,
      'privato': _privato,
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
      final idEsistente = appuntamento?.id ?? _idCreato;
      final Map<String, dynamic> salvato;
      if (idEsistente != null) {
        salvato = await servizio.aggiornaAppuntamento(idEsistente, dati);
      } else {
        salvato = await servizio.inserisciAppuntamento(dati);
        _idCreato = salvato['id']?.toString();
      }
      final id = salvato['id']?.toString();
      final allegatiOk = await _caricaAllegatiNuovi(servizio, id ?? '');
      if (!mounted) return;
      if (!allegatiOk) return;
      try {
        await _aggiornaPromemoria(
          servizio,
          id ?? '',
          notificaMin: notificaMin,
          giorno: giorno,
          giornoFine: giornoFine,
          oraInizio: oraInizio,
          oraFine: oraFine,
          tuttoIlGiorno: _tuttoIlGiorno,
          ripetizione: ripetizione,
        );
      } catch (_) {
        // La notifica è best-effort: l'appuntamento resta salvato.
      }
      if (!_invitiInviati) {
        _invitiInviati = true;
        await _inviaInviti(servizio, id, nuoviInvitati);
      }
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
    final nomeVisibile = _privato ? 'Impegno privato' : nome;
    final giorno = dataIsoVisita(parseDataItaliana(_data.text) ?? _dataScelta);
    final data = DateTime.tryParse(giorno);
    final quando = data == null ? giorno : formattaDataVisita(data);
    final ora = normalizzaOraVisita(_ora.text);
    final oraFine = normalizzaOraVisita(_oraFine.text);
    final cliente = _privato ? '' : (_clienteSelezionato?.nome?.trim() ?? '');
    final orario = _tuttoIlGiorno
        ? ' (tutto il giorno)'
        : ora == null
        ? ''
        : oraFine == null
        ? ' alle $ora'
        : ' dalle $ora alle $oraFine';
    final testo = [
      'Invito per "$nomeVisibile" il $quando$orario',
      if (cliente.isNotEmpty) 'Cliente: $cliente',
      'Apri il calendario e conferma la disponibilità.',
    ].join('. ');

    for (final uid in destinatari) {
      try {
        await servizio.creaNotifica(
          utenteUid: uid,
          tipo: 'appuntamento',
          titolo: 'Conferma disponibilità: $nomeVisibile',
          testo: testo,
          targetTipo: 'appuntamento',
          targetId: id,
        );
      } catch (_) {
        // La notifica non deve impedire il salvataggio dell'appuntamento.
      }
      try {
        await servizio.inviaWhatsappAUtente(
          utenteUid: uid,
          messaggio: 'Closer · Invito appuntamento\n$nomeVisibile\n$testo',
        );
      } catch (_) {
        // WhatsApp è best-effort e può non essere configurato.
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
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
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
                                  labelText: 'Data inizio *',
                                  hintText: 'gg/mm/aaaa',
                                  suffixIcon: IconButton(
                                    key: const Key('appuntamento-scegli-data'),
                                    tooltip: 'Scegli la data di inizio',
                                    onPressed: _salvando ? null : _scegliData,
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                  ),
                                ),
                                validator: validaDataAppuntamento,
                              ),
                            ),
                            const SizedBox(width: AppSpazi.xxs),
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    key: const Key(
                                      'appuntamento-tutto-il-giorno',
                                    ),
                                    value: _tuttoIlGiorno,
                                    onChanged: _salvando
                                        ? null
                                        : (valore) => _cambiaTuttoIlGiorno(
                                            valore == true,
                                          ),
                                  ),
                                  const Flexible(
                                    child: Text('Tutto il giorno'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        TextFormField(
                          key: const Key('appuntamento-ora'),
                          controller: _ora,
                          enabled: !_salvando && !_tuttoIlGiorno,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9:]'),
                            ),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Ora inizio',
                            hintText: 'HH:MM',
                            suffixIcon: IconButton(
                              key: const Key('appuntamento-scegli-ora'),
                              tooltip: 'Scegli l\'ora di inizio',
                              onPressed: _salvando || _tuttoIlGiorno
                                  ? null
                                  : _scegliOra,
                              icon: const Icon(Icons.schedule_outlined),
                            ),
                          ),
                          validator: _validaOraAppuntamento,
                        ),
                        TextFormField(
                          key: const Key('appuntamento-data-fine'),
                          controller: _dataFine,
                          enabled: !_salvando,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9/]'),
                            ),
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Data fine *',
                            hintText: 'gg/mm/aaaa',
                            suffixIcon: IconButton(
                              key: const Key('appuntamento-scegli-data-fine'),
                              tooltip: 'Scegli la data di fine',
                              onPressed: _salvando ? null : _scegliDataFine,
                              icon: const Icon(Icons.event_outlined),
                            ),
                          ),
                          validator: validaDataAppuntamento,
                        ),
                        TextFormField(
                          key: const Key('appuntamento-ora-fine'),
                          controller: _oraFine,
                          enabled: !_salvando && !_tuttoIlGiorno,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9:]'),
                            ),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Ora fine',
                            hintText: 'HH:MM',
                            suffixIcon: IconButton(
                              key: const Key('appuntamento-scegli-ora-fine'),
                              tooltip: 'Scegli l\'ora di fine',
                              onPressed: _salvando || _tuttoIlGiorno
                                  ? null
                                  : _scegliOraFine,
                              icon: const Icon(Icons.schedule_outlined),
                            ),
                          ),
                          validator: _validaOraAppuntamento,
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
                      titolo: 'Ripetizione',
                      figli: [
                        DropdownButtonFormField<String>(
                          key: const Key('appuntamento-ripeti'),
                          initialValue: _ripetizioneTipo,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Ripeti',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: ripetizioneMai,
                              child: Text('Mai'),
                            ),
                            DropdownMenuItem(
                              value: ripetizioneGiornaliera,
                              child: Text('Ogni giorno'),
                            ),
                            DropdownMenuItem(
                              value: ripetizioneSettimanale,
                              child: Text('Ogni settimana'),
                            ),
                            DropdownMenuItem(
                              value: ripetizioneBisettimanale,
                              child: Text('Ogni due settimane'),
                            ),
                            DropdownMenuItem(
                              value: ripetizioneMensile,
                              child: Text('Ogni mese'),
                            ),
                            DropdownMenuItem(
                              value: ripetizioneAnnuale,
                              child: Text('Ogni anno'),
                            ),
                            DropdownMenuItem(
                              value: ripetizionePersonalizzata,
                              child: Text('Personalizza'),
                            ),
                          ],
                          onChanged: _salvando
                              ? null
                              : (valore) {
                                  if (valore == null) return;
                                  setState(() => _ripetizioneTipo = valore);
                                },
                        ),
                        if (_ripetizioneTipo == ripetizionePersonalizzata)
                          TextFormField(
                            key: const Key(
                              'appuntamento-intervallo-ripetizione',
                            ),
                            controller: _intervalloRipetizione,
                            enabled: !_salvando,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Ogni quante settimane',
                              hintText: '1',
                            ),
                          ),
                      ],
                      extra: [
                        if (_ripetizioneTipo == ripetizioneGiornaliera ||
                            _ripetizioneTipo == ripetizioneSettimanale ||
                            _ripetizioneTipo == ripetizioneBisettimanale ||
                            _ripetizioneTipo == ripetizionePersonalizzata) ...[
                          Text(
                            'Giorni della settimana',
                            style: tema.textTheme.bodySmall?.copyWith(
                              color: tema.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpazi.xs),
                          Wrap(
                            spacing: AppSpazi.xs,
                            runSpacing: AppSpazi.xs,
                            children: [
                              for (var giorno = 1; giorno <= 7; giorno++)
                                FilterChip(
                                  key: Key(
                                    'appuntamento-ripeti-giorno-$giorno',
                                  ),
                                  label: Text(
                                    nomiGiorniRipetizione[giorno - 1],
                                  ),
                                  selected: _giorniRipetizione.contains(giorno),
                                  onSelected: _salvando
                                      ? null
                                      : (scelto) => setState(() {
                                          if (scelto) {
                                            _giorniRipetizione.add(giorno);
                                          } else {
                                            _giorniRipetizione.remove(giorno);
                                          }
                                        }),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpazi.xs),
                        ],
                        Text(
                          _ripetizioneTipo == ripetizioneMai
                              ? "L'appuntamento non si ripete."
                              : 'Ripetizione: '
                                    '${etichettaRipetizione({'tipo': _ripetizioneTipo, 'intervallo_settimane': int.tryParse(_intervalloRipetizione.text) ?? 1})}.',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    _SezioneAppuntamento(
                      titolo: 'Notifica',
                      figli: [
                        DropdownButtonFormField<String>(
                          key: const Key('appuntamento-notifica'),
                          initialValue: _notificaScelta,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Avvisami',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'nessuna',
                              child: Text('Nessuna notifica'),
                            ),
                            DropdownMenuItem(
                              value: '0',
                              child: Text("All'ora dell'evento"),
                            ),
                            DropdownMenuItem(
                              value: '5',
                              child: Text('5 minuti prima'),
                            ),
                            DropdownMenuItem(
                              value: '10',
                              child: Text('10 minuti prima'),
                            ),
                            DropdownMenuItem(
                              value: '15',
                              child: Text('15 minuti prima'),
                            ),
                            DropdownMenuItem(
                              value: '30',
                              child: Text('30 minuti prima'),
                            ),
                            DropdownMenuItem(
                              value: 'personalizzata',
                              child: Text('Personalizza'),
                            ),
                          ],
                          onChanged: _salvando
                              ? null
                              : (valore) {
                                  if (valore == null) return;
                                  setState(() => _notificaScelta = valore);
                                },
                        ),
                        if (_notificaScelta == 'personalizzata')
                          TextFormField(
                            key: const Key('appuntamento-notifica-minuti'),
                            controller: _notificaPersonalizzata,
                            enabled: !_salvando,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Minuti prima',
                              hintText: 'Es. 45',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    _SezioneAppuntamento(
                      titolo: 'Privacy',
                      figli: const [],
                      extra: [
                        SwitchListTile(
                          key: const Key('appuntamento-privato'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Appuntamento privato'),
                          subtitle: const Text(
                            'Titolo, luogo e dettagli visibili solo a te e '
                            "all'utente assegnato.",
                          ),
                          value: _privato,
                          onChanged: _salvando
                              ? null
                              : (valore) => setState(() => _privato = valore),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    _SezioneAppuntamento(
                      titolo: 'Allegati',
                      figli: const [],
                      extra: [
                        if (_caricamentoAllegati)
                          const Padding(
                            padding: EdgeInsets.only(bottom: AppSpazi.s),
                            child: LinearProgressIndicator(),
                          ),
                        if (_erroreAllegati != null) ...[
                          AvvisoErrore(
                            key: const Key('appuntamento-allegati-errore'),
                            testo: _erroreAllegati!,
                          ),
                          const SizedBox(height: AppSpazi.s),
                        ],
                        if (_allegati.isEmpty && _allegatiNuovi.isEmpty)
                          Text(
                            'Nessun allegato.',
                            style: tema.textTheme.bodySmall?.copyWith(
                              color: tema.colorScheme.onSurfaceVariant,
                            ),
                          )
                        else
                          Wrap(
                            spacing: AppSpazi.xs,
                            runSpacing: AppSpazi.xs,
                            children: [
                              for (final allegato in _allegati)
                                InputChip(
                                  key: Key(
                                    'appuntamento-allegato-${allegato.id}',
                                  ),
                                  avatar: Icon(
                                    allegato.immagine
                                        ? Icons.image_outlined
                                        : allegato.video
                                        ? Icons.videocam_outlined
                                        : Icons.attach_file,
                                    size: 16,
                                  ),
                                  label: Text(
                                    '${allegato.nome} · '
                                    '${allegato.dimensioneLeggibile}',
                                  ),
                                  onPressed: _salvando
                                      ? null
                                      : () => _apriAllegato(allegato),
                                  onDeleted: _salvando
                                      ? null
                                      : () => _eliminaAllegato(allegato),
                                ),
                              for (final file in _allegatiNuovi)
                                InputChip(
                                  key: Key(
                                    'appuntamento-nuovo-allegato-${file.name}',
                                  ),
                                  avatar: const Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 16,
                                  ),
                                  label: Text('${file.name} · da caricare'),
                                  onDeleted: _salvando
                                      ? null
                                      : () => setState(
                                          () => _allegatiNuovi.remove(file),
                                        ),
                                ),
                            ],
                          ),
                        const SizedBox(height: AppSpazi.s),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            key: const Key('appuntamento-allegati-aggiungi'),
                            onPressed: _salvando ? null : _scegliAllegati,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('Aggiungi immagini o video'),
                          ),
                        ),
                        const SizedBox(height: AppSpazi.xxs),
                        Text(
                          'Max 10 MB per file. Puoi allegare immagini, video, '
                          'PDF o file email.',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
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
                            'Nessun collega invitato.',
                            key: const Key('appuntamento-nessun-invitato'),
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
                        const SizedBox(height: AppSpazi.xxs),
                        Text(
                          'I colleghi invitati ricevono una notifica e possono '
                          'confermare o rifiutare la disponibilità.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
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
