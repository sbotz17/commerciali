// Logica pura del calendario: conversione degli appuntamenti e dei task in voci
// dell'agenda, raggruppamento per giorno, periodi (giorno, settimana, mese) e
// posizionamento delle voci nella griglia oraria.
//
// Il file non usa Firebase né widget: le funzioni sono verificabili con unit
// test e restano condivise tra la schermata e le viste.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/appuntamento.dart';
import '../../data/models/task_item.dart';
import '../visite/visite_screen.dart'
    show dataIsoVisita, etichettaGiornoVisite, formattaDataVisita;

// ---------------------------------------------------------------------------
// Tipi di voce e modello
// ---------------------------------------------------------------------------

/// Tipo di voce dell'agenda: appuntamento o task.
const String tipoAppuntamento = 'appuntamento';
const String tipoTask = 'task';

/// Vista del periodo: giornaliera, settimanale o mensile.
enum VistaAgenda {
  giorno('Giorno'),
  settimana('Settimana'),
  mese('Mese');

  const VistaAgenda(this.etichetta);

  /// Etichetta italiana mostrata nel selettore.
  final String etichetta;
}

/// Stile della vista: calendario classico oppure elenco a card.
enum StileAgenda {
  calendario('Calendario'),
  card('Card');

  const StileAgenda(this.etichetta);

  /// Etichetta italiana mostrata nel selettore.
  final String etichetta;
}

/// Vista iniziale: il calendario, con il mese come periodo di partenza.
const VistaAgenda vistaAgendaPredefinita = VistaAgenda.mese;

/// Stile iniziale: calendario classico (non l'elenco a card).
const StileAgenda stileAgendaPredefinito = StileAgenda.calendario;

/// Voce mostrata nel calendario, ricavata da un appuntamento o da un task.
class ElementoAgenda {
  const ElementoAgenda({
    required this.data,
    required this.titolo,
    required this.tipo,
    this.ora,
    this.appuntamento,
    this.task,
  });

  /// Giorno della voce in formato `YYYY-MM-DD`.
  final String data;

  /// Ora `HH:MM`, oppure `null` quando la voce non ha un orario.
  final String? ora;

  /// Titolo visibile (con fallback se il documento è senza titolo).
  final String titolo;

  /// `appuntamento` oppure `task`.
  final String tipo;

  /// Appuntamento di origine, se [tipo] è `appuntamento`.
  final Appuntamento? appuntamento;

  /// Task di origine, se [tipo] è `task`.
  final TaskItem? task;

  /// `true` se la voce è un appuntamento.
  bool get isAppuntamento => tipo == tipoAppuntamento;
}

/// Ora normalizzata `HH:MM`, oppure `null` se assente.
String? _oraElemento(String? ora) {
  final valore = ora?.trim() ?? '';
  if (valore.isEmpty) return null;
  final parti = valore.split(':');
  if (parti.length != 2) return valore;
  final ore = int.tryParse(parti[0]);
  final minuti = int.tryParse(parti[1]);
  if (ore == null || minuti == null) return valore;
  if (ore < 0 || ore > 23 || minuti < 0 || minuti > 59) return valore;
  return '${ore.toString().padLeft(2, '0')}:'
      '${minuti.toString().padLeft(2, '0')}';
}

/// Titolo con fallback per i documenti senza titolo.
String _titoloElemento(String? titolo, String fallback) {
  final valore = titolo?.trim() ?? '';
  return valore.isEmpty ? fallback : valore;
}

