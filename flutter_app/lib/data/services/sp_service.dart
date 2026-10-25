import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/allegato.dart';
import '../models/appuntamento.dart';
import '../models/azienda.dart';
import '../models/bando.dart';
import '../models/categoria.dart';
import '../models/cliente.dart';
import '../models/condivisione_calendario.dart';
import '../models/fonte_bando.dart';
import '../models/integrazione_azienda.dart';
import '../models/licenza.dart';
import '../models/messaggio_chat.dart';
import '../models/notifica.dart';
import '../models/preventivo.dart';
import '../models/stanza_chat.dart';
import '../models/prodotto.dart';
import '../models/ruolo.dart';
import '../models/task_item.dart';
import '../models/user_profile.dart';
import '../models/visita.dart';

/// Filtra una lista di id "figli" per il payload Firestore.
///
/// Accetta una lista (o `null`), tiene solo le stringhe non vuote dopo trim,
/// elimina i duplicati e l'eventuale [escludiId], mantenendo l'ordine.
List<String> sanificaFigliIds(dynamic valore, {String? escludiId}) {
  if (valore is! List) return const [];
  final visti = <String>{};
  final risultato = <String>[];
  for (final elemento in valore) {
    if (elemento is! String) continue;
    final s = elemento.trim();
    if (s.isEmpty) continue;
    if (escludiId != null && s == escludiId) continue;
    if (!visti.add(s)) continue;
    risultato.add(s);
  }
  return risultato;
}

/// Suddivide [elementi] in blocchi consecutivi di al più [dimensione]
/// elementi. Utile per limitare la grandezza delle batch Firestore.
List<List<T>> aBlocchi<T>(List<T> elementi, int dimensione) {
  if (dimensione <= 0) {
    throw ArgumentError.value(dimensione, 'dimensione', 'Deve essere > 0');
  }
  final blocchi = <List<T>>[];
  for (var i = 0; i < elementi.length; i += dimensione) {
    final fine = i + dimensione < elementi.length
        ? i + dimensione
        : elementi.length;
    blocchi.add(elementi.sublist(i, fine));
  }
  return blocchi;
}

/// Deriva la chiave stabile di un ruolo dal [nome] visibile.
///
/// Ripulisce (trim), normalizza in minuscolo, sostituisce spazi e caratteri
/// non alfanumerici con `_`, elimina gli underscore iniziali/finali e quelli
/// doppi; se il risultato è vuoto usa `ruolo`.
String chiaveRuoloDaNome(String nome) {
  var s = nome.trim().toLowerCase();
  s = s.replaceAll(RegExp('[^a-z0-9]+'), '_');
  s = s.replaceAll(RegExp('_+'), '_');
  s = s.replaceAll(RegExp('^_+|_+\$'), '');
  return s.isEmpty ? 'ruolo' : s;
}

/// Filtra una lista di appuntamenti per intervallo di date e operatore.
///
/// [dal] e [al] sono estremi inclusivi, confrontati sul `DateTime` ottenuto da
/// [dataOraAppuntamento] (data + ora). Se [dal] o [al] è indicato, gli
/// appuntamenti senza data/ora valida vengono esclusi. [operatoreId] filtra
/// per `operatoreId`. I filtri sono opzionali e si applicano in AND.
List<Appuntamento> filtraAppuntamenti(
  List<Appuntamento> appuntamenti, {
  DateTime? dal,
  DateTime? al,
  String? operatoreId,
}) {
  final haIntervallo = dal != null || al != null;
  return appuntamenti.where((a) {
    if (operatoreId != null && a.operatoreId != operatoreId) return false;
    if (haIntervallo) {
      final dt = dataOraAppuntamento(a);
      if (dt == null) return false;
      if (dal != null && dt.isBefore(dal)) return false;
      if (al != null && dt.isAfter(al)) return false;
    }
    return true;
  }).toList();
}

/// Filtra una lista di task per stato (aperti) e operatore.
///
/// [soloAperti] `true` tiene solo i task con `stato == 'aperto'`;
/// [operatoreId] filtra per `operatoreId`. I filtri sono opzionali e in AND.
List<TaskItem> filtraTask(
  List<TaskItem> task, {
  bool? soloAperti,
  String? operatoreId,
}) {
  return task.where((t) {
    if (operatoreId != null && t.operatoreId != operatoreId) return false;
    if (soloAperti == true && t.stato != 'aperto') return false;
    return true;
  }).toList();
}

/// Ordina una lista di task per scadenza crescente, con gli elementi senza
/// scadenza in fondo; a parità di scadenza mette prima i task `urgente`.
///
/// Restituisce una nuova lista (non muta quella in ingresso).
List<TaskItem> ordinaTask(List<TaskItem> task) {
  final ordinati = [...task];
  ordinati.sort((a, b) {
    final da = dataOraTask(a);
    final db = dataOraTask(b);
    if (da != null && db != null) {
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
    } else if (da != null) {
      return -1;
    } else if (db != null) {
      return 1;
    }
    final pa = a.priorita == 'urgente' ? 1 : 0;
    final pb = b.priorita == 'urgente' ? 1 : 0;
    return pb.compareTo(pa);
  });
  return ordinati;
}

/// Filtra le notifiche non ancora lette (`lettaAt` assente o vuoto), come
/// [notificaNonLetta].
List<Notifica> filtraNotificheNonLette(List<Notifica> notifiche) {
  return notifiche.where(notificaNonLetta).toList();
}

/// Ordina una lista di notifiche per `createdAt` discendente (le più recenti
/// per prime), con le notifiche senza data in fondo.
///
/// Restituisce una nuova lista (non muta quella in ingresso).
List<Notifica> ordinaNotifiche(List<Notifica> notifiche) {
  final ordinate = [...notifiche];
  ordinate.sort((a, b) {
    final da = a.createdAt;
    final db = b.createdAt;
    if (da != null && db != null) {
      final cmp = db.compareTo(da);
      if (cmp != 0) return cmp;
    } else if (da != null) {
      return -1;
    } else if (db != null) {
      return 1;
    }
    return 0;
  });
  return ordinate;
}

/// Ordina una lista di stanze chat per `updatedAt` discendente (le più
/// recenti per prime), con le stanze senza `updatedAt` in fondo.
///
/// Restituisce una nuova lista (non muta quella in ingresso).
List<StanzaChat> ordinaStanzeChat(List<StanzaChat> stanze) {
  final ordinate = [...stanze];
  ordinate.sort((a, b) {
    final da = a.updatedAt;
    final db = b.updatedAt;
    if (da != null && db != null) {
      final cmp = db.compareTo(da);
      if (cmp != 0) return cmp;
    } else if (da != null) {
      return -1;
    } else if (db != null) {
      return 1;
    }
    return 0;
  });
  return ordinate;
}

/// Normalizza le impostazioni dell'agenda aziendale.
///
/// Accetta chiavi snake_case o camelCase; valida gli interi positivi e gli
/// orari `HH:MM`: i valori invalidi ricadono sul default. Restituisce sempre
/// una mappa completa con chiavi snake_case.
Map<String, dynamic> normalizzaImpostazioniAgenda(Map<String, dynamic> dati) {
  /// Valore testuale ripulito (trim), con [fallback] se vuoto o assente.
  String stringa(dynamic valore, String fallback) {
    final s = (valore?.toString() ?? '').trim();
    return s.isEmpty ? fallback : s;
  }

  /// Legge un valore accettando sia la chiave snake_case sia quella camelCase
  /// (la prima, se presente, ha la precedenza).
  dynamic val(String snake, String camel) =>
      dati.containsKey(snake) ? dati[snake] : dati[camel];

  /// Intero strettamente positivo; i valori nulli, non numerici o <= 0
  /// ricadono su [fallback].
  int interoPositivo(String snake, String camel, int fallback) {
    final v = val(snake, camel);
    int? n;
    if (v is int) {
      n = v;
    } else if (v is num) {
      n = v.toInt();
    } else if (v != null) {
      n = int.tryParse(v.toString().trim());
    }
    return (n == null || n <= 0) ? fallback : n;
  }

  /// Orario in formato `HH:MM`; gli orari non conformi ricadono su [fallback].
  String orario(String snake, String camel, String fallback) {
    final s = stringa(val(snake, camel), '');
    final m = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').firstMatch(s);
    return m == null ? fallback : s;
  }

  /// Booleano; i valori non booleani ricadono su [fallback].
  bool booleano(String snake, String camel, bool fallback) {
    final v = val(snake, camel);
    return v is bool ? v : fallback;
  }

  return <String, dynamic>{
    'fuso_orario': stringa(val('fuso_orario', 'fusoOrario'), 'Europe/Rome'),
    'anticipo_min': interoPositivo('anticipo_min', 'anticipoMin', 1440),
    'orario_invio_cliente': orario(
      'orario_invio_cliente',
      'orarioInvioCliente',
      '18:00',
    ),
    'canale_cliente': stringa(
      val('canale_cliente', 'canaleCliente'),
      'whatsapp',
    ),
    'slot_durata_min': interoPositivo('slot_durata_min', 'slotDurataMin', 60),
    'slot_finestra_giorni': interoPositivo(
      'slot_finestra_giorni',
      'slotFinestraGiorni',
      14,
    ),
    'slot_scadenza_giorni': interoPositivo(
      'slot_scadenza_giorni',
      'slotScadenzaGiorni',
      7,
    ),
    'allegati_max_kb': interoPositivo('allegati_max_kb', 'allegatiMaxKb', 5120),
    'allegati_max': interoPositivo('allegati_max', 'allegatiMax', 10),
    'maps_attivo': booleano('maps_attivo', 'mapsAttivo', true),
  };
}

/// Verifica che una condivisione di calendario sia valida.
///
/// I due uid devono essere non vuoti (dopo trim) e diversi tra loro; il
/// [livello] deve appartenere a [livelliCondivisione].
bool condivisioneCalendarioValida({
  required String? proprietarioUid,
  required String? destinatarioUid,
  required String? livello,
}) {
  final proprietario = proprietarioUid?.trim() ?? '';
  final destinatario = destinatarioUid?.trim() ?? '';
  if (proprietario.isEmpty || destinatario.isEmpty) return false;
  if (proprietario == destinatario) return false;
  return livelliCondivisione.contains(livello);
}

/// Filtra una lista di condivisioni tenendo solo quelle attive.
List<CondivisioneCalendario> condivisioniAttive(
  List<CondivisioneCalendario> condivisioni,
) {
  return condivisioni.where((c) => c.attiva).toList();
}

/// Compara due condivisioni per `createdAt` discendente (le più recenti per
/// prime), con i valori assenti in fondo.
int confrontaCondivisioniPerData(
  CondivisioneCalendario a,
  CondivisioneCalendario b,
) {
  final da = a.createdAt;
  final db = b.createdAt;
  if (da != null && db != null) {
    final cmp = db.compareTo(da);
    if (cmp != 0) return cmp;
  } else if (da != null) {
    return -1;
  } else if (db != null) {
    return 1;
  }
  return 0;
}

/// Normalizza un numero WhatsApp in sole cifre (prefisso internazionale
/// incluso), così il server riceve sempre un valore pulito.
String normalizzaNumeroWhatsapp(String? numero) =>
    (numero ?? '').replaceAll(RegExp(r'\D'), '');

/// Normalizza la risposta del server WhatsApp.
///
/// Il server storico usa `connesso` e `numero`; la schermata usa
/// `connected` e `number`. Accetta entrambi senza perdere gli altri campi.
Map<String, dynamic> normalizzaStatoWhatsapp(Map<String, dynamic> dati) {
  final connected =
      dati['connected'] == true ||
      dati['connesso'] == true ||
      dati['stato'] == 'aperta';
  final numero = dati['number'] ?? dati['numero'];
  return {
    ...dati,
    'connected': connected,
    if (numero != null) 'number': numero.toString(),
  };
}

/// URL `/send` del server WhatsApp a partire dall'indirizzo configurato.
///
/// Ritorna `null` se l'indirizzo è vuoto, non è http/https o non è valido.
Uri? uriInvioWhatsapp(String? indirizzo) {
  final base = (indirizzo ?? '').trim().replaceAll(RegExp(r'/+$'), '');
  if (base.isEmpty) return null;
  final uri = Uri.tryParse('$base/send');
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return uri;
}

/// Base del Worker Cloudflare che fa da proxy autenticato verso il server
/// WhatsApp (la API key resta nel KV del Worker).
const String workerWhatsappBase =
    'https://commerciali-vies.bottiandrea83.workers.dev';

/// Worker Cloudflare di produzione, con il progetto Firebase di produzione.
const String workerWhatsappBaseProd =
    'https://commerciali-vies-prod.bottiandrea83.workers.dev';

/// Sceglie il Worker dell'ambiente: staging è il default, `APP_ENV=prod`
/// usa il Worker collegato a `commerciali-prod`.
String workerWhatsappBasePerAmbiente(String ambiente) =>
    ambiente == 'prod' ? workerWhatsappBaseProd : workerWhatsappBase;

String get _workerWhatsappBase => workerWhatsappBasePerAmbiente(
  const String.fromEnvironment('APP_ENV', defaultValue: 'staging'),
);

/// Dati non riservati di un appuntamento privato, salvati nel documento
/// principale leggibile dall'azienda.
Map<String, dynamic> redigiAppuntamentoPrivato(Map<String, dynamic> payload) {
  return {
    ...payload,
    'titolo': 'Impegno privato',
    'cliente_id': null,
    'cliente_nome': '',
    'luogo': null,
    'indirizzo': null,
    'note': null,
    'call_provider': null,
    'call_url': null,
  };
}

