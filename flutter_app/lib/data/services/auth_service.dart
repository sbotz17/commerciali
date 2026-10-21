import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

/// Risultato di un accesso riuscito: credenziale Auth e profilo Firestore.
class LoginRisultato {
  const LoginRisultato({required this.credential, required this.profile});

  final UserCredential credential;
  final UserProfile? profile;
}

/// Servizio di autenticazione email/password, Google e profilo.
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

  /// Accesso con Google via popup (solo web).
  ///
  /// Usa `signInWithPopup` con `GoogleAuthProvider`. Dopo l'accesso carica il
  /// profilo dell'utente; se è disabilitato (`attivo == false`) esegue il
  /// logout e lancia un [FirebaseAuthException] con codice `user-disabled`,
  /// traducibile con [messaggioErroreGoogle].
  Future<LoginRisultato> signInWithGoogleWeb() async {
    final credenziale = await _auth.signInWithPopup(GoogleAuthProvider());
    final profilo = await loadProfile(credenziale.user?.email ?? '');
    if (isDisabled(profilo)) {
      await signOut();
      throw FirebaseAuthException(
        code: 'user-disabled',
        message: 'Utente disabilitato',
      );
    }
    return LoginRisultato(credential: credenziale, profile: profilo);
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

/// Messaggio in italiano per gli errori dell'accesso con Google (popup web).
///
/// Funzione pura: distingue popup chiuso o bloccato, errori di rete, account
/// collegato a un altro metodo, accesso disabilitato e utente non attivo.
String messaggioErroreGoogle(Object errore) {
  if (errore is FirebaseAuthException) {
    switch (errore.code) {
      case 'popup-closed-by-user':
        return 'Accesso annullato. Riprova per accedere con Google.';
      case 'cancelled-popup-request':
        return 'Operazione annullata. Riprova.';
      case 'popup-blocked':
        return 'Pop-up bloccato dal browser. Consenti i pop-up e riprova.';
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'account-exists-with-different-credential':
        return 'Esiste già un account con questa email collegato a un altro metodo di accesso.';
      case 'operation-not-allowed':
        return 'Accesso con Google non disponibile.';
      case 'user-disabled':
        return 'Utente disabilitato. Contatta l\'amministratore.';
      default:
        return 'Accesso con Google non riuscito. Riprova.';
    }
  }
  return 'Accesso con Google non riuscito. Controlla la connessione e riprova.';
}
