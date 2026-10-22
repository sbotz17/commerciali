import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/ruolo.dart';
import 'package:commerciali_app/features/impostazioni/ruoli_screen.dart';

void main() {
  group('etichette aree permesso', () {
    test('chiavi note tradotte in italiano', () {
      expect(etichettaAreaPermesso('gestione_utenti'), 'Gestione utenti');
      expect(etichettaAreaPermesso('preventivi_propri'), 'Preventivi propri');
    });

    test('chiavi sconosciute diventano leggibili', () {
      expect(etichettaAreaPermesso('note_interne'), 'Note interne');
      expect(etichettaAreaPermesso(''), 'Area');
    });
  });

  group('livelli permesso', () {
    test('traduce i livelli noti', () {
      expect(etichettaLivelloPermesso('lettura'), 'Sola lettura');
      expect(etichettaLivelloPermesso('scrittura'), 'Sola scrittura');
      expect(etichettaLivelloPermesso('entrambi'), 'Lettura e scrittura');
      expect(etichettaLivelloPermesso(null), 'Nessuno');
    });

    test('valori sconosciuti diventano leggibili', () {
      expect(etichettaLivelloPermesso('speciale'), 'Speciale');
    });
  });

  group('etichettePermessi', () {
    test('ordina per etichetta e include il livello', () {
      final righe = etichettePermessi({
        'preventivi_tutti': 'lettura',
        'clienti': 'entrambi',
      });
      expect(righe, ['Clienti: Lettura e scrittura', 'Preventivi di tutti: Sola lettura']);
    });

    test('mappa vuota produce lista vuota', () {
      expect(etichettePermessi(const {}), isEmpty);
    });
  });

  group('riepilogoPermessi', () {
    test('conta i livelli', () {
      expect(
        riepilogoPermessi({
          'clienti': 'entrambi',
          'bandi': 'entrambi',
          'listino': 'lettura',
        }),
        '2 aree in lettura e scrittura · 1 in sola lettura',
      );
    });

    test('senza permessi spiega che non sono configurati', () {
      expect(riepilogoPermessi(const {}), 'Nessun permesso configurato');
    });
  });

  group('descrizione e sconto', () {
    test('descrizione assente ha fallback', () {
      expect(
        descrizioneRuolo(const Ruolo(id: 'r1', nome: 'Admin')),
        'Nessuna descrizione',
      );
    });

    test('descrizione presente viene ripulita', () {
      expect(
        descrizioneRuolo(const Ruolo(id: 'r1', nome: 'Admin', descrizione: ' Accesso completo ')),
        'Accesso completo',
      );
    });

    test('sconto zero e sconto positivo', () {
      expect(etichettaScontoMassimo(0), 'Nessuno sconto');
      expect(etichettaScontoMassimo(-5), 'Nessuno sconto');
      expect(etichettaScontoMassimo(20), 'Fino al 20%');
    });
  });

  group('messaggioErroreRuoli', () {
    test('permission-denied spiega il problema', () {
      expect(
        messaggioErroreRuoli(
          FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
        ),
        contains('Non hai i permessi'),
      );
    });

    test('errore di rete invita a riprovare', () {
      expect(
        messaggioErroreRuoli(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        contains('Connessione assente'),
      );
    });
  });

  testWidgets('CorpoRuoli vuoto mostra lo stato dedicato', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: CorpoRuoli(ruoli: [])),
      ),
    );

    expect(find.byKey(const Key('ruoli-vuoto')), findsOneWidget);
    expect(find.text('Nessun ruolo'), findsOneWidget);
  });
}
