// Modello del messaggio di chat.
//
// I campi del documento Firestore sono snake_case (`mittente_uid`,
// `image_key`, `created_at`, `eliminato`, `idempotenza_key`); il modello li
// espone in camelCase ([mittenteUid], [imageKey], [createdAt], [eliminato],
// [idempotenzaKey]) come convenzione Dart/Flutter.

/// Messaggio come vive nella collezione Firestore `messaggi_chat`.
///
/// I nomi dei campi Firestore sono snake_case; il modello li espone in
/// camelCase come convenzione Dart/Flutter.
class MessaggioChat {
  const MessaggioChat({
    required this.id,
    this.mittenteUid,
    this.testo,
    this.tipo = 'testo',
    this.imageKey,
    this.createdAt,
    this.eliminato = false,
    this.idempotenzaKey,
  });

  /// Crea un messaggio dal documento Firestore. [id] è l'id del documento.
  factory MessaggioChat.fromMap(Map<String, dynamic> map, {required String id}) {
    return MessaggioChat(
      id: id,
      mittenteUid: map['mittente_uid'] as String?,
      testo: map['testo'] as String?,
      tipo: (map['tipo'] as String?) ?? 'testo',
      imageKey: map['image_key'] as String?,
      createdAt: map['created_at'] as String?,
      eliminato: (map['eliminato'] as bool?) ?? false,
      idempotenzaKey: map['idempotenza_key'] as String?,
    );
  }

  /// Id del documento `messaggi_chat`.
  final String id;

  /// Uid del mittente (campo `mittente_uid`).
  final String? mittenteUid;

  /// Testo del messaggio (campo `testo`).
  final String? testo;

  /// Tipo di messaggio: `testo` (default) o `immagine`. Campo `tipo`.
  final String tipo;

  /// Chiave dell'immagine su storage, per i messaggi immagine (campo
  /// `image_key`).
  final String? imageKey;

  /// Timestamp di creazione ISO-8601 (campo `created_at`).
  final String? createdAt;

  /// `true` se il messaggio è stato eliminato (campo `eliminato`), default
  /// `false`.
  final bool eliminato;

  /// Chiave di idempotenza per evitare inserimenti duplicati (campo
  /// `idempotenza_key`).
  final String? idempotenzaKey;

  /// Serializza verso i campi Firestore (snake_case), escluso [id] che è la
  /// chiave documento.
  Map<String, dynamic> toMap() => {
        'mittente_uid': mittenteUid,
        'testo': testo,
        'tipo': tipo,
        'image_key': imageKey,
        'created_at': createdAt,
        'eliminato': eliminato,
        'idempotenza_key': idempotenzaKey,
      };
}

/// Anteprima leggibile di un messaggio per la lista stanze.
///
/// Ritorna `Messaggio eliminato` se eliminato, `[Immagine]` se il tipo è
/// immagine, il testo troncato a 80 caratteri, oppure `Nuovo messaggio` se il
/// testo è assente o vuoto.
String anteprimaMessaggio(MessaggioChat m) {
  if (m.eliminato) return 'Messaggio eliminato';
  if (m.tipo == 'immagine') return '[Immagine]';

  final testo = m.testo?.trim() ?? '';
  if (testo.isEmpty) return 'Nuovo messaggio';

  return testo.length <= 80 ? testo : testo.substring(0, 80);
}
