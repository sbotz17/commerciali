// Pianificazione degli avvisi all'operatore (appuntamenti, task, preventivi).
//
// Le funzioni di questo file sono pure: ricevono i modelli già letti da
// Firestore e calcolano *quando* avvisare, *chi* avvisare e *con quale testo*.
// Non scrivono su Firestore e non chiamano il Worker, così si possono
// verificare con i test senza Firebase.
//
// Un avviso viene consegnato su due canali indipendenti:
// - in-app: il client crea un documento `notifiche` quando l'ora è arrivata;
// - WhatsApp: il client registra l'avviso futuro nel Worker, che al momento
//   giusto invia il messaggio al numero dell'operatore.
//
// La chiave è deterministica (tipo + elemento + utente + ora): registrare due
// volte lo stesso avviso non produce duplicati.

import 'models/appuntamento.dart';
import 'models/preventivo.dart';
import 'models/task_item.dart';

/// Chiave delle preferenze: giorni di anticipo per i task (default 1).
const String chiaveAnticipoTask = 'anticipo_task_giorni';

/// Chiave delle preferenze: giorni di anticipo per i preventivi (default 3).
const String chiaveAnticipoPreventivo = 'anticipo_preventivo_giorni';

/// Anticipo predefinito per i task, in giorni.
const int anticipoTaskPredefinito = 1;

/// Anticipo predefinito per i preventivi, in giorni.
const int anticipoPreventivoPredefinito = 3;

/// Quanti giorni nel passato restano validi per un avviso in-app non ancora
/// creato: evita di riempire il centro notifiche con elementi vecchi.
const int giorniIndietroAvvisi = 7;

/// Quanti giorni nel futuro si registrano sul Worker.
const int giorniAvantiAvvisi = 90;

/// Legge un anticipo in giorni da una mappa di preferenze, con limiti sani.
int anticipoDaMappa(Map<String, dynamic>? dati, String chiave, int predefinito) {
  final valore = dati?[chiave];
  final numero = valore is num ? valore.toInt() : int.tryParse('$valore');
  if (numero == null) return predefinito;
  return numero.clamp(0, 30);
}

/// Un avviso calcolato per un singolo destinatario.
class AvvisoProgrammato {
  const AvvisoProgrammato({
    required this.tipo,
    required this.targetId,
    required this.utenteUid,
    required this.titolo,
    required this.testo,
    required this.quando,
  });

  /// Tipo dell'elemento: `appuntamento`, `task` o `preventivo`.
  final String tipo;

  /// Id dell'elemento collegato.
  final String targetId;

  /// Uid del destinatario.
  final String utenteUid;

  /// Titolo breve mostrato nel centro notifiche.
  final String titolo;

  /// Testo del messaggio (in-app e WhatsApp).
  final String testo;

  /// Momento in cui l'avviso deve partire (ora locale).
  final DateTime quando;

  /// Chiave deterministica, senza caratteri problematici per Firestore/KV.
  ///
  /// Stesso elemento + stesso destinatario + stessa ora = stessa chiave.
  String get chiave {
    final base = '$tipo:$targetId:$utenteUid:'
        '${quando.toUtc().toIso8601String().substring(0, 16)}';
    return base.replaceAll('/', '_').replaceAll(' ', '_');
  }

  /// Id del documento `notifiche` creato dal client.
  String get idDocumento => 'avviso_$chiave';

  /// Momento in UTC in formato ISO, usato dal Worker per la coda.
  String get quandoIso => quando.toUtc().toIso8601String();

  /// `true` se l'avviso è già scaduto (va mostrato subito in-app).
  bool scaduto(DateTime adesso) => !quando.isAfter(adesso);

  /// `true` se l'avviso è nel futuro e va registrato sul Worker.
  bool futuro(DateTime adesso) => quando.isAfter(adesso);
}

/// Scadenza di un task come data/ora locale; `null` se manca o non è valida.
DateTime? scadenzaTask(TaskItem task) {
  final giorno = _dataIso(task.scadenzaData);
  if (giorno == null) return null;
  final ora = _ora(task.scadenzaOra) ?? const (ora: 9, minuto: 0);
  return DateTime(giorno.year, giorno.month, giorno.day, ora.ora, ora.minuto);
}

