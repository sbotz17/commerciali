import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/features/shell/app_shell.dart';

void main() {
  /// Su telefono lo schermo è sotto i 600 px: compare la `NavigationBar`.
  Future<void> mostraShell(
    WidgetTester tester, {
    String percorso = '/bandi',
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppShell(
          percorso: percorso,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder nellaBarra(String testo) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(testo),
      );

  group('AppShell su telefono', () {
    testWidgets('Bandi è una destinazione principale e il titolo è Bandi',
        (tester) async {
      await mostraShell(tester);

      final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(barra.destinations.length, 5);
      expect(
        barra.destinations
            .map((destinazione) => (destinazione as NavigationDestination).label),
        ['Dashboard', 'Clienti', 'Preventivi', 'Bandi', 'Altro'],
      );

      expect(nellaBarra('Bandi'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Bandi')),
        findsOneWidget,
      );

      // `/bandi` è la quarta voce principale.
      expect(barra.selectedIndex, 3);
    });

    testWidgets('Visite non è nella NavigationBar ma nel drawer Altro',
        (tester) async {
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

    testWidgets('le rotte delle voci secondarie aprono il drawer',
        (tester) async {
      await mostraShell(tester, percorso: '/visite');

      final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
      // `/visite` vive sotto "Altro".
      expect(barra.selectedIndex, 4);
    });
  });
}
