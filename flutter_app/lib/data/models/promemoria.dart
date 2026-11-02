// Modello del promemoria di invio notifiche.
//
// I campi del documento Firestore sono snake_case (`azienda_id`,
// `riferito_a`, `elemento_id`, `destinatario_tipo`, `quando_at`,
// `inviato_at`, `idempotenza_key`, `created_at`); il modello li espone in
// camelCase ([aziendaId], [riferitoA], [elementoId], [destinatarioTipo],
// [quandoAt], [inviatoAt], [idempotenzaKey], [createdAt]) come convenzione
// Dart/Flutter.

/// Promemoria come vive nella collezione Firestore `promemoria`.
///
/// Rappresenta un invio programmato (in-app, push, WhatsApp o email) verso
/// un operatore o un cliente, legato a un elemento dell'agenda
/// (appuntamento, task o visita).
///
/// I nomi dei campi Firestore sono snake_case; il modello li espone in
/// camelCase come convenzione Dart/Flutter.
class Promemoria {
  const Promemoria({
    required this.id,
    this.aziendaId,
    this.riferitoA,
    this.elementoId,
    this.destinatarioTipo,
    this.canale,
    this.destinatario,
    this.quandoAt,
    this.stato = 'programmato',
    this.inviatoAt,
    this.tentativi = 0,
    this.errore,
    this.idempotenzaKey,
    this.createdAt,
  });

  /// Crea un promemoria dal documento Firestore. [id] è l'id del documento.
  factory Promemoria.fromMap(Map<String, dynamic> map, {required String id}) {
    return Promemoria(
      id: id,
      aziendaId: map['azienda_id'] as String?,
      riferitoA: map['riferito_a'] as String?,
      elementoId: map['elemento_id'] as String?,
      destinatarioTipo: map['destinatario_tipo'] as String?,
      canale: map['canale'] as String?,
      destinatario: map['destinatario'] as String?,
      quandoAt: map['quando_at'] as String?,
      stato: (map['stato'] as String?) ?? 'programmato',
      inviatoAt: map['inviato_at'] as String?,
      tentativi: (map['tentativi'] as num?)?.toInt() ?? 0,
      errore: map['errore'] as String?,
      idempotenzaKey: map['idempotenza_key'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  /// Id del documento `promemoria`.
  final String id;

  /// Id dell'azienda a cui appartiene (campo Firestore `azienda_id`).
  final String? aziendaId;

  /// Tipo di elemento a cui si riferisce (`appuntamento`, `task`, `visita`).
  /// Campo `riferito_a`.
  final String? riferitoA;

  /// Id dell'elemento collegato (campo `elemento_id`).
  final String? elementoId;

  /// Tipo di destinatario (`operatore`, `cliente`). Campo `destinatario_tipo`.
  final String? destinatarioTipo;

  /// Canale di invio (`inapp`, `push`, `whatsapp`, `email`). Campo `canale`.
  final String? canale;

  /// Destinatario concreto: uid utente, numero di telefono o indirizzo email
  /// (campo `destinatario`).
  final String? destinatario;

  /// Timestamp di programmazione ISO-8601 UTC (campo `quando_at`).
  final String? quandoAt;

  /// Stato (`programmato`, `in_elaborazione`, `inviato`, `fallito`,
  /// `annullato`). Campo `stato`, default `programmato`.
  final String stato;

  /// Timestamp di invio effettivo ISO-8601 (campo `inviato_at`).
  final String? inviatoAt;

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
        'riferito_a': riferitoA,
        'elemento_id': elementoId,
        'destinatario_tipo': destinatarioTipo,
        'canale': canale,
        'destinatario': destinatario,
        'quando_at': quandoAt,
        'stato': stato,
        'inviato_at': inviatoAt,
        'tentativi': tentativi,
        'errore': errore,
        'idempotenza_key': idempotenzaKey,
        'created_at': createdAt,
      };
}
