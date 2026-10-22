import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/licenza.dart';
import 'package:commerciali_app/features/impostazioni/licenze_screen.dart';

void main() {
  group('etichette licenza', () {
    test('piano noto e sconosciuto', () {
      expect(etichettaPiano('trial'), 'Trial');
      expect(etichettaPiano('base'), 'Base');
      expect(etichettaPiano('enterprise'), 'Enterprise');
      expect(etichettaPiano(''), '—');
    });

    test('stato noto, vuoto e sconosciuto', () {
      expect(etichettaStatoLicenza('attiva'), 'Attiva');
      expect(etichettaStatoLicenza('scaduta'), 'Scaduta');
      expect(etichettaStatoLicenza(''), 'Attiva');
      expect(etichettaStatoLicenza('sospesa'), 'Sospesa');
      expect(etichettaStatoLicenza('altro'), 'altro');
    });
  });

  group('stato effettivo', () {
    test('data di fine passata rende la licenza scaduta', () {
      final licenza = Licenza(
        id: 'a1',
        stato: 'attiva',
        dataFine: '2026-10-01',
      );
      expect(
        statoLicenzaEffettivo(licenza, oggi: DateTime(2026, 10, 22)),
        'scaduta',
      );
    });

    test('data di fine futura lascia lo stato dichiarato', () {
      final licenza = Licenza(
        id: 'a1',
        stato: 'attiva',
        dataFine: '2026-12-31',
      );
      expect(
        statoLicenzaEffettivo(licenza, oggi: DateTime(2026, 10, 22)),
        'attiva',
      );
    });

    test('senza data usa lo stato del modello', () {
      expect(
        statoLicenzaEffettivo(
          const Licenza(id: 'a1', stato: 'trial'),
          oggi: DateTime(2026, 10, 22),
        ),
        'trial',
      );
    });
  });

  group('formati', () {
    test('data italiana e data assente', () {
      expect(formattaDataLicenza('2026-10-22'), '22/10/2026');
      expect(formattaDataLicenza(null), '—');
      expect(formattaDataLicenza('non-data'), '—');
    });

    test('limiti numerici e illimitati', () {
      expect(formattaLimite(null), 'Illimitato');
      expect(formattaLimite(-1), 'Illimitato');
      expect(formattaLimite(0), '0');
      expect(formattaLimite(10), '10');
    });

    test('note con fallback', () {
      expect(noteLicenza(null), 'Nessuna nota');
      expect(noteLicenza('  '), 'Nessuna nota');
      expect(noteLicenza(' Rinnovo a gennaio '), 'Rinnovo a gennaio');
    });
  });

  group('messaggioErroreLicenza', () {
    test('permessi negati spiega il problema', () {
      expect(
        messaggioErroreLicenza(
          FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
        ),
        contains('Non hai i permessi'),
      );
    });

    test('sessione scaduta invita ad accedere', () {
      expect(
        messaggioErroreLicenza(
          FirebaseException(plugin: 'cloud_firestore', code: 'unauthenticated'),
        ),
        contains('Sessione scaduta'),
      );
    });
  });

  testWidgets('CorpoLicenza senza licenza mostra lo stato vuoto', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CorpoLicenza(licenza: null, onRiprova: () {}),
        ),
      ),
    );

    expect(find.byKey(const Key('licenze-vuoto')), findsOneWidget);
    expect(find.text('Nessuna licenza'), findsOneWidget);
  });

  testWidgets('CorpoLicenza mostra la scheda con i dati', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CorpoLicenza(
            licenza: const Licenza(
              id: 'a1',
              piano: 'trial',
              stato: 'attiva',
              dataInizio: '2026-01-01',
              dataFine: '2026-12-31',
              maxUtenti: 5,
              maxPreventivi: 50,
            ),
            onRiprova: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('licenze-scheda')), findsOneWidget);
    expect(find.text('Piano Trial'), findsOneWidget);
    expect(find.text('Attiva'), findsWidgets);
    expect(find.text('01/01/2026'), findsOneWidget);
    expect(find.text('31/12/2026'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
  });
}
