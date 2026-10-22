/// Prodotto come vive nella collezione Firestore `prodotti`.
///
/// I nomi dei campi Firestore sono snake_case ([azienda_id]); il modello li
/// espone in camelCase ([aziendaId]) come convenzione Dart/Flutter.
class Prodotto {
  const Prodotto({
    required this.id,
    this.aziendaId,
    this.nome,
    this.categoria,
    this.prezzo,
    this.descrizione,
    this.immagine,
    this.attivo = true,
  });

  /// Crea un prodotto dal documento Firestore. [id] è l'id del documento.
  factory Prodotto.fromMap(Map<String, dynamic> map, {required String id}) {
    return Prodotto(
      id: id,
      aziendaId: map['azienda_id'] as String?,
      nome: map['nome'] as String?,
      categoria: map['categoria'] as String?,
      prezzo: map['prezzo'] as num?,
      descrizione: map['descrizione'] as String?,
      immagine: map['immagine'] as String?,
      attivo: (map['attivo'] as bool?) ?? true,
    );
  }

  /// Id del documento `prodotti`.
  final String id;

  /// Id dell'azienda a cui appartiene (campo Firestore `azienda_id`).
  final String? aziendaId;

  final String? nome;

  /// Categoria di appartenenza (riferimento per nome/id).
  final String? categoria;

  /// Prezzo numerico (euro).
  final num? prezzo;

  final String? descrizione;

  /// URL dell'immagine, `null` se assente.
  final String? immagine;

  /// `false` nasconde il prodotto dal catalogo.
  final bool attivo;

  /// Serializza verso i campi Firestore (snake_case), escluso [id] che è la
  /// chiave documento.
  Map<String, dynamic> toMap() => {
        'azienda_id': aziendaId,
        'nome': nome,
        'categoria': categoria,
        'prezzo': prezzo,
        'descrizione': descrizione,
        'immagine': immagine,
        'attivo': attivo,
      };
}
