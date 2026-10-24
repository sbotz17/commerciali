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
    this.durataMin = 60,
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
      durataMin: (map['durata_min'] as num?)?.toInt() ?? 60,
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
      statoCondivisione:
          (map['stato_condivisione'] as String?) ??
          statoCondivisioneNonCondiviso,
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

  /// Durata in minuti (campo `durata_min`), default 60.
  final int durataMin;

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

  /// Serializza verso i campi Firestore (snake_case), escluso [id] che è la
  /// chiave documento.
  Map<String, dynamic> toMap() => {
    'azienda_id': aziendaId,
    'titolo': titolo,
    'tipo': tipo,
    'data': data,
    'ora': ora,
    'durata_min': durataMin,
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
