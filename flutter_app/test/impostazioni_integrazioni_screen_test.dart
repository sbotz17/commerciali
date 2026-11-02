import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/integrazione_azienda.dart';
import 'package:commerciali_app/features/impostazioni/impostazioni_integrazioni_screen.dart';

/// Contenitore con stato per provare il corpo senza provider né Firebase.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.iniziale,
    required this.onSalva,
    this.caricamento = false,
    this.salvataggio = false,
    this.errore,
    this.messaggioErroreSalvataggio,
    this.onRiprova,
    this.onVoce,
  });

  final IntegrazioneAzienda iniziale;
  final void Function(IntegrazioneAzienda) onSalva;
  final bool caricamento;
  final bool salvataggio;
  final Object? errore;
  final String? messaggioErroreSalvataggio;
  final VoidCallback? onRiprova;
  final void Function(String rotta)? onVoce;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late IntegrazioneAzienda _integrazione = widget.iniziale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: CorpoIntegrazioni(
          integrazione: _integrazione,
          caricamento: widget.caricamento,
          salvataggio: widget.salvataggio,
          errore: widget.errore,
          messaggioErroreSalvataggio: widget.messaggioErroreSalvataggio,
          onSalva: (integrazione) {
            setState(() => _integrazione = integrazione);
            widget.onSalva(integrazione);
          },
          onRiprova: widget.onRiprova ?? () {},
          onVoce: widget.onVoce,
        ),
      ),
    );
  }
}

