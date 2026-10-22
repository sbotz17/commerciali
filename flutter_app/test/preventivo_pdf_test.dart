import 'package:commerciali_app/data/models/preventivo.dart';
import 'package:commerciali_app/data/services/preventivo_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Preventivo di esempio con righe, sconto e note.
Preventivo preventivoEsempio() {
  return Preventivo(
    id: 'prev-1',
    clienteNome: 'Rossi Srl',
    numero: 'PRV-0001',
    revisione: 0,
    righe: const [
      PreventivoRiga(
        codice: 'SW-001',
        nome: 'Licenza annuale',
        prezzo: 120,
        qty: 2,
        um: 'pz',
        scontoPerc: 10,
        scontoVal: 24,
        ivaPerc: 22,
      ),
      PreventivoRiga(
        nome: 'Installazione',
        prezzo: 250,
        qty: 1,
        ivaPerc: 22,
      ),
    ],
    sconto: 5,
    note: 'Pagamento a 30 giorni.',
    subtotale: 466,
    impSconto: 23.3,
    imponibile: 442.7,
    iva: 97.39,
    totaleIva: 540.09,
    stato: 'inviato',
    createdAt: '2026-10-20T10:00:00.000Z',
  );
}

void main() {
  group('generaPdfPreventivo', () {
    test('genera un PDF non vuoto che inizia con %PDF', () async {
      final byte = await generaPdfPreventivo(preventivo: preventivoEsempio());

      expect(byte, isNotEmpty);
      expect(byte.length, greaterThan(1000));
      expect(
        String.fromCharCodes(byte.take(4)),
        '%PDF',
      );
    });

    test('genera il PDF anche senza righe, note e numero', () async {
      const vuoto = Preventivo(id: 'prev-vuoto');
      final byte = await generaPdfPreventivo(
        preventivo: vuoto,
        nomeAzienda: '',
      );

      expect(byte, isNotEmpty);
      expect(String.fromCharCodes(byte.take(4)), '%PDF');
    });
  });

  group('formati del PDF', () {
    test('importi nel formato italiano', () {
      expect(formattaImportoPdf(1234.5), contains('1.234,50'));
      expect(formattaImportoPdf(0), contains('0,00'));
      expect(formattaImportoPdf(null), '-');
    });

    test('quantità senza decimali inutili', () {
      expect(formattaQuantitaPdf(2), '2');
      expect(formattaQuantitaPdf(1.5), '1,5');
      expect(formattaQuantitaPdf(null), '-');
    });

    test('data italiana con fallback', () {
      expect(formattaDataPdf('2026-10-20T10:00:00.000Z'), '20/10/2026');
      expect(formattaDataPdf(null, adesso: DateTime(2026, 1, 5)), '05/01/2026');
      expect(formattaDataPdf('non una data'), '-');
    });

    test('nome file dal numero del preventivo', () {
      expect(nomeFilePdfPreventivo(preventivoEsempio()), 'PRV-0001');
      expect(nomeFilePdfPreventivo(const Preventivo(id: 'x')), 'preventivo');
      expect(
        nomeFilePdfPreventivo(
          const Preventivo(id: 'x', numero: 'PRV/0002 R1'),
        ),
        'PRV-0002-R1',
      );
    });
  });
}
