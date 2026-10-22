import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/categoria.dart';
import 'package:commerciali_app/data/models/prodotto.dart';

void main() {
  group('Prodotto.fromMap', () {
    test('legge tutti i campi', () {
      final prodotto = Prodotto.fromMap({
        'azienda_id': 'az-1',
        'nome': 'Licenza software',
        'categoria': 'software',
        'prezzo': 120.50,
        'descrizione': 'Licenza annuale',
        'immagine': 'https://example.com/soft.png',
        'attivo': false,
      }, id: 'p-1');

      expect(prodotto.id, 'p-1');
      expect(prodotto.aziendaId, 'az-1');
      expect(prodotto.nome, 'Licenza software');
      expect(prodotto.categoria, 'software');
      expect(prodotto.prezzo, 120.50);
      expect(prodotto.descrizione, 'Licenza annuale');
      expect(prodotto.immagine, 'https://example.com/soft.png');
      expect(prodotto.attivo, isFalse);
    });

    test('prezzo intero resta num', () {
      final prodotto = Prodotto.fromMap({'prezzo': 100}, id: 'p-2');

      expect(prodotto.prezzo, 100);
      expect(prodotto.prezzo, isA<num>());
    });

    test('default: campi assenti valgono null, attivo true', () {
      final prodotto = Prodotto.fromMap({}, id: 'p-1');

      expect(prodotto.id, 'p-1');
      expect(prodotto.aziendaId, isNull);
      expect(prodotto.nome, isNull);
      expect(prodotto.categoria, isNull);
      expect(prodotto.prezzo, isNull);
      expect(prodotto.descrizione, isNull);
      expect(prodotto.immagine, isNull);
      expect(prodotto.attivo, isTrue);
    });

    test('toMap serializza in snake_case senza id', () {
      final prodotto = Prodotto(
        id: 'p-1',
        aziendaId: 'az-1',
        nome: 'Licenza software',
        categoria: 'software',
        prezzo: 120.50,
        descrizione: 'Licenza annuale',
        immagine: 'https://example.com/soft.png',
        attivo: false,
      );

      final map = prodotto.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['azienda_id'], 'az-1');
      expect(map['nome'], 'Licenza software');
      expect(map['categoria'], 'software');
      expect(map['prezzo'], 120.50);
      expect(map['descrizione'], 'Licenza annuale');
      expect(map['immagine'], 'https://example.com/soft.png');
      expect(map['attivo'], isFalse);
    });
  });

  group('Categoria.fromMap', () {
    test('legge tutti i campi', () {
      final categoria = Categoria.fromMap({
        'azienda_id': 'az-1',
        'nome': 'software',
        'icona': '💻',
        'ordine': 2,
      }, id: 'cat-1');

      expect(categoria.id, 'cat-1');
      expect(categoria.aziendaId, 'az-1');
      expect(categoria.nome, 'software');
      expect(categoria.icona, '💻');
      expect(categoria.ordine, 2);
    });

    test('ordine numerico (double) è convertito a int', () {
      final categoria = Categoria.fromMap({'ordine': 3.0}, id: 'cat-1');

      expect(categoria.ordine, 3);
      expect(categoria.ordine, isA<int>());
    });

    test('default: campi assenti valgono null', () {
      final categoria = Categoria.fromMap({}, id: 'cat-1');

      expect(categoria.id, 'cat-1');
      expect(categoria.aziendaId, isNull);
      expect(categoria.nome, isNull);
      expect(categoria.icona, isNull);
      expect(categoria.ordine, isNull);
    });

    test('toMap serializza in snake_case senza id', () {
      final categoria = Categoria(
        id: 'cat-1',
        aziendaId: 'az-1',
        nome: 'software',
        icona: '💻',
        ordine: 2,
      );

      final map = categoria.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['azienda_id'], 'az-1');
      expect(map['nome'], 'software');
      expect(map['icona'], '💻');
      expect(map['ordine'], 2);
    });
  });
}