void main() {
  /// Monta il corpo puro con una finestra alta e larga (dialog desktop).
  Future<void> mostraIntegrazioni(
    WidgetTester tester, {
    required void Function(IntegrazioneAzienda) onSalva,
    IntegrazioneAzienda? iniziale,
    bool caricamento = false,
    bool salvataggio = false,
    Object? errore,
    String? messaggioErroreSalvataggio,
    VoidCallback? onRiprova,
    void Function(String)? onVoce,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _Harness(
        iniziale: iniziale ?? IntegrazioneAzienda.vuota('a1'),
        caricamento: caricamento,
        salvataggio: salvataggio,
        errore: errore,
        messaggioErroreSalvataggio: messaggioErroreSalvataggio,
        onSalva: onSalva,
        onRiprova: onRiprova,
        onVoce: onVoce,
      ),
    );
    if (caricamento) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> apriDialog(WidgetTester tester, String provider) async {
    await tester.tap(find.byKey(Key('integrazioni-$provider-configura')));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra le card di tutti i provider e dei servizi',
      (tester) async {
    await mostraIntegrazioni(tester, onSalva: (_) {});

    for (final chiave in [
      'integrazioni-card-google',
      'integrazioni-card-microsoft',
      'integrazioni-card-smtp',
      'integrazioni-card-whatsapp',
      'integrazioni-card-r2',
      'integrazioni-card-push',
    ]) {
      expect(find.byKey(Key(chiave)), findsOneWidget, reason: chiave);
    }

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Microsoft'), findsOneWidget);
    expect(find.text('Email SMTP'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Storage R2'), findsOneWidget);
    expect(find.text('Push'), findsOneWidget);
  });

  testWidgets('Google e Microsoft partono da configurare', (tester) async {
    await mostraIntegrazioni(tester, onSalva: (_) {});

    expect(find.text('Da configurare'), findsNWidgets(2));
    expect(find.text('Configurato'), findsNothing);
    expect(find.text('Non attiva'), findsNWidgets(4));
  });

  testWidgets('i servizi non pronti mostrano il pulsante disabilitato',
      (tester) async {
    await mostraIntegrazioni(tester, onSalva: (_) {});

    expect(
      find.text('Richiede la configurazione del server'),
      findsNWidgets(3),
    );
    for (final chiave in [
      'integrazioni-smtp-configura',
      'integrazioni-whatsapp-configura',
      'integrazioni-r2-configura',
    ]) {
      final pulsante =
          tester.widget<OutlinedButton>(find.byKey(Key(chiave)));
      expect(pulsante.onPressed, isNull, reason: chiave);
    }
  });

  testWidgets('Push rimanda alle notifiche quando la callback è presente',
      (tester) async {
    final rotte = <String>[];
    await mostraIntegrazioni(tester, onSalva: (_) {}, onVoce: rotte.add);

    expect(find.text('Gestisci da Notifiche'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('integrazioni-push-apri')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('integrazioni-push-apri')));
    await tester.pumpAndSettle();

    expect(rotte, ['/impostazioni/notifiche']);
  });

  testWidgets('dialog Google: modalità, Client ID e salvataggio senza secret',
      (tester) async {
    final salvate = <IntegrazioneAzienda>[];
    await mostraIntegrazioni(tester, onSalva: salvate.add);

    await apriDialog(tester, 'google');
    expect(find.text('Configura Google'), findsOneWidget);
    expect(find.text('Usa app Closer'), findsOneWidget);
    expect(find.text('Usa app propria'), findsOneWidget);

    await tester.tap(find.text('Usa app propria'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('integrazione-google-client-id')),
      'client-google-123',
    );
    await tester.ensureVisible(find.byKey(const Key('integrazione-google-salva')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('integrazione-google-salva')));
    await tester.pumpAndSettle();

    expect(salvate, hasLength(1));
    final google = salvate.single.google;
    expect(google, isNotNull);
    expect(google!.modalita, 'personalizzata');
    expect(google.clientId, 'client-google-123');
    expect(google.stato, 'configurata');
    expect(google.attivo, isTrue);
    expect(google.toMap().containsKey('client_secret'), isFalse);
    expect(salvate.single.toMap().containsKey('client_secret'), isFalse);

    // La card si aggiorna con lo stato configurato.
    expect(find.text('Configurato'), findsOneWidget);
    expect(find.text('Da configurare'), findsOneWidget);
  });

  testWidgets('dialog Google: Client Secret disabilitato e redirect in sola '
      'lettura', (tester) async {
    await mostraIntegrazioni(tester, onSalva: (_) {});
    await apriDialog(tester, 'google');

    final secret = tester.widget<TextField>(
      find.byKey(const Key('integrazione-google-secret')),
    );
    expect(secret.enabled, isFalse);
    expect(find.text(testoClientSecret), findsOneWidget);

    final redirect = tester.widget<TextField>(
      find.byKey(const Key('integrazione-google-redirect')),
    );
    expect(redirect.readOnly, isTrue);
    expect(redirect.controller?.text, redirectDaGenerare);
  });

  testWidgets('dialog Microsoft: Tenant ID, redirect salvato e modalità Closer',
      (tester) async {
    final salvate = <IntegrazioneAzienda>[];
    final iniziale = IntegrazioneAzienda.vuota('a1').copyWith(
      microsoft: ConfigIntegrazioneProvider(
        redirectUri: 'https://worker.example.it/callback',
      ),
    );
    await mostraIntegrazioni(tester, onSalva: salvate.add, iniziale: iniziale);

    await apriDialog(tester, 'microsoft');
    expect(find.text('Configura Microsoft'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('integrazione-microsoft-redirect')),
          )
          .controller
          ?.text,
      'https://worker.example.it/callback',
    );

    await tester.enterText(
      find.byKey(const Key('integrazione-microsoft-client-id')),
      'client-ms-1',
    );
    await tester.enterText(
      find.byKey(const Key('integrazione-microsoft-tenant')),
      'tenant-1',
    );
    await tester.ensureVisible(
      find.byKey(const Key('integrazione-microsoft-salva')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('integrazione-microsoft-salva')));
    await tester.pumpAndSettle();

    expect(salvate, hasLength(1));
    final microsoft = salvate.single.microsoft!;
    expect(microsoft.modalita, 'closer');
    expect(microsoft.clientId, 'client-ms-1');
    expect(microsoft.tenantId, 'tenant-1');
    expect(microsoft.redirectUri, 'https://worker.example.it/callback');
    expect(microsoft.stato, 'configurata');
  });

  testWidgets('dialog: Annulla non salva nulla', (tester) async {
    final salvate = <IntegrazioneAzienda>[];
    await mostraIntegrazioni(tester, onSalva: salvate.add);

    await apriDialog(tester, 'google');
    await tester.tap(find.byKey(const Key('integrazione-google-annulla')));
    await tester.pumpAndSettle();

    expect(salvate, isEmpty);
    expect(find.text('Usa app Closer'), findsNothing);
  });

  testWidgets('mostra caricamento ed errore con Riprova', (tester) async {
    await mostraIntegrazioni(
      tester,
      onSalva: (_) {},
      caricamento: true,
    );
    expect(find.byKey(const Key('integrazioni-caricamento')), findsOneWidget);

    var riprove = 0;
    await mostraIntegrazioni(
      tester,
      onSalva: (_) {},
      errore: Exception('rete'),
      onRiprova: () => riprove++,
    );
    expect(
      find.byKey(const Key('integrazioni-errore-caricamento')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('integrazioni-riprova')));
    await tester.pumpAndSettle();
    expect(riprove, 1);
  });
}