/// Avvisi di un task: uno con l'anticipo scelto e uno alla scadenza.
///
/// Non produce nulla per i task completati o senza scadenza. Se l'anticipo è
/// zero resta solo l'avviso alla scadenza.
List<AvvisoProgrammato> avvisiTask(
  TaskItem task, {
  required String utenteUid,
  int anticipoGiorni = anticipoTaskPredefinito,
}) {
  final uid = utenteUid.trim();
  final scadenza = scadenzaTask(task);
  final id = task.id.trim();
  if (uid.isEmpty || id.isEmpty || scadenza == null) return const [];
  if (task.stato.trim().toLowerCase() == 'completato') return const [];

  final titoloTask = (task.titolo ?? '').trim();
  final nome = titoloTask.isEmpty ? 'Task' : titoloTask;
  final quando = '${_dataItaliana(scadenza)} alle ${_oraItaliana(scadenza)}';
  final avvisi = <AvvisoProgrammato>[];

  final anticipo = anticipoGiorni.clamp(0, 30);
  if (anticipo > 0) {
    final giornoAnticipo = DateTime(
      scadenza.year,
      scadenza.month,
      scadenza.day,
      9,
    ).subtract(Duration(days: anticipo));
    if (giornoAnticipo.isBefore(scadenza)) {
      avvisi.add(
        AvvisoProgrammato(
          tipo: 'task',
          targetId: id,
          utenteUid: uid,
          titolo: 'Task in scadenza: $nome',
          testo:
              'Closer · Task in scadenza\n"$nome" scade il $quando.',
          quando: giornoAnticipo,
        ),
      );
    }
  }

  avvisi.add(
    AvvisoProgrammato(
      tipo: 'task',
      targetId: id,
      utenteUid: uid,
      titolo: 'Task da completare: $nome',
      testo: 'Closer · Task da completare\n"$nome" scade il $quando.',
      quando: scadenza,
    ),
  );
  return avvisi;
}

/// Ultimo giorno di validità di un preventivo, alle 09:00 locali.
DateTime? scadenzaPreventivo(Preventivo preventivo) {
  final giorno = _dataIso(preventivo.validoFino);
  if (giorno == null) return null;
  return DateTime(giorno.year, giorno.month, giorno.day, 9);
}

/// Momento in cui il preventivo risulta scaduto: il giorno dopo la validità.
DateTime? scadutoDalPreventivo(Preventivo preventivo) {
  final ultimo = scadenzaPreventivo(preventivo);
  if (ultimo == null) return null;
  return DateTime(ultimo.year, ultimo.month, ultimo.day + 1, 9);
}

/// `true` se il preventivo ha una data di validità passata e non è già
/// accettato o rifiutato.
bool preventivoScaduto(Preventivo preventivo, {DateTime? adesso}) {
  final ultimo = scadenzaPreventivo(preventivo);
  if (ultimo == null || _statoChiusoPreventivo(preventivo.stato)) return false;
  final ora = adesso ?? DateTime.now();
  final oggi = DateTime(ora.year, ora.month, ora.day);
  final giorno = DateTime(ultimo.year, ultimo.month, ultimo.day);
  return giorno.isBefore(oggi);
}

/// Avvisi di un preventivo: uno con l'anticipo scelto e uno alla scadenza.
///
/// Non produce nulla per preventivi senza validità o già chiusi (accettato,
/// rifiutato, annullato).
List<AvvisoProgrammato> avvisiPreventivo(
  Preventivo preventivo, {
  required String utenteUid,
  int anticipoGiorni = anticipoPreventivoPredefinito,
}) {
  final uid = utenteUid.trim();
  final scadenza = scadenzaPreventivo(preventivo);
  final id = preventivo.id.trim();
  if (uid.isEmpty || id.isEmpty || scadenza == null) return const [];
  if (_statoChiusoPreventivo(preventivo.stato)) return const [];

  final numero = (preventivo.numero ?? '').trim();
  final nome = numero.isEmpty ? 'Preventivo' : 'Preventivo $numero';
  final giorno = _dataItaliana(scadenza);
  final scaduto = scadutoDalPreventivo(preventivo) ?? scadenza;
  final avvisi = <AvvisoProgrammato>[];

  final anticipo = anticipoGiorni.clamp(0, 30);
  if (anticipo > 0) {
    final giornoAnticipo = scadenza.subtract(Duration(days: anticipo));
    avvisi.add(
      AvvisoProgrammato(
        tipo: 'preventivo',
        targetId: id,
        utenteUid: uid,
        titolo: '$nome in scadenza',
        testo: 'Closer · Preventivo in scadenza\n$nome scade il $giorno.',
        quando: giornoAnticipo,
      ),
    );
  }

  avvisi.add(
    AvvisoProgrammato(
      tipo: 'preventivo',
      targetId: id,
      utenteUid: uid,
      titolo: '$nome scaduto',
      testo: 'Closer · Preventivo scaduto\n$nome è scaduto il $giorno.',
      quando: scaduto,
    ),
  );
  return avvisi;
}

