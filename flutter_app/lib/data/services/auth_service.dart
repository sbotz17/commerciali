import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

/// Servizio di autenticazione email/password e profilo.
///
/// Incapsula `FirebaseAuth` (credenziali) e `FirebaseFirestore` (profilo in
/// `utenti`). Nessuna UI: viene iniettato dai provider e usato dagli strati
/// superiori.
class AuthService {
  AuthService({required this._auth, required this._firestore});

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Stream dello stato di autenticazione (utente corrente o `null`).
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Login con email/password. L'email viene normalizzata (trim + lowercase).
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: _normalizzaEmail(email),
      password: password,
    );
  }

  /// Disconnette l'utente corrente.
  Future<void> signOut() => _auth.signOut();

  /// Invia l'email di recupero password.
  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: _normalizzaEmail(email));
  }

  /// Carica il profilo dalla collezione `utenti` cercando per email.
  ///
  /// Ritorna `null` se l'email è vuota, la query fallisce o non esiste un
  /// record corrispondente.
  Future<UserProfile?> loadProfile(String email) async {
    final em = _normalizzaEmail(email);
    if (em.isEmpty) return null;
    try {
      final snapshot = await _firestore
          .collection('utenti')
          .where('email', isEqualTo: em)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return UserProfile.fromMap(doc.data(), id: doc.id);
    } catch (_) {
      return null;
    }
  }

  /// `true` se il profilo esiste ed è esplicitamente disabilitato (`attivo == false`).
  bool isDisabled(UserProfile? profile) =>
      profile != null && profile.attivo == false;

  String _normalizzaEmail(String email) => email.trim().toLowerCase();
}
