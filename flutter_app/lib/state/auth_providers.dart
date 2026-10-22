import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_profile.dart';
import '../data/services/auth_service.dart';

/// Istanza singleton di `FirebaseAuth`.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Istanza singleton di `FirebaseFirestore`.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Servizio di autenticazione e profilo.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

/// Stato di autenticazione: l'utente corrente oppure `null` se non loggato.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// Profilo Firestore dell'utente autenticato.
///
/// Osserva [authStateProvider]: senza utente (o senza email) risolve `null`,
/// altrimenti carica il profilo dalla collezione `utenti`, provando prima la
/// lettura diretta `utenti/{uid}`.
final profileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;
  final email = user.email;
  if (email == null || email.isEmpty) return null;
  return ref.watch(authServiceProvider).loadProfile(email, uid: user.uid);
});
