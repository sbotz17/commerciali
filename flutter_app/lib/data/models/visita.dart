// Modello della visita del giro visite.
//
// Riproduce fedelmente la struttura dati della vecchia app
// (`js/sp-firestore.js` → collezione `giro_visite`): i campi del documento
// sono snake_case (`cliente_id`, `visita_padre_id`, `promemoria_min`,
// `created_at`); il modello li espone in camelCase ([clienteId],
// [visitaPadreId], [promemoriaMin]) come convenzione Dart/Flutter.

/// Visita come vive nella collezione Firestore `giro_visite`.
///
/// I nomi dei campi Firestore sono snake_case; il modello li espone in
/// camelCase come convenzione Dart/Flutter.
class Visita {
  const Visita({
    required this.id,
    this.aziendaId,
    this.utenteId,
    this.clienteId,
    this.clienteNome,
    this.telefono,
    this.indirizzo,
    this.data,
    this.ora,
    this.ordine = 0,
    this.stato = 'da_fare',
    this.note,
    this.visitaPadreId,
    this.promemoriaMin,
    this.promemoriaAt,
    this.promemoriaNumero,
    this.promemoriaInviatoAt,
  });

  /// Crea una visita dal documento Firestore. [id] è l'id del documento.
  factory Visita.fromMap(Map<String, dynamic> map, {required String id}) {
    return Visita(
      id: id,
      aziendaId: map['azienda_id'] as String?,
      utenteId: map['utente_id'] as String?,
      clienteId: map['cliente_id'] as String?,
      clienteNome: map['cliente_nome'] as String?,
      telefono: map['telefono'] as String?,
      indirizzo: map['indirizzo'] as String?,
      data: map['data'] as String?,
      ora: map['ora'] as String?,
      ordine: (map['ordine'] as num?)?.toInt() ?? 0,
      stato: (map['stato'] as String?) ?? 'da_fare',
      note: map['note'] as String?,
      visitaPadreId: map['visita_padre_id'] as String?,
      promemoriaMin: (map['promemoria_min'] as num?)?.toInt(),
      promemoriaAt: map['promemoria_at'] as String?,
      promemoriaNumero: map['promemoria_numero'] as String?,
      promemoriaInviatoAt: map['promemoria_inviato_at'] as String?,
    );
  }

  /// Id del documento `giro_visite`.
  final String id;

  /// Id dell'azienda a cui appartiene (campo Firestore `azienda_id`).
  final String? aziendaId;

  /// Id dell'utente a cui è assegnata la visita (campo `utente_id`).
  final String? utenteId;

  /// Id del cliente collegato (campo `cliente_id`).
  final String? clienteId;

  /// Nome del cliente denormalizzato (campo `cliente_nome`).
  final String? clienteNome;

  /// Telefono del cliente (campo `telefono`).
  final String? telefono;

  /// Indirizzo del cliente (campo `indirizzo`).
  final String? indirizzo;

  /// Data della visita `YYYY-MM-DD` (campo `data`).
  final String? data;

  /// Ora della visita `HH:MM` (campo `ora`).
  final String? ora;

  /// Posizione nella lista del giro (campo `ordine`), default 0.
  final int ordine;

  /// Stato della visita (`da_fare`, `fatto`, ...). Campo `stato`, default
  /// `da_fare` (come la vecchia app).
  final String stato;

  /// Note libere (campo `note`).
  final String? note;

  /// Id della visita padre per le visite ricorrenti (campo `visita_padre_id`).
  final String? visitaPadreId;

  /// Minuti di anticipo del promemoria (campo `promemoria_min`), `null` se
  /// assente.
  final int? promemoriaMin;

  /// Timestamp a cui è programmato il promemoria (campo `promemoria_at`).
  final String? promemoriaAt;

  /// Numero di telefono a cui inviare il promemoria (campo
  /// `promemoria_numero`).
  final String? promemoriaNumero;

  /// Timestamp di invio del promemoria (campo `promemoria_inviato_at`),
  /// `null` se non ancora inviato.
  final String? promemoriaInviatoAt;

  /// Serializza verso i campi Firestore (snake_case), escluso [id] che è la
  /// chiave documento.
  Map<String, dynamic> toMap() => {
        'azienda_id': aziendaId,
        'utente_id': utenteId,
        'cliente_id': clienteId,
        'cliente_nome': clienteNome,
        'telefono': telefono,
        'indirizzo': indirizzo,
        'data': data,
        'ora': ora,
        'ordine': ordine,
        'stato': stato,
        'note': note,
        'visita_padre_id': visitaPadreId,
        'promemoria_min': promemoriaMin,
        'promemoria_at': promemoriaAt,
        'promemoria_numero': promemoriaNumero,
        'promemoria_inviato_at': promemoriaInviatoAt,
      };
}
