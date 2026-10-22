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
    // La pulsazione del mockup è in `repeat`: pumpAndSettle non arriverebbe
    // mai a stabilizzarsi, quindi si avanza di un tempo esplicito.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Tocca la scelta e attende la fine della transizione del pannello.
  Future<void> scegli(WidgetTester tester, String chiave) async {
    await tester.tap(find.byKey(Key(chiave)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  testWidgets('di default mostra Android con titolo, scelte e pulsante finale',
      (tester) async {
    await mostraIntro(tester);

    expect(find.text('Installa Closer'), findsOneWidget);
    expect(find.byKey(const Key('intro-icona-app')), findsOneWidget);

    // Selettore a tre scelte.
    expect(find.byKey(const Key('intro-scelta-android')), findsOneWidget);
    expect(find.byKey(const Key('intro-scelta-iphone')), findsOneWidget);
    expect(find.byKey(const Key('intro-scelta-desktop')), findsOneWidget);

    // Pannello Android visibile, gli altri no.
    expect(
      find.byKey(const Key('intro-suggerimento-android')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('intro-suggerimento-iphone')), findsNothing);
    expect(find.byKey(const Key('intro-suggerimento-desktop')), findsNothing);

    expect(find.text('Android (Chrome)'), findsOneWidget);
    expect(find.textContaining('menu ⋮'), findsOneWidget);
    expect(find.textContaining('"Installa app"'), findsOneWidget);
    expect(find.textContaining('"Aggiungi a schermata Home"'), findsOneWidget);

    expect(find.byKey(const Key('intro-ho-capito')), findsOneWidget);
  });

  testWidgets('tocco su iPhone mostra i passi per iPhone e iPad',
      (tester) async {
    await mostraIntro(tester);

    await scegli(tester, 'intro-scelta-iphone');

    expect(find.byKey(const Key('intro-suggerimento-iphone')), findsOneWidget);
    expect(find.byKey(const Key('intro-suggerimento-android')), findsNothing);
    expect(find.byKey(const Key('intro-suggerimento-desktop')), findsNothing);

    expect(find.text('iPhone e iPad (Safari)'), findsOneWidget);
    expect(find.textContaining('Condividi'), findsOneWidget);
    expect(find.textContaining('"Aggiungi a Home"'), findsOneWidget);
    expect(find.textContaining('"Aggiungi"'), findsOneWidget);
  });

  testWidgets('tocco su Computer mostra i passi per il desktop', (tester) async {
    await mostraIntro(tester);

    await scegli(tester, 'intro-scelta-desktop');

    expect(find.byKey(const Key('intro-suggerimento-desktop')), findsOneWidget);
    expect(find.byKey(const Key('intro-suggerimento-android')), findsNothing);
    expect(find.byKey(const Key('intro-suggerimento-iphone')), findsNothing);

    expect(find.text('Computer (Chrome o Edge)'), findsOneWidget);
    expect(find.textContaining('barra degli indirizzi'), findsOneWidget);
    expect(find.textContaining('"Installa".'), findsOneWidget);
  });

  testWidgets('il pulsante "Ho capito, inizia" chiama onFine', (tester) async {
    var chiamate = 0;
    await mostraIntro(tester, onFine: () => chiamate++);

    final pulsante = find.byKey(const Key('intro-ho-capito'));
    await tester.ensureVisible(pulsante);
    await tester.tap(pulsante);
    await tester.pump();

    expect(chiamate, 1);
  });
}