/// Converte gli appuntamenti in voci dell'agenda.
///
/// Gli appuntamenti senza `data` non possono essere collocati in un giorno e
/// vengono scartati; l'ordine di partenza è quello del servizio.
List<ElementoAgenda> elementiDaAppuntamenti(
  List<Appuntamento> appuntamenti, {
  DateTime? dal,
  DateTime? al,
}) {
  final elementi = <ElementoAgenda>[];
  for (final appuntamento in appuntamenti) {
    final data = appuntamento.data?.trim() ?? '';
    if (data.isEmpty) continue;

    if (dal != null && al != null) {
      for (final giorno in occorrenzeAppuntamento(
        appuntamento,
        dal: dal,
        al: al,
      )) {
        elementi.add(
          ElementoAgenda(
            data: dataIsoVisita(giorno),
            ora: appuntamento.tuttoIlGiorno
                ? null
                : _oraElemento(appuntamento.ora),
            titolo: _titoloElemento(appuntamento.titolo, 'Appuntamento'),
            tipo: tipoAppuntamento,
            appuntamento: appuntamento,
          ),
        );
      }
      continue;
    }

    elementi.add(
      ElementoAgenda(
        data: data,
        ora: appuntamento.tuttoIlGiorno ? null : _oraElemento(appuntamento.ora),
        titolo: _titoloElemento(appuntamento.titolo, 'Appuntamento'),
        tipo: tipoAppuntamento,
        appuntamento: appuntamento,
      ),
    );
  }
  return elementi;
}

/// Converte i task in voci dell'agenda.
///
/// Solo i task con `scadenzaData` hanno un giorno: quelli senza scadenza sono
/// esclusi dal calendario.
List<ElementoAgenda> elementiDaTask(List<TaskItem> task) {
  final elementi = <ElementoAgenda>[];
  for (final voce in task) {
    final data = voce.scadenzaData?.trim() ?? '';
    if (data.isEmpty) continue;
    elementi.add(
      ElementoAgenda(
        data: data,
        ora: _oraElemento(voce.scadenzaOra),
        titolo: _titoloElemento(voce.titolo, 'Task'),
        tipo: tipoTask,
        task: voce,
      ),
    );
  }
  return elementi;
}

/// Chiave di ordinamento dell'ora: le voci senza ora finiscono in fondo.
String _chiaveOra(ElementoAgenda elemento) => elemento.ora ?? '99:99';

/// Raggruppa le voci per giorno (`YYYY-MM-DD`).
///
/// Le chiavi sono ordinate per data crescente e, dentro ogni giorno, le voci
/// sono ordinate per ora (senza ora in fondo) e poi per titolo.
Map<String, List<ElementoAgenda>> raggruppaPerGiorno(
  List<ElementoAgenda> elementi,
) {
  final gruppi = <String, List<ElementoAgenda>>{};
  for (final elemento in elementi) {
    final data = elemento.data.trim();
    if (data.isEmpty) continue;
    gruppi.putIfAbsent(data, () => <ElementoAgenda>[]).add(elemento);
  }

  final giorni = gruppi.keys.toList()..sort();
  final risultato = <String, List<ElementoAgenda>>{};
  for (final giorno in giorni) {
    final voci = gruppi[giorno]!;
    voci.sort((a, b) {
      final cmpOra = _chiaveOra(a).compareTo(_chiaveOra(b));
      if (cmpOra != 0) return cmpOra;
      return a.titolo.toLowerCase().compareTo(b.titolo.toLowerCase());
    });
    risultato[giorno] = voci;
  }
  return risultato;
}

// ---------------------------------------------------------------------------
// Date e periodi
// ---------------------------------------------------------------------------

/// Nomi italiani dei mesi, da gennaio a dicembre.
const List<String> nomiMesi = [
  'Gennaio',
  'Febbraio',
  'Marzo',
  'Aprile',
  'Maggio',
  'Giugno',
  'Luglio',
  'Agosto',
  'Settembre',
  'Ottobre',
  'Novembre',
  'Dicembre',
];

/// Nomi italiani brevi dei giorni, da lunedì a domenica.
const List<String> nomiGiorniBrevi = [
  'Lun',
  'Mar',
  'Mer',
  'Gio',
  'Ven',
  'Sab',
  'Dom',
];

/// Nomi italiani completi dei giorni, da lunedì a domenica.
const List<String> nomiGiorni = [
  'Lunedì',
  'Martedì',
  'Mercoledì',
  'Giovedì',
  'Venerdì',
  'Sabato',
  'Domenica',
];

