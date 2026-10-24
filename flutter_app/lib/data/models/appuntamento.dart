// Modello dell'appuntamento in agenda.
//
// I campi del documento Firestore sono snake_case (`azienda_id`,
// `durata_min`, `call_provider`, `invitati_uids`, `stato_condivisione`,
// `created_at`); il modello li espone in camelCase ([aziendaId], [durataMin],
// [callProvider], [invitatiUids], [statoCondivisione], [createdAt]) come
// convenzione Dart/Flutter.

/// Stato della condivisione dell'appuntamento con i colleghi.
const String statoCondivisioneNonCondiviso = 'non_condiviso';
const String statoCondivisioneInAttesa = 'in_attesa';
const String statoCondivisioneConfermato = 'confermato';
const String statoCondivisioneRifiutato = 'rifiutato';

/// Appuntamento come vive nella collezione Firestore `appuntamenti`.
///
/// I nomi dei campi Firestore sono snake_case; il modello li espone in
/// camelCase come convenzione Dart/Flutter.
class Appuntamento {
  const Appuntamento({
    required this.id,
    this.aziendaId,
    this.titolo,
    this.tipo = 'appuntamento',
    this.data,
    this.ora,
    this.dataFine,
    this.oraFine,
    this.tuttoIlGiorno = false,
    this.durataMin = 60,
    this.ripetizione = const {'tipo': 'mai'},
    this.notificaMin,
    this.privato = false,
    this.clienteId,
    this.clienteNome,
    this.operatoreId,
    this.luogo,
    this.indirizzo,
    this.note,
    this.stato = 'da_fare',
    this.visitaId,
    this.callProvider,
    this.callUrl,
    this.meetingId,
    this.googleEventId,
    this.outlookEventId,
    this.invitatiUids = const [],
    this.conferme = const {},
    this.statoCondivisione = statoCondivisioneNonCondiviso,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Crea un appuntamento dal documento Firestore. [id] è l'id del documento.
  factory Appuntamento.fromMap(Map<String, dynamic> map, {required String id}) {
    return Appuntamento(
      id: id,
      aziendaId: map['azienda_id'] as String?,
      titolo: map['titolo'] as String?,
      tipo: (map['tipo'] as String?) ?? 'appuntamento',
      data: map['data'] as String?,
      ora: map['ora'] as String?,
      dataFine: map['data_fine'] as String?,
      oraFine: map['ora_fine'] as String?,
      tuttoIlGiorno: map['tutto_il_giorno'] == true,
      durataMin: (map['durata_min'] as num?)?.toInt() ?? 60,
      ripetizione: _mappaRipetizione(map['ripetizione']),
      notificaMin: (map['notifica_min'] as num?)?.toInt(),
      privato: map['privato'] == true,
      clienteId: map['cliente_id'] as String?,
      clienteNome: map['cliente_nome'] as String?,
      operatoreId: map['operatore_id'] as String?,
      luogo: map['luogo'] as String?,
      indirizzo: map['indirizzo'] as String?,
      note: map['note'] as String?,
      stato: (map['stato'] as String?) ?? 'da_fare',
      visitaId: map['visita_id'] as String?,
      callProvider: map['call_provider'] as String?,
      callUrl: map['call_url'] as String?,
      meetingId: map['meeting_id'] as String?,
      googleEventId: map['google_event_id'] as String?,
      outlookEventId: map['outlook_event_id'] as String?,
      invitatiUids: _listaUid(map['invitati_uids']),
      conferme: _mappaConferme(map['conferme']),
      statoCondivisione: _normalizzaStatoCondivisione(
        map['stato_condivisione'],
      ),
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  /// Id del documento `appuntamenti`.
  final String id;

  /// Id dell'azienda a cui appartiene (campo Firestore `azienda_id`).
  final String? aziendaId;

  /// Titolo dell'appuntamento (campo `titolo`).
  final String? titolo;

  /// Tipologia (`visita`, `appuntamento`). Campo `tipo`, default
  /// `appuntamento`.
  final String tipo;

  /// Data dell'appuntamento `YYYY-MM-DD` (campo `data`).
  final String? data;

  /// Ora dell'appuntamento `HH:MM` (campo `ora`).
  final String? ora;

  /// Data di fine (campo `data_fine`), `YYYY-MM-DD`.
  final String? dataFine;

  /// Ora di fine (campo `ora_fine`), `HH:MM`.
  final String? oraFine;

  /// `true` per un appuntamento che dura tutto il giorno (campo
  /// `tutto_il_giorno`).
  final bool tuttoIlGiorno;

  /// Durata in minuti (campo `durata_min`), default 60. Per gli appuntamenti
  /// con inizio e fine viene ricalcolata al salvataggio.
  final int durataMin;

  /// Regola di ripetizione (campo `ripetizione`).
  final Map<String, dynamic> ripetizione;

  /// Minuti prima dell'inizio per la notifica (campo `notifica_min`).
  ///
  /// `0` = all'ora dell'evento, `null` = nessuna notifica.
  final int? notificaMin;

  /// `true` se titolo, luogo e dettagli sono visibili solo a creatore e
  /// operatore (campo `privato`).
  final bool privato;

  /// Id del cliente collegato (campo `cliente_id`).
  final String? clienteId;

  /// Nome del cliente denormalizzato (campo `cliente_nome`).
  final String? clienteNome;

  /// Id dell'operatore assegnato (campo `operatore_id`).
  final String? operatoreId;

  /// Luogo dell'appuntamento (campo `luogo`).
  final String? luogo;

  /// Indirizzo (campo `indirizzo`).
  final String? indirizzo;

  /// Note libere (campo `note`).
  final String? note;

  /// Stato (`da_fare`, `fatto`, `annullato`). Campo `stato`, default
  /// `da_fare`.
  final String stato;

  /// Id della visita collegata, se presente (campo `visita_id`).
  final String? visitaId;

  /// Provider della call (`google_meet`, `teams`, `manuale`). Campo
  /// `call_provider`.
  final String? callProvider;

  /// URL della call (campo `call_url`).
  final String? callUrl;

  /// Id del meeting (campo `meeting_id`).
  final String? meetingId;

  /// Id dell'evento Google Calendar (campo `google_event_id`).
  final String? googleEventId;

  /// Id dell'evento Outlook (campo `outlook_event_id`).
  final String? outlookEventId;

  /// Uid dei colleghi invitati a confermare la disponibilità (campo
  /// `invitati_uids`).
  final List<String> invitatiUids;

  /// Risposte degli invitati: uid → `{stato, at}` (campo `conferme`).
  final Map<String, dynamic> conferme;

  /// Stato della condivisione (`non_condiviso`, `in_attesa`, `confermato`,
  /// `rifiutato`). Campo `stato_condivisione`, default `non_condiviso`.
  final String statoCondivisione;

  /// `true` quando ci sono invitati e nessuno ha ancora confermato.
  bool get inAttesaDiConferma =>
      invitatiUids.isNotEmpty && statoCondivisione == statoCondivisioneInAttesa;

  /// Id dell'utente che ha creato il record (campo `created_by`).
  final String? createdBy;

  /// Timestamp di creazione ISO-8601 (campo `created_at`).
  final String? createdAt;

  /// Timestamp di ultima modifica ISO-8601 (campo `updated_at`).
  final String? updatedAt;

  /// Copia con i dettagli riservati letti dalla sotto-collezione privata.
  ///
  /// Per i documenti privati il documento principale contiene solo i dati di
  /// occupazione; titolo, luogo, indirizzo, note e cliente arrivano da
  /// `appuntamenti/{id}/privato/dettagli`, leggibile solo a creatore,
  /// operatore e super admin.
  Appuntamento conDettagliPrivati(Map<String, dynamic> dettagli) {
    String? testo(String chiave, String? attuale) {
      final valore = dettagli[chiave];
      if (valore == null) return attuale;
      final pulito = valore.toString().trim();
      return pulito.isEmpty ? null : pulito;
    }

    return Appuntamento(
      id: id,
      aziendaId: aziendaId,
      titolo: testo('titolo', titolo),
      tipo: tipo,
      data: data,
      ora: ora,
      dataFine: dataFine,
      oraFine: oraFine,
      tuttoIlGiorno: tuttoIlGiorno,
      durataMin: durataMin,
      ripetizione: ripetizione,
      notificaMin: notificaMin,
      privato: privato,
      clienteId: testo('cliente_id', clienteId),
      clienteNome: testo('cliente_nome', clienteNome),
      operatoreId: operatoreId,
      luogo: testo('luogo', luogo),
      indirizzo: testo('indirizzo', indirizzo),
      note: testo('note', note),
      stato: stato,
      visitaId: visitaId,
      callProvider: testo('call_provider', callProvider),
      callUrl: testo('call_url', callUrl),
      meetingId: meetingId,
      googleEventId: googleEventId,
      outlookEventId: outlookEventId,
      invitatiUids: invitatiUids,
      conferme: conferme,
      statoCondivisione: statoCondivisione,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Serializza verso i campi Firestore (snake_case), escluso [id] che è la
  /// chiave documento.
  Map<String, dynamic> toMap() => {
    'azienda_id': aziendaId,
    'titolo': titolo,
    'tipo': tipo,
    'data': data,
    'ora': ora,
    'data_fine': dataFine,
    'ora_fine': oraFine,
    'tutto_il_giorno': tuttoIlGiorno,
    'durata_min': durataMin,
    'ripetizione': ripetizione,
    'notifica_min': notificaMin,
    'privato': privato,
    'cliente_id': clienteId,
    'cliente_nome': clienteNome,
    'operatore_id': operatoreId,
    'luogo': luogo,
    'indirizzo': indirizzo,
    'note': note,
    'stato': stato,
    'visita_id': visitaId,
    'call_provider': callProvider,
    'call_url': callUrl,
    'meeting_id': meetingId,
    'google_event_id': googleEventId,
    'outlook_event_id': outlookEventId,
    'invitati_uids': invitatiUids,
    'conferme': conferme,
    'stato_condivisione': statoCondivisione,
    'created_by': createdBy,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

/// Combina [data] (`YYYY-MM-DD`) e [ora] (`HH:MM`) in un [DateTime].
///
/// Ritorna `null` se una delle due è assente, non rispetta il formato o
/// rappresenta una data/ora non valida (es. `2026-02-30` o `25:00`).
DateTime? dataOraAppuntamento(Appuntamento a) => _combinaDataOra(a.data, a.ora);

/// Tipi di ripetizione accettati.
const String ripetizioneMai = 'mai';
const String ripetizioneGiornaliera = 'giornaliera';
const String ripetizioneSettimanale = 'settimanale';
const String ripetizioneBisettimanale = 'bisettimanale';
const String ripetizioneMensile = 'mensile';
const String ripetizioneAnnuale = 'annuale';
const String ripetizionePersonalizzata = 'personalizzata';

const List<String> nomiGiorniRipetizione = [
  'Lunedì',
  'Martedì',
  'Mercoledì',
  'Giovedì',
  'Venerdì',
  'Sabato',
  'Domenica',
];

/// `true` se l'appuntamento ha una regola di ripetizione attiva.
bool appuntamentoRicorrente(Appuntamento a) {
  final tipo = (a.ripetizione['tipo'] ?? ripetizioneMai).toString();
  return tipo != ripetizioneMai;
}

/// Etichetta italiana della regola di ripetizione.
String etichettaRipetizione(Map<String, dynamic>? regola) {
  final tipo = (regola?['tipo'] ?? ripetizioneMai).toString();
  switch (tipo) {
    case ripetizioneGiornaliera:
      return 'Ogni giorno';
    case ripetizioneSettimanale:
      return 'Ogni settimana';
    case ripetizioneBisettimanale:
      return 'Ogni due settimane';
    case ripetizioneMensile:
      return 'Ogni mese';
    case ripetizioneAnnuale:
      return 'Ogni anno';
    case ripetizionePersonalizzata:
      final intervallo =
          int.tryParse(regola?['intervallo_settimane']?.toString() ?? '') ?? 1;
      return intervallo <= 1 ? 'Personalizzata' : 'Ogni $intervallo settimane';
    default:
      return 'Mai';
  }
}

/// Giorni della settimana selezionati (1 = lunedì … 7 = domenica).
List<int> giorniRipetizione(Map<String, dynamic>? regola) {
  final valori = regola?['giorni_settimana'];
  if (valori is! List) return const [];
  final giorni = <int>{};
  for (final valore in valori) {
    final giorno = valore is int ? valore : int.tryParse(valore.toString());
    if (giorno == null || giorno < 1 || giorno > 7) continue;
    giorni.add(giorno);
  }
  final ordinati = giorni.toList()..sort();
  return ordinati;
}

/// Inizio dell'appuntamento: data + ora, oppure mezzanotte se dura tutto il
/// giorno.
DateTime? inizioAppuntamento(Appuntamento a) {
  final data = _dataDaStringa(a.data);
  if (data == null) return null;
  if (a.tuttoIlGiorno) return data;
  return _combinaDataOra(a.data, a.ora) ?? data;
}

/// Fine dell'appuntamento: data/ora di fine, oppure inizio + durata.
DateTime? fineAppuntamento(Appuntamento a) {
  final inizio = inizioAppuntamento(a);
  if (inizio == null) return null;
  if (a.tuttoIlGiorno) {
    final fine = _dataDaStringa(a.dataFine) ?? _dataDaStringa(a.data);
    return fine == null
        ? inizio
        : DateTime(fine.year, fine.month, fine.day + 1);
  }
  final fineEsplicita = _combinaDataOra(a.dataFine, a.oraFine);
  if (fineEsplicita != null && fineEsplicita.isAfter(inizio)) {
    return fineEsplicita;
  }
  return inizio.add(Duration(minutes: a.durataMin <= 0 ? 30 : a.durataMin));
}

/// Durata effettiva in minuti, ricavata da inizio e fine.
int durataEffettivaAppuntamento(Appuntamento a) {
  if (a.tuttoIlGiorno) return 24 * 60;
  final inizio = inizioAppuntamento(a);
  final fine = fineAppuntamento(a);
  if (inizio == null || fine == null) {
    return a.durataMin <= 0 ? 30 : a.durataMin;
  }
  final minuti = fine.difference(inizio).inMinutes;
  return minuti <= 0 ? 30 : minuti;
}

/// `true` se [uid] può vedere titolo, luogo e dettagli dell'appuntamento.
///
/// Gli appuntamenti privati sono visibili per intero solo al creatore e
/// all'utente assegnato; gli altri vedono solo l'occupazione della fascia.
bool puoVedereDettagliAppuntamento(Appuntamento? appuntamento, String? uid) {
  if (appuntamento == null || !appuntamento.privato) return true;
  if (uid == null || uid.isEmpty) return false;
  return appuntamento.createdBy == uid || appuntamento.operatoreId == uid;
}

/// Date delle occorrenze dell'appuntamento comprese tra [dal] e [al].
///
/// Per gli appuntamenti non ricorrenti restituisce la sola data di inizio se
/// cade nell'intervallo. Le date sono normalizzate a mezzanotte.
List<DateTime> occorrenzeAppuntamento(
  Appuntamento a, {
  required DateTime dal,
  required DateTime al,
}) {
  final inizio = _dataDaStringa(a.data);
  if (inizio == null) return const [];
  final da = _dataDaStringa(dal.toIso8601String());
  final a2 = _dataDaStringa(al.toIso8601String());
  if (da == null || a2 == null || a2.isBefore(da)) return const [];

  final regola = a.ripetizione;
  final tipo = (regola['tipo'] ?? ripetizioneMai).toString();
  final giorni = giorniRipetizione(regola);
  final giorniEffettivi = giorni.isEmpty ? [inizio.weekday] : giorni;
  final intervallo =
      (int.tryParse(regola['intervallo_settimane']?.toString() ?? '') ?? 1)
          .clamp(1, 52);

  bool dentro(DateTime data) =>
      !data.isBefore(inizio) && !data.isBefore(da) && !data.isAfter(a2);

  final risultato = <DateTime>[];
  void aggiungi(DateTime data) {
    final giorno = DateTime(data.year, data.month, data.day);
    if (!dentro(giorno)) return;
    if (!risultato.contains(giorno)) risultato.add(giorno);
  }

  if (tipo == ripetizioneMai) {
    aggiungi(inizio);
    return risultato;
  }

  if (tipo == ripetizioneGiornaliera) {
    var data = inizio.isBefore(da) ? da : inizio;
    while (!data.isAfter(a2) && risultato.length < 1500) {
      aggiungi(data);
      data = DateTime(data.year, data.month, data.day + 1);
    }
    risultato.sort();
    return risultato;
  }

  if (tipo == ripetizioneSettimanale ||
      tipo == ripetizioneBisettimanale ||
      tipo == ripetizionePersonalizzata) {
    final passo = tipo == ripetizioneBisettimanale
        ? 2
        : tipo == ripetizionePersonalizzata
        ? intervallo
        : 1;
    final lunedi = DateTime(
      inizio.year,
      inizio.month,
      inizio.day - (inizio.weekday - 1),
    );
    var settimana = 0;
    while (risultato.length < 1500) {
      final base = DateTime(
        lunedi.year,
        lunedi.month,
        lunedi.day + settimana * 7 * passo,
      );
      if (base.isAfter(a2)) break;
      for (final giorno in giorniEffettivi) {
        aggiungi(DateTime(base.year, base.month, base.day + giorno - 1));
      }
      settimana++;
    }
    risultato.sort();
    return risultato;
  }

  if (tipo == ripetizioneMensile) {
    var anno = inizio.year;
    var mese = inizio.month;
    while (risultato.length < 1500) {
      final data = DateTime(anno, mese, inizio.day);
      if (data.isAfter(a2) && (anno > a2.year || mese > a2.month)) break;
      if (data.month == mese) aggiungi(data);
      mese++;
      if (mese > 12) {
        mese = 1;
        anno++;
      }
      if (anno > a2.year + 1) break;
    }
    risultato.sort();
    return risultato;
  }

  if (tipo == ripetizioneAnnuale) {
    for (
      var anno = inizio.year;
      anno <= a2.year && risultato.length < 1500;
      anno++
    ) {
      final data = DateTime(anno, inizio.month, inizio.day);
      if (data.month == inizio.month) aggiungi(data);
    }
    risultato.sort();
    return risultato;
  }

  aggiungi(inizio);
  return risultato;
}

DateTime? _dataDaStringa(String? valore) {
  final testo = valore?.trim() ?? '';
  if (testo.isEmpty) return null;
  final data = DateTime.tryParse(testo);
  if (data == null) return null;
  return DateTime(data.year, data.month, data.day);
}

Map<String, dynamic> _mappaRipetizione(dynamic valore) {
  if (valore is! Map) return const {'tipo': ripetizioneMai};
  final tipoGrezzo = (valore['tipo'] ?? ripetizioneMai).toString();
  const tipi = {
    ripetizioneMai,
    ripetizioneGiornaliera,
    ripetizioneSettimanale,
    ripetizioneBisettimanale,
    ripetizioneMensile,
    ripetizioneAnnuale,
    ripetizionePersonalizzata,
  };
  final tipo = tipi.contains(tipoGrezzo) ? tipoGrezzo : ripetizioneMai;
  final giorni = giorniRipetizione(Map<String, dynamic>.from(valore));
  final intervallo =
      int.tryParse(valore['intervallo_settimane']?.toString() ?? '') ?? 1;
  return {
    'tipo': tipo,
    'giorni_settimana': giorni,
    'intervallo_settimane': intervallo.clamp(1, 52),
  };
}

/// Etichetta leggibile per lo stato di un appuntamento, con fallback.
String etichettaStatoAppuntamento(String? stato) {
  const etichette = {
    'da_fare': 'Da fare',
    'fatto': 'Fatto',
    'annullato': 'Annullato',
  };
  final s = stato?.trim();
  if (s == null || s.isEmpty) return 'Sconosciuto';
  return etichette[s] ?? s;
}

/// Etichetta italiana dello stato di condivisione.
String etichettaStatoCondivisione(String? stato) {
  switch (stato?.trim().toLowerCase()) {
    case statoCondivisioneInAttesa:
      return 'In attesa di conferma';
    case statoCondivisioneConfermato:
      return 'Confermato';
    case statoCondivisioneRifiutato:
      return 'Non disponibile';
    default:
      return 'Non condiviso';
  }
}

/// Etichetta della notifica configurata.
String etichettaNotificaAppuntamento(int? minuti) {
  if (minuti == null) return 'Nessuna';
  if (minuti <= 0) return 'All\'ora dell\'evento';
  return '$minuti minuti prima';
}

/// Etichetta della risposta di un singolo invitato (`null` = in attesa).
String etichettaRispostaInvito(String? stato) {
  switch (stato?.trim().toLowerCase()) {
    case 'confermato':
      return 'Confermato';
    case 'rifiutato':
      return 'Non disponibile';
    default:
      return 'In attesa';
  }
}

/// Stato (`confermato`/`rifiutato`) della risposta dell'utente [uid], oppure
/// `null` se non ha ancora risposto.
String? rispostaInvito(Map<String, dynamic> conferme, String uid) {
  final valore = conferme[uid];
  if (valore is Map) {
    final stato = (valore['stato'] as String?)?.trim().toLowerCase();
    return stato == 'confermato' || stato == 'rifiutato' ? stato : null;
  }
  if (valore is String) {
    final stato = valore.trim().toLowerCase();
    return stato == 'confermato' || stato == 'rifiutato' ? stato : null;
  }
  return null;
}

/// Calcola lo stato della condivisione dalle risposte ricevute.
///
/// - nessun invitato → `non_condiviso`;
/// - almeno un `confermato` → `confermato`;
/// - tutti hanno risposto `rifiutato` → `rifiutato`;
/// - altrimenti → `in_attesa`.
String statoCondivisioneDaConferme(
  List<String> invitati,
  Map<String, dynamic> conferme,
) {
  final unici = <String>{
    for (final uid in invitati)
      if (uid.trim().isNotEmpty) uid.trim(),
  };
  if (unici.isEmpty) return statoCondivisioneNonCondiviso;

  var risposte = 0;
  var confermati = 0;
  for (final uid in unici) {
    final risposta = rispostaInvito(conferme, uid);
    if (risposta == null) continue;
    risposte++;
    if (risposta == 'confermato') confermati++;
  }
  if (confermati > 0) return statoCondivisioneConfermato;
  if (risposte == unici.length) return statoCondivisioneRifiutato;
  return statoCondivisioneInAttesa;
}

/// Testo della notifica inviata a chi ha creato l'appuntamento quando un
/// invitato risponde.
String messaggioRispostaInvito({
  required String nomeRispondente,
  required bool disponibile,
  required String titolo,
  String? data,
  String? ora,
}) {
  final nome = nomeRispondente.trim().isEmpty
      ? 'Un collega'
      : nomeRispondente.trim();
  final oggetto = titolo.trim().isEmpty ? 'Appuntamento' : titolo.trim();
  final quando = [
    (data ?? '').trim(),
    (ora ?? '').trim(),
  ].where((voce) => voce.isNotEmpty).join(' ');
  final azione = disponibile
      ? 'ha confermato la disponibilità'
      : 'non è disponibile';
  return '$nome $azione per "$oggetto"'
      '${quando.isEmpty ? '.' : ' del $quando.'}';
}

List<String> _listaUid(dynamic valore) {
  if (valore is! List) return const [];
  final visti = <String>{};
  final risultato = <String>[];
  for (final elemento in valore) {
    if (elemento is! String) continue;
    final uid = elemento.trim();
    if (uid.isEmpty || !visti.add(uid)) continue;
    risultato.add(uid);
  }
  return risultato;
}

Map<String, dynamic> _mappaConferme(dynamic valore) {
  if (valore is! Map) return const {};
  final risultato = <String, dynamic>{};
  for (final voce in valore.entries) {
    final uid = voce.key.toString().trim();
    if (uid.isEmpty) continue;
    risultato[uid] = voce.value;
  }
  return risultato;
}

String _normalizzaStatoCondivisione(dynamic valore) {
  final stato = valore?.toString().trim().toLowerCase() ?? '';
  switch (stato) {
    case statoCondivisioneInAttesa:
    case statoCondivisioneConfermato:
    case statoCondivisioneRifiutato:
      return stato;
    default:
      return statoCondivisioneNonCondiviso;
  }
}

DateTime? _combinaDataOra(String? data, String? ora) {
  if (data == null || ora == null) return null;
  final dataMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
      .firstMatch(data.trim());
  final oraMatch = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(ora.trim());
  if (dataMatch == null || oraMatch == null) return null;

  final anno = int.tryParse(dataMatch.group(1)!);
  final mese = int.tryParse(dataMatch.group(2)!);
  final giorno = int.tryParse(dataMatch.group(3)!);
  final ore = int.tryParse(oraMatch.group(1)!);
  final minuti = int.tryParse(oraMatch.group(2)!);
  if (anno == null ||
      mese == null ||
      giorno == null ||
      ore == null ||
      minuti == null) {
    return null;
  }

  final dt = DateTime(anno, mese, giorno, ore, minuti);
  if (dt.year != anno ||
      dt.month != mese ||
      dt.day != giorno ||
      dt.hour != ore ||
      dt.minute != minuti) {
    return null;
  }
  return dt;
}
