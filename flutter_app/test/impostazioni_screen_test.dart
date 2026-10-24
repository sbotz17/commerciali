import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/azienda.dart';
import 'package:commerciali_app/data/models/user_profile.dart';
import 'package:commerciali_app/features/impostazioni/impostazioni_screen.dart';

void main() {
  const profilo = UserProfile(
    id: 'u1',
    uid: 'u1',
    email: 'mario.rossi@example.it',
    nome: 'Mario Rossi',
    ruolo: 'admin',
    superAdmin: true,
  );

  const aziende = [
    Azienda(id: 'a1', nome: 'Acme S.r.l.', ruolo: 'admin'),
    Azienda(id: 'a2', nome: 'Beta S.r.l.', ruolo: 'commerciale'),
  ];

  /// Monta [CorpoImpostazioni] in un'app minima, senza provider né Firebase.
  Future<void> mostraImpostazioni(
    WidgetTester tester, {
    UserProfile? profiloDaMostrare = profilo,
    List<Azienda> aziendeDaMostrare = aziende,
    String? aziendaAttivaId = 'a1',
    bool admin = true,
    void Function(String)? onCambiaAzienda,
    VoidCallback? onLogout,
    void Function(String)? onVoce,
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CorpoImpostazioni(
            profilo: profiloDaMostrare,
            aziende: aziendeDaMostrare,
            aziendaAttivaId: aziendaAttivaId,
            admin: admin,
            onCambiaAzienda: onCambiaAzienda ?? (_) {},
            onLogout: onLogout ?? () {},
            onVoce: onVoce ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra profilo, ruolo, badge super admin e azienda attiva',
      (tester) async {
    await mostraImpostazioni(tester);

    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(find.text('mario.rossi@example.it'), findsOneWidget);
    expect(find.text('admin'), findsOneWidget);
    expect(find.text('Super admin'), findsOneWidget);
    expect(
      find.byKey(const Key('impostazioni-super-admin-badge')),
      findsOneWidget,
    );
    expect(find.text('Azienda attiva'), findsOneWidget);
    expect(
      find.byKey(const Key('impostazioni-azienda-tendina')),
      findsOneWidget,
    );
  });

  testWidgets(
      'il commerciale vede Notifiche ma non le voci di amministrazione',
      (tester) async {
    const commerciale = UserProfile(
      id: 'u2',
      uid: 'u2',
      email: 'commerciale@example.it',
      nome: 'Commerciale',
      ruolo: 'commerciale',
    );

    await mostraImpostazioni(
      tester,
      profiloDaMostrare: commerciale,
      aziendeDaMostrare: const [
        Azienda(id: 'a1', nome: 'Acme S.r.l.', ruolo: 'commerciale'),
      ],
      admin: false,
    );

    expect(
      find.byKey(const Key('impostazioni-voce-notifiche')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('impostazioni-voce-condivisioni')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('impostazioni-personali')), findsOneWidget);
    expect(find.byKey(const Key('impostazioni-accessi')), findsNothing);
    expect(find.byKey(const Key('impostazioni-voce-utenti')), findsNothing);
    expect(find.byKey(const Key('impostazioni-voce-ruoli')), findsNothing);
    expect(find.byKey(const Key('impostazioni-voce-licenze')), findsNothing);
    expect(
      find.byKey(const Key('impostazioni-voce-integrazioni')),
      findsNothing,
    );
  });

  testWidgets('mostra le voci Utenti e Ruoli e naviga alla rotta scelta',
      (tester) async {
    final rotte = <String>[];
    await mostraImpostazioni(tester, onVoce: rotte.add);

    expect(find.text('Utenti'), findsOneWidget);
    expect(find.text('Ruoli e permessi'), findsOneWidget);
    expect(find.text('Licenze'), findsOneWidget);

    await tester.tap(find.byKey(const Key('impostazioni-voce-utenti')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('impostazioni-voce-ruoli')));
    await tester.pumpAndSettle();

    expect(rotte, ['/impostazioni/utenti', '/impostazioni/ruoli']);
  });

  testWidgets('la voce Super Admin compare solo per i super admin',
      (tester) async {
    await mostraImpostazioni(tester);
    expect(
      find.byKey(const Key('impostazioni-voce-super-admin')),
      findsOneWidget,
    );

    await mostraImpostazioni(
      tester,
      profiloDaMostrare: const UserProfile(
        id: 'u2',
        uid: 'u2',
        email: 'anna@example.it',
        nome: 'Anna Bianchi',
        ruolo: 'commerciale',
      ),
    );
    expect(
      find.byKey(const Key('impostazioni-voce-super-admin')),
      findsNothing,
    );
    expect(find.text('Super admin'), findsNothing);
  });

  testWidgets('senza super admin non mostra il badge', (tester) async {
    await mostraImpostazioni(
      tester,
      profiloDaMostrare: const UserProfile(
        id: 'u2',
        uid: 'u2',
        email: 'anna@example.it',
        nome: 'Anna Bianchi',
        ruolo: 'commerciale',
      ),
    );

    expect(
      find.byKey(const Key('impostazioni-super-admin-badge')),
      findsNothing,
    );
  });

  testWidgets('il pulsante di logout chiama onLogout', (tester) async {
    var uscite = 0;
    await mostraImpostazioni(tester, onLogout: () => uscite++);

    await tester.tap(find.byKey(const Key('impostazioni-logout')));
    await tester.pumpAndSettle();

    expect(uscite, 1);
  });

  testWidgets('la tendina azienda chiama onCambiaAzienda con l\'id scelto',
      (tester) async {
    final scelte = <String>[];
    await mostraImpostazioni(tester, onCambiaAzienda: scelte.add);

    await tester.tap(
      find.byKey(const Key('impostazioni-azienda-tendina')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta S.r.l.').last);
    await tester.pumpAndSettle();

    expect(scelte, ['a2']);
  });

  testWidgets('con una sola azienda mostra il nome senza tendina',
      (tester) async {
    await mostraImpostazioni(
      tester,
      aziendeDaMostrare: const [
        Azienda(id: 'a1', nome: 'Acme S.r.l.', ruolo: 'admin'),
      ],
    );

    expect(
      find.byKey(const Key('impostazioni-azienda-tendina')),
      findsNothing,
    );
    expect(find.text('Acme S.r.l.'), findsOneWidget);
  });

  testWidgets('senza aziende mostra lo stato vuoto', (tester) async {
    await mostraImpostazioni(tester, aziendeDaMostrare: const []);

    expect(
      find.byKey(const Key('impostazioni-azienda-vuota')),
      findsOneWidget,
    );
  });
}
