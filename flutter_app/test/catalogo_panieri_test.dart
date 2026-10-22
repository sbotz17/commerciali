import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/core/theme/app_theme.dart';
import 'package:commerciali_app/data/models/categoria.dart';
import 'package:commerciali_app/data/models/prodotto.dart';
import 'package:commerciali_app/features/catalogo/catalogo_screen.dart';

/// Verifica la sezione "Paniere (sotto-prodotti)" del form prodotto.
///
/// Il form non legge provider Firebase in fase di build: si può montare senza
/// servizi esterni, passando i prodotti disponibili come parametro.
void main() {
  const categoria = Categoria(id: 'c1', nome: 'Software');

  const prodotti = <Prodotto>[
    Prodotto(
      id: 'p1',
      nome: 'Paniere base',
      categoria: 'Software',
      prezzo: 100,
    ),
    Prodotto(
      id: 'p2',
      nome: 'Licenza extra',
      categoria: 'Software',
      prezzo: 20,
    ),
  ];

  Future<void> monta(WidgetTester tester, {Prodotto? prodotto}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: ProdottoFormScreen(
            prodotto: prodotto,
            categorie: const [categoria],
            prodotti: prodotti,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra la sezione paniere con switch e contatore', (
    tester,
  ) async {
    await monta(tester, prodotto: prodotti.first);

    expect(find.byKey(const Key('prodotto-paniere')), findsOneWidget);
    expect(find.text('Paniere (sotto-prodotti)'), findsOneWidget);
    expect(find.byKey(const Key('prodotto-figlio-p2')), findsOneWidget);
    expect(find.byKey(const Key('prodotto-figli-a-zero')), findsOneWidget);
    expect(find.text('Selezionati: 0'), findsOneWidget);
  });

  testWidgets('selezionando un figlio il contatore sale a 1', (tester) async {
    await monta(tester, prodotto: prodotti.first);

    final casella = find.byKey(const Key('prodotto-figlio-p2'));
    await tester.ensureVisible(casella);
    await tester.tap(casella);
    await tester.pumpAndSettle();

    expect(find.text('Selezionati: 1'), findsOneWidget);
  });

  testWidgets('il prodotto corrente non compare tra i figli', (tester) async {
    await monta(tester, prodotto: prodotti.first);

    expect(find.byKey(const Key('prodotto-figlio-p1')), findsNothing);
  });
}