/// I sette giorni (lunedì → domenica) della settimana che contiene [giorno].
List<DateTime> giorniSettimana(DateTime giorno) {
  final base = DateTime(giorno.year, giorno.month, giorno.day);
  final lunedi = DateTime(base.year, base.month, base.day - (base.weekday - 1));
  return [
    for (var indice = 0; indice < 7; indice++)
      DateTime(lunedi.year, lunedi.month, lunedi.day + indice),
  ];
}

/// Giorni della griglia mensile, da lunedì a domenica.
///
/// Comprende i giorni del mese precedente e del successivo necessari a
/// completare le settimane: la prima cella è sempre un lunedì.
List<DateTime> giorniGrigliaMese(DateTime mese) {
  final primo = DateTime(mese.year, mese.month, 1);
  final lunedi = DateTime(
    primo.year,
    primo.month,
    primo.day - (primo.weekday - 1),
  );
  final ultimo = DateTime(mese.year, mese.month + 1, 0);
  final domenica = DateTime(
    ultimo.year,
    ultimo.month,
    ultimo.day + (7 - ultimo.weekday),
  );
  final numeroGiorni = _giorniDiDifferenza(lunedi, domenica) + 1;
  return [
    for (var indice = 0; indice < numeroGiorni; indice++)
      DateTime(lunedi.year, lunedi.month, lunedi.day + indice),
  ];
}

/// Giorni interi tra due date, senza dipendere dall'ora legale.
int _giorniDiDifferenza(DateTime da, DateTime a) => DateTime.utc(
  a.year,
  a.month,
  a.day,
).difference(DateTime.utc(da.year, da.month, da.day)).inDays;

/// Etichetta del giorno: "Oggi", "Domani" (o "Ieri") oppure `gg/mm/aaaa`.
///
/// [oggi] serve ai test per fissare il riferimento; in app è la data corrente.
String etichettaGiorno(DateTime giorno, {DateTime? oggi}) =>
    etichettaGiornoVisite(giorno, oggi: oggi);

/// Etichetta del periodo corrente nella barra del calendario.
String etichettaPeriodo(VistaAgenda vista, DateTime giorno) {
  switch (vista) {
    case VistaAgenda.giorno:
      return etichettaGiorno(giorno);
    case VistaAgenda.settimana:
      final giorni = giorniSettimana(giorno);
      return '${formattaDataVisita(giorni.first)} – '
          '${formattaDataVisita(giorni.last)}';
    case VistaAgenda.mese:
      return '${nomiMesi[giorno.month - 1]} ${giorno.year}';
  }
}

/// Sposta [giorno] avanti o indietro di un periodo della vista.
///
/// [verso] è `1` (successivo) o `-1` (precedente); per il mese la data torna
/// al primo giorno del mese, così i mesi corti non vengono saltati.
DateTime spostaPeriodo(VistaAgenda vista, DateTime giorno, int verso) {
  switch (vista) {
    case VistaAgenda.giorno:
      return DateTime(giorno.year, giorno.month, giorno.day + verso);
    case VistaAgenda.settimana:
      return DateTime(giorno.year, giorno.month, giorno.day + 7 * verso);
    case VistaAgenda.mese:
      return DateTime(giorno.year, giorno.month + verso, 1);
  }
}

/// `true` se la voce cade nel periodo mostrato dalla vista.
bool elementoNelPeriodo(
  ElementoAgenda elemento,
  VistaAgenda vista,
  DateTime giorno,
) {
  switch (vista) {
    case VistaAgenda.giorno:
      return elemento.data.trim() == dataIsoVisita(giorno);
    case VistaAgenda.settimana:
      final giorni = {
        for (final voce in giorniSettimana(giorno)) dataIsoVisita(voce),
      };
      return giorni.contains(elemento.data.trim());
    case VistaAgenda.mese:
      final data = DateTime.tryParse(elemento.data.trim());
      return data != null &&
          data.year == giorno.year &&
          data.month == giorno.month;
  }
}

