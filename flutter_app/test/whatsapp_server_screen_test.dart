import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/user_profile.dart';
import 'package:commerciali_app/features/superadmin/whatsapp_server_screen.dart';
import 'package:commerciali_app/state/auth_providers.dart';

void main() {
  test('apiKeyConfigWhatsapp legge apiKey e il fallback api_key', () {
    expect(
      apiKeyConfigWhatsapp({'url': 'https://wa.example', 'apiKey': 'segreta'}),
      'segreta',
    );
    expect(apiKeyConfigWhatsapp({'api_key': 'vecchia'}), 'vecchia');
    expect(apiKeyConfigWhatsapp(null), '');
  });

  testWidgets('la configurazione WhatsApp è riservata al super admin', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(
            (ref) async =>
                const UserProfile(id: 'u1', uid: 'u1', superAdmin: false),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: WhatsappServerScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('whatsapp-config-riservato')), findsOneWidget);
    expect(find.text('Accesso riservato'), findsOneWidget);
    expect(find.byKey(const Key('whatsapp-config-url')), findsNothing);
  });
}
