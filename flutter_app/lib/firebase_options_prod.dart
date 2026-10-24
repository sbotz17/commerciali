// File di configurazione Firebase per l'ambiente di produzione.
// Generato manualmente dai dati dell'app web `Closer Web` del progetto
// `commerciali-prod`. Non contiene segreti: la apiKey Firebase web è pubblica.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptionsProd {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'Le app mobile di produzione non sono ancora configurate. '
          'Creare le app Android/iOS nel progetto commerciali-prod.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptionsProd non supporta questa piattaforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBGoqyO_SgJeIUoE3YALsNmuBe4i1JIZ4A',
    appId: '1:490758179089:web:c4f3ef4b4f8e9ffcc4e4b0',
    messagingSenderId: '490758179089',
    projectId: 'commerciali-prod',
    authDomain: 'commerciali-prod.firebaseapp.com',
    storageBucket: 'commerciali-prod.firebasestorage.app',
  );
}
