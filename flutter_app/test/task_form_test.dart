import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/task_item.dart';
import 'package:commerciali_app/features/task/task_form_screen.dart';

/// Test delle funzioni pure del form task e del form stesso.
///
/// Il form, in test, non trova Firebase inizializzato: il caricamento di
/// clienti e utenti fallisce senza rompere la schermata, che resta visibile
/// con i campi e l'avviso d'errore. Il salvataggio non viene mai eseguito
/// davvero.
void main() {
  group('validaTitoloTask', () {
    test('null restituisce un errore', () {
      expect(validaTitoloTask(null), 'Inserisci il titolo del task');
    });

    test('stringa vuota restituisce un errore', () {
      expect(validaTitoloTask(''), 'Inserisci il titolo del task');
    });

    test('solo spazi restituisce un errore', () {
      expect(validaTitoloTask('   '), 'Inserisci il titolo del task');
    });

    test('un titolo valido supera la validazione', () {
      expect(validaTitoloTask('Richiamare Acme'), isNull);
    });

    test('gli spazi esterni vengono ignorati', () {
      expect(validaTitoloTask('  Richiamare Acme  '), isNull);
    });
  });

  group('validaDataTask', () {
    test('data assente o vuota è ammessa (campo facoltativo)', () {
      expect(validaDataTask(null), isNull);
      expect(validaDataTask(''), isNull);
      expect(validaDataTask('   '), isNull);
    });

    test('data italiana valida supera la validazione', () {
      expect(validaDataTask('24/10/2026'), isNull);
      expect(validaDataTask('01/01/2026'), isNull);
    });

    test('formato ISO e testo libero sono rifiutati', () {
      expect(validaDataTask('2026-10-24'), isNotNull);
      expect(validaDataTask('domani'), isNotNull);
      expect(validaDataTask('24/10'), isNotNull);
    });

    test('un giorno inesistente è un errore', () {
      expect(validaDataTask('31/02/2026'), isNotNull);
      expect(validaDataTask('32/01/2026'), isNotNull);
    });
  });

  group('etichettaPrioritaTaskForm', () {
    test('urgente restituisce Urgente', () {
      expect(etichettaPrioritaTaskForm('urgente'), 'Urgente');
      expect(etichettaPrioritaTaskForm('  URGENTE  '), 'Urgente');
    });

    test('normale, vuoto o assente ricadono su Normale', () {
      expect(etichettaPrioritaTaskForm('normale'), 'Normale');
      expect(etichettaPrioritaTaskForm(''), 'Normale');
      expect(etichettaPrioritaTaskForm(null), 'Normale');
      expect(etichettaPrioritaTaskForm('altro'), 'Normale');
    });
  });

  group('TaskFormScreen', () {
    Future<void> apriForm(WidgetTester tester, {TaskItem? task}) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: TaskFormScreen(task: task)),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> premiSalva(WidgetTester tester) async {
      final salva = find.byKey(const Key('salva-task'));
      await tester.ensureVisible(salva);
      await tester.pumpAndSettle();
      await tester.tap(salva);
      await tester.pumpAndSettle();
    }

    testWidgets('mostra tutti i campi del nuovo task', (tester) async {
      await apriForm(tester);

      expect(find.text('Nuovo task'), findsOneWidget);
      for (final chiave in [
        'task-titolo',
        'task-descrizione',
        'task-scadenza-data',
        'task-scadenza-ora',
        'task-operatore',
        'task-priorita',
        'task-cliente',
        'task-note',
      ]) {
        expect(find.byKey(Key(chiave)), findsOneWidget, reason: chiave);
      }
    });

    testWidgets('la priorità predefinita è Normale', (tester) async {
      await apriForm(tester);

      final campo = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('task-priorita')),
      );
      expect(campo.initialValue, 'normale');
      expect(find.text('Normale'), findsOneWidget);
    });

    testWidgets('il titolo vuoto blocca il salvataggio', (tester) async {
      await apriForm(tester);
      await premiSalva(tester);

      expect(find.text('Inserisci il titolo del task'), findsOneWidget);
    });

    testWidgets('una data non valida mostra l\'errore', (tester) async {
      await apriForm(tester);

      await tester.enterText(
        find.byKey(const Key('task-titolo')),
        'Richiamare Acme',
      );
      await tester.enterText(
        find.byKey(const Key('task-scadenza-data')),
        '31/02/2026',
      );
      await premiSalva(tester);

      expect(find.text('Inserisci una data valida (gg/mm/aaaa)'), findsOneWidget);
    });

    testWidgets('in assenza di Firebase mostra l\'errore di caricamento',
        (tester) async {
      await apriForm(tester);

      expect(find.byKey(const Key('task-errore-dati')), findsOneWidget);
      expect(find.byKey(const Key('task-riprova')), findsOneWidget);
      expect(find.byKey(const Key('task-titolo')), findsOneWidget);
    });

    testWidgets('il salvataggio fallito mostra l\'avviso d\'errore',
        (tester) async {
      await apriForm(tester);

      await tester.enterText(
        find.byKey(const Key('task-titolo')),
        'Richiamare Acme',
      );
      await premiSalva(tester);

      expect(find.byKey(const Key('task-errore')), findsOneWidget);
    });

    testWidgets('in modifica precompila i campi dal task', (tester) async {
      await apriForm(
        tester,
        task: const TaskItem(
          id: 't1',
          titolo: 'Richiamare ACME',
          descrizione: 'Confermare il preventivo',
          scadenzaData: '2026-11-05',
          scadenzaOra: '09:30',
          priorita: 'urgente',
          note: 'Portare il catalogo',
        ),
      );

      expect(find.text('Modifica task'), findsOneWidget);
      expect(find.text('Richiamare ACME'), findsOneWidget);
      expect(find.text('Confermare il preventivo'), findsOneWidget);
      expect(find.text('05/11/2026'), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('Portare il catalogo'), findsOneWidget);
      expect(find.text('Urgente'), findsOneWidget);
    });
  });
}
