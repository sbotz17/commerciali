// Modello del bando (agevolazione/incentivo).
//
// Riproduce fedelmente la struttura dati della vecchia app
// (`js/sp-firestore.js` → collezione `bandi_incentivi`, popolata da
// `supabase/functions/sync-bandi`): i campi del documento sono snake_case
// (`data_chiusura`, `link_ufficiale`, `agevolazione_max`, ...); il modello li
// espone in camelCase ([dataChiusura], [linkUfficiale], [agevolazioneMax])
// come convenzione Dart/Flutter.

/// Bando come vive nella collezione Firestore `bandi_incentivi`.
///
/// I nomi dei campi Firestore sono snake_case; il modello li espone in
/// camelCase come convenzione Dart/Flutter.
class Bando {
  const Bando({
    required this.id,
    this.titolo,
    this.descrizione,
    this.dataApertura,
    this.dataChiusura,
    this.stato,
    this.codiciAteco = const [],
    this.tuttiAteco = false,
    this.regioni = const [],
    this.tutteRegioni = false,
    this.province = const [],
    this.formaAgevolazione = const [],
    this.dimensioni = const [],
    this.settoreAttivita = const [],
    this.obiettivi = const [],
    this.soggettoConcedente,
    this.agevolazioneMin,
    this.agevolazioneMax,
    this.stanziamento,
    this.linkUfficiale,
    this.fonte,
    this.ultimoAggiornamento,
    this.dataImportazione,
  });

  /// Crea un bando dal documento Firestore. [id] è l'id del documento.
  factory Bando.fromMap(Map<String, dynamic> map, {required String id}) {
    return Bando(
      id: id,
      titolo: map['titolo'] as String?,
      descrizione: map['descrizione'] as String?,
      dataApertura: map['data_apertura'] as String?,
      dataChiusura: map['data_chiusura'] as String?,
      stato: map['stato'] as String?,
      codiciAteco: _listaStringhe(map['codici_ateco']),
      tuttiAteco: map['tutti_ateco'] == true,
      regioni: _listaStringhe(map['regioni']),
      tutteRegioni: map['tutte_regioni'] == true,
      province: _listaStringhe(map['province']),
      formaAgevolazione: _listaStringhe(map['forma_agevolazione']),
      dimensioni: _listaStringhe(map['dimensioni']),
      settoreAttivita: _listaStringhe(map['settore_attivita']),
      obiettivi: _listaStringhe(map['obiettivi']),
      soggettoConcedente: map['soggetto_concedente'] as String?,
      agevolazioneMin: map['agevolazione_min'] as num?,
      agevolazioneMax: map['agevolazione_max'] as num?,
      stanziamento: map['stanziamento'] as num?,
      linkUfficiale: map['link_ufficiale'] as String?,
      fonte: map['fonte'] as String?,
      ultimoAggiornamento: map['ultimo_aggiornamento'] as String?,
      dataImportazione: map['data_importazione'] as String?,
    );
  }

  /// Id del documento `bandi_incentivi`.
  final String id;

  /// Titolo del bando (campo Firestore `titolo`).
  final String? titolo;

  /// Descrizione (campo `descrizione`).
  final String? descrizione;

  /// Data di apertura (campo `data_apertura`).
  final String? dataApertura;

  /// Data di chiusura (campo `data_chiusura`), `null` se permanente o ignota.
  final String? dataChiusura;

  /// Stato del bando (`attivo`, `in_scadenza`, `permanente`, `scaduto`).
  final String? stato;

  /// Codici ATECO (campo `codici_ateco`), vuoto se aperto a tutti.
  final List<String> codiciAteco;

  /// `true` se il bando non filtra per ATECO (campo `tutti_ateco`).
  final bool tuttiAteco;

  /// Regioni ammesse (campo `regioni`), vuoto se aperto a tutte.
  final List<String> regioni;

  /// `true` se il bando non filtra per regione (campo `tutte_regioni`).
  final bool tutteRegioni;

  /// Province ammesse (campo `province`), vuoto se assente o non filtrato.
  final List<String> province;

  /// Forme di agevolazione (campo `forma_agevolazione`).
  final List<String> formaAgevolazione;

  /// Dimensioni d'impresa ammesse / beneficiari (campo `dimensioni`).
  final List<String> dimensioni;

  /// Settori di attività (campo `settore_attivita`).
  final List<String> settoreAttivita;

  /// Obiettivi/finalità (campo `obiettivi`).
  final List<String> obiettivi;

  /// Soggetto concedente (campo `soggetto_concedente`).
  final String? soggettoConcedente;

  /// Agevolazione minima in euro (campo `agevolazione_min`), `null` se assente.
  final num? agevolazioneMin;

  /// Agevolazione massima in euro (campo `agevolazione_max`), `null` se assente.
  final num? agevolazioneMax;

  /// Stanziamento complessivo (campo `stanziamento`), `null` se assente.
  final num? stanziamento;

  /// Link ufficiale (campo `link_ufficiale`).
  final String? linkUfficiale;

  /// Fonte del bando (campo `fonte`).
  final String? fonte;

  /// Ultimo aggiornamento (campo `ultimo_aggiornamento`).
  final String? ultimoAggiornamento;

  /// Data di importazione (campo `data_importazione`).
  final String? dataImportazione;

  /// Serializza verso i campi Firestore (snake_case), escluso [id] che è la
  /// chiave documento.
  Map<String, dynamic> toMap() => {
        'titolo': titolo,
        'descrizione': descrizione,
        'data_apertura': dataApertura,
        'data_chiusura': dataChiusura,
        'stato': stato,
        'codici_ateco': codiciAteco,
        'tutti_ateco': tuttiAteco,
        'regioni': regioni,
        'tutte_regioni': tutteRegioni,
        'province': province,
        'forma_agevolazione': formaAgevolazione,
        'dimensioni': dimensioni,
        'settore_attivita': settoreAttivita,
        'obiettivi': obiettivi,
        'soggetto_concedente': soggettoConcedente,
        'agevolazione_min': agevolazioneMin,
        'agevolazione_max': agevolazioneMax,
        'stanziamento': stanziamento,
        'link_ufficiale': linkUfficiale,
        'fonte': fonte,
        'ultimo_aggiornamento': ultimoAggiornamento,
        'data_importazione': dataImportazione,
      };
}

/// Converte un valore Firestore (array o assente) in `List<String>`.
List<String> _listaStringhe(dynamic valore) {
  if (valore is List) {
    return valore.map((e) => e.toString()).toList();
  }
  return const [];
}

/// Ordina i bandi per [Bando.dataChiusura] crescente, con quelli senza data in
/// fondo (stesso comportamento di `SP.getBandi` nella vecchia app, che usa
/// `"9999-12-31"` come sentinella per i valori assenti).
List<Bando> ordinaBandiPerScadenza(List<Bando> bandi) {
  final ordinati = [...bandi];
  ordinati.sort((a, b) {
    final da = a.dataChiusura ?? '9999-12-31';
    final db = b.dataChiusura ?? '9999-12-31';
    return da.compareTo(db);
  });
  return ordinati;
}
