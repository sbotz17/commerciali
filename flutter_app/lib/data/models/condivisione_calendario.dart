// Modello della condivisione del calendario tra due utenti.
//
// I campi del documento Firestore sono snake_case (`azienda_id`,
// `proprietario_uid`, `created_at`); il modello li espone in camelCase
// ([aziendaId], [proprietarioUid], [createdAt]) come convenzione Dart/Flutter.

import 'integrazione_azienda.dart';

/// Valori ammessi per lo stato di una condivisione.
const Set<String> _statiCondivisioneValidi = {'attiva', 'revocata'};

/// Valori ammessi per il livello di condivisione.
const Set<String> _livelliCondivisioneValidi = {
  'libero_occupato',
  'dettagli',
  'modifica',
};

/// Ritorna il livello se valido, altrimenti il default `dettagli`.
String _normalizzaLivello(String? valore) =>
    _livelliCondivisioneValidi.contains(valore) ? valore! : 'dettagli';

/// Ritorna lo stato se valido, altrimenti il default `attiva`.
String _normalizzaStato(String? valore) =>
    _statiCondivisioneValidi.contains(valore) ? valore! : 'attiva';

/// Sentinel usata da [copyWith] per distinguere "campo non passato" da
/// "campo da azzerare a `null`".
const Object _sentinel = Object();

/// Condivisione del calendario di un'azienda con un altro utente, come vive
/// nella collezione Firestore `condivisioni_calendario`.
class CondivisioneCalendario {
  /// Crea una condivisione. Livello e stato non validi ricadono sui default
  /// (`dettagli` e `attiva`).
  factory CondivisioneCalendario({
    required String id,
    String? aziendaId,
    String? proprietarioUid,
    String? destinatarioUid,
    String? livello,
    String? stato,
    String? creatoDa,
    String? createdAt,
    String? updatedAt,
    String? revokedAt,
    String? revokedBy,
  }) {
    return CondivisioneCalendario._(
      id: id,
      aziendaId: aziendaId,
      proprietarioUid: proprietarioUid,
      destinatarioUid: destinatarioUid,
      livello: _normalizzaLivello(livello),
      stato: _normalizzaStato(stato),
      creatoDa: creatoDa,
      createdAt: createdAt,
      updatedAt: updatedAt,
      revokedAt: revokedAt,
      revokedBy: revokedBy,
    );
  }

  const CondivisioneCalendario._({
    required this.id,
    this.aziendaId,
    this.proprietarioUid,
    this.destinatarioUid,
    required this.livello,
    required this.stato,
    this.creatoDa,
    this.createdAt,
    this.updatedAt,
    this.revokedAt,
    this.revokedBy,
  });

  /// Legge una condivisione dalla mappa Firestore. [id] è l'id del documento.
  ///
  /// Livello e stato non validi o mancanti ricadono sui default (`dettagli` e
  /// `attiva`).
  factory CondivisioneCalendario.fromMap(Map<String, dynamic> map,
      {required String id}) {
    return CondivisioneCalendario(
      id: id,
      aziendaId: map['azienda_id'] as String?,
      proprietarioUid: map['proprietario_uid'] as String?,
      destinatarioUid: map['destinatario_uid'] as String?,
      livello: map['livello'] as String?,
      stato: map['stato'] as String?,
      creatoDa: map['creato_da'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      revokedAt: map['revoked_at'] as String?,
      revokedBy: map['revoked_by'] as String?,
    );
  }

  /// Id del documento `condivisioni_calendario`.
  final String id;

  /// Id dell'azienda a cui si riferisce la condivisione (campo `azienda_id`).
  final String? aziendaId;

  /// Uid del proprietario del calendario (campo `proprietario_uid`).
  final String? proprietarioUid;

  /// Uid del destinatario della condivisione (campo `destinatario_uid`).
  final String? destinatarioUid;

  /// Livello di condivisione (`libero_occupato`, `dettagli`, `modifica`).
  /// Campo `livello`, default `dettagli`.
  final String livello;

  /// Stato della condivisione (`attiva` o `revocata`). Campo `stato`, default
  /// `attiva`.
  final String stato;

  /// Uid dell'utente che ha creato la condivisione (campo `creato_da`).
  final String? creatoDa;

  /// Timestamp di creazione ISO-8601 (campo `created_at`).
  final String? createdAt;

  /// Timestamp di ultima modifica ISO-8601 (campo `updated_at`).
  final String? updatedAt;

  /// Timestamp di revoca ISO-8601, `null` se non revocata (campo `revoked_at`).
  final String? revokedAt;

  /// Uid dell'utente che ha revocato la condivisione (campo `revoked_by`).
  final String? revokedBy;

  /// `true` se la condivisione è attiva.
  bool get attiva => stato == 'attiva';

  /// Etichetta leggibile per il livello corrente, con fallback.
  String get etichettaLivello => etichettaLivelloCondivisione(livello);

  /// Id deterministico del documento per una condivisione tra
  /// [proprietarioUid] e [destinatarioUid] nell'azienda [aziendaId].
  static String idPer({
    required String aziendaId,
    required String proprietarioUid,
    required String destinatarioUid,
  }) =>
      [aziendaId, proprietarioUid, destinatarioUid].join('_');

  /// Restituisce una copia con i campi indicati modificati. I campi non
  /// passati mantengono il valore corrente; per azzerare un campo passare
  /// esplicitamente `null`. Livello e stato non validi ricadono sui default.
  CondivisioneCalendario copyWith({
    String? id,
    Object? aziendaId = _sentinel,
    Object? proprietarioUid = _sentinel,
    Object? destinatarioUid = _sentinel,
    String? livello,
    String? stato,
    Object? creatoDa = _sentinel,
    Object? createdAt = _sentinel,
    Object? updatedAt = _sentinel,
    Object? revokedAt = _sentinel,
    Object? revokedBy = _sentinel,
  }) {
    return CondivisioneCalendario(
      id: id ?? this.id,
      aziendaId: aziendaId == _sentinel ? this.aziendaId : aziendaId as String?,
      proprietarioUid: proprietarioUid == _sentinel
          ? this.proprietarioUid
          : proprietarioUid as String?,
      destinatarioUid: destinatarioUid == _sentinel
          ? this.destinatarioUid
          : destinatarioUid as String?,
      livello: livello ?? this.livello,
      stato: stato ?? this.stato,
      creatoDa: creatoDa == _sentinel ? this.creatoDa : creatoDa as String?,
      createdAt: createdAt == _sentinel ? this.createdAt : createdAt as String?,
      updatedAt: updatedAt == _sentinel ? this.updatedAt : updatedAt as String?,
      revokedAt: revokedAt == _sentinel ? this.revokedAt : revokedAt as String?,
      revokedBy: revokedBy == _sentinel ? this.revokedBy : revokedBy as String?,
    );
  }

  /// Serializza verso i campi Firestore (snake_case), escluso [id] che è la
  /// chiave documento.
  Map<String, dynamic> toMap() => {
        'azienda_id': aziendaId,
        'proprietario_uid': proprietarioUid,
        'destinatario_uid': destinatarioUid,
        'livello': livello,
        'stato': stato,
        'creato_da': creatoDa,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'revoked_at': revokedAt,
        'revoked_by': revokedBy,
      };
}
