import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_profile.dart';

/// Risultato di un accesso riuscito: credenziale Auth e profilo Firestore.
class LoginRisultato {
  const LoginRisultato({required this.credential, required this.profile});

  final UserCredential credential;
  final UserProfile? profile;
}

/// Errore lanciato quando l'email indicata per la creazione di un utente
/// amministrativo è già registrata in Firebase Auth.
class EmailGiaRegistrataException implements Exception {
  const EmailGiaRegistrataException();

  @override
  String toString() => 'EmailGiaRegistrataException: email già registrata';
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

  /// Accesso con Google, adatto a web e mobile.
  ///
  /// Sul web usa il popup con [GoogleAuthProvider]; su Android/iOS usa il
  /// flusso nativo di `google_sign_in` (vedi [signInWithGoogleMobile]).
  Future<LoginRisultato> signInWithGoogle() {
    return kIsWeb ? signInWithGoogleWeb() : signInWithGoogleMobile();
  }

  /// Accesso con Google via popup (solo web).
  ///
  /// Usa `signInWithPopup` con `GoogleAuthProvider`. Dopo l'accesso carica il
  /// profilo dell'utente; se è disabilitato (`attivo == false`) esegue il
  /// logout e lancia un [FirebaseAuthException] con codice `user-disabled`,
  /// traducibile con [messaggioErroreGoogle].
  Future<LoginRisultato> signInWithGoogleWeb() async {
    final credenziale = await _auth.signInWithPopup(GoogleAuthProvider());
    return _finalizzaAccessoGoogle(credenziale);
  }