/// Voci che cadono nel periodo mostrato dalla vista.
List<ElementoAgenda> elementiNelPeriodo(
  List<ElementoAgenda> elementi,
  VistaAgenda vista,
  DateTime giorno,
) => [
  for (final elemento in elementi)
    if (elementoNelPeriodo(elemento, vista, giorno)) elemento,
];

// ---------------------------------------------------------------------------
// Griglia oraria
// ---------------------------------------------------------------------------

/// Minuti dalla mezzanotte per un'ora `HH:MM`; `null` se assente o non valida.
int? minutiDaOra(String? ora) {
  final normalizzata = _oraElemento(ora);
  if (normalizzata == null) return null;
  final parti = normalizzata.split(':');
  if (parti.length != 2) return null;
  final ore = int.tryParse(parti[0]);
  final minuti = int.tryParse(parti[1]);
  if (ore == null || minuti == null) return null;
  if (ore < 0 || ore > 23 || minuti < 0 || minuti > 59) return null;
  return ore * 60 + minuti;
}

/// Durata in minuti di una voce: quella dell'appuntamento (default 60) oppure
/// 30 minuti per i task e per le durate non valide.
int durataMinutiElemento(ElementoAgenda elemento) {
  final appuntamento = elemento.appuntamento;
  if (appuntamento != null) {
    final durata = durataEffettivaAppuntamento(appuntamento);
    return durata > 0 ? durata : 30;
  }
  return 30;
}

/// Voce con orario e posizione calcolata nella griglia di un giorno.
class VocePosizionata {
  const VocePosizionata({
    required this.elemento,
    required this.inizio,
    required this.fine,
    required this.corsia,
    required this.corsie,
  });

  /// Voce originale dell'agenda.
  final ElementoAgenda elemento;

  /// Minuti dalla mezzanotte di inizio e fine.
  final int inizio;
  final int fine;

  /// Indice della colonna (0-based) e numero totale di colonne del gruppo
  /// sovrapposto, usati per affiancare gli eventi in parallelo.
  final int corsia;
  final int corsie;
}

/// Dispone le voci con orario di un giorno, affiancando quelle sovrapposte.
///
/// Le voci senza ora vengono ignorate (vanno nella sezione "Senza orario").
/// Le voci sono ordinate per inizio e fine; ogni gruppo di voci sovrapposte
/// riceve delle corsie, così nessuna card copre un'altra.
List<VocePosizionata> disponiVociGiorno(List<ElementoAgenda> elementi) {
  final conOrario = <({ElementoAgenda elemento, int inizio, int fine})>[];
  for (final elemento in elementi) {
    final inizio = minutiDaOra(elemento.ora);
    if (inizio == null) continue;
    final durata = durataMinutiElemento(elemento);
    final fine = (inizio + durata).clamp(0, 24 * 60);
    conOrario.add((elemento: elemento, inizio: inizio, fine: fine));
  }

  conOrario.sort((a, b) {
    final cmpInizio = a.inizio.compareTo(b.inizio);
    if (cmpInizio != 0) return cmpInizio;
    final cmpFine = a.fine.compareTo(b.fine);
    if (cmpFine != 0) return cmpFine;
    return a.elemento.titolo.toLowerCase().compareTo(
      b.elemento.titolo.toLowerCase(),
    );
  });

  final risultato = <VocePosizionata>[];
  var indice = 0;
  while (indice < conOrario.length) {
    final gruppo = <({ElementoAgenda elemento, int inizio, int fine})>[];
    var fineGruppo = conOrario[indice].fine;
    gruppo.add(conOrario[indice]);
    var successivo = indice + 1;
    while (successivo < conOrario.length &&
        conOrario[successivo].inizio < fineGruppo) {
      gruppo.add(conOrario[successivo]);
      if (conOrario[successivo].fine > fineGruppo) {
        fineGruppo = conOrario[successivo].fine;
      }
      successivo++;
    }

    final fineCorsie = <int>[];
    final corsie = <int>[];
    for (final voce in gruppo) {
      var corsia = fineCorsie.indexWhere((fine) => fine <= voce.inizio);
      if (corsia == -1) {
        corsia = fineCorsie.length;
        fineCorsie.add(voce.fine);
      } else {
        fineCorsie[corsia] = voce.fine;
      }
      corsie.add(corsia);
    }

    final numeroCorsie = fineCorsie.length;
    for (var posizione = 0; posizione < gruppo.length; posizione++) {
      final voce = gruppo[posizione];
      risultato.add(
        VocePosizionata(
          elemento: voce.elemento,
          inizio: voce.inizio,
          fine: voce.fine,
          corsia: corsie[posizione],
          corsie: numeroCorsie,
        ),
      );
    }

    indice = successivo;
  }
  return risultato;
}

