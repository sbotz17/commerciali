import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/condivisione_calendario.dart';
import 'package:commerciali_app/data/models/user_profile.dart';
import 'package:commerciali_app/features/impostazioni/condivisione_calendario_screen.dart';

UserProfile _utente(String uid, String nome) => UserProfile(
      id: uid,
      uid: uid,
      nome: nome,
      email: '$uid@example.test',
    );

CondivisioneCalendario _condivisione({
  required String id,
  required String proprietario,
  required String destinatario,
  String livello = 'dettagli',
}) =>
    CondivisioneCalendario(
      id: id,
      aziendaId: 'az-1',
      proprietarioUid: proprietario,
      destinatarioUid: destinatario,
      livello: livello,
      stato: 'attiva',
      createdAt: '2026-10-24T10:00:00Z',
    );

void main() {
  test('colleghiCondivisibili esclude se stesso, vuoti e duplicati', () {
    final utenti = [
      _utente('a', 'Anna'),
      _utente('b', 'Bruno'),
      _utente('b', 'Bruno duplicato'),
      _utente('', 'Senza uid'),
      _utente('c', 'Carla'),
    ];

    final risultato = colleghiCondivisibili(utenti, 'a');

    expect(risultato.map((u) => u.uid), ['b', 'c']);
  });

  test('nomeUtentePerUid usa Collega se il profilo non esiste', () {
    expect(nomeUtentePerUid([_utente('b', 'Bruno')], 'b'), 'Bruno');
    expect(nomeUtentePerUid([_utente('b', 'Bruno')], 'x'), 'Collega');
    expect(nomeUtentePerUid([_utente('b', 'Bruno')], null), 'Collega');
  });

  Future<void> mostra(
    WidgetTester tester, {
    List<UserProfile>? utenti,
    List<CondivisioneCalendario> condivisioni = const [],
    List<CondivisioneCalendario> ricevute = const [],
    bool caricamento = false,
    Object? errore,
    void Function(String, String)? onCondividi,
    void Function(CondivisioneCalendario)? onRevoca,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CorpoCondivisioneCalendario(
            utenti: utenti ??
                [
                  _utente('a', 'Anna'),
                  _utente('b', 'Bruno'),
                ],
            uidCorrente: 'a',
            condivisioni: condivisioni,
            ricevute: ricevute,
            caricamento: caricamento,
            errore: errore,
            onCondividi: onCondividi ?? (_, _) {},
            onRevoca: onRevoca ?? (_) {},
            onRiprova: () {},
          ),
        ),
      ),
    );
    if (caricamento) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('mostra le sezioni e il livello predefinito Dettagli',
      (tester) async {
    await mostra(tester);

    expect(find.text('Condivisione calendario'), findsOneWidget);
    expect(find.text('Condivisioni attive'), findsOneWidget);
    expect(find.text('Condivisi con me'), findsOneWidget);
    expect(find.text('Dettagli evento'), findsOneWidget);
    expect(find.byKey(const Key('condivisione-crea')), findsOneWidget);
    expect(find.byKey(const Key('condivisione-vuoto')), findsOneWidget);
  });

  testWidgets('crea la condivisione con collega e livello scelti',
      (tester) async {
    String? destinatario;
    String? livello;
    await mostra(
      tester,
      onCondividi: (uid, liv) {
        destinatario = uid;
        livello = liv;
      },
    );

    final collega = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('condivisione-collega')),
    );
    collega.onChanged?.call('b');
    await tester.pump();

    final livelloWidget = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('condivisione-livello')),
    );
    livelloWidget.onChanged?.call('modifica');
    await tester.pump();

    expect(find.byKey(const Key('condivisione-avviso-modifica')),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('condivisione-crea')));
    await tester.pump();

    expect(destinatario, 'b');
    expect(livello, 'modifica');
  });

  testWidgets('chiede conferma prima di revocare', (tester) async {
    CondivisioneCalendario? revocata;
    final condivisione = _condivisione(
      id: 'az-1_a_b',
      proprietario: 'a',
      destinatario: 'b',
    );
    await mostra(
      tester,
      condivisioni: [condivisione],
      onRevoca: (c) => revocata = c,
    );

    await tester.tap(find.byKey(const Key('condivisione-revoca-b')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialog-revoca-condivisione')),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('conferma-revoca-condivisione')));
    await tester.pumpAndSettle();

    expect(revocata?.id, 'az-1_a_b');
  });

  testWidgets('mostra i calendari ricevuti in sola lettura', (tester) async {
    await mostra(
      tester,
      ricevute: [
        _condivisione(
          id: 'az-1_b_a',
          proprietario: 'b',
          destinatario: 'a',
        ),
      ],
    );

    expect(find.byKey(const Key('condivisione-riga-b')), findsOneWidget);
    expect(find.text('Sola lettura'), findsOneWidget);
    expect(find.byKey(const Key('condivisione-revoca-b')), findsNothing);
  });

  testWidgets('mostra caricamento', (tester) async {
    await mostra(tester, caricamento: true);
    expect(find.byKey(const Key('condivisione-caricamento')), findsOneWidget);
  });

  testWidgets('mostra errore con Riprova', (tester) async {
    await mostra(tester, errore: StateError('errore'));
    expect(find.byKey(const Key('condivisione-errore-caricamento')),
        findsOneWidget);
    expect(find.byKey(const Key('condivisione-riprova')), findsOneWidget);
  });
}
