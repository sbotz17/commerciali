// Modelli dei preventivi e funzioni pure per i totali.
//
// Riproducono fedelmente la struttura dati della vecchia app
// (`js/sp-firestore.js` + `js/app.js`):
// - i campi del documento `preventivi` sono snake_case (`cliente_id`,
//   `imp_sconto`, `totale_iva`, `created_at`);
// - le righe (`righe`) sono oggetti salvati così come arrivano dall'editor
//   Alpine.js, quindi **camelCase** (`prodottoId`, `qty`, `scontoPerc`,
//   `scontoVal`, `ivaPerc`). Questo è voluto per restare compatibili con i
//   dati già presenti in Firestore.
//
// Le funzioni pure di calcolo (`totaleRiga`, `calcolaTotali`) replicano i
// getter della vecchia app (subtotale, sconto globale, imponibile, IVA,
// totale), incluso il fattore fisso 22% quando l'IVA è inclusa.

/// Riga di un preventivo (oggetto dentro l'array Firestore `righe`).
///
/// I nomi dei campi sono camelCase perché la vecchia app salva l'array
/// direttamente dall'editor, senza rinominare le chiavi.
class PreventivoRiga {
  const PreventivoRiga({
    this.prodottoId,
    this.codice,
    this.nome,
    this.prezzo = 0,
    this.immagine,
    this.qty = 0,
    this.um,
    this.scontoPerc = 0,
    this.scontoVal = 0,
    this.ivaPerc = 22,
    this.paniereId,
    this.paniereNome,
  });

  /// Crea una riga dall'oggetto Firestore (chiavi camelCase).
  factory PreventivoRiga.fromMap(Map<String, dynamic> map) {
    return PreventivoRiga(
      prodottoId: map['prodottoId'] as String?,
      codice: map['codice'] as String?,
      nome: map['nome'] as String?,
      prezzo: (map['prezzo'] as num?) ?? 0,
      immagine: map['immagine'] as String?,
      qty: (map['qty'] as num?) ?? 0,
      um: map['um'] as String?,
      scontoPerc: (map['scontoPerc'] as num?) ?? 0,
      scontoVal: (map['scontoVal'] as num?) ?? 0,
      ivaPerc: (map['ivaPerc'] as num?) ?? 22,
      paniereId: map['paniereId'] as String?,
      paniereNome: map['paniereNome'] as String?,
    );
  }

  /// Id del prodotto collegato (campo `prodottoId`).
  final String? prodottoId;

  /// Codice articolo mostrato nel documento (es. `SW-001`).
  final String? codice;

  /// Descrizione/nome della riga (campo `nome`).
  final String? nome;

  /// Prezzo unitario numerico.
  final num prezzo;

  /// URL dell'immagine del prodotto, `null` se assente.
  final String? immagine;

  /// Quantità (campo `qty`).
  final num qty;

  /// Unità di misura (es. `pz`).
  final String? um;

  /// Sconto riga in percentuale (campo `scontoPerc`).
  final num scontoPerc;

  /// Sconto riga in valore assoluto (campo `scontoVal`).
  final num scontoVal;

  /// Aliquota IVA della riga (campo `ivaPerc`), default 22.
  final num ivaPerc;

  /// Id del paniere collegato (campo `paniereId`), `null` se la riga non è
  /// un paniere.
  final String? paniereId;

  /// Nome del paniere collegato (campo `paniereNome`), `null` se assente.
  final String? paniereNome;

  /// Restituisce una copia della riga con i campi indicati modificati.
  ///
  /// I campi non passati mantengono il valore corrente. Serve per
  /// l'inserimento dei panieri (es. variare `qty`, `prezzo` o collegare un
  /// paniere).
  PreventivoRiga copyWith({
    String? prodottoId,
    String? codice,
    String? nome,
    num? prezzo,
    String? immagine,
    num? qty,
    String? um,
    num? scontoPerc,
    num? scontoVal,
    num? ivaPerc,
    String? paniereId,
    String? paniereNome,
  }) {
    return PreventivoRiga(
      prodottoId: prodottoId ?? this.prodottoId,
      codice: codice ?? this.codice,
      nome: nome ?? this.nome,
      prezzo: prezzo ?? this.prezzo,
      immagine: immagine ?? this.immagine,
      qty: qty ?? this.qty,
      um: um ?? this.um,
      scontoPerc: scontoPerc ?? this.scontoPerc,
      scontoVal: scontoVal ?? this.scontoVal,
      ivaPerc: ivaPerc ?? this.ivaPerc,
      paniereId: paniereId ?? this.paniereId,
      paniereNome: paniereNome ?? this.paniereNome,
    );
  }

