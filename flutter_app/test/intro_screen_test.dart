import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/features/intro/intro_screen.dart';

void main() {
  Future<void> mostraIntro(
    WidgetTester tester, {
    VoidCallback? onFine,
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: IntroScreen(onFine: onFine ?? () {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra titolo e i tre suggerimenti di installazione',
      (tester) async {
    await mostraIntro(tester);

    expect(find.text('Installa Commerciali'), findsOneWidget);
    expect(find.byKey(const Key('intro-icona-app')), findsOneWidget);

    expect(
      find.byKey(const Key('intro-suggerimento-android')),
      findsOneWidget,
    );
    expect(
      find.text('Android (Chrome)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('"Installa app"'),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('intro-suggerimento-iphone')),
      findsOneWidget,
    );
    expect(find.text('iPhone e iPad (Safari)'), findsOneWidget);
    expect(find.textContaining('"Aggiungi a Home"'), findsOneWidget);

    expect(
      find.byKey(const Key('intro-suggerimento-desktop')),
      findsOneWidget,
    );
    expect(find.text('Computer (Chrome o Edge)'), findsOneWidget);
    expect(find.textContaining('barra degli indirizzi'), findsOneWidget);

    expect(find.byKey(const Key('intro-ho-capito')), findsOneWidget);
  });

  testWidgets('il pulsante "Ho capito, inizia" chiama onFine', (tester) async {
    var chiamate = 0;
    await mostraIntro(tester, onFine: () => chiamate++);

    await tester.tap(find.byKey(const Key('intro-ho-capito')));
    await tester.pumpAndSettle();

    expect(chiamate, 1);
  });
}
