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

/// Tiene allineata l'azienda attiva alle aziende dell'utente autenticato.
///
/// Va osservato (lo fa `AuthGate`) per restare attivo. Quando l'elenco delle
/// aziende arriva — anche dopo il login — imposta [aziendaAttivaProvider] sulla
/// prima azienda se non ce n'è una o se quella scelta non appartiene più
/// all'utente. Una scelta ancora valida non viene mai sovrascritta.
///
/// Non modifica provider durante la build: il primo giro (aziende già
/// disponibili) è differito a un microtask, i successivi arrivano dal listener.
final aziendaAttivaSyncProvider = Provider<void>((ref) {
  void applica(List<Azienda>? aziende) {
    if (aziende == null || aziende.isEmpty) return;
    final corrente = ref.read(aziendaAttivaProvider);
    if (aziende.any((azienda) => azienda.id == corrente)) return;
    // Il super admin può entrare in un'azienda qualsiasi dalla schermata
    // Super Admin: una scelta manuale non viene sovrascritta.
    final profilo = ref.read(profileProvider).asData?.value;
    if (profilo?.superAdmin == true && corrente != null) return;
    ref.read(aziendaAttivaProvider.notifier).state = aziende.first.id;
  }

  Future<void>.microtask(() {
    if (!ref.mounted) return;
    applica(ref.read(aziendeUtenteProvider).asData?.value);
  });

  ref.listen<AsyncValue<List<Azienda>>>(
    aziendeUtenteProvider,
    (_, attuale) => applica(attuale.asData?.value),
  );
});
