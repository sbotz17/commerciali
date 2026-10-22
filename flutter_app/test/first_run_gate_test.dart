import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/features/intro/first_run_gate.dart';
import 'package:commerciali_app/features/intro/intro_screen.dart';
import 'package:commerciali_app/splash_screen.dart';

void main() {
  Future<void> mostraGate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const FirstRunGate(child: Text('contenuto app')),
      ),
    );
  }

  testWidgets('flag assente: splash, poi intro; "Ho capito" salva e mostra app',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await mostraGate(tester);
    // Prima lettura delle preferenze ancora in corso.
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(IntroScreen), findsOneWidget);
    expect(find.text('contenuto app'), findsNothing);

    await tester.tap(find.byKey(const Key('intro-ho-capito')));
    await tester.pumpAndSettle();

    expect(find.text('contenuto app'), findsOneWidget);
    expect(find.byType(IntroScreen), findsNothing);

    final preferenze = await SharedPreferences.getInstance();
    expect(preferenze.getBool(chiaveIntroVista), isTrue);
  });

  testWidgets('flag vero: mostra subito il contenuto senza intro',
      (tester) async {
    SharedPreferences.setMockInitialValues({chiaveIntroVista: true});

    await mostraGate(tester);
    await tester.pumpAndSettle();

    expect(find.text('contenuto app'), findsOneWidget);
    expect(find.byType(IntroScreen), findsNothing);
    expect(find.byType(SplashScreen), findsNothing);
  });
}
