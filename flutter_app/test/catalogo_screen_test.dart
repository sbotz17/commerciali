import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/features/catalogo/catalogo_screen.dart';

void main() {
  group('validaNomeProdotto', () {
    test('vuoto o spazi è un errore', () {
      expect(validaNomeProdotto(null), 'Inserisci il nome del prodotto');
      expect(validaNomeProdotto('   '), 'Inserisci il nome del prodotto');
    });

    test('un nome valido passa', () {
      expect(validaNomeProdotto('Quadro elettrico'), isNull);
    });
  });

  group('prezzoDaTesto', () {
    test('vuoto restituisce null', () {
      expect(prezzoDaTesto(''), isNull);
      expect(prezzoDaTesto(null), isNull);
    });

    test('accetta virgola e punto', () {
      expect(prezzoDaTesto('120,50'), 120.5);
      expect(prezzoDaTesto('120.50'), 120.5);
      expect(prezzoDaTesto('1.234,50'), 1234.5);
    });

    test('testo non numerico restituisce null', () {
      expect(prezzoDaTesto('abc'), isNull);
    });
  });

  group('validaPrezzo', () {
    test('vuoto è ammesso', () {
      expect(validaPrezzo(''), isNull);
    });

    test('numero valido', () {
      expect(validaPrezzo('0'), isNull);
      expect(validaPrezzo('120,50'), isNull);
    });

    test('negativo è un errore', () {
      expect(validaPrezzo('-1'), 'Il prezzo non può essere negativo');
    });

    test('non numerico è un errore', () {
      expect(validaPrezzo('abc'), 'Inserisci un prezzo valido, es. 120,50');
    });
  });

  group('validaNomeCategoria', () {
    test('vuoto è un errore', () {
      expect(validaNomeCategoria(''), 'Inserisci il nome della categoria');
    });

    test('nome valido', () {
      expect(validaNomeCategoria('Servizi'), isNull);
    });
  });

  group('formattaPrezzo', () {
    test('formato italiano', () {
      expect(formattaPrezzo(1234.5), contains('1.234,50'));
    });

    test('assente mostra il trattino', () {
      expect(formattaPrezzo(null), '—');
    });
  });
}
