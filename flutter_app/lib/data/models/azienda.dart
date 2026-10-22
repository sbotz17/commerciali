/// Azienda come viene esposta all'utente loggato.
///
/// È il risultato della lettura congiunta di due documenti Firestore:
/// il documento `aziende/{id}` (nome, logo, `whatsapp_attivo`) e il documento
/// `membri/{aziendaId}_{uid}` (il [ruolo] dell'utente in quell'azienda).
///
/// I nomi dei campi Firestore sono snake_case ([whatsapp_attivo]); il modello
/// li espone in camelCase ([whatsappAttivo]) come convenzione Dart/Flutter.
class Azienda {
  const Azienda({
    required this.id,
    required this.nome,
    this.logo,
    this.ruolo = 'commerciale',
    this.whatsappAttivo = false,
  });

  /// Crea un'azienda da una mappa Firestore (campi `aziende` + `ruolo` da `membri`).
  ///
  /// [id] è l'id del documento `aziende`.
  factory Azienda.fromMap(Map<String, dynamic> map, {required String id}) {
    return Azienda(
      id: id,
      nome: (map['nome'] as String?) ?? 'Azienda',
      logo: map['logo'] as String?,
      ruolo: (map['ruolo'] as String?) ?? 'commerciale',
      whatsappAttivo: map['whatsapp_attivo'] == true,
    );
  }

  /// Id del documento `aziende`.
  final String id;

  final String nome;

  /// URL del logo, `null` se assente.
  final String? logo;

  /// Ruolo dell'utente corrente in questa azienda (da `membri`).
  final String ruolo;

  /// Stato del canale WhatsApp dell'azienda (campo Firestore `whatsapp_attivo`).
  final bool whatsappAttivo;
}
