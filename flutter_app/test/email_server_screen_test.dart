import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/user_profile.dart';
import 'package:commerciali_app/features/superadmin/email_server_screen.dart';
import 'package:commerciali_app/state/auth_providers.dart';

void main() {
  testWidgets('un utente non super admin vede Accesso riservato', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(
            (ref) async => const UserProfile(
              id: 'u1',
              uid: 'u1',
              email: 'utente@example.com',
              superAdmin: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const EmailServerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('email-config-riservato')), findsOneWidget);
    expect(find.text('Accesso riservato'), findsOneWidget);
  });
}
