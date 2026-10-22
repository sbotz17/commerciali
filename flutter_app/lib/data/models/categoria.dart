/// Categoria come vive nella collezione Firestore `categorie`.
///
/// I nomi dei campi Firestore sono snake_case ([azienda_id]); il modello li
/// espone in camelCase ([aziendaId]) come convenzione Dart/Flutter.
class Categoria {
  const Categoria({
    required this.id,
    this.aziendaId,
    this.nome,
    this.icona,
    this.ordine,
  });

  /// Crea una categoria dal documento Firestore. [id] è l'id del documento.
  factory Categoria.fromMap(Map<String, dynamic> map, {required String id}) {
    return Categoria(
      id: id,
      aziendaId: map['azienda_id'] as String?,
      nome: map['nome'] as String?,
      icona: map['icona'] as String?,
      ordine: (map['ordine'] as num?)?.toInt(),
    );
  }

  /// Id del documento `categorie`.
  final String id;

  /// Id dell'azienda a cui appartiene (campo Firestore `azienda_id`).
  final String? aziendaId;

  final String? nome;

  /// Emoji o icona della categoria.
  final String? icona;

  /// Posizione di ordinamento (campo Firestore `ordine`).
  final int? ordine;

  /// Serializza verso i campi Firestore (snake_case), escluso [id] che è la
  /// chiave documento.
  Map<String, dynamic> toMap() => {
        'azienda_id': aziendaId,
        'nome': nome,
        'icona': icona,
        'ordine': ordine,
      };
}
