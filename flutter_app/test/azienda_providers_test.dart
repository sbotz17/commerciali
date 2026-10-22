import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/azienda.dart';
import 'package:commerciali_app/data/models/user_profile.dart';
import 'package:commerciali_app/state/auth_providers.dart';
import 'package:commerciali_app/state/azienda_providers.dart';

void main() {
  const azienda1 = Azienda(id: 'a1', nome: 'Prima azienda');
  const azienda2 = Azienda(id: 'a2', nome: 'Seconda azienda');

  ProviderContainer contenitore({
    required UserProfile profilo,
    List<Azienda> aziende = const [azienda1, azienda2],
  }) {
    return ProviderContainer(
      overrides: [
        profileProvider.overrideWith((ref) async => profilo),
        aziendeUtenteProvider.overrideWith((ref) async => aziende),
      ],
    );
  }

  Future<void> attendiMicrotask() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('imposta la prima azienda quando non ce n\'è una attiva', () async {
    final container = contenitore(
      profilo: const UserProfile(id: 'u1', uid: 'u1'),
    );
    addTearDown(container.dispose);

    container.read(aziendaAttivaSyncProvider);
    await attendiMicrotask();

    expect(container.read(aziendaAttivaProvider), 'a1');
  });

  test('mantiene l\'azienda attiva se appartiene all\'utente', () async {
    final container = contenitore(
      profilo: const UserProfile(id: 'u1', uid: 'u1'),
    );
    addTearDown(container.dispose);
    container.read(aziendaAttivaProvider.notifier).state = 'a2';

    container.read(aziendaAttivaSyncProvider);
    await attendiMicrotask();

    expect(container.read(aziendaAttivaProvider), 'a2');
  });

  test('sostituisce un\'azienda non più disponibile', () async {
    final container = contenitore(
      profilo: const UserProfile(id: 'u1', uid: 'u1'),
    );
    addTearDown(container.dispose);
    container.read(aziendaAttivaProvider.notifier).state = 'vecchia';

    container.read(aziendaAttivaSyncProvider);
    await attendiMicrotask();

    expect(container.read(aziendaAttivaProvider), 'a1');
  });

  test('il super admin conserva l\'azienda scelta manualmente', () async {
    final container = contenitore(
      profilo: const UserProfile(id: 'u1', uid: 'u1', superAdmin: true),
    );
    addTearDown(container.dispose);
    await container.read(profileProvider.future);
    container.read(aziendaAttivaProvider.notifier).state = 'esterna';

    container.read(aziendaAttivaSyncProvider);
    await attendiMicrotask();

    expect(container.read(aziendaAttivaProvider), 'esterna');
  });

  test('senza aziende non tocca la selezione', () async {
    final container = contenitore(
      profilo: const UserProfile(id: 'u1', uid: 'u1'),
      aziende: const [],
    );
    addTearDown(container.dispose);
    container.read(aziendaAttivaProvider.notifier).state = 'a1';

    container.read(aziendaAttivaSyncProvider);
    await attendiMicrotask();

    expect(container.read(aziendaAttivaProvider), 'a1');
  });
}