/// Intervallo orario da mostrare nella griglia, in minuti dalla mezzanotte.
///
/// Parte da 07:00–21:00 e si allarga per includere tutte le voci con orario,
/// arrotondando alle ore intere.
({int inizio, int fine}) intervalloOrarioElementi(
  List<ElementoAgenda> elementi,
) {
  var inizio = 7 * 60;
  var fine = 21 * 60;
  var trovata = false;
  for (final elemento in elementi) {
    final partenza = minutiDaOra(elemento.ora);
    if (partenza == null) continue;
    trovata = true;
    final arrivo = (partenza + durataMinutiElemento(elemento)).clamp(
      0,
      24 * 60,
    );
    if (partenza < inizio) inizio = partenza;
    if (arrivo > fine) fine = arrivo;
  }
  if (!trovata) return (inizio: inizio, fine: fine);

  inizio = (inizio ~/ 60) * 60;
  fine = ((fine + 59) ~/ 60) * 60;
  if (fine <= inizio) fine = inizio + 60;
  return (inizio: inizio, fine: fine);
}

/// Voci con orario della lista, ordinate per ora e titolo.
List<ElementoAgenda> vociConOrario(List<ElementoAgenda> elementi) =>
    [
      for (final elemento in elementi)
        if (minutiDaOra(elemento.ora) != null) elemento,
    ]..sort((a, b) {
      final cmpOra = (a.ora ?? '').compareTo(b.ora ?? '');
      if (cmpOra != 0) return cmpOra;
      return a.titolo.toLowerCase().compareTo(b.titolo.toLowerCase());
    });

/// Voci senza orario della lista, ordinate per titolo.
List<ElementoAgenda> vociSenzaOrario(List<ElementoAgenda> elementi) => [
  for (final elemento in elementi)
    if (minutiDaOra(elemento.ora) == null) elemento,
]..sort((a, b) => a.titolo.toLowerCase().compareTo(b.titolo.toLowerCase()));

// ---------------------------------------------------------------------------
// Etichette e colori
// ---------------------------------------------------------------------------

/// Etichetta italiana dello stato di un task (`Completato`/`Da fare`).
String etichettaStatoTask(String? stato) {
  final chiave = stato?.trim().toLowerCase() ?? '';
  return chiave == 'completato' ? 'Completato' : 'Da fare';
}

/// Etichetta dello stato della voce, coerente con il suo tipo.
String etichettaStatoElemento(ElementoAgenda elemento) {
  if (elemento.isAppuntamento) {
    return etichettaStatoAppuntamento(elemento.appuntamento?.stato);
  }
  return etichettaStatoTask(elemento.task?.stato);
}

/// Etichetta della condivisione dell'appuntamento, oppure `null` se la voce è
/// un task o non è condivisa.
String? etichettaCondivisioneElemento(ElementoAgenda elemento) {
  final stato = elemento.appuntamento?.statoCondivisione;
  if (stato == null || stato == statoCondivisioneNonCondiviso) return null;
  return etichettaStatoCondivisione(stato);
}

