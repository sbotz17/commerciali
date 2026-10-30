import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/features/impostazioni/impostazioni_agenda_screen.dart';

/// Contenitore con stato per provare il corpo senza provider né Firebase.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.onSalva,
    this.iniziali = ImpostazioniAgenda.predefinite,
    this.caricamento = false,
    this.errore,
    this.messaggioErroreSalvataggio,
    this.onRiprova,
  });

  final ImpostazioniAgenda iniziali;
  final bool caricamento;
  final Object? errore;
  final String? messaggioErroreSalvataggio;
  final void Function(ImpostazioniAgenda) onSalva;
  final VoidCallback? onRiprova;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late ImpostazioniAgenda _impostazioni = widget.iniziali;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: CorpoImpostazioniAgenda(
          impostazioni: _impostazioni,
          caricamento: widget.caricamento,
          errore: widget.errore,
          messaggioErroreSalvataggio: widget.messaggioErroreSalvataggio,
          onSalva: (impostazioni) {
            setState(() => _impostazioni = impostazioni);
            widget.onSalva(impostazioni);
          },
          onRiprova: widget.onRiprova ?? () {},
        ),
      ),
    );
  }
}

void main() {
  /// Monta il corpo puro con una finestra alta, così i campi sono raggiungibili.
  Future<void> mostraAgenda(
    WidgetTester tester, {
    required void Function(ImpostazioniAgenda) onSalva,
    ImpostazioniAgenda iniziali = ImpostazioniAgenda.predefinite,
    bool caricamento = false,
    Object? errore,
    String? messaggioErroreSalvataggio,
    VoidCallback? onRiprova,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _Harness(
        iniziali: iniziali,
        caricamento: caricamento,
        errore: errore,
        messaggioErroreSalvataggio: messaggioErroreSalvataggio,
        onSalva: onSalva,
        onRiprova: onRiprova,
      ),
    );
    // L'indicatore di caricamento non si ferma mai: `pumpAndSettle` andrebbe in
    // timeout, quindi in quello stato si avanza di un solo frame.
    if (caricamento) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('mostra tutte le sezioni con i campi dell\'agenda',
      (tester) async {
    await mostraAgenda(tester, onSalva: (_) {});

    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Template cliente'), findsOneWidget);
    expect(find.text('Slot'), findsOneWidget);
    expect(find.text('Allegati'), findsOneWidget);

    for (final chiave in [
      'agenda-fuso',
      'agenda-anticipo',
      'agenda-orario-invio',
      'agenda-canale',
      'agenda-template',
      'agenda-slot-durata',
      'agenda-slot-finestra',
      'agenda-slot-scadenza',
      'agenda-allegati-kb',
      'agenda-allegati-num',
      'agenda-maps',
      'agenda-salva',
    ]) {
      expect(find.byKey(Key(chiave)), findsOneWidget, reason: chiave);
    }
  });

  testWidgets('i campi mostrano i valori predefiniti', (tester) async {
    await mostraAgenda(tester, onSalva: (_) {});

    expect(
      tester.widget<TextField>(find.byKey(const Key('agenda-fuso'))).controller?.text,
      'Europe/Rome',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('agenda-anticipo')))
          .controller
          ?.text,
      '1440',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('agenda-orario-invio')))
          .controller
          ?.text,
      '18:00',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('agenda-template')))
          .controller
          ?.text,
      templateClientePredefinitoAgenda,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('agenda-slot-durata')))
          .controller
          ?.text,
      '60',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('agenda-slot-finestra')))
          .controller
          ?.text,
      '14',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('agenda-slot-scadenza')))
          .controller
          ?.text,
      '7',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('agenda-allegati-kb')))
          .controller
          ?.text,
      '5120',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('agenda-allegati-num')))
          .controller
          ?.text,
      '10',
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('agenda-maps')))
          .value,
      isTrue,
    );

    // Il template predefinito usa tutti i segnaposto previsti.
    for (final segnaposto in [
      '{{data}}',
      '{{ora}}',
      '{{luogo}}',
      '{{azienda}}',
      '{{riferimento}}',
    ]) {
      expect(templateClientePredefinitoAgenda, contains(segnaposto));
    }
  });

  testWidgets('salva le impostazioni modificate, compresi canale e Maps',
      (tester) async {
    final salvate = <ImpostazioniAgenda>[];
    await mostraAgenda(
      tester,
      onSalva: salvate.add,
      iniziali: ImpostazioniAgenda.daMappa(const {}),
    );

    await tester.enterText(find.byKey(const Key('agenda-fuso')), 'Europe/Berlin');
    await tester.enterText(find.byKey(const Key('agenda-anticipo')), '60');
    await tester.enterText(
      find.byKey(const Key('agenda-orario-invio')),
      '09:30',
    );
    await tester.enterText(
      find.byKey(const Key('agenda-slot-durata')),
      '30',
    );
    await tester.enterText(
      find.byKey(const Key('agenda-template')),
      'Ciao {{azienda}}, ci vediamo il {{data}} alle {{ora}}.',
    );

    await tester.tap(find.byKey(const Key('agenda-canale')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('agenda-maps')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agenda-maps')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('agenda-salva')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agenda-salva')));
    await tester.pumpAndSettle();

    expect(salvate, hasLength(1));
    final impostazioni = salvate.single;
    expect(impostazioni.fusoOrario, 'Europe/Berlin');
    expect(impostazioni.anticipoMin, 60);
    expect(impostazioni.orarioInvioCliente, '09:30');
    expect(impostazioni.canaleCliente, 'email');
    expect(impostazioni.slotDurataMin, 30);
    expect(impostazioni.slotFinestraGiorni, 14);
    expect(impostazioni.templateCliente, contains('{{azienda}}'));
    expect(impostazioni.mapsAttivo, isFalse);
    expect(find.byKey(const Key('agenda-errore')), findsNothing);
  });

  testWidgets('orario non valido: mostra l\'avviso e non salva',
      (tester) async {
    final salvate = <ImpostazioniAgenda>[];
    await mostraAgenda(tester, onSalva: salvate.add);

    await tester.enterText(
      find.byKey(const Key('agenda-orario-invio')),
      '25:99',
    );
    await tester.ensureVisible(find.byKey(const Key('agenda-salva')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agenda-salva')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-errore')), findsOneWidget);
    expect(
      find.text('Inserisci l\'orario di invio nel formato HH:MM.'),
      findsOneWidget,
    );
    expect(salvate, isEmpty);
  });

  testWidgets('numero non positivo: mostra l\'avviso e non salva',
      (tester) async {
    final salvate = <ImpostazioniAgenda>[];
    await mostraAgenda(tester, onSalva: salvate.add);

    await tester.enterText(find.byKey(const Key('agenda-allegati-num')), '0');
    await tester.ensureVisible(find.byKey(const Key('agenda-salva')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agenda-salva')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-errore')), findsOneWidget);
    expect(salvate, isEmpty);
  });

  testWidgets('mostra il caricamento', (tester) async {
    await mostraAgenda(
      tester,
      onSalva: (_) {},
      caricamento: true,
    );

    expect(find.byKey(const Key('agenda-caricamento')), findsOneWidget);
    expect(find.byKey(const Key('agenda-salva')), findsNothing);
  });

  testWidgets('errore di caricamento con Riprova', (tester) async {
    var riprove = 0;
    await mostraAgenda(
      tester,
      onSalva: (_) {},
      errore: Exception('rete assente'),
      onRiprova: () => riprove++,
    );

    expect(find.text('Agenda non disponibile'), findsOneWidget);
    expect(find.byKey(const Key('agenda-riprova')), findsOneWidget);

    await tester.tap(find.byKey(const Key('agenda-riprova')));
    await tester.pumpAndSettle();
    expect(riprove, 1);
  });

  testWidgets('errore di salvataggio mostrato nell\'avviso', (tester) async {
    await mostraAgenda(
      tester,
      onSalva: (_) {},
      messaggioErroreSalvataggio: 'Connessione assente. Riprova.',
    );

    expect(find.byKey(const Key('agenda-errore')), findsOneWidget);
    expect(find.text('Connessione assente. Riprova.'), findsOneWidget);
  });
}
