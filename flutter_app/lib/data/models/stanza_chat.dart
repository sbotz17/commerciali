// Modello della stanza (conversazione) della chat.
//
// I campi del documento Firestore sono snake_case (`azienda_id`,
// `partecipanti_uids`, `creatore_uid`, `ultimo_messaggio`,
// `ultimo_messaggio_at`, `created_at`, `updated_at`); il modello li espone in
// camelCase ([aziendaId], [partecipantiUids], [creatoreUid],
// [ultimoMessaggio], [ultimoMessaggioAt], [createdAt], [updatedAt]) come
// convenzione Dart/Flutter.

/// Stanza di chat come vive nella collezione Firestore `stanze_chat`.
///
/// Una stanza può essere diretta (due partecipanti) o di gruppo. I nomi dei
/// campi Firestore sono snake_case; il modello li espone in camelCase come
/// convenzione Dart/Flutter.
class StanzaChat {
  const StanzaChat({
    required this.id,
    this.aziendaId,
    this.tipo = 'diretta',
    this.nome,
    this.partecipantiUids = const [],
    this.creatoreUid,
    this.ultimoMessaggio,
    this.ultimoMessaggioAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Crea una stanza dal documento Firestore. [id] è l'id del documento.
  factory StanzaChat.fromMap(Map<String, dynamic> map, {required String id}) {
    return StanzaChat(
      id: id,
      aziendaId: map['azienda_id'] as String?,
      tipo: (map['tipo'] as String?) ?? 'diretta',
      nome: map['nome'] as String?,
      partecipantiUids: (map['partecipanti_uids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      creatoreUid: map['creatore_uid'] as String?,
      ultimoMessaggio: map['ultimo_messaggio'] as String?,
      ultimoMessaggioAt: map['ultimo_messaggio_at'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  /// Id del documento `stanze_chat`.
  final String id;

  /// Id dell'azienda a cui appartiene (campo Firestore `azienda_id`).
  final String? aziendaId;

  /// Tipo di stanza: `diretta` (default) o `gruppo`. Campo `tipo`.
  final String tipo;

  /// Nome della stanza, usato per i gruppi (campo `nome`).
  final String? nome;

  /// Uid dei partecipanti (campo `partecipanti_uids`).
  final List<String> partecipantiUids;

  /// Uid del creatore della stanza (campo `creatore_uid`).
  final String? creatoreUid;

  /// Anteprima dell'ultimo messaggio, denormalizzato (campo
  /// `ultimo_messaggio`).
  final String? ultimoMessaggio;

  /// Timestamp dell'ultimo messaggio ISO-8601 (campo `ultimo_messaggio_at`).
  final String? ultimoMessaggioAt;

  /// Timestamp di creazione ISO-8601 (campo `created_at`).
  final String? createdAt;

  /// Timestamp di ultima modifica ISO-8601 (campo `updated_at`).
  final String? updatedAt;

  /// Serializza verso i campi Firestore (snake_case), escluso [id] che è la
  /// chiave documento.
  Map<String, dynamic> toMap() => {
        'azienda_id': aziendaId,
        'tipo': tipo,
        'nome': nome,
        'partecipanti_uids': partecipantiUids,
        'creatore_uid': creatoreUid,
        'ultimo_messaggio': ultimoMessaggio,
        'ultimo_messaggio_at': ultimoMessaggioAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

/// Id deterministico della stanza diretta tra due uid.
///
/// Restituisce `diretta_{aziendaId}_{uidMin}_{uidMax}` con gli uid ordinati
/// alfabeticamente (compareTo), così la stessa coppia produce sempre lo stesso
/// id indipendentemente dall'ordine dei parametri.
String idChatDiretta(String aziendaId, String uid1, String uid2) {
  final uidMin = uid1.compareTo(uid2) <= 0 ? uid1 : uid2;
  final uidMax = uid1.compareTo(uid2) <= 0 ? uid2 : uid1;
  return 'diretta_${aziendaId}_${uidMin}_$uidMax';
}

/// Nome da mostrare per una stanza di chat.
///
/// Per una stanza diretta mostra il nome dell'altro partecipante (se presente
/// in [nomiUtenti]) o il suo uid; per un gruppo mostra [StanzaChat.nome] o
/// `Gruppo` come fallback.
String nomeStanzaChat(
  StanzaChat s, {
  required String uidCorrente,
  Map<String, String> nomiUtenti = const {},
}) {
  if (s.tipo == 'gruppo') {
    final nome = s.nome?.trim();
    return (nome == null || nome.isEmpty) ? 'Gruppo' : nome;
  }

  // Stanza diretta: mostra l'altro partecipante.
  String? altro;
  for (final uid in s.partecipantiUids) {
    if (uid != uidCorrente) {
      altro = uid;
      break;
    }
  }

  if (altro == null) {
    // Nessun altro partecipante noto: usa il nome della stanza se presente.
    final nome = s.nome?.trim();
    return (nome == null || nome.isEmpty) ? 'Diretta' : nome;
  }

  final nomeAltro = nomiUtenti[altro]?.trim();
  if (nomeAltro != null && nomeAltro.isNotEmpty) return nomeAltro;
  return altro;
}
