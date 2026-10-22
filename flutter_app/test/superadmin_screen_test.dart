import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/azienda.dart';
import 'package:commerciali_app/features/superadmin/superadmin_screen.dart';

void main() {
  const volty = Azienda(id: 'a1', nome: 'VOLTY');
  const alfa = Azienda(id: 'a2', nome: 'Alfa Srl');

  group('filtraAziende', () {
    const aziende = [volty, alfa];

    test('testo vuoto torna tutte le aziende', () {
      expect(filtraAziende(aziende, ''), aziende);
      expect(filtraAziende(aziende, '   '), aziende);
    });

    test('cerca per nome senza distinzione di maiuscole', () {
      expect(filtraAziende(aziende, 'alfa').map((a) => a.id), ['a2']);
      expect(filtraAziende(aziende, ' VOLTY ').map((a) => a.id), ['a1']);
    });

    test('nessuna corrispondenza torna lista vuota', () {
      expect(filtraAziende(aziende, 'beta'), isEmpty);
    });
  });

  group('messaggioErroreSuperAdmin', () {
    test('permessi negati spiega il problema', () {
      final errore = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      expect(messaggioErroreSuperAdmin(errore), contains('Non hai i permessi'));
    });

    test('errore di rete invita a controllare la connessione', () {
      final errore = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      expect(
        messaggioErroreSuperAdmin(errore),
        contains('Connessione assente'),
      );
    });

    test('errore generico non espone dettagli tecnici', () {
      expect(
        messaggioErroreSuperAdmin(Exception('rete')),
        contains('connessione e riprova'),
      );
    });
  });

  group('CorpoSuperAdmin', () {
    /// Monta [CorpoSuperAdmin] in un'app minima, senza provider né Firebase.
    Future<void> mostraCorpo(
      WidgetTester tester, {
      List<Azienda> aziende = const [volty, alfa],
      bool? largo,
      ValueChanged<Azienda>? onEntra,
      VoidCallback? onNuova,
    }) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CorpoSuperAdmin(
              aziende: aziende,
              largo: largo,
              onEntra: onEntra ?? (_) {},
              onRiprova: () {},
              onNuova: onNuova,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('mostra lo stato vuoto senza aziende', (tester) async {
      await mostraCorpo(tester, aziende: const []);

      expect(find.byKey(const Key('superadmin-vuoto')), findsOneWidget);
      expect(find.text('Nessuna azienda'), findsOneWidget);
      expect(find.byKey(const Key('superadmin-lista')), findsNothing);
      expect(find.byKey(const Key('superadmin-tabella')), findsNothing);
    });

    testWidgets('mostra le aziende con il pulsante Entra', (tester) async {
      Azienda? scelta;
      await mostraCorpo(
        tester,
        largo: false,
        onEntra: (azienda) => scelta = azienda,
      );

      expect(find.byKey(const Key('superadmin-lista')), findsOneWidget);
      expect(find.text('VOLTY'), findsOneWidget);
      expect(find.text('Alfa Srl'), findsOneWidget);
      expect(find.text('Entra'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('superadmin-entra-a2')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('superadmin-entra-a2')));
      await tester.pumpAndSettle();

      expect(scelta?.id, 'a2');
    });

    testWidgets('la ricerca filtra la lista', (tester) async {
      await mostraCorpo(tester, largo: false);

      await tester.enterText(
        find.byKey(const Key('superadmin-ricerca')),
        'alfa',
      );
      await tester.pumpAndSettle();

      expect(find.text('Alfa Srl'), findsOneWidget);
      expect(find.text('VOLTY'), findsNothing);
      expect(find.text('Entra'), findsOneWidget);
    });

    testWidgets('layout largo usa la tabella', (tester) async {
      await mostraCorpo(tester, largo: true);

      expect(find.byKey(const Key('superadmin-tabella')), findsOneWidget);
      expect(find.byKey(const Key('superadmin-lista')), findsNothing);
      expect(
        find.byKey(const ValueKey('superadmin-entra-a1')),
        findsOneWidget,
      );
    });

    testWidgets('senza callback "Nuova azienda" non compare', (tester) async {
      await mostraCorpo(tester, largo: false);

      expect(find.text('Aziende'), findsOneWidget);
      expect(find.byKey(const Key('superadmin-nuova')), findsNothing);
      expect(find.byKey(const Key('superadmin-nuova-vuoto')), findsNothing);
    });

    testWidgets('con callback compare il pulsante "Nuova azienda"', (
      tester,
    ) async {
      var premuto = 0;
      await mostraCorpo(tester, largo: false, onNuova: () => premuto++);

      expect(find.byKey(const Key('superadmin-nuova')), findsOneWidget);
      expect(find.text('Aziende'), findsOneWidget);

      await tester.tap(find.byKey(const Key('superadmin-nuova')));
      await tester.pumpAndSettle();

      expect(premuto, 1);
    });

    testWidgets('stato vuoto con callback mostra il pulsante dedicato', (
      tester,
    ) async {
      var premuto = 0;
      await mostraCorpo(
        tester,
        aziende: const [],
        onNuova: () => premuto++,
      );

      expect(find.byKey(const Key('superadmin-vuoto')), findsOneWidget);
      expect(
        find.byKey(const Key('superadmin-nuova-vuoto')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('superadmin-nuova')), findsNothing);

      await tester.tap(find.byKey(const Key('superadmin-nuova-vuoto')));
      await tester.pumpAndSettle();

      expect(premuto, 1);
    });
  });
}
