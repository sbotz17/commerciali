import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/preventivo.dart';
import 'package:commerciali_app/features/preventivi/preventivo_edit_screen.dart';

void main() {
  group('testoNumeroPreventivo', () {
    test('vuoto o null', () {
      expect(testoNumeroPreventivo(null), '');

    });

    test('interi e decimali italiani', () {
      expect(testoNumeroPreventivo(12), '12');
      expect(testoNumeroPreventivo(12.5), '12,5');
    });
  });

  group('scontoGlobaleEuroDaPercentuale', () {
    test('calcola lo sconto', () {
      expect(scontoGlobaleEuroDaPercentuale(100, 10), 10);
    });

    test('limita la percentuale tra 0 e 100', () {
      expect(scontoGlobaleEuroDaPercentuale(100, 150), 100);
      expect(scontoGlobaleEuroDaPercentuale(100, -5), 0);
    });
  });

  group('rigaPreventivoDaCampi', () {
    test('calcola totale riga con IVA di default', () {
      final riga = rigaPreventivoDaCampi(
        nome: 'Quadro elettrico',
        quantita: '2',
        prezzo: '100',
        scontoPerc: '0',
      );
      expect(riga.nome, 'Quadro elettrico');
      expect(riga.qty, 2);
      expect(riga.prezzo, 100);
      expect(riga.ivaPerc, 22);
      expect(totaleRiga(riga), 200);
    });

    test('IVA zero esplicito resta zero', () {
      final riga = rigaPreventivoDaCampi(
        nome: 'Esente',
        quantita: '1',
        prezzo: '50',
        ivaPerc: '0',
      );
      expect(riga.ivaPerc, 0);
    });
  });

  group('totaliEditorPreventivo', () {
    test('subtotale, IVA e totale', () {
      final righe = [
        rigaPreventivoDaCampi(
          nome: 'Voce',
          quantita: '2',
          prezzo: '100',
          scontoPerc: '0',
        ),
      ];
      final totali = totaliEditorPreventivo(righe);
      expect(totali.subtotale, 200);
      expect(totali.iva, 0);
      expect(totali.totaleIva, 200);
    });

    test('sconto generale in percentuale', () {
      final righe = [
        rigaPreventivoDaCampi(
          nome: 'Voce',
          quantita: '1',
          prezzo: '100',
          scontoPerc: '0',
        ),
      ];
      final totali = totaliEditorPreventivo(righe, scontoGenerale: '10');
      expect(totali.imponibile, 90);
      expect(totali.totaleIva, 90);
    });
  });
}
