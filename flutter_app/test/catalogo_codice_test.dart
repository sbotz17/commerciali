import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/categoria.dart';
import 'package:commerciali_app/data/models/prodotto.dart';
import 'package:commerciali_app/features/catalogo/catalogo_screen.dart';

/// Verifica il codice prodotto: formattazione per gli elenchi e campo nel form.
///
/// Il form non legge provider Firebase in fase di build: si può montare senza
/// servizi esterni, passando categorie e prodotti come parametri.
void main() {
  group('codiceVisualizzatoProdotto', () {
    test('mostra il codice quando presente', () {
      const prodotto = Prodotto(id: 'p1', nome: 'Licenza', codice: 'PRD-001');
      expect(codiceVisualizzatoProdotto(prodotto), 'PRD-001');
    });

    test('usa il segnaposto quando il codice manca', () {
      const senzaCodice = Prodotto(id: 'p1', nome: 'Licenza');
      expect(codiceVisualizzatoProdotto(senzaCodice), '—');

      const vuoto = Prodotto(id: 'p1', nome: 'Licenza', codice: '');
      expect(codiceVisualizzatoProdotto(vuoto), '—');
    });

    test('ignora gli spazi attorno al codice', () {
      const conSpazi = Prodotto(id: 'p1', nome: 'Licenza', codice: '  PRD-007  ');
      expect(codiceVisualizzatoProdotto(conSpazi), 'PRD-007');

      const soloSpazi = Prodotto(id: 'p1', nome: 'Licenza', codice: '   ');
      expect(codiceVisualizzatoProdotto(soloSpazi), '—');
    });
  });

  group('ProdottoFormScreen', () {
    const categoria = Categoria(id: 'c1', nome: 'Software');

    Future<void> monta(WidgetTester tester, {Prodotto? prodotto}) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: ProdottoFormScreen(
              prodotto: prodotto,
              categorie: const [categoria],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('mostra il campo codice prodotto', (tester) async {
      await monta(tester);

      final campo = find.byKey(const Key('prodotto-codice'));
      expect(campo, findsOneWidget);
      expect(find.text('Codice prodotto'), findsOneWidget);

      // Il campo sta dopo il nome: stessa card, ordine di lettura.
      final yNome = tester.getTopLeft(find.byKey(const Key('prodotto-nome'))).dy;
      expect(tester.getTopLeft(campo).dy, greaterThan(yNome));
    });

    testWidgets('precompila il codice in modifica', (tester) async {
      await monta(
        tester,
        prodotto: const Prodotto(
          id: 'p1',
          nome: 'Licenza',
          codice: 'PRD-001',
        ),
      );

      final campo = tester.widget<TextFormField>(
        find.byKey(const Key('prodotto-codice')),
      );
      expect(campo.controller?.text, 'PRD-001');
    });
  });
}
