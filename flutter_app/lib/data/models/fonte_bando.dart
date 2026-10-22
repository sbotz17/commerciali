// Modello della fonte dei bandi.
//
// Riproduce la struttura dati della vecchia app
// (`js/sp-firestore.js` → collezione `bandi_fonti`, campi di
// `SP.salvaFonteBandi`): i campi del documento sono snake_case
// (`sync_stato`, `ultimo_sync`, `updated_at`); il modello li espone in
// camelCase ([syncStato], [ultimoSync], [updatedAt]) come convenzione
// Dart/Flutter.

/// Fonte come vive nella collezione Firestore `bandi_fonti`.
///
/// I nomi dei campi Firestore sono snake_case; il modello li espone in
/// camelCase come convenzione Dart/Flutter.
class FonteBando {
  const FonteBando({
    required this.id,
    this.nome,
    this.url,
    this.tipo = 'rss',
    this.attiva = true,
    this.note,
    this.syncStato,
    this.ultimoSync,
    this.syncImportati,
    this.syncErrore,
    this.updatedAt,
  });

  /// Crea una fonte dal documento Firestore. [id] è l'id del documento.
  factory FonteBando.fromMap(Map<String, dynamic> map, {required String id}) {
    return FonteBando(
      id: id,
      nome: map['nome'] as String?,
      url: map['url'] as String?,
      tipo: (map['tipo'] as String?) ?? 'rss',
      attiva: map['attiva'] != false,
      note: map['note'] as String?,
      syncStato: map['sync_stato'] as String?,
      ultimoSync: map['ultimo_sync'] as String?,
      syncImportati: map['sync_importati'] as num?,
      syncErrore: map['sync_errore'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  /// Id del documento `bandi_fonti`.
  final String id;

  /// Nome della fonte (campo Firestore `nome`).
  final String? nome;

  /// URL della fonte (campo `url`).
  final String? url;

  /// Tipo di fonte (`rss`, `json_incentivi`, ...). Campo `tipo`, default
  /// `rss` (come la vecchia app).
  final String tipo;

  /// `true` se la fonte è attiva (campo `attiva`, default `true`).
  final bool attiva;

  /// Note libere (campo `note`).
  final String? note;

  /// Stato dell'ultimo sync (`ok`, `errore`, `in_corso`). Campo `sync_stato`.
  final String? syncStato;

  /// Timestamp dell'ultimo sync (campo `ultimo_sync`).
  final String? ultimoSync;

  /// Record importati nell'ultimo sync (campo `sync_importati`).
  final num? syncImportati;

  /// Errore dell'ultimo sync (campo `sync_errore`).
  final String? syncErrore;

  /// Timestamp di ultima modifica (campo `updated_at`).
  final String? updatedAt;

  /// Serializza verso i campi Firestore (snake_case), escluso [id] che è la
  /// chiave documento.
  Map<String, dynamic> toMap() => {
        'nome': nome,
        'url': url,
        'tipo': tipo,
        'attiva': attiva,
        'note': note,
        'sync_stato': syncStato,
        'ultimo_sync': ultimoSync,
        'sync_importati': syncImportati,
        'sync_errore': syncErrore,
        'updated_at': updatedAt,
      };
}