/// Colore del badge di condivisione della voce.
Color coloreCondivisioneElemento(ElementoAgenda elemento) {
  switch (elemento.appuntamento?.statoCondivisione) {
    case statoCondivisioneConfermato:
      return AppColors.accettato;
    case statoCondivisioneRifiutato:
      return AppColors.errore;
    default:
      return AppColors.attesa;
  }
}

/// Colore del badge di stato della voce.
Color coloreStatoElemento(ElementoAgenda elemento) {
  final stato = elemento.isAppuntamento
      ? (elemento.appuntamento?.stato ?? '')
      : (elemento.task?.stato ?? '');
  switch (stato.trim().toLowerCase()) {
    case 'fatto':
    case 'completato':
      return AppColors.accettato;
    case 'annullato':
      return AppColors.errore;
    default:
      return AppColors.attesa;
  }
}

/// Riga secondaria della card: cliente e operatore, con `—` se assenti.
String dettaglioElemento(
  ElementoAgenda elemento,
  Map<String, String> nomiOperatori,
) {
  final parti = <String>[];
  final cliente =
      (elemento.appuntamento?.clienteNome ?? elemento.task?.clienteNome ?? '')
          .trim();
  if (cliente.isNotEmpty) parti.add(cliente);

  final operatoreId =
      (elemento.appuntamento?.operatoreId ?? elemento.task?.operatoreId ?? '')
          .trim();
  final operatore = nomiOperatori[operatoreId]?.trim() ?? '';
  if (operatore.isNotEmpty) parti.add(operatore);

  return parti.isEmpty ? '—' : parti.join(' · ');
}

/// Titolo visibile della voce: per un appuntamento privato non visibile a
/// [uid] diventa "Impegno privato".
String titoloVisibileElemento(ElementoAgenda elemento, String? uid) {
  final appuntamento = elemento.appuntamento;
  if (appuntamento == null) return elemento.titolo;
  return puoVedereDettagliAppuntamento(appuntamento, uid)
      ? elemento.titolo
      : 'Impegno privato';
}

/// Dettaglio visibile della voce: vuoto per gli appuntamenti privati non
/// visibili a [uid].
String dettaglioVisibileElemento(
  ElementoAgenda elemento,
  Map<String, String> nomiOperatori,
  String? uid,
) {
  final appuntamento = elemento.appuntamento;
  if (appuntamento != null &&
      !puoVedereDettagliAppuntamento(appuntamento, uid)) {
    return '—';
  }
  return dettaglioElemento(elemento, nomiOperatori);
}

/// Etichetta dell'orario della voce, con "Tutto il giorno" per gli
/// appuntamenti senza orario.
String etichettaOrarioElemento(ElementoAgenda elemento) {
  if (elemento.appuntamento?.tuttoIlGiorno == true) return 'Tutto il giorno';
  return elemento.ora ?? '—';
}

/// Data e ora della voce in formato italiano: `gg/mm/aaaa · HH:MM`.
///
/// Se l'ora manca resta la sola data; se la data non è interpretabile si
/// mostra il valore originale.
String etichettaDataOraElemento(ElementoAgenda elemento) {
  final grezza = elemento.data.trim();
  final iso = DateTime.tryParse(grezza);
  final data = iso == null ? grezza : formattaDataVisita(iso);
  final appuntamento = elemento.appuntamento;
  if (appuntamento?.tuttoIlGiorno == true) {
    return '$data · Tutto il giorno';
  }
  final ora = elemento.ora;
  if (ora == null) return data;
  final oraFine = appuntamento?.oraFine?.trim() ?? '';
  if (oraFine.isNotEmpty) return '$data · $ora–$oraFine';
  return '$data · $ora';
}

/// Azioni restituite dal dialogo di dettaglio della voce.
const String azioneModificaVoce = 'modifica';
const String azioneEliminaVoce = 'elimina';
const String azioneApriTaskVoce = 'apri-task';

/// Azioni di risposta a un invito di condivisione.
const String azioneConfermaInvitoVoce = 'conferma-invito';
const String azioneRifiutaInvitoVoce = 'rifiuta-invito';