/// Dettagli riservati di un appuntamento privato, salvati nella sotto-collezione
/// `appuntamenti/{id}/privato/dettagli`.
Map<String, dynamic> dettagliPrivatiAppuntamento(Map<String, dynamic> payload) {
  return {
    'titolo': payload['titolo'],
    'cliente_id': payload['cliente_id'],
    'cliente_nome': payload['cliente_nome'],
    'luogo': payload['luogo'],
    'indirizzo': payload['indirizzo'],
    'note': payload['note'],
    'call_provider': payload['call_provider'],
    'call_url': payload['call_url'],
  };
}

/// Servizio dati base dell'app Flutter, porting dell'interfaccia `SP` della
/// vecchia app (sottoinsieme aziende/membri/profilo).
///
/// Incapsula `FirebaseFirestore`; per l'uid dell'utente corrente usa
/// `FirebaseAuth.instance.currentUser`, coerente con la vecchia app.
/// Nessuna UI: viene iniettato dai provider e usato dagli strati superiori.
///
/// Le scritture riproducono esattamente i campi della vecchia app
/// (`js/sp-firestore.js`) così da restare compatibili con `firestore.rules`
/// e con i dati già esistenti.
class SpService {
  SpService(this._firestore);

  final FirebaseFirestore _firestore;

  String? _aziendaAttiva;

  String _now() => DateTime.now().toIso8601String();

  /// Data `YYYY-MM-DD` (stessa granularità della vecchia app per le licenze).
  String _data(DateTime d) => d.toIso8601String().substring(0, 10);

  // ---------- azienda attiva ----------

  /// Imposta l'id dell'azienda attiva (memoria locale, come `SP.setAziendaAttiva`).
  void setAziendaAttiva(String? id) => _aziendaAttiva = id;

  /// Id dell'azienda attiva, `null` se non selezionata.
  String? getAziendaAttiva() => _aziendaAttiva;

  /// Blocca le scritture se l'azienda attiva non è impostata.
  ///
  /// Evita di inviare documenti con `azienda_id: null`, che Firestore
  /// rifiuterebbe con `permission-denied`.
  void _richiediAzienda() {
    if (_aziendaAttiva == null) {
      throw StateError(
        'Nessuna azienda attiva. Seleziona un\'azienda e riprova.',
      );
    }
  }

  // ---------- aziende / membri ----------

  /// Elenco delle aziende a cui l'utente appartiene.
  ///
  /// Legge `membri` filtrando per [uid] (`utente_id`), poi legge i documenti
  /// `aziende/{azienda_id}` in parallelo e fonde il ruolo della membership.
  Future<List<Azienda>> getAziendeUtente(String uid) async {
    final membri = await _firestore
        .collection('membri')
        .where('utente_id', isEqualTo: uid)
        .get();

    final aziende = await Future.wait(
      membri.docs.map((m) async {
        final aziendaId = m.data()['azienda_id'] as String?;
        if (aziendaId == null) return null;
        final az = await _firestore.collection('aziende').doc(aziendaId).get();
        if (!az.exists) return null;
        return Azienda.fromMap({
          ...az.data()!,
          'ruolo': m.data()['ruolo'],
        }, id: az.id);
      }),
    );

    return aziende.whereType<Azienda>().toList();
  }

  /// Rinomina l'azienda con [id] impostando il campo `nome` (trim) e
  /// `updated_at`. Non fa nulla se il nome, dopo il trim, è vuoto.
  Future<void> rinominaAzienda(String id, String nome) async {
    final n = nome.trim();
    if (n.isEmpty) return;
    await _firestore.collection('aziende').doc(id).update({
      'nome': n,
      'updated_at': _now(),
    });
  }

  // ---------- profilo ----------

  /// Garantisce l'esistenza del profilo `utenti/{uid}` per l'[email].
  ///
  /// Cerca `utenti` per email; se esiste lo restituisce, altrimenti crea
  /// `utenti/{uid}` (uid da `FirebaseAuth.instance.currentUser`) con i campi
  /// base della vecchia app. Ritorna `null` se l'email è vuota o non c'è un
  /// utente autenticato.
  Future<UserProfile?> assicuraProfilo(String email, String nome) async {
    final em = email.trim().toLowerCase();
    if (em.isEmpty) return null;

    final q = await _firestore
        .collection('utenti')
        .where('email', isEqualTo: em)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) {
      final d = q.docs.first;
      return UserProfile.fromMap(d.data(), id: d.id);
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final username = em.split('@').first;
    final nomeFinale = nome.trim().isEmpty ? username : nome.trim();
    final payload = <String, dynamic>{
      'username': username,
      'email': em,
      'nome': nomeFinale,
      'ruolo': 'admin',
      'attivo': true,
      'created_at': _now(),
    };
    await _firestore
        .collection('utenti')
        .doc(uid)
        .set(payload, SetOptions(merge: true));
    return UserProfile.fromMap(payload, id: uid);
  }

  /// Cerca il profilo `utenti` con l'[email] normalizzata (trim + lowercase).
  ///
  /// Ritorna il primo risultato o `null` se l'email è vuota o nessun profilo
  /// corrisponde.
  Future<UserProfile?> getUtentePerEmail(String email) async {
    final em = email.trim().toLowerCase();
    if (em.isEmpty) return null;
    final q = await _firestore
        .collection('utenti')
        .where('email', isEqualTo: em)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    final d = q.docs.first;
    return UserProfile.fromMap(d.data(), id: d.id);
  }

  // ---------- creazione azienda / membri / seed ----------

  /// Crea un documento `aziende` con `created_by`, `created_at` e l'anagrafica
  /// base (stessi campi della vecchia app). Ritorna `{id, ...campi}`.
  Future<Map<String, dynamic>> creaAzienda(Map<String, dynamic> dati) async {
    final payload = <String, dynamic>{
      'nome': ((dati['nome'] as String?) ?? 'La mia azienda').trim(),
      'created_at': _now(),
      'created_by': FirebaseAuth.instance.currentUser?.uid,
    };
    const anagrafica = [
      'partita_iva',
      'codice_fiscale',
      'indirizzo',
      'comune',
      'provincia',
      'cap',
      'telefono',
      'email',
      'pec',
    ];
    for (final k in anagrafica) {
      final v = dati[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        payload[k] = v.toString().trim();
      }
    }
    final ref = await _firestore.collection('aziende').add(payload);
    return {'id': ref.id, ...payload};
  }

  /// Aggiunge (o aggiorna) la membership `membri/{aziendaId}_{utenteId}`.
  Future<void> aggiungiMembro(String aziendaId, String utenteId, String ruolo) {
    return _firestore.collection('membri').doc('${aziendaId}_$utenteId').set({
      'azienda_id': aziendaId,
      'utente_id': utenteId,
      'ruolo': ruolo,
      'created_at': _now(),
    }, SetOptions(merge: true));
  }

  /// Popola un'azienda nuova: 2 ruoli di sistema, 3 categorie e licenza trial.
  ///
  /// Stessi dati della vecchia app (`SP.seedAzienda`) in un'unica batch.
  Future<void> seedAzienda(String aziendaId) async {
    final batch = _firestore.batch();

    final ruoli = <Map<String, dynamic>>[
      {
        'nome': 'Amministratore',
        'chiave': 'admin',
        'descrizione': 'Accesso completo',
        'sconto_max': 100,
        'sistema': true,
        'permessi': <String, String>{
          'dashboard': 'entrambi',
          'listino': 'entrambi',
          'gestione_prodotti': 'entrambi',
          'preventivi_propri': 'entrambi',
          'preventivi_tutti': 'entrambi',
          'approva_preventivi': 'entrambi',
          'clienti': 'entrambi',
          'bandi': 'entrambi',
          'gestione_categorie': 'entrambi',
          'gestione_utenti': 'entrambi',
          'gestione_ruoli': 'entrambi',
          'impostazioni': 'entrambi',
        },
      },
      {
        'nome': 'Commerciale',
        'chiave': 'commerciale',
        'descrizione': 'Accesso operativo',
        'sconto_max': 20,
        'sistema': true,
        'permessi': <String, String>{
          'dashboard': 'lettura',
          'listino': 'lettura',
          'preventivi_propri': 'entrambi',
          'clienti': 'entrambi',
          'bandi': 'lettura',
        },
      },
    ];
    for (final r in ruoli) {
      batch.set(_firestore.collection('ruoli').doc(), {
        ...r,
        'azienda_id': aziendaId,
        'created_at': _now(),
      });
    }

    final categorie = <Map<String, dynamic>>[
      {'nome': 'software', 'icona': '💻', 'ordine': 1},
      {'nome': 'servizi', 'icona': '🛠️', 'ordine': 2},
      {'nome': 'hardware', 'icona': '🖥️', 'ordine': 3},
    ];
    for (final c in categorie) {
      batch.set(_firestore.collection('categorie').doc(), {
        ...c,
        'azienda_id': aziendaId,
        'created_at': _now(),
      });
    }

    final oggi = DateTime.now();
    final fine = oggi.add(const Duration(days: 14));
    batch.set(_firestore.collection('licenze').doc(aziendaId), {
      'azienda_id': aziendaId,
      'piano': 'trial',
      'stato': 'attiva',
      'data_inizio': _data(oggi),
      'data_fine': _data(fine),
      'max_utenti': 2,
      'max_preventivi': 20,
      'updated_at': _now(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // ---------- utenti / membri ----------

  /// Elenco degli utenti membri dell'azienda attiva, con il relativo [ruolo].
  ///
  /// Legge `membri` filtrando per `azienda_id`, poi legge i profili `utenti`
  /// in parallelo e fonde il ruolo della membership (come `SP.getUtenti`).
  /// Ritorna una lista vuota se non è impostata un'azienda attiva.
  Future<List<UserProfile>> getUtenti() async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return [];
    final membri = await _firestore
        .collection('membri')
        .where('azienda_id', isEqualTo: aziendaId)
        .get();

    final utenti = await Future.wait(
      membri.docs.map((m) async {
        final uid = m.data()['utente_id'] as String?;
        if (uid == null) return null;
        final u = await _firestore.collection('utenti').doc(uid).get();
        if (!u.exists) return null;
        return UserProfile.fromMap({
          ...u.data()!,
          'ruolo': m.data()['ruolo'],
        }, id: u.id);
      }),
    );

    return utenti.whereType<UserProfile>().toList();
  }

  /// Aggiorna il [ruolo] del membro [uid] nell'azienda attiva.
  ///
  /// Scrive `membri/{aziendaId}_{uid}` con merge, riproducendo i campi della
  /// vecchia app (`SP.aggiornaUtente`). Non fa nulla senza azienda attiva.
  Future<void> aggiornaRuoloUtente(String uid, String ruolo) {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return Future.value();
    return _firestore.collection('membri').doc('${aziendaId}_$uid').set({
      'azienda_id': aziendaId,
      'utente_id': uid,
      'ruolo': ruolo,
    }, SetOptions(merge: true));
  }

  /// Elimina la membership `membri/{aziendaId}_{uid}` del membro [uid]
  /// nell'azienda attiva (come `SP.eliminaUtente`). Non fa nulla senza
  /// azienda attiva.
  Future<void> eliminaMembro(String uid) {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return Future.value();
    return _firestore.collection('membri').doc('${aziendaId}_$uid').delete();
  }

  // ---------- ruoli ----------

  /// Elenco dei ruoli dell'azienda attiva, ordinati lato client per [nome]
  /// (come `SP.getRuoli`). Ritorna una lista vuota se non è impostata
  /// un'azienda attiva.
  Future<List<Ruolo>> getRuoli() async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return [];
    final snap = await _firestore
        .collection('ruoli')
        .where('azienda_id', isEqualTo: aziendaId)
        .get();
    final ruoli = snap.docs
        .map((d) => Ruolo.fromMap(d.data(), id: d.id))
        .toList();
    ruoli.sort((a, b) => a.nome.compareTo(b.nome));
    return ruoli;
  }

  /// Crea un ruolo nell'azienda attiva (come `SP.inserisciRuolo`).
  ///
  /// Richiede un'azienda attiva; scrive `azienda_id`, `nome` (trim), `chiave`
  /// (da [chiaveRuoloDaNome]), `descrizione`, `sconto_max`, `permessi` (solo i
  /// valori non vuoti), `sistema: false` e `created_at`. Ritorna
  /// `{id, ...payload}`.
  Future<Map<String, dynamic>> inserisciRuolo({
    required String nome,
    String descrizione = '',
    int scontoMax = 0,
    Map<String, String> permessi = const {},
  }) async {
    _richiediAzienda();
    final payload = <String, dynamic>{
      'azienda_id': _aziendaAttiva,
      'nome': nome.trim(),
      'chiave': chiaveRuoloDaNome(nome),
      'descrizione': descrizione.trim(),
      'sconto_max': scontoMax,
      'permessi': _permessiRuolo(permessi),
      'sistema': false,
      'created_at': _now(),
    };
    final ref = await _firestore.collection('ruoli').add(payload);
    return {'id': ref.id, ...payload};
  }

  /// Aggiorna il ruolo [id] limitandosi ai campi modificabili.
  ///
  /// Scrive solo `nome` (trim), `descrizione`, `sconto_max`, `permessi` (solo i
  /// valori non vuoti) e `updated_at`; non tocca `azienda_id`, `chiave` o
  /// `sistema`.
  Future<void> aggiornaRuolo(
    String id, {
    required String nome,
    String descrizione = '',
    int scontoMax = 0,
    Map<String, String> permessi = const {},
  }) {
    return _firestore.collection('ruoli').doc(id).update({
      'nome': nome.trim(),
      'descrizione': descrizione.trim(),
      'sconto_max': scontoMax,
      'permessi': _permessiRuolo(permessi),
      'updated_at': _now(),
    });
  }

  /// Elimina il ruolo con l'[id] indicato.
  Future<void> eliminaRuolo(String id) {
    return _firestore.collection('ruoli').doc(id).delete();
  }

  // ---------- licenza ----------

  /// Legge la licenza dell'azienda attiva da `licenze/{aziendaId}`.
  ///
  /// Ritorna `null` se non è impostata un'azienda attiva o il documento non
  /// esiste.
  Future<Licenza?> getLicenzaAzienda() async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return null;
    final snap = await _firestore.collection('licenze').doc(aziendaId).get();
    final dati = snap.data();
    if (!snap.exists || dati == null) return null;
    return Licenza.fromMap(dati, id: snap.id);
  }

  // ---------- super admin ----------

  /// Elenco di tutte le aziende, ordinato lato client per [nome] (per il
  /// super admin, come `SP.getTutteAziende` senza l'arricchimento
  /// membri/licenza).
  Future<List<Azienda>> getTutteAziende() async {
    final snap = await _firestore.collection('aziende').get();
    final aziende = snap.docs
        .map((d) => Azienda.fromMap(d.data(), id: d.id))
        .toList();
    aziende.sort((a, b) => a.nome.compareTo(b.nome));
    return aziende;
  }

  // ---------- clienti ----------

  /// Elenco dei clienti dell'azienda attiva, ordinati lato client per [nome].
  ///
  /// Ritorna una lista vuota se non è impostata un'azienda attiva.
  Future<List<Cliente>> getClienti() async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return [];
    final snap = await _firestore
        .collection('clienti')
        .where('azienda_id', isEqualTo: aziendaId)
        .get();
    final clienti = snap.docs
        .map((d) => Cliente.fromMap(d.data(), id: d.id))
        .toList();
    clienti.sort((a, b) => (a.nome ?? '').compareTo(b.nome ?? ''));
    return clienti;
  }

