import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/features/clienti/clienti_screen.dart';

/// Test delle validazioni del form clienti (funzioni pure) e del form stesso.
///
/// La lista non viene montata nei test: legge `SpService`, che richiede
/// Firebase. Il form invece non legge provider finché la validazione non passa,
/// quindi si può verificare senza servizi esterni.
void main() {
  group('validaNomeCliente', () {
    test('null restituisce un errore', () {
      expect(validaNomeCliente(null), 'Inserisci il nome del cliente');
    });

    test('stringa vuota restituisce un errore', () {
      expect(validaNomeCliente(''), 'Inserisci il nome del cliente');
    });

    test('solo spazi restituisce un errore', () {
      expect(validaNomeCliente('   '), 'Inserisci il nome del cliente');
    });

    test('un nome valido supera la validazione', () {
      expect(validaNomeCliente('Acme S.r.l.'), isNull);
    });

    test('gli spazi esterni vengono ignorati', () {
      expect(validaNomeCliente('  Acme  '), isNull);
    });
  });

  group('validaPivaCliente', () {
    test('P.IVA assente è ammessa', () {
      expect(validaPivaCliente(null), isNull);
      expect(validaPivaCliente(''), isNull);
      expect(validaPivaCliente('   '), isNull);
      expect(validaPivaCliente('IT'), isNull);
    });

    test('11 cifre sono valide', () {
      expect(validaPivaCliente('12345678901'), isNull);
    });

    test('il prefisso IT viene accettato', () {
      expect(validaPivaCliente('IT12345678901'), isNull);
      expect(validaPivaCliente('it12345678901'), isNull);
    });

    test('gli spazi esterni vengono ignorati', () {
      expect(validaPivaCliente('  12345678901  '), isNull);
    });

    test('meno di 11 cifre è un errore', () {
      expect(validaPivaCliente('123'), 'La P.IVA deve avere 11 cifre');
    });

    test('più di 11 cifre è un errore', () {
      expect(validaPivaCliente('123456789012'), 'La P.IVA deve avere 11 cifre');
    });

    test('lettere sono un errore', () {
      expect(validaPivaCliente('ABCDEFGHIJK'), 'La P.IVA deve avere 11 cifre');
    });
  });

  group('messaggioErroreClienti', () {
    test('permessi mancanti', () {
      expect(
        messaggioErroreClienti(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        'Non hai i permessi per gestire i clienti. Contatta l\'amministratore.',
      );
    });

    test('connessione assente', () {
      expect(
        messaggioErroreClienti(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        'Connessione assente. Controlla la rete e riprova.',
      );
    });

    test('sessione scaduta', () {
      expect(
        messaggioErroreClienti(
          FirebaseException(plugin: 'firebase_auth', code: 'unauthenticated'),
        ),
        'Sessione scaduta. Accedi di nuovo e riprova.',
      );
    });

    test('errore non Firebase', () {
      expect(
        messaggioErroreClienti(Exception('rete assente')),
        'Operazione non riuscita. Controlla la connessione e riprova.',
      );
    });
  });

  group('ClienteFormScreen', () {
    Future<void> apriForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ClienteFormScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> premiSalva(WidgetTester tester) async {
      final salva = find.byKey(const Key('salva-cliente'));
      await tester.ensureVisible(salva);
      await tester.pumpAndSettle();
      await tester.tap(salva);
      await tester.pumpAndSettle();
    }

    testWidgets('mostra le sezioni e i campi del form', (tester) async {
      await apriForm(tester);

      expect(find.text('Nuovo cliente'), findsOneWidget);
      expect(find.text('ANAGRAFICA'), findsOneWidget);
      expect(find.text('SEDE LEGALE'), findsOneWidget);
      expect(find.text('CONTATTI'), findsOneWidget);
      expect(find.text('ATTIVITÀ'), findsOneWidget);
      expect(find.byKey(const Key('cliente-nome')), findsOneWidget);
      expect(find.byKey(const Key('cliente-piva')), findsOneWidget);
      expect(find.byKey(const Key('cliente-regione')), findsOneWidget);
      expect(find.byKey(const Key('cliente-settore')), findsOneWidget);
      expect(find.byKey(const Key('cliente-note')), findsOneWidget);
    });

    testWidgets('il nome vuoto blocca il salvataggio', (tester) async {
      await apriForm(tester);
      await premiSalva(tester);

      expect(find.text('Inserisci il nome del cliente'), findsOneWidget);
    });

    testWidgets('una P.IVA non valida mostra l\'errore', (tester) async {
      await apriForm(tester);

      await tester.ensureVisible(find.byKey(const Key('cliente-piva')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('cliente-piva')),
        '123',
      );
      await premiSalva(tester);
      await tester.ensureVisible(find.byKey(const Key('cliente-piva')));
      await tester.pumpAndSettle();

      expect(find.text('La P.IVA deve avere 11 cifre'), findsOneWidget);
    });
  });
}
