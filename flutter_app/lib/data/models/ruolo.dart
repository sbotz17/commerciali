/// Ruolo come vive nella collezione Firestore `ruoli`.
///
/// Riproduce i campi della vecchia app (`js/sp-firestore.js` → `SP.seedAzienda`
/// e `SP.inserisciRuolo`): i campi del documento sono snake_case
/// (`azienda_id`, `sconto_max`); il modello li espone in camelCase
/// ([aziendaId], [scontoMax]) come convenzione Dart/Flutter.
///
/// [permessi] è la mappa dei permessi per area (`dashboard`, `clienti`, …),
/// con valori `lettura`/`scrittura`/`entrambi` come nella vecchia app.
class Ruolo {
  const Ruolo({
    required this.id,
    this.aziendaId,
    this.nome = '',
    this.chiave,
    this.descrizione,
    this.scontoMax = 0,
    this.permessi = const {},
    this.sistema = false,
  });

  /// Crea un ruolo dal documento Firestore. [id] è l'id del documento.
  factory Ruolo.fromMap(Map<String, dynamic> map, {required String id}) {
    return Ruolo(
      id: id,
      aziendaId: map['azienda_id'] as String?,
      nome: (map['nome'] as String?) ?? '',
      chiave: map['chiave'] as String?,
      descrizione: map['descrizione'] as String?,
      scontoMax: (map['sconto_max'] as num?)?.toInt() ?? 0,
      permessi: Map<String, dynamic>.from(map['permessi'] as Map? ?? const {}),
      sistema: map['sistema'] == true,
    );
  }

  /// Id del documento `ruoli`.
  final String id;

  /// Id dell'azienda a cui appartiene (campo Firestore `azienda_id`).
  final String? aziendaId;

  /// Nome visibile del ruolo (es. "Amministratore").
  final String nome;

  /// Chiave stabile del ruolo (es. `admin`, `commerciale`).
  final String? chiave;

  /// Descrizione libera del ruolo.
  final String? descrizione;

  /// Sconto massimo applicabile (campo Firestore `sconto_max`), default 0.
  final int scontoMax;

  /// Permessi per area (`dashboard`, `clienti`, `preventivi_propri`, …).
  final Map<String, dynamic> permessi;

  /// `true` per i ruoli di sistema (campo Firestore `sistema`), default false.
  final bool sistema;
}
