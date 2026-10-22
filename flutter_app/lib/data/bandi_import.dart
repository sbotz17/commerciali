// Funzioni pure per l'importazione dei bandi open data di incentivi.gov.it.
//
// Non toccano Firebase né la UI: ricevono i dati in ingresso e restituiscono
// nuove strutture, senza effetti collaterali. Portano in Dart la logica di
// normalizzazione della vecchia app (`js/app.js` → `_normalizzaBando`): i
// campi di output sono snake_case e coincidono con quelli della collezione
// Firestore `bandi_incentivi` (vedi `data/models/bando.dart`).

/// Estrae la lista di record bandi da un JSON open data di incentivi.gov.it.
///
/// Riconosce tre forme in ingresso:
/// - array diretto `[...]`;
/// - risposta Solr `{response: {docs: [...]}}`;
/// - oggetto con `{docs: [...]}`.
///
/// Qualsiasi altra struttura (o un valore non mappa/lista) restituisce una
/// lista vuota.
List<dynamic> estraiRecordsBandi(dynamic json) {
  if (json is List) return json;
  if (json is Map) {
    final response = json['response'];
    if (response is Map) {
      final docs = response['docs'];
      if (docs is List) return docs;
    }
    final docs = json['docs'];
    if (docs is List) return docs;
  }
  return const [];
}

/// Calcola lo stato di un bando dalla data di chiusura.
///
/// - data vuota o assente → `permanente`;
/// - data già passata → `scaduto`;
/// - entro 30 giorni (inclusi) → `in_scadenza`;
/// - altrimenti → `attivo`;
/// - data non interpretabile → `permanente`.
String statoBandoDaData(String? dataChiusura, {DateTime? adesso}) {
  final s = (dataChiusura ?? '').trim();
  if (s.isEmpty) return 'permanente';

  final fine = DateTime.tryParse(s);
  if (fine == null) return 'permanente';

  final ora = adesso ?? DateTime.now();
  if (fine.isBefore(ora)) return 'scaduto';

  final giorni =
      (fine.difference(ora).inMilliseconds / Duration.millisecondsPerDay)
          .round();
  return giorni <= 30 ? 'in_scadenza' : 'attivo';
}

/// Normalizza un singolo record open data di incentivi.gov.it nel formato
/// Firestore `bandi_incentivi` (chiavi snake_case, vedi `Bando.toMap`).
Map<String, dynamic> normalizzaBandoIncentivi(
  Map<String, dynamic> record, {
  String fonte = 'incentivi.gov.it',
  DateTime? adesso,
}) {
  final ora = adesso ?? DateTime.now();

  final titolo = _stringa(record['Titolo']);
  final link = _stringa(record['Link_istituzionale']);
  final idIncentivo = _stringa(record['ID_Incentivo']);
  final id = idIncentivo.isNotEmpty
      ? idIncentivo
      : 'bando_${_hashStabile(link.isNotEmpty ? link : titolo)}';

  final descrizione = _stringa(record['Descrizione']);
  final dataChiusura = _data(record['Data_chiusura']);

  // ATECO: stringa separata da `;`; si tengono solo i token che iniziano con
  // una cifra. Se la stringa è vuota o contiene "tutti"/"qualsiasi"/
  // "indifferente" il bando è aperto a tutti gli ATECO.
  final ateco = _stringa(record['Codici_ATECO']);
  final atecoLow = ateco.toLowerCase();
  final tuttiAteco = ateco.isEmpty ||
      atecoLow.contains('tutti') ||
      atecoLow.contains('qualsiasi') ||
      atecoLow.contains('indifferente');
  final codiciAteco = tuttiAteco
      ? <String>[]
      : ateco
          .split(';')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty && _iniziaConCifra(c))
          .toList();

  final regioni = _listaStringhe(record['Regioni']);
  final province = _province(record);

  return {
    'id': id,
    'titolo': titolo,
    'descrizione':
        descrizione.length > 2000 ? descrizione.substring(0, 2000) : descrizione,
    'data_apertura': _data(record['Data_apertura']),
    'data_chiusura': dataChiusura,
    'stato': statoBandoDaData(dataChiusura, adesso: ora),
    'codici_ateco': codiciAteco,
    'tutti_ateco': tuttiAteco,
    'regioni': regioni,
    'tutte_regioni': regioni.isEmpty,
    'province': province,
    'forma_agevolazione': _listaStringhe(record['Forma_agevolazione']),
    'dimensioni': _listaStringhe(record['Dimensioni']),
    'settore_attivita': _listaStringhe(record['Settore_Attivita']),
    'obiettivi': _listaStringhe(record['Obiettivo_Finalita']),
    'soggetto_concedente': _stringa(record['Soggetto_Concedente']),
    'agevolazione_min': _numero(record['Agevolazione_Concedibile_min']),
    'agevolazione_max': _numero(record['Agevolazione_Concedibile_max']),
    'stanziamento': _numero(record['Stanziamento_incentivo']),
    'link_ufficiale': link,
    'fonte': fonte,
    'ultimo_aggiornamento': _data(record['Data_ultimo_aggiornamento']),
    'data_importazione': ora.toUtc().toIso8601String(),
  };
}