/// Avvisi degli appuntamenti con `notifica_min` configurata.
///
/// Considera le occorrenze (anche ricorrenti) tra [giorniIndietro] giorni nel
/// passato e [giorniAvanti] nel futuro, per ogni destinatario in
/// [utenteUids]. Gli appuntamenti annullati non producono avvisi.
List<AvvisoProgrammato> avvisiAppuntamento(
  Appuntamento appuntamento, {
  required List<String> utenteUids,
  DateTime? adesso,
  int giorniIndietro = giorniIndietroAvvisi,
  int giorniAvanti = giorniAvantiAvvisi,
}) {
  final minuti = appuntamento.notificaMin;
  final id = appuntamento.id.trim();
  final destinatari = {
    for (final uid in utenteUids)
      if (uid.trim().isNotEmpty) uid.trim(),
  };
  if (minuti == null || minuti < 0 || id.isEmpty || destinatari.isEmpty) {
    return const [];
  }
  final stato = appuntamento.stato.trim().toLowerCase();
  if (stato == 'annullato' || stato == 'fatto') return const [];

  final ora = DateTime.now();
  final oraAdesso = adesso ?? ora;
  final giorni = occorrenzeAppuntamento(
    appuntamento,
    dal: oraAdesso.subtract(Duration(days: giorniIndietro)),
    al: oraAdesso.add(Duration(days: giorniAvanti)),
  );
  if (giorni.isEmpty) return const [];

  final titoloVisibile = appuntamento.privato
      ? 'Impegno privato'
      : ((appuntamento.titolo ?? '').trim().isEmpty
            ? 'Appuntamento'
            : appuntamento.titolo!.trim());
  final avvisi = <AvvisoProgrammato>[];
  for (final giorno in giorni) {
    final inizio = appuntamento.tuttoIlGiorno
        ? DateTime(giorno.year, giorno.month, giorno.day, 9)
        : _combina(giorno, appuntamento.ora) ??
              DateTime(giorno.year, giorno.month, giorno.day, 9);
    final quando = inizio.subtract(Duration(minutes: minuti));
    final orario = appuntamento.tuttoIlGiorno
        ? ' (tutto il giorno)'
        : appuntamento.ora == null
        ? ''
        : ' alle ${appuntamento.ora}';
    final testo =
        'Closer · Promemoria\n"$titoloVisibile" il '
        '${_dataItaliana(giorno)}$orario.';
    for (final uid in destinatari) {
      avvisi.add(
        AvvisoProgrammato(
          tipo: 'appuntamento',
          targetId: id,
          utenteUid: uid,
          titolo: 'Promemoria: $titoloVisibile',
          testo: testo,
          quando: quando,
        ),
      );
    }
  }
  return avvisi;
}

/// Tiene gli avvisi non ancora inviati da mostrare in-app: scaduti da non più
/// di [giorniIndietro] giorni.
List<AvvisoProgrammato> avvisiDaMostrare(
  List<AvvisoProgrammato> avvisi, {
  DateTime? adesso,
  int giorniIndietro = giorniIndietroAvvisi,
}) {
  final ora = adesso ?? DateTime.now();
  final limite = ora.subtract(Duration(days: giorniIndietro));
  return [
    for (final avviso in avvisi)
      if (avviso.scaduto(ora) && avviso.quando.isAfter(limite)) avviso,
  ];
}

/// Tiene gli avvisi futuri da registrare sul Worker, entro [giorniAvanti].
List<AvvisoProgrammato> avvisiDaRegistrare(
  List<AvvisoProgrammato> avvisi, {
  DateTime? adesso,
  int giorniAvanti = giorniAvantiAvvisi,
}) {
  final ora = adesso ?? DateTime.now();
  final limite = ora.add(Duration(days: giorniAvanti));
  return [
    for (final avviso in avvisi)
      if (avviso.futuro(ora) && avviso.quando.isBefore(limite)) avviso,
  ];
}

bool _statoChiusoPreventivo(String stato) {
  switch (stato.trim().toLowerCase()) {
    case 'accettato':
    case 'rifiutato':
    case 'annullato':
      return true;
    default:
      return false;
  }
}

DateTime? _dataIso(String? valore) {
  final testo = (valore ?? '').trim();
  if (testo.isEmpty) return null;
  final data = DateTime.tryParse(testo);
  if (data == null) return null;
  return DateTime(data.year, data.month, data.day);
}

({int ora, int minuto})? _ora(String? valore) {
  final testo = (valore ?? '').trim();
  final trovata = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(testo);
  if (trovata == null) return null;
  final ora = int.tryParse(trovata.group(1)!);
  final minuto = int.tryParse(trovata.group(2)!);
  if (ora == null || minuto == null) return null;
  if (ora < 0 || ora > 23 || minuto < 0 || minuto > 59) return null;
  return (ora: ora, minuto: minuto);
}

DateTime? _combina(DateTime giorno, String? ora) {
  final parti = _ora(ora);
  if (parti == null) return null;
  return DateTime(giorno.year, giorno.month, giorno.day, parti.ora, parti.minuto);
}

String _dataItaliana(DateTime data) {
  final giorno = data.day.toString().padLeft(2, '0');
  final mese = data.month.toString().padLeft(2, '0');
  return '$giorno/$mese/${data.year}';
}

String _oraItaliana(DateTime data) {
  final ora = data.hour.toString().padLeft(2, '0');
  final minuto = data.minute.toString().padLeft(2, '0');
  return '$ora:$minuto';
}
