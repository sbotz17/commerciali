/// Profilo utente come vive nella collezione Firestore `utenti`.
///
/// La chiave documento di `utenti` coincide con l'uid Firebase Auth: per questo
/// [id] e [uid] assumono lo stesso valore quando il record non espone un campo
/// `uid` esplicito.
///
/// I nomi dei campi Firestore sono snake_case ([super_admin], [menu_utente]);
/// il modello li espone in camelCase ([superAdmin], [menuUtente]) come
/// convenzione Dart/Flutter.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.uid,
    this.email,
    this.nome,
    this.username,
    this.ruolo,
    this.attivo,
    this.superAdmin = false,
    this.menuUtente,
  });

  /// Crea un profilo dal documento Firestore.
  ///
  /// [id] è l'id del documento, che coincide con l'uid Auth.
  factory UserProfile.fromMap(Map<String, dynamic> map, {required String id}) {
    return UserProfile(
      id: id,
      uid: map['uid'] as String? ?? id,
      email: map['email'] as String?,
      nome: map['nome'] as String?,
      username: map['username'] as String?,
      ruolo: map['ruolo'] as String?,
      attivo: map['attivo'] as bool?,
      superAdmin: map['super_admin'] == true,
      menuUtente: map['menu_utente'],
    );
  }

  /// Id del documento Firestore (coincide con l'uid Auth).
  final String id;

  /// Uid Firebase Auth. Coincide con [id] se non presente come campo.
  final String uid;

  final String? email;
  final String? nome;
  final String? username;
  final String? ruolo;

  /// `false` disabilita l'accesso; `null`/`true` lo consentono.
  final bool? attivo;

  /// Accesso da super admin (campo Firestore `super_admin`).
  final bool superAdmin;

  /// Menu personalizzato (campo Firestore `menu_utente`).
  final dynamic menuUtente;

  /// Serializza verso i campi Firestore (snake_case), esclusi [id] e [uid]
  /// che sono la chiave documento.
  Map<String, dynamic> toMap() => {
        'email': email,
        'nome': nome,
        'username': username,
        'ruolo': ruolo,
        'attivo': attivo,
        'super_admin': superAdmin,
        'menu_utente': menuUtente,
      };
}