/// Normalizza una lista di record, ignorando gli elementi che non sono [Map].
List<Map<String, dynamic>> normalizzaBandiIncentivi(
  List<dynamic> records, {
  String fonte = 'incentivi.gov.it',
  DateTime? adesso,
}) {
  final risultato = <Map<String, dynamic>>[];
  for (final r in records) {
    if (r is Map) {
      risultato.add(normalizzaBandoIncentivi(
        _comeMappaStringhe(r),
        fonte: fonte,
        adesso: adesso,
      ));
    }
  }
  return risultato;
}

// ── Helpers ────────────────────────────────────────────────────────────────

/// Valore convertito a stringa, con spazi esterni rimossi (`''` se null).
String _stringa(dynamic v) => (v?.toString() ?? '').trim();

/// Valore data come stringa, oppure `null` se assente o vuoto.
String? _data(dynamic v) {
  final s = _stringa(v);
  return s.isEmpty ? null : s;
}

/// Valore numerico (anche da stringa), default `0` se non interpretabile.
num _numero(dynamic v) {
  if (v is num) return v;
  if (v is String) {
    final n = num.tryParse(v.trim());
    if (n != null) return n;
  }
  return 0;
}

/// Valore lista convertito in `List<String>` (esclusi gli elementi null);
/// lista vuota se il valore non è una lista.
List<String> _listaStringhe(dynamic v) {
  if (v is! List) return const [];
  return v.where((e) => e != null).map((e) => e.toString()).toList();
}

/// Province ammesse, lette in ordine di priorità:
/// - `Province` (lista);
/// - `Provincia` (stringa singola oppure lista);
/// - `Comuni` (solo se lista di stringhe).
/// Lista vuota se nessun campo è valorizzato.
List<String> _province(Map<String, dynamic> record) {
  final province = record['Province'];
  if (province is List) return _listaStringhe(province);

  final provincia = record['Provincia'];
  if (provincia is List) return _listaStringhe(provincia);
  if (provincia != null) {
    final s = _stringa(provincia);
    return s.isEmpty ? const [] : [s];
  }

  final comuni = record['Comuni'];
  if (comuni is List) return _listaStringhe(comuni);
  return const [];
}

/// Copia una [Map] generica in `Map<String, dynamic>`, scartando le chiavi non
/// stringa (non presenti nel JSON decodificato).
Map<String, dynamic> _comeMappaStringhe(Map mappa) {
  final risultato = <String, dynamic>{};
  for (final entry in mappa.entries) {
    if (entry.key is String) risultato[entry.key as String] = entry.value;
  }
  return risultato;
}

/// `true` se la stringa inizia con una cifra (equivalente a `/^\d/`).
bool _iniziaConCifra(String s) {
  final c = s.codeUnitAt(0);
  return c >= 0x30 && c <= 0x39;
}

/// Hash numerico stabile e non negativo di una stringa (somma sui codeUnits,
/// stile `hashStr` della vecchia app). Usato per l'id quando manca
/// `ID_Incentivo`.
int _hashStabile(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}
