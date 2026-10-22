/// Licenza come vive nella collezione Firestore `licenze`.
///
/// Il documento `licenze/{aziendaId}` usa l'id dell'azienda come chiave: per
/// questo [id] e [aziendaId] coincidono quando il record non espone un campo
/// `azienda_id` esplicito.
///
/// Riproduce i campi della vecchia app (`js/sp-firestore.js` →
/// `SP.seedAzienda`/`SP.salvaLicenza`): i campi del documento sono snake_case
/// (`data_inizio`, `max_utenti`, `max_preventivi`); il modello li espone in
/// camelCase ([dataInizio], [maxUtenti], [maxPreventivi]) come convenzione
/// Dart/Flutter.
class Licenza {
  const Licenza({
    required this.id,
    this.aziendaId,
    this.piano = 'trial',
    this.stato = 'attiva',
    this.dataInizio,
    this.dataFine,
    this.maxUtenti,
    this.maxPreventivi,
    this.note,
  });

  /// Crea una licenza dal documento Firestore. [id] è l'id del documento
  /// (coincide con l'id dell'azienda).
  factory Licenza.fromMap(Map<String, dynamic> map, {required String id}) {
    return Licenza(
      id: id,
      aziendaId: (map['azienda_id'] as String?) ?? id,
      piano: (map['piano'] as String?) ?? 'trial',
      stato: (map['stato'] as String?) ?? 'attiva',
      dataInizio: map['data_inizio'] as String?,
      dataFine: map['data_fine'] as String?,
      maxUtenti: (map['max_utenti'] as num?)?.toInt(),
      maxPreventivi: (map['max_preventivi'] as num?)?.toInt(),
      note: map['note'] as String?,
    );
  }

  /// Id del documento `licenze` (coincide con l'id dell'azienda).
  final String id;

  /// Id dell'azienda a cui si riferisce la licenza (campo `azienda_id`).
  final String? aziendaId;

  /// Piano di licenza (`trial`, `base`, …). Campo `piano`, default `trial`.
  final String piano;

  /// Stato della licenza (`attiva`, `scaduta`, …). Campo `stato`, default
  /// `attiva`.
  final String stato;

  /// Data di inizio `YYYY-MM-DD` (campo `data_inizio`), `null` se assente.
  final String? dataInizio;

  /// Data di fine `YYYY-MM-DD` (campo `data_fine`), `null` se assente.
  final String? dataFine;

  /// Numero massimo di utenti (campo `max_utenti`), `null` se assente.
  final int? maxUtenti;

  /// Numero massimo di preventivi (campo `max_preventivi`), `null` se assente.
  final int? maxPreventivi;

  /// Note libere sulla licenza (campo `note`).
  final String? note;
}
