// Modello della notifica mostrata all'utente.
//
// I campi del documento Firestore sono snake_case (`azienda_id`,
// `utente_uid`, `mittente_uid`, `target_tipo`, `target_id`,
// `programmata_at`, `inviata_at`, `letta_at`, `idempotenza_key`,
// `created_at`); il modello li espone in camelCase ([aziendaId], [utenteUid],
// [mittenteUid], [targetTipo], [targetId], [programmataAt], [inviataAt],
// [lettaAt], [idempotenzaKey], [createdAt]) come convenzione Dart/Flutter.

/// Notifica come vive nella collezione Firestore `notifiche`.
///
/// Rappresenta una notifica rivolta a un utente, collegata a un elemento
/// dell'app (appuntamento, task, promemoria, chat o comunicazione) e
/// consegnata su uno o più canali.
///
/// I nomi dei campi Firestore sono snake_case; il modello li espone in
/// camelCase come convenzione Dart/Flutter.
class Notifica {
  const Notifica({
    required this.id,
    this.aziendaId,
    this.utenteUid,
    this.mittenteUid,
    this.tipo,
    this.titolo,
    this.testo,
    this.targetTipo,
    this.targetId,
    this.canale,
    this.stato = 'programmata',
    this.programmataAt,
    this.inviataAt,
    this.lettaAt,
    this.tentativi = 0,
    this.errore,
    this.idempotenzaKey,
    this.createdAt,
  });

  /// Crea una notifica dal documento Firestore. [id] è l'id del documento.
  factory Notifica.fromMap(Map<String, dynamic> map, {required String id}) {
    return Notifica(
      id: id,
      aziendaId: map['azienda_id'] as String?,
      utenteUid: map['utente_uid'] as String?,
      mittenteUid: map['mittente_uid'] as String?,
      tipo: map['tipo'] as String?,
      titolo: map['titolo'] as String?,
      testo: map['testo'] as String?,
      targetTipo: map['target_tipo'] as String?,
      targetId: map['target_id'] as String?,
      canale: map['canale'] as String?,
      stato: (map['stato'] as String?) ?? 'programmata',
      programmataAt: map['programmata_at'] as String?,
      inviataAt: map['inviata_at'] as String?,
      lettaAt: map['letta_at'] as String?,
      tentativi: (map['tentativi'] as num?)?.toInt() ?? 0,
      errore: map['errore'] as String?,
      idempotenzaKey: map['idempotenza_key'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  /// Id del documento `notifiche`.
  final String id;

  /// Id dell'azienda a cui appartiene (campo Firestore `azienda_id`).
  final String? aziendaId;

  /// Uid dell'utente destinatario (campo `utente_uid`).
  final String? utenteUid;

  /// Uid dell'utente che ha generato la notifica (campo `mittente_uid`).
  final String? mittenteUid;

  /// Tipo di evento (`appuntamento`, `task`, `promemoria`, `chat`,
  /// `comunicazione`). Campo `tipo`.
  final String? tipo;

  /// Titolo della notifica (campo `titolo`).
  final String? titolo;

  /// Corpo della notifica (campo `testo`).
  final String? testo;

  /// Tipo dell'elemento collegato (campo `target_tipo`).
  final String? targetTipo;

  /// Id dell'elemento collegato (campo `target_id`).
  final String? targetId;

  /// Canale di consegna (`inapp`, `push`, `whatsapp`, `email`). Campo
  /// `canale`.
  final String? canale;

  /// Stato (`programmata`, `inviata`, `letta`, `fallita`). Campo `stato`,
  /// default `programmata`.
  final String stato;

  /// Timestamp di programmazione ISO-8601 (campo `programmata_at`).
  final String? programmataAt;

  /// Timestamp di invio effettivo ISO-8601 (campo `inviata_at`).
  final String? inviataAt;

  /// Timestamp di lettura ISO-8601 (campo `letta_at`).
  final String? lettaAt;

  /// Numero di tentativi di invio (campo `tentativi`), default 0.
  final int tentativi;

  /// Descrizione dell'eventuale errore (campo `errore`).
  final String? errore;

  /// Chiave di idempotenza per evitare invii duplicati (campo
  /// `idempotenza_key`).
  final String? idempotenzaKey;

  /// Timestamp di creazione ISO-8601 (campo `created_at`).
  final String? createdAt;

  /// Serializza verso i campi Firestore (snake_case), escluso [id] che è la
  /// chiave documento.
  Map<String, dynamic> toMap() => {
        'azienda_id': aziendaId,
        'utente_uid': utenteUid,
        'mittente_uid': mittenteUid,
        'tipo': tipo,
        'titolo': titolo,
        'testo': testo,
        'target_tipo': targetTipo,
        'target_id': targetId,
        'canale': canale,
        'stato': stato,
        'programmata_at': programmataAt,
        'inviata_at': inviataAt,
        'letta_at': lettaAt,
        'tentativi': tentativi,
        'errore': errore,
        'idempotenza_key': idempotenzaKey,
        'created_at': createdAt,
      };
}

/// Etichetta leggibile per il tipo di una notifica, con fallback.
String etichettaTipoNotifica(String? tipo) {
  const etichette = {
    'appuntamento': 'Appuntamento',
    'task': 'Task',
    'promemoria': 'Promemoria',
    'chat': 'Chat',
    'comunicazione': 'Comunicazione',
  };
  final t = tipo?.trim();
  if (t == null || t.isEmpty) return 'Non definita';
  return etichette[t] ?? t;
}

/// Etichetta leggibile per il canale di una notifica, con fallback.
String etichettaCanaleNotifica(String? canale) {
  const etichette = {
    'inapp': 'In app',
    'push': 'Push',
    'whatsapp': 'WhatsApp',
    'email': 'Email',
  };
  final c = canale?.trim();
  if (c == null || c.isEmpty) return 'Non definito';
  return etichette[c] ?? c;
}

/// Ritorna `true` se [n] non è ancora stata letta (`lettaAt` assente o vuoto).
bool notificaNonLetta(Notifica n) {
  final lettaAt = n.lettaAt?.trim();
  return lettaAt == null || lettaAt.isEmpty;
}
