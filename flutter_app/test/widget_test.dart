import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/features/shell/app_shell.dart';
import 'package:commerciali_app/core/ui/placeholder_screen.dart';

void main() {
  testWidgets('la shell mostra Dashboard senza Firebase', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(
          percorso: '/',
          child: PlaceholderScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Dashboard')),
      findsOneWidget,
    );
    expect(find.byType(PlaceholderScreen), findsOneWidget);
  });

  testWidgets('sotto 600 px usa NavigationBar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(
          percorso: '/',
          child: PlaceholderScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('da 600 px usa NavigationRail', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(
          percorso: '/',
          child: PlaceholderScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Altro apre il drawer con le voci secondarie', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(
          percorso: '/',
          child: PlaceholderScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Altro'));
    await tester.pumpAndSettle();

    expect(find.text('Catalogo'), findsOneWidget);
    expect(find.text('Bandi'), findsOneWidget);
    expect(find.text('Impostazioni'), findsOneWidget);
  });
}
