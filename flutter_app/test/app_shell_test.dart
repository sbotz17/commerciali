import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/features/shell/app_shell.dart';

void main() {
  /// Su telefono lo schermo è sotto i 600 px: compare la `NavigationBar`.
  Future<void> mostraShell(
    WidgetTester tester, {
    String percorso = '/calendario',
    Size dimensione = const Size(400, 900),
  }) async {
    tester.view.physicalSize = dimensione;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppShell(percorso: percorso, child: const SizedBox.expand()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder nellaBarra(String testo) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(testo),
  );

  group('AppShell su telefono', () {
    testWidgets(
      'Calendario è una destinazione principale e il titolo è Calendario',
      (tester) async {
        await mostraShell(tester);

        final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(barra.destinations.length, 5);
        expect(
          barra.destinations.map(
            (destinazione) => (destinazione as NavigationDestination).label,
          ),
          ['Dashboard', 'Calendario', 'Clienti', 'Preventivi', 'Altro'],
        );

        expect(nellaBarra('Calendario'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Calendario'),
          ),
          findsOneWidget,
        );

        // Calendario è la seconda voce principale.
        expect(barra.selectedIndex, 1);
      },
    );

    testWidgets('tenendo premuto Calendario si scelgono Visite o Task', (
      tester,
    ) async {
      await mostraShell(tester, percorso: '/');
      await tester.longPress(find.byKey(const Key('nav-calendario-normale')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nav-menu-visite')), findsOneWidget);
      expect(find.byKey(const Key('nav-menu-task')), findsOneWidget);
      expect(find.text('Visite'), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
    });

    testWidgets('Visite non è nella NavigationBar ma nel drawer Altro', (
      tester,
    ) async {
      await mostraShell(tester);

      expect(nellaBarra('Visite'), findsNothing);

      await tester.tap(nellaBarra('Altro'));
      await tester.pumpAndSettle();

      expect(find.byType(Drawer), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Drawer), matching: find.text('Visite')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byIcon(Icons.event_outlined),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Visite e Task evidenziano Calendario nella barra', (
      tester,
    ) async {
      await mostraShell(tester, percorso: '/visite');

      final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(barra.selectedIndex, 1);
    });

    testWidgets('Chat è nel drawer Altro con il titolo in AppBar', (
      tester,
    ) async {
      await mostraShell(tester, percorso: '/chat');

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Chat')),
        findsOneWidget,
      );

      await tester.tap(nellaBarra('Altro'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(Drawer), matching: find.text('Chat')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byIcon(Icons.chat_bubble_outline),
        ),
        findsOneWidget,
      );
    });
  });

  group('AppShell su desktop', () {
    testWidgets('la barra laterale mostra tutte le pagine senza Altro', (
      tester,
    ) async {
      await mostraShell(
        tester,
        percorso: '/calendario',
        dimensione: const Size(1200, 1000),
      );

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byIcon(Icons.more_horiz), findsNothing);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations.length, 10);
      expect(rail.selectedIndex, 5);
      for (final etichetta in [
        'Dashboard',
        'Clienti',
        'Catalogo',
        'Preventivi',
        'Visite',
        'Calendario',
        'Task',
        'Chat',
        'Bandi',
        'Notifiche',
      ]) {
        expect(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text(etichetta),
          ),
          findsOneWidget,
          reason: etichetta,
        );
      }
      expect(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Impostazioni'),
        ),
        findsNothing,
      );
      expect(find.byKey(const Key('rail-impostazioni')), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('con una rotta impostazioni la rotella è selezionata', (
      tester,
    ) async {
      await mostraShell(
        tester,
        percorso: '/impostazioni/agenda',
        dimensione: const Size(1200, 1000),
      );

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, isNull);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });
}
