// Generazione del PDF di un preventivo (F14).
//
// Il documento usa i font standard del pacchetto `pdf` (Helvetica), quindi non
// richiede asset né rete ed è generabile anche nei test. I testi sono in
// italiano e gli importi seguono il formato italiano (`1.234,56 €`).
//
// I totali stampati sono quelli salvati nel documento (gli stessi mostrati dal
// riepilogo dell'editor), così il PDF non ricalcola nulla e resta identico a
// quanto l'utente vede a schermo.

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/preventivo.dart';

/// Formatta un importo nel formato italiano (`1.234,56 EUR`), `-` se assente.
///
/// Il simbolo `€` non è disponibile nei font standard del pacchetto `pdf`
/// (Helvetica, senza supporto Unicode): si usa quindi `EUR` per non perdere
/// cifre né separatori italiani.
String formattaImportoPdf(num? valore) {
  if (valore == null) return '-';
  return NumberFormat.currency(
    locale: 'it_IT',
    symbol: 'EUR',
    decimalDigits: 2,
  ).format(valore);
}

/// Formatta una quantità senza decimali inutili (`2`, `1,5`).
String formattaQuantitaPdf(num? valore) {
  if (valore == null) return '-';
  final doppio = valore.toDouble();
  if (doppio == doppio.roundToDouble()) return doppio.toInt().toString();
  return NumberFormat('#,##0.##', 'it_IT').format(doppio);
}

/// Data del documento in formato italiano (`22/10/2026`).
///
/// Con [iso] vuoto o assente usa [adesso] (data odierna); con un valore non
/// interpretabile restituisce `-` per non inventare una data.
String formattaDataPdf(String? iso, {DateTime? adesso}) {
  final testo = (iso ?? '').trim();
  final data = testo.isEmpty ? (adesso ?? DateTime.now()) : DateTime.tryParse(testo);
  if (data == null) return '-';
  final giorno = data.day.toString().padLeft(2, '0');
  final mese = data.month.toString().padLeft(2, '0');
  return '$giorno/$mese/${data.year}';
}

/// Nome file (senza estensione) da usare per la condivisione del PDF.
///
/// Usa il numero del preventivo (`PRV-0001`), ripulito dai caratteri non
/// adatti a un nome file; `preventivo` se il numero manca.
String nomeFilePdfPreventivo(Preventivo preventivo) {
  final numero = (preventivo.numero ?? '').trim();
  final base = numero.isEmpty ? 'preventivo' : numero;
  final pulito = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
  return pulito.isEmpty ? 'preventivo' : pulito;
}

/// Messaggio in italiano per un errore di generazione/condivisione del PDF.
String messaggioErrorePdfPreventivo(Object errore) {
  return 'Non è stato possibile generare il PDF del preventivo. '
      'Riprova.';
}

/// Numero mostrato nell'intestazione del PDF.
String numeroVisualizzatoPdf(Preventivo preventivo) {
  final numero = (preventivo.numero ?? '').trim();
  return numero.isEmpty ? '(senza numero)' : numero;
}

// ---------------------------------------------------------------------------
// Costruzione del documento
// ---------------------------------------------------------------------------

/// Genera il PDF di [preventivo] e ne restituisce i byte.
///
/// [nomeAzienda] compare nell'intestazione; se vuoto si usa `Commerciali`.
Future<Uint8List> generaPdfPreventivo({
  required Preventivo preventivo,
  String nomeAzienda = 'Commerciali',
}) async {
  final azienda = nomeAzienda.trim().isEmpty ? 'Commerciali' : nomeAzienda.trim();
  final documento = pw.Document();

  documento.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 32),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      footer: (contesto) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Pagina ${contesto.pageNumber} di ${contesto.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (contesto) => [
        _intestazione(azienda: azienda, preventivo: preventivo),
        pw.SizedBox(height: 16),
        _tabellaRighe(preventivo.righe),
        pw.SizedBox(height: 16),
        _riepilogo(preventivo),
        if ((preventivo.note ?? '').trim().isNotEmpty) ...[
          pw.SizedBox(height: 14),
          _note(preventivo.note!),
        ],
      ],
    ),
  );

  return documento.save();
}

/// Intestazione: azienda a sinistra, dati del documento a destra.
pw.Widget _intestazione({
  required String azienda,
  required Preventivo preventivo,
}) {
  final cliente = (preventivo.clienteNome ?? '').trim();
  final data = formattaDataPdf(preventivo.createdAt);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  azienda,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey900,
                  ),
                ),
                if (preventivo.revisione > 0) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Revisione ${preventivo.revisione}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 24),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Preventivo ${numeroVisualizzatoPdf(preventivo)}',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Data: $data',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Cliente: ${cliente.isEmpty ? '-' : cliente}',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Divider(color: PdfColors.grey400, thickness: 0.8),
    ],
  );
}

