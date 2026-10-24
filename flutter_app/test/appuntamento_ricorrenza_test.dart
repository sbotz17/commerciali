import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/appuntamento.dart';
import 'package:commerciali_app/data/services/sp_service.dart';
import 'package:commerciali_app/features/calendario/calendario_screen.dart';

void main() {
  Appuntamento appuntamento({
    String id = 'a1',
    String? data = '2026-10-05',
    String? ora = '09:00',
    String? dataFine,
    String? oraFine,
    bool tuttoIlGiorno = false,
    Map<String, dynamic> ripetizione = const {'tipo': 'mai'},
    bool privato = false,
    String? createdBy,
    String? operatoreId,
  }) {
    return Appuntamento(
      id: id,
      titolo: 'Visita',
      data: data,
      ora: ora,
      dataFine: dataFine,
      oraFine: oraFine,
      tuttoIlGiorno: tuttoIlGiorno,
      ripetizione: ripetizione,
      privato: privato,
      createdBy: createdBy,
      operatoreId: operatoreId,
      durataMin: 60,
    );
  }

  group('inizio e fine', () {
    test('usa ora di inizio e fine esplicite', () {
      final a = appuntamento(
        data: '2026-10-05',
        ora: '09:15',
        dataFine: '2026-10-05',
        oraFine: '11:00',
      );

      expect(inizioAppuntamento(a), DateTime(2026, 10, 5, 9, 15));
      expect(fineAppuntamento(a), DateTime(2026, 10, 5, 11, 0));
      expect(durataEffettivaAppuntamento(a), 105);
    });

    test('senza ora di fine usa la durata', () {
      final a = appuntamento(ora: '09:00');
      expect(durataEffettivaAppuntamento(a), 60);
    });

    test('tutto il giorno dura 24 ore', () {
      final a = appuntamento(
        ora: null,
        tuttoIlGiorno: true,
        dataFine: '2026-10-05',
      );
      expect(durataEffettivaAppuntamento(a), 1440);
      expect(fineAppuntamento(a), DateTime(2026, 10, 6));
    });
  });

  group('occorrenze', () {
    final dal = DateTime(2026, 10, 1);
    final al = DateTime(2026, 11, 30);

    test('mai restituisce solo la data originale', () {
      final a = appuntamento();
      expect(occorrenzeAppuntamento(a, dal: dal, al: al), [
        DateTime(2026, 10, 5),
      ]);
      expect(
        occorrenzeAppuntamento(a, dal: DateTime(2026, 11, 1), al: al),
        isEmpty,
      );
    });

    test('ogni giorno', () {
      final a = appuntamento(
        ripetizione: const {'tipo': ripetizioneGiornaliera},
      );
      final giorni = occorrenzeAppuntamento(
        a,
        dal: DateTime(2026, 10, 4),
        al: DateTime(2026, 10, 7),
      );
      expect(giorni, [
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 6),
        DateTime(2026, 10, 7),
      ]);
    });

    test('ogni settimana con giorni scelti', () {
      final a = appuntamento(
        ripetizione: const {
          'tipo': ripetizioneSettimanale,
          'giorni_settimana': [1, 3],
        },
      );
      final giorni = occorrenzeAppuntamento(
        a,
        dal: DateTime(2026, 10, 5),
        al: DateTime(2026, 10, 18),
      );
      expect(giorni, [
        DateTime(2026, 10, 5), // lunedì
        DateTime(2026, 10, 7), // mercoledì
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 14),
      ]);
    });

    test('ogni due settimane', () {
      final a = appuntamento(
        ripetizione: const {
          'tipo': ripetizioneBisettimanale,
          'giorni_settimana': [1],
        },
      );
      expect(
        occorrenzeAppuntamento(
          a,
          dal: DateTime(2026, 10, 5),
          al: DateTime(2026, 10, 26),
        ),
        [DateTime(2026, 10, 5), DateTime(2026, 10, 19)],
      );
    });

    test('ogni mese', () {
      final a = appuntamento(
        data: '2026-01-31',
        ripetizione: const {'tipo': ripetizioneMensile},
      );
      expect(
        occorrenzeAppuntamento(
          a,
          dal: DateTime(2026, 1, 1),
          al: DateTime(2026, 3, 31),
        ),
        [DateTime(2026, 1, 31), DateTime(2026, 3, 31)],
      );
    });

    test('ogni anno', () {
      final a = appuntamento(
        data: '2026-02-28',
        ripetizione: const {'tipo': ripetizioneAnnuale},
      );
      expect(
        occorrenzeAppuntamento(
          a,
          dal: DateTime(2026, 1, 1),
          al: DateTime(2028, 12, 31),
        ),
        [DateTime(2026, 2, 28), DateTime(2027, 2, 28), DateTime(2028, 2, 28)],
      );
    });

    test('personalizzata ogni due settimane', () {
      final a = appuntamento(
        ripetizione: const {
          'tipo': ripetizionePersonalizzata,
          'giorni_settimana': [5],
          'intervallo_settimane': 2,
        },
      );
      expect(
        occorrenzeAppuntamento(
          a,
          dal: DateTime(2026, 10, 1),
          al: DateTime(2026, 10, 31),
        ),
        [DateTime(2026, 10, 9), DateTime(2026, 10, 23)],
      );
    });
  });

  group('notifica', () {
    test('etichette', () {
      expect(etichettaNotificaAppuntamento(null), 'Nessuna');
      expect(etichettaNotificaAppuntamento(0), 'All\'ora dell\'evento');
      expect(etichettaNotificaAppuntamento(15), '15 minuti prima');
    });
  });

  group('privacy', () {
    final privato = appuntamento(
      privato: true,
      createdBy: 'andrea',
      operatoreId: 'simone',
    );

    test('creatore e operatore vedono i dettagli', () {
      expect(puoVedereDettagliAppuntamento(privato, 'andrea'), isTrue);
      expect(puoVedereDettagliAppuntamento(privato, 'simone'), isTrue);
    });

    test('gli altri non vedono i dettagli', () {
      expect(puoVedereDettagliAppuntamento(privato, 'altro'), isFalse);
      expect(puoVedereDettagliAppuntamento(privato, null), isFalse);
      expect(puoVedereDettagliAppuntamento(appuntamento(), 'altro'), isTrue);
    });

    test('titolo e dettaglio vengono mascherati', () {
      final elemento = elementiDaAppuntamenti([privato]).single;
      expect(titoloVisibileElemento(elemento, 'altro'), 'Impegno privato');
      expect(titoloVisibileElemento(elemento, 'andrea'), 'Visita');
      expect(dettaglioVisibileElemento(elemento, const {}, 'altro'), '—');
    });
  });

  group('redazione privacy', () {
    test('il documento principale non contiene i dettagli', () {
      final payload = {
        'titolo': 'Visita riservata',
        'cliente_nome': 'ACME',
        'luogo': 'Sede',
        'indirizzo': 'Via Roma 1',
        'note': 'Segreto',
        'call_url': 'https://meet.example.com/abc',
        'data': '2026-10-05',
        'privato': true,
      };
      final principale = redigiAppuntamentoPrivato(payload);
      final dettagli = dettagliPrivatiAppuntamento(payload);

      expect(principale['titolo'], 'Impegno privato');
      expect(principale['luogo'], isNull);
      expect(principale['indirizzo'], isNull);
      expect(principale['note'], isNull);
      expect(principale['call_url'], isNull);
      expect(dettagli['titolo'], 'Visita riservata');
      expect(dettagli['luogo'], 'Sede');
      expect(dettagli['note'], 'Segreto');
    });
  });

  group('espansione nel calendario', () {
    test('elementiDaAppuntamenti genera le occorrenze nel periodo', () {
      final a = appuntamento(
        ripetizione: const {'tipo': ripetizioneGiornaliera},
      );
      final elementi = elementiDaAppuntamenti(
        [a],
        dal: DateTime(2026, 10, 4),
        al: DateTime(2026, 10, 6),
      );
      expect(elementi.map((elemento) => elemento.data), [
        '2026-10-05',
        '2026-10-06',
      ]);
    });

    testWidgets('la griglia nasconde il titolo degli appuntamenti privati', (
      tester,
    ) async {
      final privato = appuntamento(
        privato: true,
        createdBy: 'andrea',
        operatoreId: 'simone',
      );
      final elementi = elementiDaAppuntamenti([privato]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: VistaGrigliaOraria(
                giorni: [DateTime(2026, 10, 5)],
                elementi: elementi,
                uidCorrente: 'altro',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Impegno privato'), findsOneWidget);
      expect(find.text('Visita'), findsNothing);
    });
  });
}
