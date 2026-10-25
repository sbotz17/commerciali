import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/features/impostazioni/notifiche_preferenze_screen.dart';

/// Contenitore con stato per provare il corpo senza provider né Firebase.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.onSalva,
    this.iniziali = PreferenzeNotifiche.predefinite,
    this.caricamento = false,
    this.errore,
    this.onRiprova,
  });

  final PreferenzeNotifiche iniziali;
  final bool caricamento;
  final Object? errore;
  final VoidCallback onSalva;
  final VoidCallback? onRiprova;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late PreferenzeNotifiche _preferenze = widget.iniziali;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: CorpoNotifichePreferenze(
          preferenze: _preferenze,
          caricamento: widget.caricamento,
          errore: widget.errore,
          onModifica: (preferenze) =>
              setState(() => _preferenze = preferenze),
          onRiprova: widget.onRiprova ?? () {},
          onSalva: widget.onSalva,
        ),
      ),
    );
  }
}

void main() {
  group('orari di notifica', () {
    test('orari validi', () {
      expect(orarioValidoNotifiche('22:00'), isTrue);
      expect(orarioValidoNotifiche('08:00'), isTrue);
      expect(orarioValidoNotifiche('00:00'), isTrue);
      expect(orarioValidoNotifiche('23:59'), isTrue);
      expect(orarioValidoNotifiche(' 07:30 '), isTrue);
    });

    test('orari non validi', () {
      expect(orarioValidoNotifiche(null), isFalse);
      expect(orarioValidoNotifiche(''), isFalse);
      expect(orarioValidoNotifiche('   '), isFalse);
      expect(orarioValidoNotifiche('24:00'), isFalse);
      expect(orarioValidoNotifiche('22:60'), isFalse);
      expect(orarioValidoNotifiche('9:30'), isFalse);
      expect(orarioValidoNotifiche('22.00'), isFalse);
      expect(orarioValidoNotifiche('sera'), isFalse);
    });

    test('normalizzazione in HH:MM', () {
      expect(normalizzaOrarioNotifiche('21:15'), '21:15');
      expect(normalizzaOrarioNotifiche(' 09:05 '), '09:05');
      expect(normalizzaOrarioNotifiche(null), '22:00');
      expect(normalizzaOrarioNotifiche(''), '22:00');
      expect(normalizzaOrarioNotifiche('25:00'), '22:00');
    });

    test('la fine del silenzio ricade sulle 08:00', () {
      expect(
        normalizzaOrarioNotifiche(
          'non valido',
          predefinito: orarioSilenzioFinePredefinito,
        ),
        '08:00',
      );
    });
  });

  group('preferenze predefinite', () {
    test('valori di partenza', () {
      const preferenze = PreferenzeNotifiche.predefinite;
      expect(preferenze.push, isTrue);
      expect(preferenze.whatsapp, isFalse);
      expect(preferenze.chat, isTrue);
      expect(preferenze.anteprimaPush, isTrue);
      expect(preferenze.silenzioInizio, '22:00');
      expect(preferenze.silenzioFine, '08:00');
      expect(preferenze.numeroWhatsapp, isEmpty);
      expect(preferenze.consensoWhatsapp, isFalse);
      expect(preferenze.anticipoTaskGiorni, 1);
      expect(preferenze.anticipoPreventivoGiorni, 3);
    });

    test('documento assente usa i default', () {
      final preferenze = PreferenzeNotifiche.daMappa(null);
      expect(preferenze.push, isTrue);
      expect(preferenze.chat, isTrue);
      expect(preferenze.silenzioInizio, '22:00');
      expect(preferenze.silenzioFine, '08:00');
    });

    test('legge i valori salvati e ignora la chat disattivata', () {
      final preferenze = PreferenzeNotifiche.daMappa({
        'canale_push': false,
        'canale_whatsapp': true,
        'canale_chat': false,
        'numero_whatsapp': ' +39 333 1234567 ',
        'consenso_whatsapp': true,
        'silenzio_da': '21:30',
        'silenzio_a': '07:15',
        'urgenze_passano': false,
        'anteprima_push': false,
        'anticipo_task_giorni': 5,
        'anticipo_preventivo_giorni': 7,
      });
      expect(preferenze.push, isFalse);
      expect(preferenze.whatsapp, isTrue);
      expect(preferenze.chat, isTrue);
      expect(preferenze.numeroWhatsapp, '+39 333 1234567');
      expect(preferenze.consensoWhatsapp, isTrue);
      expect(preferenze.silenzioInizio, '21:30');
      expect(preferenze.silenzioFine, '07:15');
      expect(preferenze.urgenzePassano, isFalse);
      expect(preferenze.anteprimaPush, isFalse);
      expect(preferenze.anticipoTaskGiorni, 5);
      expect(preferenze.anticipoPreventivoGiorni, 7);
    });

    test('orari corrotti ricadono sui default', () {
      final preferenze = PreferenzeNotifiche.daMappa({
        'silenzio_da': 'tardi',
        'silenzio_a': '99:99',
      });
      expect(preferenze.silenzioInizio, '22:00');
      expect(preferenze.silenzioFine, '08:00');
    });

    test('la mappa salvata contiene chiavi e orari normalizzati', () {
      const preferenze = PreferenzeNotifiche(
        push: false,
        whatsapp: true,
        numeroWhatsapp: ' 3331234567 ',
        consensoWhatsapp: true,
        silenzioInizio: '',
        silenzioFine: '7',
      );
      final mappa = preferenze.aMappa();
      expect(mappa['canale_push'], isFalse);
      expect(mappa['canale_whatsapp'], isTrue);
      expect(mappa['canale_chat'], isTrue);
      expect(mappa['numero_whatsapp'], '3331234567');
      expect(mappa['consenso_whatsapp'], isTrue);
      expect(mappa['silenzio_da'], '22:00');
      expect(mappa['silenzio_a'], '08:00');
      expect(mappa['anticipo_task_giorni'], 1);
      expect(mappa['anticipo_preventivo_giorni'], 3);
    });
  });

  group('widget', () {
    testWidgets('mostra le sezioni e i campi principali', (tester) async {
      await tester.pumpWidget(_Harness(onSalva: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Notifiche sul dispositivo'), findsOneWidget);
      expect(find.byKey(const Key('notifiche-push-attiva')), findsOneWidget);
      expect(find.byKey(const Key('notifiche-push-disattiva')), findsOneWidget);
      expect(find.text('Canali'), findsOneWidget);
      expect(find.text('WhatsApp'), findsWidgets);
      expect(find.text('Orari di silenzio'), findsOneWidget);
      expect(find.text('Anticipo degli avvisi'), findsOneWidget);
      expect(
        find.byKey(const Key('notifiche-anticipo-task')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notifiche-anticipo-preventivo')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('notifiche-push')), findsOneWidget);
      expect(find.byKey(const Key('notifiche-whatsapp')), findsOneWidget);
      expect(find.byKey(const Key('notifiche-chat')), findsOneWidget);
      expect(
        find.byKey(const Key('notifiche-numero-whatsapp')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notifiche-consenso-whatsapp')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('notifiche-whatsapp-salva')), findsOneWidget);
      expect(
        find.byKey(const Key('notifiche-silenzio-inizio')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('notifiche-silenzio-fine')), findsOneWidget);
      expect(find.byKey(const Key('notifiche-urgenze')), findsOneWidget);
      expect(find.byKey(const Key('notifiche-anteprima')), findsOneWidget);
      expect(find.byKey(const Key('notifiche-salva')), findsOneWidget);
    });

    testWidgets('la chat è mostrata come sempre attiva', (tester) async {
      await tester.pumpWidget(_Harness(onSalva: () {}));
      await tester.pumpAndSettle();

      final chat = tester.widget<SwitchListTile>(
        find.byKey(const Key('notifiche-chat')),
      );
      expect(chat.value, isTrue);
      expect(chat.onChanged, isNull);
    });

    testWidgets('mostra gli orari salvati', (tester) async {
      await tester.pumpWidget(
        _Harness(
          onSalva: () {},
          iniziali: const PreferenzeNotifiche(
            push: false,
            silenzioInizio: '21:00',
            silenzioFine: '07:00',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final push = tester.widget<SwitchListTile>(
        find.byKey(const Key('notifiche-push')),
      );
      expect(push.value, isFalse);

      final inizio = tester.widget<TextField>(
        find.byKey(const Key('notifiche-silenzio-inizio')),
      );
      final fine = tester.widget<TextField>(
        find.byKey(const Key('notifiche-silenzio-fine')),
      );
      expect(inizio.controller?.text, '21:00');
      expect(fine.controller?.text, '07:00');
    });

    testWidgets('mostra gli orari predefiniti', (tester) async {
      await tester.pumpWidget(_Harness(onSalva: () {}));
      await tester.pumpAndSettle();

      final inizio = tester.widget<TextField>(
        find.byKey(const Key('notifiche-silenzio-inizio')),
      );
      final fine = tester.widget<TextField>(
        find.byKey(const Key('notifiche-silenzio-fine')),
      );
      expect(inizio.controller?.text, '22:00');
      expect(fine.controller?.text, '08:00');
    });

    testWidgets('modifica il numero e il consenso WhatsApp', (tester) async {
      PreferenzeNotifiche? ultime;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: _CorpoConStato(
              onCambia: (preferenze) => ultime = preferenze,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('notifiche-numero-whatsapp')),
        '+39 333 1234567',
      );
      await tester.pumpAndSettle();
      expect(ultime?.numeroWhatsapp, '+39 333 1234567');

      await tester.ensureVisible(
        find.byKey(const Key('notifiche-consenso-whatsapp')),
      );
      await tester.tap(find.byKey(const Key('notifiche-consenso-whatsapp')));
      await tester.pumpAndSettle();
      expect(ultime?.consensoWhatsapp, isTrue);
    });

    testWidgets('il pulsante Salva chiama il salvataggio', (tester) async {
      var salvataggi = 0;
      await tester.pumpWidget(_Harness(onSalva: () => salvataggi++));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('notifiche-salva')));
      await tester.tap(find.byKey(const Key('notifiche-salva')));
      await tester.pumpAndSettle();

      expect(salvataggi, 1);
    });

    testWidgets('caricamento mostra il progresso', (tester) async {
      await tester.pumpWidget(
        _Harness(onSalva: () {}, caricamento: true),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('notifiche-preferenze-caricamento')),
        findsOneWidget,
      );
    });

    testWidgets('errore mostra Riprova', (tester) async {
      var riprove = 0;
      await tester.pumpWidget(
        _Harness(
          onSalva: () {},
          errore: Exception('rete'),
          onRiprova: () => riprove++,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notifiche-preferenze-errore')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('notifiche-preferenze-riprova')),
      );
      await tester.pumpAndSettle();
      expect(riprove, 1);
    });
  });
}

/// Corpo con stato minimo che riporta ogni modifica al test.
class _CorpoConStato extends StatefulWidget {
  const _CorpoConStato({required this.onCambia});

  final ValueChanged<PreferenzeNotifiche> onCambia;

  @override
  State<_CorpoConStato> createState() => _CorpoConStatoState();
}

class _CorpoConStatoState extends State<_CorpoConStato> {
  PreferenzeNotifiche _preferenze = PreferenzeNotifiche.predefinite;

  @override
  Widget build(BuildContext context) {
    return CorpoNotifichePreferenze(
      preferenze: _preferenze,
      onModifica: (preferenze) {
        setState(() => _preferenze = preferenze);
        widget.onCambia(preferenze);
      },
      onRiprova: () {},
      onSalva: () {},
    );
  }
}