  /// Accesso con Google nativo (solo Android/iOS).
  ///
  /// Inizializza [GoogleSignIn] una sola volta con il `serverClientId` (client
  /// ID web pubblico, non segreto), chiede l'account al sistema e scambia
  /// l'ID token con una credenziale Firebase. Se il token manca lancia una
  /// [GoogleSignInException] con codice `clientConfigurationError`.
  Future<LoginRisultato> signInWithGoogleMobile() async {
    await _inizializzaGoogleSignInMobile();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'Token Google non disponibile',
      );
    }
    final credenziale = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    return _finalizzaAccessoGoogle(credenziale);
  }

  /// Inizializza `google_sign_in` una sola volta (richiesto dall'API 7.x).
  static Future<void>? _googleSignInInit;

  Future<void> _inizializzaGoogleSignInMobile() {
    return _googleSignInInit ??= GoogleSignIn.instance.initialize(
      serverClientId: const String.fromEnvironment(
        'GOOGLE_SERVER_CLIENT_ID',
        defaultValue: '686757330506-97f1qm6egpbbhbpa0mf7nkpqk8i7474t.apps.googleusercontent.com',
      ),
    );
  }

  /// Carica il profilo e controlla che l'utente sia attivo.
  ///
  /// Se disabilitato (`attivo == false`) esegue il logout e lancia una
  /// [FirebaseAuthException] con codice `user-disabled`, traducibile con
  /// [messaggioErroreGoogle].
  Future<LoginRisultato> _finalizzaAccessoGoogle(
    UserCredential credenziale,
  ) async {
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

  /// Invia l'email di accesso (reset password) all'indirizzo indicato,
  /// normalizzato con trim + lowercase.
  Future<void> inviaEmailAccesso(String email) =>
      _auth.sendPasswordResetEmail(email: normalizzaEmailAmministrazione(email));

  /// Verifica il codice ricevuto via email (`oobCode`) e ritorna l'email
  /// associata. Lancia una `FirebaseAuthException` se il codice è scaduto o
  /// non valido.
  Future<String> verifyResetCode(String code) {
    return _auth.verifyPasswordResetCode(code);
  }

  /// Imposta la nuova password usando il codice di recupero.
  ///
  /// Lancia una `FirebaseAuthException` se il codice è scaduto/non valido o
  /// se la password viene rifiutata dalle regole di Firebase.
  Future<void> confirmPasswordReset(String code, String newPassword) {
    return _auth.confirmPasswordReset(code: code, newPassword: newPassword);
  }

  /// Crea un utente amministrativo (Auth + profilo Firestore) usando una
  /// seconda app Firebase temporanea, così da non interferire con la sessione
  /// dell'amministratore corrente.
  ///
  /// - Email e nome vengono normalizzati (trim + lowercase / trim).
  /// - La password deve avere almeno 8 caratteri, altrimenti [ArgumentError].
  /// - Su `email-already-in-use` lancia [EmailGiaRegistrataException].
  ///
  /// Ritorna l'`uid` dell'utente appena creato.
  Future<String> creaAccountConProfilo({
    required String email,
    required String password,
    required String nome,
    required String ruolo,
    bool superAdmin = false,
  }) async {
    final emailNormalizzata = normalizzaEmailAmministrazione(email);
    final nomeNormalizzato = nome.trim();

    final errorePassword = validaPasswordTemporanea(password);
    if (errorePassword != null) {
      throw ArgumentError(errorePassword);
    }

    final appSecondaria = await Firebase.initializeApp(
      name: 'crea-utente-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      final auth2 = FirebaseAuth.instanceFor(app: appSecondaria);
      final credenziale = await auth2.createUserWithEmailAndPassword(
        email: emailNormalizzata,
        password: password,
      );
      final uid = credenziale.user!.uid;
      final username = emailNormalizzata.split('@').first;

      await FirebaseFirestore.instanceFor(app: appSecondaria)
          .collection('utenti')
          .doc(uid)
          .set({
        'uid': uid,
        'email': emailNormalizzata,
        'nome': nomeNormalizzato,
        'username': username,
        'ruolo': ruolo,
        'attivo': true,
        'super_admin': superAdmin,
        'created_at': DateTime.now().toIso8601String(),
      });

      await auth2.signOut();

      return uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw const EmailGiaRegistrataException();
      }
      rethrow;
    } finally {
      await appSecondaria.delete();
    }
  }

  /// Carica il profilo dalla collezione `utenti`.
  ///
  /// Se [uid] è indicato prova prima la lettura diretta `utenti/{uid}` (una
  /// sola lettura invece di una query) e, solo se non trova il documento o la
  /// lettura fallisce, ripiega sulla query per email.
  ///
  /// Ritorna `null` se l'email è vuota (e manca [uid]), la query fallisce o
  /// non esiste un record corrispondente.
  Future<UserProfile?> loadProfile(String email, {String? uid}) async {
    final chiave = uid?.trim();
    final haUid = chiave != null && chiave.isNotEmpty;
    final em = _normalizzaEmail(email);
    if (!haUid && em.isEmpty) return null;

    if (haUid) {
      try {
        final doc = await _firestore.collection('utenti').doc(chiave).get();
        final dati = doc.data();
        if (doc.exists && dati != null) {
          return UserProfile.fromMap(dati, id: doc.id);
        }
      } catch (_) {
        // Lettura diretta non riuscita: si prova la query per email.
      }
    }

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

/// Normalizza un'email amministrativa con trim + lowercase.
String normalizzaEmailAmministrazione(String email) => email.trim().toLowerCase();

/// Valida una password temporanea di amministrazione.
///
/// Ritorna `null` se è valida (almeno 8 caratteri), altrimenti un messaggio
/// d'errore in italiano.
String? validaPasswordTemporanea(String? password) {
  if (password == null || password.isEmpty) {
    return 'La password non può essere vuota.';
  }
  if (password.length < 8) {
    return 'La password deve avere almeno 8 caratteri.';
  }
  return null;
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
  if (errore is GoogleSignInException) {
    switch (errore.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Accesso annullato. Riprova per accedere con Google.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Accesso interrotto. Riprova.';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Configurazione di Google non valida. Contatta l\'assistenza.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Impossibile mostrare la schermata Google. Riprova.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Account Google diverso da quello atteso. Riprova.';
      case GoogleSignInExceptionCode.unknownError:
        return 'Accesso con Google non riuscito. Riprova.';
    }
  }
  return 'Accesso con Google non riuscito. Controlla la connessione e riprova.';
}
