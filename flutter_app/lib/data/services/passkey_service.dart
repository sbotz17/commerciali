// I parametri del costruttore servono solo ai test: i campi restano lazy.
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

/// Accesso con Face ID / Touch ID (passkey WebAuthn) per Closer.
///
/// Firebase Authentication non ha le passkey: le funzioni Cloud svolgono la
/// parte del server (sfida, verifica della firma, custom token). La chiave
/// privata resta sul dispositivo; qui non passa nessun dato biometrico.
class PasskeyService {
  PasskeyService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    PasskeyAuthenticator? authenticator,
  })  : _functions = functions,
        _auth = auth,
        _authenticator = authenticator;

  // Lazy: la semplice creazione del servizio (es. nei test o su mobile) non
  // deve toccare Firebase.
  FirebaseFunctions? _functions;
  FirebaseAuth? _auth;
  PasskeyAuthenticator? _authenticator;

  FirebaseFunctions get _fn =>
      _functions ??= FirebaseFunctions.instanceFor(region: 'europe-west1');
  FirebaseAuth get _authI => _auth ??= FirebaseAuth.instance;

  PasskeyAuthenticator get _passkeys =>
      _authenticator ??= PasskeyAuthenticator();

  /// Vero solo se il browser/dispositivo sa usare una passkey con Face ID,
  /// Touch ID o il PIN. Fuori dal web (app native) per ora non è disponibile.
  Future<bool> disponibile() async {
    if (!kIsWeb) return false;
    try {
      final disponibilita = await _passkeys.getAvailability().web();
      return disponibilita.hasPasskeySupport &&
          disponibilita.isUserVerifyingPlatformAuthenticatorAvailable != false;
    } catch (errore) {
      debugPrint('[Passkey] Supporto non rilevato: $errore');
      return false;
    }
  }

  /// Attiva Face ID per l'utente già collegato.
  Future<void> registra() async {
    final opzioni = await _chiama('passkeyRegistrazioneOpzioni');
    final richiesta = _mappa(opzioni['options']);
    final risposta = await _passkeys.register(
      RegisterRequestType.fromJson(richiesta),
    );
    await _chiama('passkeyRegistrazioneVerifica', {
      'challengeId': opzioni['challengeId'],
      'credential': risposta.toJson(),
    });
  }

  /// Entra con una passkey già attiva, senza email né password.
  Future<void> accedi() async {
    final opzioni = await _chiama('passkeyAccessoOpzioni');
    final richiesta = _mappa(opzioni['options']);
    final risposta = await _passkeys.authenticate(
      AuthenticateRequestType.fromJson(
        richiesta,
        preferImmediatelyAvailableCredentials: false,
        canBeSecurityKey: false,
      ),
    );
    final verifica = await _chiama('passkeyAccessoVerifica', {
      'challengeId': opzioni['challengeId'],
      'credential': risposta.toJson(),
    });
    final token = verifica['customToken'];
    if (token is! String || token.isEmpty) {
      throw StateError('Il server non ha aperto la sessione.');
    }
    await _authI.signInWithCustomToken(token);
  }

  Future<List<PasskeyInfo>> elenco() async {
    final risultato = await _chiama('passkeyElenco');
    final elenco = risultato['passkeys'];
    if (elenco is! List) return const [];
    return [
      for (final voce in elenco)
        if (voce is Map) PasskeyInfo.daMappa(_mappa(voce)),
    ];
  }

  Future<void> rimuovi(String id) =>
      _chiama('passkeyRimuovi', {'id': id});

  Future<Map<String, dynamic>> _chiama(
    String nome, [
    Map<String, dynamic>? dati,
  ]) async {
    final risultato =
        await _fn.httpsCallable(nome).call(dati);
    // Normalizza le mappe annidate (alcune piattaforme le restituiscono con
    // tipi dinamici) prima di passarle al plugin delle passkey.
    return _mappa(risultato.data);
  }

  static Map<String, dynamic> _mappa(Object? valore) {
    final normalizzato = jsonDecode(jsonEncode(valore));
    return normalizzato is Map
        ? normalizzato.cast<String, dynamic>()
        : <String, dynamic>{};
  }
}

/// Accesso con Face ID registrato su un dispositivo.
class PasskeyInfo {
  const PasskeyInfo({
    required this.id,
    required this.nome,
    this.creato,
    this.ultimoUso,
  });

  factory PasskeyInfo.daMappa(Map<String, dynamic> mappa) => PasskeyInfo(
        id: '${mappa['id'] ?? ''}',
        nome: '${mappa['nome'] ?? 'Dispositivo'}',
        creato: _data(mappa['creato']),
        ultimoUso: _data(mappa['ultimoUso']),
      );

  final String id;
  final String nome;
  final DateTime? creato;
  final DateTime? ultimoUso;

  static DateTime? _data(Object? valore) {
    if (valore is int) return DateTime.fromMillisecondsSinceEpoch(valore);
    if (valore is String) return DateTime.tryParse(valore);
    return null;
  }
}

/// Messaggio in italiano per un errore dell'accesso con Face ID.
String messaggioErrorePasskey(Object errore) {
  if (errore is PasskeyAuthCancelledException) {
    return 'Accesso con Face ID annullato.';
  }
  if (errore is NoCredentialsAvailableException) {
    return 'Nessun accesso con Face ID trovato su questo dispositivo: '
        'entra con email e password.';
  }
  if (errore is PasskeyUnsupportedException ||
      errore is DeviceNotSupportedException) {
    return 'Questo dispositivo o browser non supporta Face ID.';
  }
  if (errore is ExcludeCredentialsCanNotBeRegisteredException) {
    return 'Questo dispositivo è già abilitato per il tuo account.';
  }
  if (errore is TimeoutException) {
    return 'Face ID non ha risposto in tempo. Riprova.';
  }
  if (errore is FirebaseFunctionsException) {
    switch (errore.code) {
      case 'unauthenticated':
        return 'Sessione scaduta: accedi di nuovo.';
      case 'resource-exhausted':
        return 'Troppi tentativi con Face ID: attendi qualche minuto e riprova.';
      case 'permission-denied':
      case 'not-found':
      case 'invalid-argument':
        final messaggio = errore.message?.trim() ?? '';
        if (messaggio.isNotEmpty) return messaggio;
        break;
    }
    return 'Non è stato possibile usare Face ID. '
        'Riprova o entra con email e password.';
  }
  if (errore is FirebaseAuthException) {
    if (errore.code == 'user-disabled') {
      return 'Utente disattivato. Contatta l\'amministratore.';
    }
    return 'Non è stato possibile aprire la sessione. '
        'Riprova o entra con email e password.';
  }
  if (errore is AuthenticatorException) {
    return 'Non è stato possibile usare Face ID. '
        'Riprova o entra con email e password.';
  }
  return 'Non è stato possibile usare Face ID. '
      'Riprova o entra con email e password.';
}