  /// Serializza verso l'oggetto Firestore (camelCase, coerente con la
  /// vecchia app).
  Map<String, dynamic> toMap() => {
        'prodottoId': prodottoId,
        'codice': codice,
        'nome': nome,
        'prezzo': prezzo,
        'immagine': immagine,
        'qty': qty,
        'um': um,
        'scontoPerc': scontoPerc,
        'scontoVal': scontoVal,
        'ivaPerc': ivaPerc,
        'paniereId': paniereId,
        'paniereNome': paniereNome,
      };
}

/// Preventivo come vive nella collezione Firestore `preventivi`.
///
/// I nomi dei campi Firestore sono snake_case; il modello li espone in
/// camelCase come convenzione Dart/Flutter.
class Preventivo {
  const Preventivo({
    required this.id,
    this.aziendaId,
    this.clienteId,
    this.clienteNome,
    this.utenteId,
    this.numero,
    this.revisione = 0,
    this.righe = const [],
    this.sconto = 0,
    this.note,
    this.subtotale = 0,
    this.impSconto = 0,
    this.imponibile = 0,
    this.iva = 0,
    this.totaleIva = 0,
    this.stato = 'bozza',
    this.validoFino,
    this.createdAt,
  });

  /// Crea un preventivo dal documento Firestore. [id] è l'id del documento.
  factory Preventivo.fromMap(Map<String, dynamic> map, {required String id}) {
    return Preventivo(
      id: id,
      aziendaId: map['azienda_id'] as String?,
      clienteId: map['cliente_id'] as String?,
      clienteNome: map['cliente_nome'] as String?,
      utenteId: map['utente_id'] as String?,
      numero: map['numero'] as String?,
      revisione: (map['revisione'] as num?)?.toInt() ?? 0,
      righe: (map['righe'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((r) => PreventivoRiga.fromMap(Map<String, dynamic>.from(r)))
          .toList(),
      sconto: (map['sconto'] as num?) ?? 0,
      note: map['note'] as String?,
      subtotale: (map['subtotale'] as num?) ?? 0,
      impSconto: (map['imp_sconto'] as num?) ?? 0,
      imponibile: (map['imponibile'] as num?) ?? 0,
      iva: (map['iva'] as num?) ?? 0,
      totaleIva: (map['totale_iva'] as num?) ?? 0,
      stato: (map['stato'] as String?) ?? 'bozza',
      validoFino: _dataIsoValida(map['valido_fino']),
      createdAt: map['created_at'] as String?,
    );
  }

  /// Normalizza `valido_fino` in `YYYY-MM-DD`, ignorando valori non validi.
  static String? _dataIsoValida(Object? valore) {
    final testo = (valore ?? '').toString().trim();
    if (testo.isEmpty) return null;
    final data = DateTime.tryParse(testo);
    if (data == null) return null;
    return '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}';
  }

  /// Id del documento `preventivi`.
  final String id;

  /// Id dell'azienda a cui appartiene (campo Firestore `azienda_id`).
  final String? aziendaId;

  /// Id del cliente (campo `cliente_id`).
  final String? clienteId;

  /// Nome del cliente denormalizzato (campo `cliente_nome`).
  final String? clienteNome;

  /// Id dell'utente che ha emesso il preventivo (campo `utente_id`).
  final String? utenteId;

  /// Numero progressivo (es. `PRV-0001`, `PRV-0001-R1`).
  final String? numero;

  /// Numero di revisione (0 = originale).
  final int revisione;

  /// Righe del preventivo.
  final List<PreventivoRiga> righe;

  /// Sconto globale in percentuale (campo `sconto`), default 0.
  final num sconto;

  final String? note;

  /// Somma delle righe al netto degli sconti riga.
  final num subtotale;

  /// Sconto globale in valore assoluto (campo `imp_sconto`).
  final num impSconto;

  /// Imponibile (campo `imponibile`).
  final num imponibile;

  /// IVA (campo `iva`).
  final num iva;

  /// Totale documento, IVA inclusa (campo `totale_iva`).
  final num totaleIva;

  /// Stato del preventivo (`bozza`, `inviato`, `accettato`, `rifiutato`,
  /// `revisionato`).
  final String stato;

  /// Ultimo giorno di validità `YYYY-MM-DD` (campo `valido_fino`).
  ///
  /// È facoltativo: i preventivi creati prima di questa funzione restano
  /// validi senza scadenza finché non vengono riaperti e salvati.
  final String? validoFino;

  /// Data di creazione ISO-8601 (campo `created_at`).
  final String? createdAt;

  /// Serializza verso i campi Firestore (snake_case), escluso [id] che è la
  /// chiave documento.
  Map<String, dynamic> toMap() => {
        'azienda_id': aziendaId,
        'cliente_id': clienteId,
        'cliente_nome': clienteNome,
        'utente_id': utenteId,
        'numero': numero,
        'revisione': revisione,
        'righe': righe.map((r) => r.toMap()).toList(),
        'sconto': sconto,
        'note': note,
        'subtotale': subtotale,
        'imp_sconto': impSconto,
        'imponibile': imponibile,
        'iva': iva,
        'totale_iva': totaleIva,
        'stato': stato,
        'valido_fino': validoFino,
        'created_at': createdAt,
      };
}

/// Totale di una riga: `prezzo * qty - scontoVal` (come la vecchia app).
double totaleRiga(PreventivoRiga riga) {
  final prezzo = riga.prezzo.toDouble();
  final qty = riga.qty.toDouble();
  final scontoVal = riga.scontoVal.toDouble();
  return prezzo * qty - scontoVal;
}

/// Totali di un preventivo calcolati dalle righe.
class PreventivoTotali {
  const PreventivoTotali({
    required this.subtotale,
    required this.impSconto,
    required this.imponibile,
    required this.iva,
    required this.totaleIva,
  });

  final double subtotale;
  final double impSconto;
  final double imponibile;
  final double iva;
  final double totaleIva;
}

/// Calcola i totali di un preventivo dalle [righe], replicando la vecchia app.
///
/// [scontoGlobaleEuro] è lo sconto globale in euro, limitato tra 0 e il
/// subtotale. [ivaInclusa] applica il fattore fisso 22% sull'imponibile
/// (come il getter `imponibile` della vecchia app).
PreventivoTotali calcolaTotali(
  List<PreventivoRiga> righe, {
  double scontoGlobaleEuro = 0,
  bool ivaInclusa = false,
}) {
  final subtotale = righe.fold<double>(0, (somma, r) => somma + totaleRiga(r));
  final impSconto = scontoGlobaleEuro.clamp(0.0, subtotale).toDouble();
  final baseImponibile = subtotale - impSconto;
  final imponibile = ivaInclusa ? baseImponibile / 1.22 : baseImponibile;
  final iva = baseImponibile - imponibile;
  return PreventivoTotali(
    subtotale: subtotale,
    impSconto: impSconto,
    imponibile: imponibile,
    iva: iva,
    totaleIva: baseImponibile,
  );
}

/// Formatta il progressivo preventivo come `PRV-0001` (4 cifre).
String formatoNumeroPreventivo(int numero) =>
    'PRV-${numero.toString().padLeft(4, '0')}';

/// Restituisce il numero base senza il suffisso di revisione (`-R1`, `-R2`…).
String numeroBasePreventivo(String numero) =>
    numero.replaceFirst(RegExp(r'-R\d+$'), '');

/// Costruisce il numero di una revisione: `{numeroBase}-R{revisione}`.
String numeroRevisione(String numeroBase, int revisione) =>
    '$numeroBase-R$revisione';