/// Tabella delle righe: descrizione, quantità, prezzo, sconto, totale riga.
pw.Widget _tabellaRighe(List<PreventivoRiga> righe) {
  return pw.Table(
    columnWidths: const {
      0: pw.FlexColumnWidth(4.4),
      1: pw.FlexColumnWidth(1.1),
      2: pw.FlexColumnWidth(1.5),
      3: pw.FlexColumnWidth(1.1),
      4: pw.FlexColumnWidth(1.8),
    },
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
    ),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _cella('Descrizione', intestazione: true),
          _cella('Quantità', intestazione: true, allineamento: pw.TextAlign.right),
          _cella('Prezzo', intestazione: true, allineamento: pw.TextAlign.right),
          _cella('Sconto', intestazione: true, allineamento: pw.TextAlign.right),
          _cella(
            'Totale riga',
            intestazione: true,
            allineamento: pw.TextAlign.right,
          ),
        ],
      ),
      if (righe.isEmpty)
        pw.TableRow(
          children: [
            _cella('Nessuna riga'),
            _cella('-'),
            _cella('-'),
            _cella('-'),
            _cella('-'),
          ],
        )
      else
        for (final riga in righe)
          pw.TableRow(
            children: [
              _cellaRiga(riga),
              _cella(
                _quantitaConUm(riga),
                allineamento: pw.TextAlign.right,
              ),
              _cella(
                formattaImportoPdf(riga.prezzo),
                allineamento: pw.TextAlign.right,
              ),
              _cella(
                riga.scontoPerc > 0
                    ? '${formattaQuantitaPdf(riga.scontoPerc)} %'
                    : '-',
                allineamento: pw.TextAlign.right,
              ),
              _cella(
                formattaImportoPdf(totaleRiga(riga)),
                allineamento: pw.TextAlign.right,
              ),
            ],
          ),
    ],
  );
}

/// Descrizione della riga con eventuale codice articolo sotto.
pw.Widget _cellaRiga(PreventivoRiga riga) {
  final nome = (riga.nome ?? '').trim();
  final codice = (riga.codice ?? '').trim();

  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          nome.isEmpty ? '-' : nome,
          style: const pw.TextStyle(fontSize: 9),
        ),
        if (codice.isNotEmpty)
          pw.Text(
            codice,
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
      ],
    ),
  );
}

String _quantitaConUm(PreventivoRiga riga) {
  final um = (riga.um ?? '').trim();
  final quantita = formattaQuantitaPdf(riga.qty);
  return um.isEmpty ? quantita : '$quantita $um';
}

/// Cella di testo della tabella righe.
pw.Widget _cella(
  String testo, {
  bool intestazione = false,
  pw.TextAlign allineamento = pw.TextAlign.left,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Text(
      testo,
      textAlign: allineamento,
      style: pw.TextStyle(
        fontSize: intestazione ? 8.5 : 9,
        fontWeight: intestazione ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: intestazione ? PdfColors.grey800 : PdfColors.grey900,
      ),
    ),
  );
}

/// Riepilogo allineato a destra: subtotale, sconto, imponibile, IVA, totale.
pw.Widget _riepilogo(Preventivo preventivo) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.SizedBox(
        width: 230,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _rigaTotale('Subtotale', preventivo.subtotale),
            _rigaTotale('Sconto', preventivo.impSconto),
            _rigaTotale('Imponibile', preventivo.imponibile),
            _rigaTotale('IVA', preventivo.iva),
            pw.Divider(color: PdfColors.grey400, thickness: 0.8),
            _rigaTotale('Totale', preventivo.totaleIva, forte: true),
          ],
        ),
      ),
    ],
  );
}

/// Riga etichetta/importo del riepilogo.
pw.Widget _rigaTotale(String etichetta, num valore, {bool forte = false}) {
  final stile = pw.TextStyle(
    fontSize: forte ? 10 : 9,
    fontWeight: forte ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: PdfColors.grey900,
  );

  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(etichetta, style: stile),
        pw.Text(formattaImportoPdf(valore), style: stile),
      ],
    ),
  );
}

/// Riquadro delle note del preventivo.
pw.Widget _note(String note) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(8),
    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Note',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 3),
        pw.Text(note.trim(), style: const pw.TextStyle(fontSize: 9)),
      ],
    ),
  );
}
