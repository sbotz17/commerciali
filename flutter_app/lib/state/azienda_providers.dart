import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/models/azienda.dart';
import '../data/services/sp_service.dart';
import 'auth_providers.dart';

/// Servizio dati `SpService`, costruito sullo stesso `FirebaseFirestore`.
final spServiceProvider = Provider<SpService>((ref) {
  return SpService(ref.watch(firestoreProvider));
});

/// Id dell'azienda attiva (selezione corrente dell'utente).
///
/// `StateProvider` vive in `flutter_riverpod/legacy.dart` in Riverpod 3.
final aziendaAttivaProvider = StateProvider<String?>((ref) => null);

/// Elenco delle aziende dell'utente autenticato.
///
/// Osserva [profileProvider]: senza profilo risolve una lista vuota, altrimenti
/// interroga [SpService.getAziendeUtente] con l'uid del profilo.
final aziendeUtenteProvider = FutureProvider<List<Azienda>>((ref) async {
  final profile = ref.watch(profileProvider).asData?.value;
  if (profile == null) return const [];
  return ref.watch(spServiceProvider).getAziendeUtente(profile.uid);
});