  /// Legge un singolo cliente dell'azienda attiva.
  ///
  /// Ritorna `null` se non esiste o se non appartiene all'azienda attiva.
  Future<Cliente?> getCliente(String id) async {
    final aziendaId = _aziendaAttiva;
    final clienteId = id.trim();
    if (aziendaId == null || clienteId.isEmpty) return null;
    final snap = await _firestore.collection('clienti').doc(clienteId).get();
    final dati = snap.data();
    if (!snap.exists || dati == null) return null;
    if ((dati['azienda_id'] ?? '').toString() != aziendaId) return null;
    return Cliente.fromMap(dati, id: snap.id);
  }

  /// Cerca un cliente duplicato nell'azienda attiva.
  ///
  /// Il confronto usa [clienteDuplicato] (P.IVA, poi nome, poi codice fiscale).
  /// [escludiId] permette di ignorare il cliente in fase di aggiornamento.
  /// Ritorna il duplicato trovato o `null`.
  Future<Cliente?> cercaDuplicatoCliente({
    String? piva,
    String? nome,
    String? codiceFiscale,
    String? escludiId,
  }) async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return null;
    final snap = await _firestore
        .collection('clienti')
        .where('azienda_id', isEqualTo: aziendaId)
        .get();
    final altri = snap.docs
        .map((d) => Cliente.fromMap(d.data(), id: d.id))
        .where((c) => escludiId == null || c.id != escludiId)
        .toList();
    return clienteDuplicato(
      Cliente(id: '', piva: piva, nome: nome, codiceFiscale: codiceFiscale),
      altri,
    );
  }

  /// Crea un cliente normalizzando i dati e rifiutando i duplicati.
  ///
  /// Aggiunge `azienda_id` e `created_at`. Lancia [DuplicatoClienteException]
  /// se esiste già un cliente con la stessa P.IVA, nome o codice fiscale.
  Future<Map<String, dynamic>> inserisciCliente(
    Map<String, dynamic> dati,
  ) async {
    _richiediAzienda();
    final payload = _clientePayload(dati);
    final dup = await cercaDuplicatoCliente(
      piva: payload['piva'] as String?,
      nome: payload['nome'] as String?,
      codiceFiscale: payload['codice_fiscale'] as String?,
    );
    if (dup != null) throw DuplicatoClienteException();
    payload['created_at'] = _now();
    final ref = await _firestore.collection('clienti').add(payload);
    return {'id': ref.id, ...payload};
  }

  /// Aggiorna un cliente esistente.
  ///
  /// Normalizza i dati, controlla i duplicati escludendo l'[id] e imposta
  /// `updated_at`. Non modifica `azienda_id` (il cliente resta nella sua
  /// azienda). Lancia [DuplicatoClienteException] se esiste un altro cliente
  /// con la stessa P.IVA, nome o codice fiscale.
  Future<Map<String, dynamic>> aggiornaCliente(
    String id,
    Map<String, dynamic> dati,
  ) async {
    final patch = _clientePayload(dati);
    patch.remove('azienda_id');
    final dup = await cercaDuplicatoCliente(
      piva: patch['piva'] as String?,
      nome: patch['nome'] as String?,
      codiceFiscale: patch['codice_fiscale'] as String?,
      escludiId: id,
    );
    if (dup != null) throw DuplicatoClienteException();
    patch['updated_at'] = _now();
    await _firestore.collection('clienti').doc(id).update(patch);
    return {'id': id, ...patch};
  }

  /// Elimina il cliente con l'[id] indicato.
  Future<void> eliminaCliente(String id) {
    return _firestore.collection('clienti').doc(id).delete();
  }

  // ---------- visite (giro visite) ----------

  /// Elenco delle visite dell'azienda attiva per la [data] (`YYYY-MM-DD`),
  /// ordinate lato client per `ordine` e poi per `ora` (come la vecchia app).
  ///
  /// Se [utenteId] è indicato, restituisce solo le visite di quell'utente
  /// (filtro in memoria, come la vecchia app). Ritorna una lista vuota se non
  /// è impostata un'azienda attiva.
  Future<List<Visita>> getVisite(String data, {String? utenteId}) async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return [];
    final snap = await _firestore
        .collection('giro_visite')
        .where('azienda_id', isEqualTo: aziendaId)
        .get();
    final visite = snap.docs
        .map((d) => Visita.fromMap(d.data(), id: d.id))
        .where((v) => v.data == data)
        .where((v) => utenteId == null || v.utenteId == utenteId)
        .toList();
    visite.sort((a, b) {
      final cmpOrdine = a.ordine.compareTo(b.ordine);
      if (cmpOrdine != 0) return cmpOrdine;
      return (a.ora ?? '').compareTo(b.ora ?? '');
    });
    return visite;
  }

  /// Crea una visita nell'azienda attiva, con gli stessi campi e default della
  /// vecchia app (`SP.aggiungiVisita`): aggiunge `azienda_id` e `created_at`.
  Future<Map<String, dynamic>> aggiungiVisita(Map<String, dynamic> dati) async {
    _richiediAzienda();
    final payload = _visitaPayload(dati);
    payload['created_at'] = _now();
    final ref = await _firestore.collection('giro_visite').add(payload);
    return {'id': ref.id, ...payload};
  }

  /// Aggiorna una visita esistente.
  ///
  /// Normalizza i dati, imposta `updated_at` e non modifica `azienda_id`
  /// (la visita resta nella sua azienda).
  Future<Map<String, dynamic>> aggiornaVisita(
    String id,
    Map<String, dynamic> dati,
  ) async {
    final patch = _visitaPayload(dati);
    patch.remove('azienda_id');
    patch['updated_at'] = _now();
    await _firestore.collection('giro_visite').doc(id).update(patch);
    return {'id': id, ...patch};
  }

  /// Elimina la visita con l'[id] indicato.
  Future<void> eliminaVisita(String id) {
    return _firestore.collection('giro_visite').doc(id).delete();
  }

  /// Riassegna l'[ordine] a più visite in un'unica batch (come la vecchia
  /// app). Se la lista è vuota non esegue alcuna scrittura.
  Future<void> riordinaVisite(List<({String id, int ordine})> ordini) async {
    if (ordini.isEmpty) return;
    final batch = _firestore.batch();
    for (final o in ordini) {
      batch.update(_firestore.collection('giro_visite').doc(o.id), {
        'ordine': o.ordine,
      });
    }
    await batch.commit();
  }

  /// Visite dell'azienda attiva per il [clienteId], ordinate per `data` e `ora`
  /// discendenti (le più recenti per prime, come la vecchia app).
  Future<List<Visita>> getVisiteCliente(String clienteId) async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return [];
    final snap = await _firestore
        .collection('giro_visite')
        .where('azienda_id', isEqualTo: aziendaId)
        .get();
    final visite = snap.docs
        .map((d) => Visita.fromMap(d.data(), id: d.id))
        .where((v) => v.clienteId == clienteId)
        .toList();
    visite.sort((a, b) {
      final cmpData = (b.data ?? '').compareTo(a.data ?? '');
      if (cmpData != 0) return cmpData;
      return (b.ora ?? '').compareTo(a.ora ?? '');
    });
    return visite;
  }

  /// Visite dell'azienda attiva con `data` compresa tra [dal] e [al]
  /// (estremi inclusi), ordinate per `data` crescente.
  ///
  /// Se [utenteId] è indicato, restituisce solo le visite di quell'utente
  /// (filtro in memoria, come la vecchia app).
  Future<List<Visita>> getVisitePeriodo(
    String dal,
    String al, {
    String? utenteId,
  }) async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return [];
    final snap = await _firestore
        .collection('giro_visite')
        .where('azienda_id', isEqualTo: aziendaId)
        .get();
    final visite = snap.docs
        .map((d) => Visita.fromMap(d.data(), id: d.id))
        .where((v) {
          final d = v.data ?? '';
          return d.compareTo(dal) >= 0 && d.compareTo(al) <= 0;
        })
        .where((v) => utenteId == null || v.utenteId == utenteId)
        .toList();
    visite.sort((a, b) => (a.data ?? '').compareTo(b.data ?? ''));
    return visite;
  }

  /// Costruisce il payload Firestore di una visita, con gli stessi campi e
  /// default della vecchia app (`SP.aggiungiVisita`).
  ///
  /// I campi testuali vengono ripuliti (trim); `ordine` è un intero (default
  /// 0), `stato` default `da_fare`, `promemoria_min` è intero o `null`.
  /// `azienda_id` è incluso solo se è impostata un'azienda attiva.
  Map<String, dynamic> _visitaPayload(Map<String, dynamic> dati) {
    final payload = <String, dynamic>{
      'utente_id': _stringaNull(dati['utente_id']),
      'cliente_id': _stringaNull(dati['cliente_id']),
      'cliente_nome': _stringa(dati['cliente_nome']),
      'telefono': _stringaNull(dati['telefono']),
      'indirizzo': _stringaNull(dati['indirizzo']),
      'data': _stringaNull(dati['data']),
      'ora': _stringaNull(dati['ora']),
      'ordine': _intero(dati['ordine']),
      'stato': _stringa(dati['stato'], fallback: 'da_fare'),
      'note': _stringaNull(dati['note']),
      'visita_padre_id': _stringaNull(dati['visita_padre_id']),
      'promemoria_min': _interoNull(dati['promemoria_min']),
      'promemoria_at': _stringaNull(dati['promemoria_at']),
      'promemoria_numero': _stringaNull(dati['promemoria_numero']),
      'promemoria_inviato_at': _stringaNull(dati['promemoria_inviato_at']),
    };
    if (_aziendaAttiva != null) payload['azienda_id'] = _aziendaAttiva;
    return payload;
  }

  // ---------- agenda: appuntamenti ----------

  /// Elenco degli appuntamenti dell'azienda attiva.
  ///
  /// Legge `appuntamenti` filtrando per `azienda_id`, poi applica lato client
  /// i filtri [dal]/[al] (estremi inclusivi) e [operatoreId] via
  /// [filtraAppuntamenti] e ordina per `data` e `ora` crescenti. Ritorna una
  /// lista vuota se non è impostata un'azienda attiva.
  Future<List<Appuntamento>> getAppuntamenti({
    DateTime? dal,
    DateTime? al,
    String? operatoreId,
  }) async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return [];
    final snap = await _firestore
        .collection('appuntamenti')
        .where('azienda_id', isEqualTo: aziendaId)
        .get();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final appuntamenti = <Appuntamento>[];
    for (final documento in snap.docs) {
      var appuntamento = Appuntamento.fromMap(
        documento.data(),
        id: documento.id,
      );
      if (appuntamento.privato &&
          (appuntamento.createdBy == uid || appuntamento.operatoreId == uid)) {
        try {
          final dettagli = await _firestore
              .collection('appuntamenti')
              .doc(documento.id)
              .collection('privato')
              .doc('dettagli')
              .get();
          final dati = dettagli.data();
          if (dettagli.exists && dati != null) {
            appuntamento = appuntamento.conDettagliPrivati(dati);
          }
        } catch (_) {
          // Senza dettagli riservati resta il documento principale redatto.
        }
      }
      appuntamenti.add(appuntamento);
    }
    final filtrati = filtraAppuntamenti(
      appuntamenti,
      dal: dal,
      al: al,
      operatoreId: operatoreId,
    );
    appuntamenti
      ..clear()
      ..addAll(filtrati);
    appuntamenti.sort((a, b) {
      final cmpData = (a.data ?? '').compareTo(b.data ?? '');
      if (cmpData != 0) return cmpData;
      return (a.ora ?? '').compareTo(b.ora ?? '');
    });
    return appuntamenti;
  }

  /// Crea un appuntamento nell'azienda attiva.
  ///
  /// Normalizza i dati (payload snake_case, campi del modello [Appuntamento])
  /// e aggiunge `azienda_id`, `created_by` (uid corrente), `created_at` e
  /// `updated_at`. Ritorna `{id, ...payload}`.
  Future<Map<String, dynamic>> inserisciAppuntamento(
    Map<String, dynamic> dati,
  ) async {
    _richiediAzienda();
    final payload = _appuntamentoPayload(dati);
    payload['created_by'] = FirebaseAuth.instance.currentUser?.uid;
    payload['created_at'] = _now();
    payload['updated_at'] = _now();
    final ref = _firestore.collection('appuntamenti').doc();
    final batch = _firestore.batch();
    if (payload['privato'] == true) {
      batch.set(ref, redigiAppuntamentoPrivato(payload));
      batch.set(
        ref.collection('privato').doc('dettagli'),
        dettagliPrivatiAppuntamento(payload),
      );
    } else {
      batch.set(ref, payload);
    }
    await batch.commit();
    return {'id': ref.id, ...payload};
  }

  /// Aggiorna un appuntamento esistente.
  ///
  /// Normalizza i dati, imposta `updated_at` e non modifica `azienda_id`
  /// (l'appuntamento resta nella sua azienda). Ritorna `{id, ...patch}`.
  Future<Map<String, dynamic>> aggiornaAppuntamento(
    String id,
    Map<String, dynamic> dati,
  ) async {
    final patch = _appuntamentoPayload(dati);
    patch.remove('azienda_id');
    patch['updated_at'] = _now();
    final ref = _firestore.collection('appuntamenti').doc(id);
    final batch = _firestore.batch();
    if (patch['privato'] == true) {
      batch.update(ref, redigiAppuntamentoPrivato(patch));
      batch.set(
        ref.collection('privato').doc('dettagli'),
        dettagliPrivatiAppuntamento(patch),
        SetOptions(merge: true),
      );
    } else {
      batch.update(ref, patch);
    }
    await batch.commit();
    if (patch['privato'] != true) {
      try {
        await ref.collection('privato').doc('dettagli').delete();
      } catch (_) {
        // Nessun dettaglio privato da rimuovere.
      }
    }
    return {'id': id, ...patch};
  }

  /// Aggiorna solo il nome cliente denormalizzato di un appuntamento.
  ///
  /// Usato quando si modifica il cliente dal dettaglio dell'appuntamento:
  /// evita di riscrivere tutti gli altri campi.
  Future<void> aggiornaNomeClienteAppuntamento(String id, String? nome) async {
    await _firestore.collection('appuntamenti').doc(id).update({
      'cliente_nome': (nome ?? '').trim(),
      'updated_at': _now(),
    });
  }

  /// Elimina l'appuntamento con l'[id] indicato.
  Future<void> eliminaAppuntamento(String id) {
    return _firestore.collection('appuntamenti').doc(id).delete();
  }

  /// Registra la risposta di disponibilità dell'utente corrente all'invito
  /// dell'appuntamento [id].
  ///
  /// La transazione evita che due invitati che rispondono insieme si
  /// sovrascrivano la risposta. Aggiorna `conferme.{uid}`, ricalcola
  /// `stato_condivisione` e `updated_at`. L'utente deve essere tra gli
  /// invitati dell'appuntamento.
  ///
  /// Dopo la risposta avvisa chi ha creato l'appuntamento con una notifica
  /// In-App e, se ha un recapito con consenso, anche su WhatsApp.
  Future<void> rispondiInvitoAppuntamento(
    String id, {
    required bool disponibile,
    String? nomeRispondente,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Utente non autenticato');
    final riferimento = _firestore.collection('appuntamenti').doc(id);
    String creatore = '';
    String operatore = '';
    String titolo = '';
    String quando = '';

    await _firestore.runTransaction((transazione) async {
      final documento = await transazione.get(riferimento);
      if (!documento.exists) {
        throw StateError('Appuntamento non trovato');
      }
      final dati = documento.data() ?? const <String, dynamic>{};
      final invitati = sanificaFigliIds(dati['invitati_uids']);
      if (!invitati.contains(uid)) {
        throw StateError('Non sei invitato a questo appuntamento');
      }

      creatore = (dati['created_by'] ?? '').toString().trim();
      operatore = (dati['operatore_id'] ?? '').toString().trim();
      titolo = (dati['titolo'] ?? '').toString().trim();
      quando = [
        (dati['data'] ?? '').toString().trim(),
        (dati['ora'] ?? '').toString().trim(),
      ].where((voce) => voce.isNotEmpty).join(' ');

      final conferme = <String, dynamic>{};
      final grezze = dati['conferme'];
      if (grezze is Map) {
        for (final voce in grezze.entries) {
          conferme[voce.key.toString()] = voce.value;
        }
      }
      conferme[uid] = {
        'stato': disponibile ? 'confermato' : 'rifiutato',
        'at': _now(),
      };

      transazione.update(riferimento, {
        'conferme': conferme,
        'stato_condivisione': statoCondivisioneDaConferme(invitati, conferme),
        'updated_at': _now(),
      });
    });

    final destinatari = <String>{
      if (creatore.isNotEmpty && creatore != uid) creatore,
      if (operatore.isNotEmpty && operatore != uid) operatore,
    };
    if (destinatari.isEmpty) return;

    final oggetto = titolo.isEmpty ? 'Appuntamento' : titolo;
    final testo = messaggioRispostaInvito(
      nomeRispondente: nomeRispondente ?? '',
      disponibile: disponibile,
      titolo: titolo,
      data: quando,
    );

    for (final destinatario in destinatari) {
      try {
        await creaNotifica(
          utenteUid: destinatario,
          tipo: 'appuntamento',
          titolo: 'Risposta invito: $oggetto',
          testo: testo,
          targetTipo: 'appuntamento',
          targetId: id,
        );
      } catch (_) {
        // La risposta è già salvata: la notifica non deve farla fallire.
      }

      try {
        await inviaWhatsappAUtente(
          utenteUid: destinatario,
          messaggio: 'Closer · Risposta invito\n$testo',
        );
      } catch (_) {
        // WhatsApp è best-effort e può non essere configurato.
      }
    }
  }

  /// Costruisce il payload Firestore di un appuntamento, coerente con il
  /// modello [Appuntamento].
  ///
  /// I campi testuali vengono ripuliti (trim); `durata_min` è un intero
  /// (default 60), `tipo` default `appuntamento`, `stato` default `da_fare`.
  /// `azienda_id` è incluso solo se è impostata un'azienda attiva.
  Map<String, dynamic> _appuntamentoPayload(Map<String, dynamic> dati) {
    final payload = <String, dynamic>{
      'titolo': _stringa(dati['titolo']),
      'tipo': _stringa(dati['tipo'], fallback: 'appuntamento'),
      'data': _stringaNull(dati['data']),
      'ora': _stringaNull(dati['ora']),
      'data_fine': _stringaNull(dati['data_fine']),
      'ora_fine': _stringaNull(dati['ora_fine']),
      'tutto_il_giorno': dati['tutto_il_giorno'] == true,
      'durata_min': _intero(dati['durata_min'], fallback: 60),
      'ripetizione': dati['ripetizione'] is Map
          ? Map<String, dynamic>.from(dati['ripetizione'] as Map)
          : const {'tipo': 'mai'},
      'notifica_min': _interoNull(dati['notifica_min']),
      'privato': dati['privato'] == true,
      'cliente_id': _stringaNull(dati['cliente_id']),
      'cliente_nome': _stringa(dati['cliente_nome']),
      'operatore_id': _stringaNull(dati['operatore_id']),
      'luogo': _stringaNull(dati['luogo']),
      'indirizzo': _stringaNull(dati['indirizzo']),
      'note': _stringaNull(dati['note']),
      'stato': _stringa(dati['stato'], fallback: 'da_fare'),
      'visita_id': _stringaNull(dati['visita_id']),
      'call_provider': _stringaNull(dati['call_provider']),
      'call_url': _stringaNull(dati['call_url']),
      'meeting_id': _stringaNull(dati['meeting_id']),
      'google_event_id': _stringaNull(dati['google_event_id']),
      'outlook_event_id': _stringaNull(dati['outlook_event_id']),
      'invitati_uids': sanificaFigliIds(dati['invitati_uids']),
      'conferme': dati['conferme'] is Map
          ? Map<String, dynamic>.from(dati['conferme'] as Map)
          : const <String, dynamic>{},
      'stato_condivisione': _stringa(
        dati['stato_condivisione'],
        fallback: statoCondivisioneNonCondiviso,
      ),
    };
    if (_aziendaAttiva != null) payload['azienda_id'] = _aziendaAttiva;
    return payload;
  }

  // ---------- agenda: task ----------

  /// Elenco dei task dell'azienda attiva.
  ///
  /// Legge `task` filtrando per `azienda_id`, poi applica lato client i filtri
  /// [soloAperti] e [operatoreId] via [filtraTask] e ordina per scadenza
  /// crescente (senza scadenza in fondo) con gli `urgente` prima a parità di
  /// scadenza via [ordinaTask]. Ritorna una lista vuota se non è impostata
  /// un'azienda attiva.
  Future<List<TaskItem>> getTask({
    bool? soloAperti,
    String? operatoreId,
  }) async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return [];
    final snap = await _firestore
        .collection('task')
        .where('azienda_id', isEqualTo: aziendaId)
        .get();
    final task = snap.docs
        .map((d) => TaskItem.fromMap(d.data(), id: d.id))
        .toList();
    return ordinaTask(
      filtraTask(task, soloAperti: soloAperti, operatoreId: operatoreId),
    );
  }

  /// Crea un task nell'azienda attiva.
  ///
  /// Normalizza i dati (payload snake_case, campi del modello [TaskItem]) e
  /// aggiunge `azienda_id`, `created_by` (uid corrente), `created_at` e
  /// `updated_at`. Ritorna `{id, ...payload}`.
  Future<Map<String, dynamic>> inserisciTask(Map<String, dynamic> dati) async {
    _richiediAzienda();
    final payload = _taskPayload(dati);
    payload['created_by'] = FirebaseAuth.instance.currentUser?.uid;
    payload['created_at'] = _now();
    payload['updated_at'] = _now();
    final ref = await _firestore.collection('task').add(payload);
    return {'id': ref.id, ...payload};
  }

  /// Aggiorna un task esistente.
  ///
  /// Normalizza i dati, imposta `updated_at` e non modifica `azienda_id`
  /// (il task resta nella sua azienda). Ritorna `{id, ...patch}`.
  Future<Map<String, dynamic>> aggiornaTask(
    String id,
    Map<String, dynamic> dati,
  ) async {
    final patch = _taskPayload(dati);
    patch.remove('azienda_id');
    patch['updated_at'] = _now();
    await _firestore.collection('task').doc(id).update(patch);
    return {'id': id, ...patch};
  }

  /// Elimina il task con l'[id] indicato.
  Future<void> eliminaTask(String id) {
    return _firestore.collection('task').doc(id).delete();
  }

  /// Segna il task [id] come completato.
  ///
  /// Scrive `stato: completato`, `completato_at`, `updated_at` e, se noto,
  /// `completato_da` ([utenteId] o l'uid corrente).
  Future<void> completaTask(String id, {String? utenteId}) async {
    final uid = utenteId ?? FirebaseAuth.instance.currentUser?.uid;
    final patch = <String, dynamic>{
      'stato': 'completato',
      'completato_at': _now(),
      'updated_at': _now(),
    };
    if (uid != null) patch['completato_da'] = uid;
    await _firestore.collection('task').doc(id).update(patch);
  }

  /// Costruisce il payload Firestore di un task, coerente con il modello
  /// [TaskItem].
  ///
  /// I campi testuali vengono ripuliti (trim); `priorita` default `normale`,
  /// `stato` default `aperto`. `azienda_id` è incluso solo se è impostata
  /// un'azienda attiva.
  Map<String, dynamic> _taskPayload(Map<String, dynamic> dati) {
    final payload = <String, dynamic>{
      'titolo': _stringa(dati['titolo']),
      'descrizione': _stringa(dati['descrizione']),
      'scadenza_data': _stringaNull(dati['scadenza_data']),
      'scadenza_ora': _stringaNull(dati['scadenza_ora']),
      'operatore_id': _stringaNull(dati['operatore_id']),
      'priorita': _stringa(dati['priorita'], fallback: 'normale'),
      'stato': _stringa(dati['stato'], fallback: 'aperto'),
      'cliente_id': _stringaNull(dati['cliente_id']),
      'cliente_nome': _stringa(dati['cliente_nome']),
      'appuntamento_id': _stringaNull(dati['appuntamento_id']),
      'note': _stringaNull(dati['note']),
    };
    if (_aziendaAttiva != null) payload['azienda_id'] = _aziendaAttiva;
    return payload;
  }

  // ---------- agenda: impostazioni ----------

  /// Legge le impostazioni dell'agenda dell'azienda attiva da
  /// `impostazioni_agenda/{aziendaId}`.
  ///
  /// Ritorna `null` se non è impostata un'azienda attiva o il documento non
  /// esiste.
  Future<Map<String, dynamic>?> getImpostazioniAgenda() async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return null;
    final snap = await _firestore
        .collection('impostazioni_agenda')
        .doc(aziendaId)
        .get();
    final dati = snap.data();
    if (!snap.exists || dati == null) return null;
    return dati;
  }

  /// Salva le impostazioni dell'agenda dell'azienda attiva.
  ///
  /// Scrive `impostazioni_agenda/{aziendaId}` con merge, garantendo sempre
  /// `azienda_id` e `updated_at`. Richiede un'azienda attiva.
  Future<void> salvaImpostazioniAgenda(Map<String, dynamic> dati) async {
    _richiediAzienda();
    await _firestore.collection('impostazioni_agenda').doc(_aziendaAttiva).set({
      ...dati,
      'azienda_id': _aziendaAttiva,
      'updated_at': _now(),
    }, SetOptions(merge: true));
  }

  // ---------- integrazioni calendario ----------

  /// Legge l'integrazione calendario dell'azienda attiva da
  /// `integrazioni_azienda/{aziendaId}`.
  ///
  /// Ritorna `null` se non è impostata un'azienda attiva; se il documento non
  /// esiste restituisce un'[IntegrazioneAzienda] vuota (default) per
  /// l'azienda, altrimenti la deserializza con [IntegrazioneAzienda.fromMap].
  Future<IntegrazioneAzienda?> getIntegrazioneAzienda() async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return null;
    final snap = await _firestore
        .collection('integrazioni_azienda')
        .doc(aziendaId)
        .get();
    final dati = snap.data();
    if (!snap.exists || dati == null) {
      return IntegrazioneAzienda.vuota(aziendaId);
    }
    return IntegrazioneAzienda.fromMap(dati, id: aziendaId);
  }

  /// Salva l'integrazione calendario dell'azienda attiva.
  ///
  /// Scrive `integrazioni_azienda/{aziendaId}` con merge, garantendo sempre
  /// `azienda_id` e `updated_at`. Non scrive mai `client_secret` né token (il
  /// modello [IntegrazioneAzienda] li esclude per costruzione). Richiede
  /// un'azienda attiva.
  Future<void> salvaIntegrazioneAzienda(
    IntegrazioneAzienda integrazione,
  ) async {
    _richiediAzienda();
    final aziendaId = _aziendaAttiva!;
    await _firestore.collection('integrazioni_azienda').doc(aziendaId).set({
      ...integrazione.toMap(),
      'azienda_id': aziendaId,
      'updated_at': _now(),
    }, SetOptions(merge: true));
  }

  /// Elenco delle condivisioni di calendario create dall'utente corrente
  /// (proprietario) nell'azienda attiva, ordinate per `createdAt` discendente.
  ///
  /// Se [includiRevocate] è `false` (default) tiene solo le condivisioni
  /// `attiva`. Ritorna una lista vuota se non è impostata un'azienda attiva o
  /// non c'è un utente autenticato.
  Future<List<CondivisioneCalendario>> getCondivisioniCalendario({
    bool includiRevocate = false,
  }) async {
    final aziendaId = _aziendaAttiva;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (aziendaId == null || uid == null) return [];
    var query = _firestore
        .collection('condivisioni_calendario')
        .where('azienda_id', isEqualTo: aziendaId)
        .where('proprietario_uid', isEqualTo: uid);
    if (!includiRevocate) {
      query = query.where('stato', isEqualTo: 'attiva');
    }
    final snap = await query.get();
    final condivisioni = snap.docs
        .map((d) => CondivisioneCalendario.fromMap(d.data(), id: d.id))
        .toList();
    condivisioni.sort(confrontaCondivisioniPerData);
    return condivisioni;
  }

  /// Elenco delle condivisioni di calendario ricevute dall'utente corrente
  /// (destinatario) nell'azienda attiva, solo `attiva`, ordinate per
  /// `createdAt` discendente.
  ///
  /// Ritorna una lista vuota se non è impostata un'azienda attiva o non c'è un
  /// utente autenticato.
  Future<List<CondivisioneCalendario>> getCondivisioniRicevute() async {
    final aziendaId = _aziendaAttiva;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (aziendaId == null || uid == null) return [];
    final snap = await _firestore
        .collection('condivisioni_calendario')
        .where('azienda_id', isEqualTo: aziendaId)
        .where('destinatario_uid', isEqualTo: uid)
        .where('stato', isEqualTo: 'attiva')
        .get();
    final condivisioni = snap.docs
        .map((d) => CondivisioneCalendario.fromMap(d.data(), id: d.id))
        .toList();
    condivisioni.sort(confrontaCondivisioniPerData);
    return condivisioni;
  }

  /// Crea (o aggiorna) la condivisione del calendario dell'azienda attiva con
  /// il [destinatarioUid] al [livello] indicato.
  ///
  /// Richiede un'azienda attiva e un utente autenticato; valida i dati con
  /// [condivisioneCalendarioValida]. L'id è deterministico
  /// ([CondivisioneCalendario.idPer]): se esiste già una condivisione `attiva`
  /// con lo stesso livello non fa nulla, se è `attiva` con livello diverso
  /// lancia [StateError], se è `revocata` la elimina e la ricrea.
  Future<void> condividiCalendario({
    required String destinatarioUid,
    required String livello,
  }) async {
    _richiediAzienda();
    final aziendaId = _aziendaAttiva!;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Nessun utente autenticato.');
    }
    if (!condivisioneCalendarioValida(
      proprietarioUid: uid,
      destinatarioUid: destinatarioUid,
      livello: livello,
    )) {
      throw ArgumentError('Condivisione calendario non valida.');
    }
    final id = CondivisioneCalendario.idPer(
      aziendaId: aziendaId,
      proprietarioUid: uid,
      destinatarioUid: destinatarioUid,
    );
    final ref = _firestore.collection('condivisioni_calendario').doc(id);
    final snap = await ref.get();
    if (snap.exists && snap.data() != null) {
      final esistente = CondivisioneCalendario.fromMap(
        snap.data()!,
        id: snap.id,
      );
      if (esistente.attiva) {
        if (esistente.livello == livello) return;
        throw StateError('Revoca la condivisione prima di cambiare livello.');
      }
      await ref.delete();
    }
    final ora = _now();
    await ref.set({
      'azienda_id': aziendaId,
      'proprietario_uid': uid,
      'destinatario_uid': destinatarioUid,
      'livello': livello,
      'stato': 'attiva',
      'creato_da': uid,
      'created_at': ora,
      'updated_at': ora,
    });
  }

  /// Revoca la condivisione di calendario con l'[id] indicato.
  ///
  /// Imposta `stato: revocata`, `revoked_at`, `revoked_by` (uid corrente) e
  /// `updated_at`.
  Future<void> revocaCondivisione(String id) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ora = _now();
    return _firestore.collection('condivisioni_calendario').doc(id).update({
      'stato': 'revocata',
      'revoked_at': ora,
      'revoked_by': uid,
      'updated_at': ora,
    });
  }

  /// Elimina la condivisione di calendario con l'[id] indicato.
  Future<void> eliminaCondivisione(String id) {
    return _firestore.collection('condivisioni_calendario').doc(id).delete();
  }

  // ---------- preventivi ----------

  /// Elenco dei preventivi dell'azienda attiva, ordinati lato client per
  /// `created_at` discendente (i più recenti per primi).
  ///
  /// Se [soloUtenteId] è indicato, restituisce solo i preventivi emessi da
  /// quell'utente (filtro in memoria, come la vecchia app). Ritorna una lista
  /// vuota se non è impostata un'azienda attiva.
  Future<List<Preventivo>> getPreventivi({String? soloUtenteId}) async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return [];
    final snap = await _firestore
        .collection('preventivi')
        .where('azienda_id', isEqualTo: aziendaId)
        .get();
    final preventivi = snap.docs
        .map((d) => Preventivo.fromMap(d.data(), id: d.id))
        .where((p) => soloUtenteId == null || p.utenteId == soloUtenteId)
        .toList();
    preventivi.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    return preventivi;
  }

  /// Legge il preventivo `preventivi/{id}`.
  ///
  /// Ritorna `null` se l'id è vuoto o il documento non esiste; gli errori di
  /// lettura (permessi, rete) vengono propagati al chiamante.
  Future<Preventivo?> getPreventivo(String id) async {
    final chiave = id.trim();
    if (chiave.isEmpty) return null;
    final snap = await _firestore.collection('preventivi').doc(chiave).get();
    final dati = snap.data();
    if (!snap.exists || dati == null) return null;
    return Preventivo.fromMap(dati, id: snap.id);
  }

  /// Numero di preventivi dell'azienda attiva (per i limiti di piano).
  Future<int> contaPreventivi() async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return 0;
    final snap = await _firestore
        .collection('preventivi')
        .where('azienda_id', isEqualTo: aziendaId)
        .get();
    return snap.size;
  }

  /// Prossimo numero preventivo, letto e incrementato in una transazione su
  /// `contatori/preventivi_{aziendaId}` (campo `valore`), come la vecchia app.
  ///
  /// La transazione garantisce una serie continua senza numeri duplicati.
  Future<String> _nextNumeroPreventivo() async {
    final key = _aziendaAttiva ?? 'globale';
    final ref = _firestore.collection('contatori').doc('preventivi_$key');
    // La regola di lettura di `contatori` usa `resource.data.azienda_id`:
    // su un documento inesistente `resource` è null e la lettura sarebbe
    // negata anche al primo preventivo. Creiamo (o aggiorniamo) il documento
    // con l'azienda prima della transazione, così la lettura è consentita.
    await ref.set({
      'azienda_id': _aziendaAttiva,
      'updated_at': _now(),
    }, SetOptions(merge: true));
    var n = 1;
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final valore = snap.exists
          ? (snap.data()?['valore'] as num? ?? 0).toInt()
          : 0;
      n = valore + 1;
      tx.set(ref, {
        'azienda_id': _aziendaAttiva,
        'valore': n,
        'updated_at': _now(),
      }, SetOptions(merge: true));
    });
    return formatoNumeroPreventivo(n);
  }

  /// Crea un preventivo: assegna il progressivo `PRV-0001` dal contatore
  /// aziendale (transazionale), `revisione: 0`, `azienda_id` e `created_at`.
  Future<Map<String, dynamic>> inserisciPreventivo(
    Map<String, dynamic> dati,
  ) async {
    _richiediAzienda();
    final numero = await _nextNumeroPreventivo();
    final payload = _preventivoPayload(dati, numero: numero, revisione: 0);
    payload['created_at'] = _now();
    final ref = await _firestore.collection('preventivi').add(payload);
    return {'id': ref.id, ...payload, 'data': payload['created_at']};
  }

  /// Aggiorna un preventivo esistente.
  ///
  /// Aggiorna i campi modificabili (cliente, righe, note, sconto generale,
  /// totali, stato) e imposta `updated_at`. Non tocca `azienda_id`, `numero`,
  /// `revisione` e `utente_id` (il preventivo resta del suo autore e della sua
  /// azienda).
  Future<Map<String, dynamic>> aggiornaPreventivo(
    String id,
    Map<String, dynamic> dati,
  ) async {
    final patch = <String, dynamic>{
      'cliente_id': _stringaNull(dati['clienteId']),
      'cliente_nome': _stringa(dati['clienteNome']),
      'righe': dati['righe'] ?? <dynamic>[],
      'sconto': _numero(dati['sconto']) ?? 0,
      'note': _stringa(dati['note']),
      'subtotale': _numero(dati['subtotale']) ?? 0,
      'imp_sconto': _numero(dati['impSconto']) ?? 0,
      'imponibile': _numero(dati['imponibile']) ?? 0,
      'iva': _numero(dati['iva']) ?? 0,
      'totale_iva': _numero(dati['totaleIva']) ?? 0,
      'stato': _stringa(dati['stato'], fallback: 'bozza'),
      'updated_at': _now(),
    };
    await _firestore.collection('preventivi').doc(id).update(patch);
    return {'id': id, ...patch};
  }

  /// Cambia lo stato di un preventivo (bozza → inviato → accettato/…).
  Future<void> aggiornaStato(String id, String stato) async {
    await _firestore.collection('preventivi').doc(id).update({
      'stato': stato,
      'updated_at': _now(),
    });
  }

  /// Elimina il preventivo con l'[id] indicato.
  Future<void> eliminaPreventivo(String id) {
    return _firestore.collection('preventivi').doc(id).delete();
  }

  /// Crea una revisione: segna il vecchio preventivo `revisionato` e crea una
  /// copia con numero `{numeroBase}-R{revisione+1}` e stato `inviato`, senza
  /// consumare il contatore.
  Future<Map<String, dynamic>> creaRevisione(Preventivo vecchio) async {
    await _firestore.collection('preventivi').doc(vecchio.id).update({
      'stato': 'revisionato',
      'updated_at': _now(),
    });

    final baseNum = numeroBasePreventivo(vecchio.numero ?? '');
    final nuovaRev = vecchio.revisione + 1;
    final nuovoNumero = baseNum.isEmpty
        ? null
        : numeroRevisione(baseNum, nuovaRev);

    final payload = <String, dynamic>{
      'azienda_id': _aziendaAttiva ?? vecchio.aziendaId,
      'cliente_id': vecchio.clienteId,
      'cliente_nome': vecchio.clienteNome ?? '',
      'utente_id': FirebaseAuth.instance.currentUser?.uid ?? vecchio.utenteId,
      'righe': vecchio.righe.map((r) => r.toMap()).toList(),
      'sconto': vecchio.sconto,
      'note': vecchio.note ?? '',
      'subtotale': vecchio.subtotale,
      'imp_sconto': vecchio.impSconto,
      'imponibile': vecchio.imponibile,
      'iva': vecchio.iva,
      'totale_iva': vecchio.totaleIva,
      'stato': 'inviato',
      'numero': nuovoNumero,
      'revisione': nuovaRev,
      'created_at': _now(),
    };
    final ref = await _firestore.collection('preventivi').add(payload);
    return {'id': ref.id, ...payload, 'data': payload['created_at']};
  }

  /// Costruisce il payload Firestore di un preventivo.
  ///
  /// Accetta le stesse chiavi della vecchia app (`clienteId`, `clienteNome`,
  /// `righe`, `sconto`, `note`, `subtotale`, `impSconto`, `imponibile`, `iva`,
  /// `totaleIva`, `stato`) e le traduce nei campi snake_case di Firestore.
  /// [numero] e [revisione] sono inclusi solo se indicati; `azienda_id` è
  /// incluso solo se è impostata un'azienda attiva.
  Map<String, dynamic> _preventivoPayload(
    Map<String, dynamic> dati, {
    String? numero,
    int? revisione,
  }) {
    final payload = <String, dynamic>{
      'cliente_id': _stringaNull(dati['clienteId']),
      'cliente_nome': _stringa(dati['clienteNome']),
      'utente_id': dati['utenteId'] ?? FirebaseAuth.instance.currentUser?.uid,
      'righe': dati['righe'] ?? <dynamic>[],
      'sconto': _numero(dati['sconto']) ?? 0,
      'note': _stringa(dati['note']),
      'subtotale': _numero(dati['subtotale']) ?? 0,
      'imp_sconto': _numero(dati['impSconto']) ?? 0,
      'imponibile': _numero(dati['imponibile']) ?? 0,
      'iva': _numero(dati['iva']) ?? 0,
      'totale_iva': _numero(dati['totaleIva']) ?? 0,
      'stato': _stringa(dati['stato'], fallback: 'bozza'),
    };
    if (numero != null) payload['numero'] = numero;
    if (revisione != null) payload['revisione'] = revisione;
    if (_aziendaAttiva != null) payload['azienda_id'] = _aziendaAttiva;
    return payload;
  }

  // ---------- catalogo: prodotti ----------

  /// Elenco dei prodotti dell'azienda attiva, ordinati lato client per [nome].
  ///
  /// Ritorna una lista vuota se non è impostata un'azienda attiva.
  Future<List<Prodotto>> getProdotti() async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return [];
    final snap = await _firestore
        .collection('prodotti')
        .where('azienda_id', isEqualTo: aziendaId)
        .get();
    final prodotti = snap.docs
        .map((d) => Prodotto.fromMap(d.data(), id: d.id))
        .toList();
    prodotti.sort((a, b) => (a.nome ?? '').compareTo(b.nome ?? ''));
    return prodotti;
  }

  /// Crea un prodotto normalizzando i dati e aggiungendo `azienda_id` e
  /// `created_at`. Il prezzo è salvato come numero, l'immagine come URL o
  /// `null`.
  Future<Map<String, dynamic>> inserisciProdotto(
    Map<String, dynamic> dati,
  ) async {
    _richiediAzienda();
    final payload = _prodottoPayload(dati);
    payload['created_at'] = _now();
    final ref = await _firestore.collection('prodotti').add(payload);
    return {'id': ref.id, ...payload};
  }

  /// Aggiorna un prodotto esistente.
  ///
  /// Normalizza i dati, imposta `updated_at` e non modifica `azienda_id`
  /// (il prodotto resta nella sua azienda).
  Future<Map<String, dynamic>> aggiornaProdotto(
    String id,
    Map<String, dynamic> dati,
  ) async {
    final patch = _prodottoPayload(dati, id: id);
    patch.remove('azienda_id');
    patch['updated_at'] = _now();
    await _firestore.collection('prodotti').doc(id).update(patch);
    return {'id': id, ...patch};
  }

  /// Elimina il prodotto con l'[id] indicato.
  Future<void> eliminaProdotto(String id) {
    return _firestore.collection('prodotti').doc(id).delete();
  }

  // ---------- catalogo: categorie ----------

  /// Elenco delle categorie dell'azienda attiva, ordinate lato client per
  /// [ordine].
  ///
  /// Ritorna una lista vuota se non è impostata un'azienda attiva.
  Future<List<Categoria>> getCategorie() async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return [];
    final snap = await _firestore
        .collection('categorie')
        .where('azienda_id', isEqualTo: aziendaId)
        .get();
    final categorie = snap.docs
        .map((d) => Categoria.fromMap(d.data(), id: d.id))
        .toList();
    categorie.sort((a, b) => (a.ordine ?? 0).compareTo(b.ordine ?? 0));
    return categorie;
  }

  /// Crea una categoria normalizzando i dati e aggiungendo `azienda_id` e
  /// `created_at`.
  Future<Map<String, dynamic>> inserisciCategoria(
    Map<String, dynamic> dati,
  ) async {
    _richiediAzienda();
    final payload = _categoriaPayload(dati);
    payload['created_at'] = _now();
    final ref = await _firestore.collection('categorie').add(payload);
    return {'id': ref.id, ...payload};
  }

  /// Aggiorna una categoria esistente.
  ///
  /// Normalizza i dati, imposta `updated_at` e non modifica `azienda_id`
  /// (la categoria resta nella sua azienda).
  Future<Map<String, dynamic>> aggiornaCategoria(
    String id,
    Map<String, dynamic> dati,
  ) async {
    final patch = _categoriaPayload(dati);
    patch.remove('azienda_id');
    patch['updated_at'] = _now();
    await _firestore.collection('categorie').doc(id).update(patch);
    return {'id': id, ...patch};
  }

  /// Elimina la categoria con l'[id] indicato.
  Future<void> eliminaCategoria(String id) {
    return _firestore.collection('categorie').doc(id).delete();
  }

  // ---------- bandi ----------

  /// Elenco dei bandi pubblici (lettura senza login, come la vecchia app).
  ///
  /// Legge `bandi_incentivi`, esclude i bandi con `stato == 'scaduto'` e
  /// ordina lato client per `data_chiusura` crescente, con i valori assenti
  /// in fondo (via [ordinaBandiPerScadenza], coerente con `SP.getBandi`).
  Future<List<Bando>> getBandi() async {
    final snap = await _firestore.collection('bandi_incentivi').get();
    final bandi = snap.docs
        .map((d) => Bando.fromMap(d.data(), id: d.id))
        .where((b) => b.stato != 'scaduto')
        .toList();
    return ordinaBandiPerScadenza(bandi);
  }

  /// Importa un elenco di [bandi] già normalizzati in `bandi_incentivi`.
  ///
  /// Usa `bando['id']` come id documento quando è una stringa non vuota,
  /// altrimenti crea un documento con auto id (`add`). Scrive ogni documento
  /// con `set(..., SetOptions(merge: true))` in batch da massimo 400 elementi,
  /// committando una batch alla volta e chiamando [onProgresso](importati,
  /// totale) dopo ciascuna. Non tocca altre collezioni. Restituisce il numero
  /// di bandi importati (0 se la lista è vuota).
  Future<int> importaBandi(
    List<Map<String, dynamic>> bandi, {
    void Function(int importati, int totale)? onProgresso,
  }) async {
    if (bandi.isEmpty) return 0;

    final totale = bandi.length;
    var importati = 0;

    for (final blocco in aBlocchi(bandi, 400)) {
      final batch = _firestore.batch();
      for (final bando in blocco) {
        final id = bando['id'];
        final documento = id is String && id.trim().isNotEmpty
            ? _firestore.collection('bandi_incentivi').doc(id.trim())
            : _firestore.collection('bandi_incentivi').doc();
        batch.set(documento, bando, SetOptions(merge: true));
      }
      await batch.commit();
      importati += blocco.length;
      onProgresso?.call(importati, totale);
    }

    return importati;
  }

  /// Elenco delle fonti dei bandi (`bandi_fonti`, lettura pubblica), ordinate
  /// lato client per [nome] (come `SP.getFontiBandi`).
  Future<List<FonteBando>> getFontiBandi() async {
    final snap = await _firestore.collection('bandi_fonti').get();
    final fonti = snap.docs
        .map((d) => FonteBando.fromMap(d.data(), id: d.id))
        .toList();
    fonti.sort((a, b) => (a.nome ?? '').compareTo(b.nome ?? ''));
    return fonti;
  }

  // ---------- notifiche ----------

  /// Elenco delle notifiche dell'utente corrente, ordinate per `created_at`
  /// discendente (le più recenti per prime, via [ordinaNotifiche]).
  ///
  /// Filtra `notifiche` per `utente_uid == uid corrente`. Se [soloNonLette] è
  /// `true`, tiene solo le notifiche non ancora lette (via
  /// [filtraNotificheNonLette]). Ritorna una lista vuota se non c'è un utente
  /// autenticato.
  Future<List<Notifica>> getNotifiche({bool soloNonLette = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final snap = await _firestore
        .collection('notifiche')
        .where('utente_uid', isEqualTo: uid)
        .get();
    var notifiche = snap.docs
        .map((d) => Notifica.fromMap(d.data(), id: d.id))
        .toList();
    if (soloNonLette) notifiche = filtraNotificheNonLette(notifiche);
    return ordinaNotifiche(notifiche);
  }

  /// Stream in tempo reale delle notifiche dell'utente corrente (per i badge),
  /// con lo stesso filtro e ordinamento di [getNotifiche].
  ///
  /// Se [soloNonLette] è `true`, emette solo le notifiche non ancora lette.
  /// Emette una lista vuota se non c'è un utente autenticato.
  Stream<List<Notifica>> notificheStream({bool soloNonLette = false}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection('notifiche')
        .where('utente_uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          var notifiche = snap.docs
              .map((d) => Notifica.fromMap(d.data(), id: d.id))
              .toList();
          if (soloNonLette) notifiche = filtraNotificheNonLette(notifiche);
          return ordinaNotifiche(notifiche);
        });
  }

  /// Segna la notifica [id] come letta (imposta `letta_at` ISO).
  Future<void> segnaNotificaLetta(String id) {
    return _firestore.collection('notifiche').doc(id).update({
      'letta_at': _now(),
    });
  }

  /// Segna come lette più notifiche in batch da massimo 400 elementi ciascuna.
  ///
  /// Ignora gli id vuoti; non esegue alcuna scrittura se la lista è vuota.
  Future<void> segnaTutteNotificheLette(List<String> ids) async {
    final lista = ids.where((id) => id.trim().isNotEmpty).toList();
    if (lista.isEmpty) return;
    final ora = _now();
    for (final blocco in aBlocchi(lista, 400)) {
      final batch = _firestore.batch();
      for (final id in blocco) {
        batch.update(_firestore.collection('notifiche').doc(id), {
          'letta_at': ora,
        });
      }
      await batch.commit();
    }
  }

  /// Crea una notifica per l'utente [utenteUid] nell'azienda attiva.
  ///
  /// Richiede un'azienda attiva; il mittente è l'uid corrente. Imposta
  /// `created_at`, `stato: 'programmata'`, `tentativi: 0` e una
  /// `idempotenza_key` stabile. Ritorna `{id, ...payload}`.
  Future<Map<String, dynamic>> creaNotifica({
    required String utenteUid,
    required String tipo,
    required String titolo,
    String testo = '',
    String? targetTipo,
    String? targetId,
    String canale = 'inapp',
  }) async {
    _richiediAzienda();
    final payload = <String, dynamic>{
      'azienda_id': _aziendaAttiva,
      'utente_uid': utenteUid,
      'mittente_uid': FirebaseAuth.instance.currentUser?.uid,
      'tipo': tipo,
      'titolo': titolo,
      'testo': testo,
      'target_tipo': targetTipo,
      'target_id': targetId,
      'canale': canale,
      'stato': 'programmata',
      'tentativi': 0,
      'idempotenza_key':
          '$tipo:$targetId:${DateTime.now().microsecondsSinceEpoch}',
      'created_at': _now(),
    };
    final ref = await _firestore.collection('notifiche').add(payload);
    return {'id': ref.id, ...payload};
  }

  /// Salva la sottoscrizione Web Push del dispositivo corrente.
  ///
  /// La sottoscrizione contiene endpoint e chiavi p256dh/auth, non un token
  /// Firebase. Il documento è per utente e dispositivo; un nuovo salvataggio
  /// aggiorna lo stesso dispositivo.
  Future<void> salvaDispositivoWeb({
    required String endpoint,
    required String p256dh,
    required String auth,
    String? userAgent,
  }) async {
    _richiediAzienda();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Utente non autenticato.');
    }
    final id = '${_aziendaAttiva}_${uid}_web';
    await _firestore.collection('dispositivi').doc(id).set({
      'azienda_id': _aziendaAttiva,
      'utente_uid': uid,
      'piattaforma': 'web',
      'endpoint': endpoint.trim(),
      'p256dh': p256dh.trim(),
      'auth': auth.trim(),
      'user_agent': userAgent?.trim(),
      'attivo': true,
      'ultimo_uso_at': _now(),
      'created_at': _now(),
    }, SetOptions(merge: true));
  }

  /// Disattiva il dispositivo Web Push corrente senza cancellare lo storico.
  Future<void> disattivaDispositivoWeb() async {
    _richiediAzienda();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final id = '${_aziendaAttiva}_${uid}_web';
    await _firestore.collection('dispositivi').doc(id).set({
      'attivo': false,
      'ultimo_uso_at': _now(),
    }, SetOptions(merge: true));
  }

  /// Preferenze di notifica dell'utente corrente per l'azienda attiva.
  ///
  /// Legge `impostazioni_notifiche/{aziendaId}_{uid}`. Ritorna `null` se non è
  /// impostata un'azienda attiva, non c'è un utente autenticato o il documento
  /// non esiste.
  Future<Map<String, dynamic>?> getPreferenzeNotifiche() async {
    final aziendaId = _aziendaAttiva;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (aziendaId == null || uid == null) return null;
    final snap = await _firestore
        .collection('impostazioni_notifiche')
        .doc('${aziendaId}_$uid')
        .get();
    final dati = snap.data();
    if (!snap.exists || dati == null) return null;
    return dati;
  }

  /// Salva le preferenze di notifica dell'utente corrente per l'azienda attiva.
  ///
  /// Scrive `impostazioni_notifiche/{aziendaId}_{uid}` con merge, garantendo
  /// sempre `azienda_id`, `utente_uid` e `updated_at`.
  ///
  /// Aggiorna anche la rubrica aziendale `contatti_notifiche` usata per gli
  /// avvisi WhatsApp: il numero è condiviso con i colleghi dell'azienda solo
  /// quando il consenso WhatsApp è attivo.
  Future<void> salvaPreferenzeNotifiche(Map<String, dynamic> dati) async {
    _richiediAzienda();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Nessun utente autenticato.');
    }
    final aziendaId = _aziendaAttiva!;
    final numero = (dati['numero_whatsapp'] ?? '').toString().trim();
    final consenso = dati['consenso_whatsapp'] == true;
    final canale = dati['canale_whatsapp'] == true;
    final batch = _firestore.batch();

    batch.set(
      _firestore.collection('impostazioni_notifiche').doc('${aziendaId}_$uid'),
      {
        ...dati,
        'azienda_id': aziendaId,
        'utente_uid': uid,
        'updated_at': _now(),
      },
      SetOptions(merge: true),
    );

    final contatto = _firestore
        .collection('contatti_notifiche')
        .doc('${aziendaId}_$uid');
    if (consenso && canale && numero.isNotEmpty) {
      batch.set(contatto, {
        'azienda_id': aziendaId,
        'utente_uid': uid,
        'numero_whatsapp': numero,
        'consenso_whatsapp': true,
        'updated_at': _now(),
      }, SetOptions(merge: true));
    } else {
      // Non cancella il documento (la delete senza documento esistente può
      // essere negata dalle regole): azzera numero e consenso.
      batch.set(contatto, {
        'azienda_id': aziendaId,
        'utente_uid': uid,
        'numero_whatsapp': '',
        'consenso_whatsapp': false,
        'updated_at': _now(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Recapito WhatsApp di un utente dell'azienda attiva, oppure `null`.
  ///
  /// Legge `contatti_notifiche/{aziendaId}_{uid}`, la rubrica leggibile dai
  /// membri dell'azienda creata dalle preferenze di notifica dell'utente.
  Future<Map<String, dynamic>?> getContattoNotifiche(String utenteUid) async {
    final aziendaId = _aziendaAttiva;
    final uid = utenteUid.trim();
    if (aziendaId == null || uid.isEmpty) return null;
    final snap = await _firestore
        .collection('contatti_notifiche')
        .doc('${aziendaId}_$uid')
        .get();
    return snap.data();
  }

  /// Token Firebase dell'utente corrente per le chiamate al Worker.
  Future<String> _tokenFirebase() async {
    final utente = FirebaseAuth.instance.currentUser;
    if (utente == null) throw StateError('Utente non autenticato');
    final token = await utente.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Sessione scaduta. Accedi di nuovo.');
    }
    return token;
  }

  /// Chiamata autenticata al Worker Cloudflare.
  Future<Map<String, dynamic>> _chiamaWorker(
    String percorso, {
    String metodo = 'GET',
    Map<String, dynamic>? corpo,
  }) async {
    final token = await _tokenFirebase();
    final uri = Uri.parse('$_workerWhatsappBase$percorso');
    final intestazioni = {
      'Authorization': 'Bearer $token',
      if (corpo != null) 'Content-Type': 'application/json',
    };
    final risposta = metodo == 'POST'
        ? await http
              .post(
                uri,
                headers: intestazioni,
                body: corpo == null ? null : jsonEncode(corpo),
              )
              .timeout(const Duration(seconds: 20))
        : await http
              .get(uri, headers: intestazioni)
              .timeout(const Duration(seconds: 20));

    final testo = risposta.body.trim();
    dynamic decodificato;
    try {
      decodificato = testo.isEmpty ? <String, dynamic>{} : jsonDecode(testo);
    } catch (_) {
      decodificato = <String, dynamic>{};
    }
    if (risposta.statusCode < 200 || risposta.statusCode >= 300) {
      final errore = decodificato is Map
          ? (decodificato['error']?.toString() ??
                'Il server ha risposto HTTP ${risposta.statusCode}.')
          : 'Il server ha risposto HTTP ${risposta.statusCode}.';
      throw StateError(errore);
    }
    return decodificato is Map
        ? Map<String, dynamic>.from(decodificato)
        : <String, dynamic>{};
  }

  /// Invia un avviso WhatsApp a un utente dell'azienda, se ha un recapito con
  /// consenso attivo. Il numero viene letto dal Worker dalla rubrica aziendale:
  /// non transita dal client. Best-effort: non interrompe mai il chiamante.
  Future<bool> inviaWhatsappAUtente({
    required String utenteUid,
    required String messaggio,
  }) async {
    final aziendaId = _aziendaAttiva;
    final uid = utenteUid.trim();
    if (aziendaId == null || uid.isEmpty || messaggio.trim().isEmpty) {
      return false;
    }
    try {
      final esito = await _chiamaWorker(
        '/whatsapp/send',
        metodo: 'POST',
        corpo: {'aziendaId': aziendaId, 'utenteUid': uid, 'message': messaggio},
      );
      return esito['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Configurazione del server WhatsApp salvata nel KV del Worker.
  Future<Map<String, dynamic>?> getWhatsappConfig() async {
    final dati = await _chiamaWorker('/whatsapp/config');
    if (dati.isEmpty) return null;
    return dati;
  }

  /// Salva URL e API key del server WhatsApp nel KV del Worker. Riservato al
  /// super admin, che il Worker verifica con il token Firebase.
  Future<void> salvaWhatsappConfig({
    required String url,
    required String apiKey,
  }) async {
    if (uriInvioWhatsapp(url) == null) {
      throw StateError('Inserisci un indirizzo http/https valido.');
    }
    if (apiKey.trim().isEmpty) {
      throw StateError('Inserisci la API key del server WhatsApp.');
    }
    await _chiamaWorker(
      '/whatsapp/config',
      metodo: 'POST',
      corpo: {'url': url.trim(), 'apiKey': apiKey.trim()},
    );
  }

  /// Stato del server WhatsApp (`GET /status` tramite Worker).
  Future<Map<String, dynamic>> statoWhatsapp() async {
    final dati = await _chiamaWorker('/whatsapp/status');
    return normalizzaStatoWhatsapp(dati);
  }

  /// QR di pairing del server WhatsApp (`GET /qr` tramite Worker).
  Future<String?> qrWhatsapp() async {
    final dati = await _chiamaWorker('/whatsapp/qr');
    final qr = dati['qr']?.toString().trim() ?? '';
    return qr.isEmpty ? null : qr;
  }

  // ---------- allegati ----------

  /// Metadati degli allegati di un appuntamento/task nell'azienda attiva.
  Future<List<Allegato>> getAllegati(String elementoId) async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null || elementoId.trim().isEmpty) return [];
    final snap = await _firestore
        .collection('allegati')
        .where('azienda_id', isEqualTo: aziendaId)
        .get();
    final allegati = [
      for (final doc in snap.docs)
        if ((doc.data()['elemento_id'] ?? '').toString() == elementoId)
          Allegato.fromMap(doc.data(), id: doc.id),
    ];
    allegati.sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));
    return allegati;
  }

  /// Carica un file nel KV del Worker e crea il documento `allegati`.
  Future<Allegato> caricaAllegato({
    required String elementoId,
    required Uint8List bytes,
    required String nome,
    required String mime,
    String elementoTipo = 'appuntamento',
  }) async {
    _richiediAzienda();
    final token = await _tokenFirebase();
    final uri = Uri.parse('$_workerWhatsappBase/allegati/upload');
    final risposta = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'x-azienda-id': _aziendaAttiva!,
            'x-elemento-id': elementoId,
            'x-elemento-tipo': elementoTipo,
            'x-nome': Uri.encodeComponent(nome),
            'x-mime': mime,
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 60));
    final corpo = _jsonRisposta(risposta.body);
    if (risposta.statusCode < 200 || risposta.statusCode >= 300) {
      throw StateError(
        corpo['error']?.toString() ?? 'Caricamento non riuscito.',
      );
    }
    return Allegato(
      id: corpo['id']?.toString() ?? '',
      aziendaId: _aziendaAttiva,
      elementoTipo: elementoTipo,
      elementoId: elementoId,
      nome: corpo['nome']?.toString() ?? nome,
      mime: corpo['mime']?.toString() ?? mime,
      dimensione: (corpo['dimensione'] as num?)?.toInt() ?? bytes.length,
      objectKey: corpo['objectKey']?.toString(),
      createdAt: corpo['createdAt']?.toString(),
    );
  }

  /// Link temporaneo (1 ora) per aprire o mostrare un allegato.
  Future<String?> linkAllegato(Allegato allegato) async {
    final aziendaId = _aziendaAttiva;
    final key = allegato.objectKey?.trim() ?? '';
    if (aziendaId == null || key.isEmpty) return null;
    final dati = await _chiamaWorker(
      '/allegati/link',
      metodo: 'POST',
      corpo: {'aziendaId': aziendaId, 'key': key},
    );
    final url = dati['url']?.toString().trim() ?? '';
    return url.isEmpty ? null : url;
  }

  /// Elimina file e metadati di un allegato.
  Future<void> eliminaAllegato(Allegato allegato) async {
    _richiediAzienda();
    final key = allegato.objectKey?.trim() ?? '';
    if (key.isEmpty) return;
    final token = await _tokenFirebase();
    final richiesta =
        http.Request('DELETE', Uri.parse('$_workerWhatsappBase/allegati'))
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode({
            'aziendaId': _aziendaAttiva,
            'id': allegato.id,
            'key': key,
          });
    final risposta = await richiesta.send().timeout(
      const Duration(seconds: 20),
    );
    if (risposta.statusCode < 200 || risposta.statusCode >= 300) {
      throw StateError('Eliminazione non riuscita.');
    }
  }

  Map<String, dynamic> _jsonRisposta(String testo) {
    if (testo.trim().isEmpty) return const {};
    try {
      final decodificato = jsonDecode(testo);
      return decodificato is Map
          ? Map<String, dynamic>.from(decodificato)
          : const {};
    } catch (_) {
      return const {};
    }
  }

  /// Registra i promemoria WhatsApp di un appuntamento nel Worker.
  ///
  /// Le occorrenze sono già calcolate dal chiamante (data/ora ISO e testo).
  /// Il Worker risolve i numeri dalla rubrica aziendale e li invia al server
  /// WhatsApp alla scadenza.
  Future<void> registraPromemoria({
    required String appuntamentoId,
    required List<({String dueAt, String testo})> occorrenze,
    required List<String> utenteUids,
  }) async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null || appuntamentoId.trim().isEmpty) return;
    if (occorrenze.isEmpty || utenteUids.isEmpty) return;
    await _chiamaWorker(
      '/promemoria',
      metodo: 'POST',
      corpo: {
        'aziendaId': aziendaId,
        'appuntamentoId': appuntamentoId,
        'utenteUids': utenteUids,
        'occorrenze': [
          for (final occorrenza in occorrenze)
            {'dueAt': occorrenza.dueAt, 'testo': occorrenza.testo},
        ],
      },
    );
  }

  /// Annulla i promemoria WhatsApp di un appuntamento.
  Future<void> annullaPromemoria(String appuntamentoId) async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null || appuntamentoId.trim().isEmpty) return;
    try {
      await _chiamaWorker(
        '/promemoria/annulla',
        metodo: 'POST',
        corpo: {'aziendaId': aziendaId, 'appuntamentoId': appuntamentoId},
      );
    } catch (_) {
      // Best-effort: il Worker scarta comunque i promemoria vecchi.
    }
  }

  // ---------- chat ----------

  /// Elenco delle stanze di chat dell'azienda attiva a cui partecipa l'utente
  /// corrente, ordinate per `updated_at` discendente (le più recenti per
  /// prime) via [ordinaStanzeChat].
  ///
  /// Legge `chat_stanze` filtrando per `azienda_id` e per
  /// `partecipanti_uids array-contains uid corrente`. Ritorna una lista vuota
  /// se non è impostata un'azienda attiva o non c'è un utente autenticato.
  Future<List<StanzaChat>> getChatStanze() async {
    final aziendaId = _aziendaAttiva;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (aziendaId == null || uid == null) return [];
    final snap = await _firestore
        .collection('chat_stanze')
        .where('azienda_id', isEqualTo: aziendaId)
        .where('partecipanti_uids', arrayContains: uid)
        .get();
    return ordinaStanzeChat(
      snap.docs.map((d) => StanzaChat.fromMap(d.data(), id: d.id)).toList(),
    );
  }

  /// Stream in tempo reale delle stanze di chat dell'azienda attiva a cui
  /// partecipa l'utente corrente, con lo stesso filtro e ordinamento di
  /// [getChatStanze].
  ///
  /// Emette una lista vuota se non è impostata un'azienda attiva o non c'è un
  /// utente autenticato.
  Stream<List<StanzaChat>> chatStanzeStream() {
    final aziendaId = _aziendaAttiva;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (aziendaId == null || uid == null) return Stream.value(const []);
    return _firestore
        .collection('chat_stanze')
        .where('azienda_id', isEqualTo: aziendaId)
        .where('partecipanti_uids', arrayContains: uid)
        .snapshots()
        .map(
          (snap) => ordinaStanzeChat(
            snap.docs
                .map((d) => StanzaChat.fromMap(d.data(), id: d.id))
                .toList(),
          ),
        );
  }

  /// Crea (o restituisce, se già esiste) la stanza diretta tra l'utente
  /// corrente e [altroUid].
  ///
  /// Usa l'id deterministico [idChatDiretta] su `chat_stanze`; se il documento
  /// esiste lo restituisce senza riscriverlo, altrimenti lo crea con
  /// `tipo: diretta`, partecipanti `[uid, altroUid]`, `creatore_uid`, e
  /// `created_at`/`updated_at`.
  Future<StanzaChat> creaChatDiretta(String altroUid) async {
    _richiediAzienda();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Nessun utente autenticato.');
    }
    final aziendaId = _aziendaAttiva!;
    final id = idChatDiretta(aziendaId, uid, altroUid);
    final ref = _firestore.collection('chat_stanze').doc(id);
    final snap = await ref.get();
    if (snap.exists && snap.data() != null) {
      return StanzaChat.fromMap(snap.data()!, id: snap.id);
    }
    final ora = _now();
    final payload = <String, dynamic>{
      'azienda_id': aziendaId,
      'tipo': 'diretta',
      'partecipanti_uids': [uid, altroUid],
      'creatore_uid': uid,
      'created_at': ora,
      'updated_at': ora,
    };
    await ref.set(payload);
    return StanzaChat.fromMap(payload, id: id);
  }

  /// Crea una stanza di gruppo nell'azienda attiva.
  ///
  /// Il [nome] (dopo trim) non può essere vuoto; i [partecipanti] vengono
  /// ripuliti, deduplicati e integrati sempre con il creatore (uid corrente).
  /// Usa `add` con `tipo: gruppo`.
  Future<StanzaChat> creaGruppo(String nome, List<String> partecipanti) async {
    _richiediAzienda();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Nessun utente autenticato.');
    }
    final n = nome.trim();
    if (n.isEmpty) {
      throw ArgumentError.value(nome, 'nome', 'Non può essere vuoto');
    }
    final uids = <String>[];
    for (final p in [...partecipanti, uid]) {
      final s = p.trim();
      if (s.isNotEmpty && !uids.contains(s)) uids.add(s);
    }
    final ora = _now();
    final payload = <String, dynamic>{
      'azienda_id': _aziendaAttiva,
      'tipo': 'gruppo',
      'nome': n,
      'partecipanti_uids': uids,
      'creatore_uid': uid,
      'created_at': ora,
      'updated_at': ora,
    };
    final ref = await _firestore.collection('chat_stanze').add(payload);
    return StanzaChat.fromMap(payload, id: ref.id);
  }

  /// Stream dei messaggi della stanza [stanzaId], dalla sottocollezione
  /// `chat_stanze/{stanzaId}/messaggi`, ordinati lato client per `created_at`
  /// crescente.
  Stream<List<MessaggioChat>> messaggiStream(String stanzaId) {
    return _firestore
        .collection('chat_stanze')
        .doc(stanzaId)
        .collection('messaggi')
        .snapshots()
        .map((snap) {
          final messaggi = snap.docs
              .map((d) => MessaggioChat.fromMap(d.data(), id: d.id))
              .toList();
          messaggi.sort(
            (a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''),
          );
          return messaggi;
        });
  }

  /// Invia un messaggio nella stanza [stanzaId].
  ///
  /// Richiede un'azienda attiva; [testo] (trim) o [imageKey] (trim) devono
  /// essere valorizzati. Aggiunge il messaggio nella sottocollezione
  /// `chat_stanze/{stanzaId}/messaggi` con `mittente_uid` (uid corrente),
  /// `tipo` testo/immagine, `created_at`, `eliminato: false` e una
  /// `idempotenza_key`; poi aggiorna la stanza con `ultimo_messaggio`,
  /// `ultimo_messaggio_at` e `updated_at`. Ritorna `{id, ...payload}`.
  Future<Map<String, dynamic>> inviaMessaggio(
    String stanzaId,
    String testo, {
    String? imageKey,
  }) async {
    _richiediAzienda();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Nessun utente autenticato.');
    }
    final t = testo.trim();
    final img = _stringaNull(imageKey);
    final haImmagine = img != null;
    if (t.isEmpty && !haImmagine) {
      throw ArgumentError('Servono testo o immagine per inviare un messaggio.');
    }
    final ora = _now();
    final payload = <String, dynamic>{
      'mittente_uid': uid,
      'testo': t,
      'tipo': haImmagine ? 'immagine' : 'testo',
      'image_key': img,
      'created_at': ora,
      'eliminato': false,
      'idempotenza_key':
          '$stanzaId:$uid:${DateTime.now().microsecondsSinceEpoch}',
    };
    final ref = await _firestore
        .collection('chat_stanze')
        .doc(stanzaId)
        .collection('messaggi')
        .add(payload);
    await _firestore.collection('chat_stanze').doc(stanzaId).update({
      'ultimo_messaggio': t.isNotEmpty ? t : '[Immagine]',
      'ultimo_messaggio_at': ora,
      'updated_at': ora,
    });
    return {'id': ref.id, ...payload};
  }

  /// Elimina (soft delete) il messaggio [messaggioId] della stanza [stanzaId]:
  /// imposta `eliminato: true`, `testo: ''` e `image_key: null`.
  Future<void> eliminaMessaggio(String stanzaId, String messaggioId) {
    return _firestore
        .collection('chat_stanze')
        .doc(stanzaId)
        .collection('messaggi')
        .doc(messaggioId)
        .update({'eliminato': true, 'testo': '', 'image_key': null});
  }

  /// Segna la stanza [stanzaId] come letta dall'utente corrente.
  ///
  /// Scrive `chat_stanze/{stanzaId}/letture/{uid}` con `ultima_lettura_at`.
  /// Non fa nulla se non c'è un utente autenticato.
  Future<void> segnaChatLetta(String stanzaId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Future.value();
    return _firestore
        .collection('chat_stanze')
        .doc(stanzaId)
        .collection('letture')
        .doc(uid)
        .set({'ultima_lettura_at': _now()});
  }

  /// Timestamp dell'ultima lettura della stanza [stanzaId] da parte
  /// dell'utente corrente, letto da `chat_stanze/{stanzaId}/letture/{uid}`.
  ///
  /// Ritorna `null` se non c'è un utente autenticato, il documento non esiste
  /// o il valore non è un timestamp ISO-8601 valido.
  Future<DateTime?> ultimaLetturaChat(String stanzaId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _firestore
        .collection('chat_stanze')
        .doc(stanzaId)
        .collection('letture')
        .doc(uid)
        .get();
    final dati = snap.data();
    if (!snap.exists || dati == null) return null;
    final s = dati['ultima_lettura_at'] as String?;
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  /// Costruisce il payload Firestore di un prodotto.
  ///
  /// `nome`/`categoria`/`descrizione` vengono ripuliti (trim); `prezzo` è
  /// numerico (omesso se assente), `immagine` è l'URL o assente se vuota,
  /// `attivo` vale `true` se non specificato. Se presenti, `figliIds` viene
  /// convertito in `figli_ids` (sanificato, senza [id]) e `figliAZero` in
  /// `figli_a_zero` (bool); se le chiavi mancano i campi non vengono aggiunti,
  /// così un aggiornamento parziale non cancella i figli esistenti.
  /// `azienda_id` è incluso solo se è impostata un'azienda attiva.
  Map<String, dynamic> _prodottoPayload(
    Map<String, dynamic> dati, {
    String? id,
  }) {
    final payload = <String, dynamic>{
      'nome': _stringa(dati['nome']),
      'codice': _stringa(dati['codice']),
      'categoria': _stringa(dati['categoria']),
      'descrizione': _stringa(dati['descrizione']),
      'attivo': dati['attivo'] ?? true,
    };
    final prezzo = _numero(dati['prezzo']);
    if (prezzo != null) payload['prezzo'] = prezzo;
    final immagine = _stringaNull(dati['immagine']);
    if (immagine != null) payload['immagine'] = immagine;
    if (dati.containsKey('figliIds')) {
      payload['figli_ids'] = sanificaFigliIds(dati['figliIds'], escludiId: id);
    }
    if (dati.containsKey('figliAZero')) {
      payload['figli_a_zero'] = dati['figliAZero'] == true;
    }
    if (_aziendaAttiva != null) payload['azienda_id'] = _aziendaAttiva;
    return payload;
  }

  /// Costruisce il payload Firestore di una categoria.
  ///
  /// `nome`/`icona` vengono ripuliti (trim), `ordine` è un intero (default 0).
  /// `azienda_id` è incluso solo se è impostata un'azienda attiva.
  Map<String, dynamic> _categoriaPayload(Map<String, dynamic> dati) {
    final payload = <String, dynamic>{
      'nome': _stringa(dati['nome']),
      'icona': _stringa(dati['icona']),
      'ordine': _intero(dati['ordine']),
    };
    if (_aziendaAttiva != null) payload['azienda_id'] = _aziendaAttiva;
    return payload;
  }

  /// Costruisce il payload Firestore di un cliente, con gli stessi campi e
  /// valori di default della vecchia app (`SP._clientePayload`).
  ///
  /// La P.IVA viene normalizzata con [normalizzaPiva]; i campi testuali
  /// vengono ripuliti (trim) e valorizzati con `""` se assenti. `azienda_id`
  /// è incluso solo se è impostata un'azienda attiva.
  Map<String, dynamic> _clientePayload(Map<String, dynamic> dati) {
    final payload = <String, dynamic>{
      'tipo_cliente': _stringa(dati['tipo_cliente'], fallback: 'azienda'),
      'nome': _stringa(dati['nome']),
      'referente': _stringa(dati['referente']),
      'email': _stringa(dati['email']),
      'telefono': _stringa(dati['telefono']),
      'piva': normalizzaPiva(dati['piva'] as String?) ?? '',
      'codice_fiscale': _stringa(dati['codice_fiscale']),
      'indirizzo': _stringa(dati['indirizzo']),
      'civico': _stringa(dati['civico']),
      'cap': _stringa(dati['cap']),
      'citta': _stringa(dati['citta']),
      'provincia': _stringa(dati['provincia']),
      'ateco': _stringa(dati['ateco']),
      'settore': _stringa(dati['settore'], fallback: 'ristorazione'),
      'regione': _stringa(dati['regione'], fallback: 'lombardia'),
      'note': _stringa(dati['note']),
    };
    if (_aziendaAttiva != null) payload['azienda_id'] = _aziendaAttiva;
    return payload;
  }

  /// Valore testuale ripulito (trim), con [fallback] se vuoto o assente.
  String _stringa(dynamic valore, {String fallback = ''}) {
    final s = (valore?.toString() ?? '').trim();
    return s.isEmpty ? fallback : s;
  }

  /// Valore testuale ripulito (trim), `null` se vuoto o assente.
  String? _stringaNull(dynamic valore) {
    final s = (valore?.toString() ?? '').trim();
    return s.isEmpty ? null : s;
  }

  /// Valore numerico, `null` se assente o non interpretabile come numero.
  num? _numero(dynamic valore) {
    if (valore is num) return valore;
    if (valore == null) return null;
    return num.tryParse(valore.toString().trim());
  }

  /// Valore intero, con [fallback] se assente o non interpretabile.
  int _intero(dynamic valore, {int fallback = 0}) {
    if (valore is int) return valore;
    if (valore is num) return valore.toInt();
    if (valore == null) return fallback;
    return int.tryParse(valore.toString().trim()) ?? fallback;
  }

  /// Valore intero, `null` se assente o non interpretabile.
  int? _interoNull(dynamic valore) {
    if (valore is int) return valore;
    if (valore is num) return valore.toInt();
    if (valore == null) return null;
    return int.tryParse(valore.toString().trim());
  }

  /// Mappa dei permessi di un ruolo con i soli valori non vuoti (trim).
  Map<String, String> _permessiRuolo(Map<String, String> permessi) {
    return <String, String>{
      for (final e in permessi.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
    };
  }
}
