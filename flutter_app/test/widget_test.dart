import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/splash_screen.dart';

void main() {
  testWidgets('SplashScreen mostra il nome Commerciali', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('Commerciali'), findsOneWidget);
    expect(find.text('Caricamento…'), findsOneWidget);
  });
}
