import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/azienda.dart';
import '../models/bando.dart';
import '../models/categoria.dart';
import '../models/cliente.dart';
import '../models/fonte_bando.dart';
import '../models/licenza.dart';
import '../models/preventivo.dart';
import '../models/prodotto.dart';
import '../models/ruolo.dart';
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

    final aziende = await Future.wait(membri.docs.map((m) async {
      final aziendaId = m.data()['azienda_id'] as String?;
      if (aziendaId == null) return null;
      final az = await _firestore.collection('aziende').doc(aziendaId).get();
      if (!az.exists) return null;
      return Azienda.fromMap(
        {
          ...az.data()!,
          'ruolo': m.data()['ruolo'],
        },
        id: az.id,
      );
    }));

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
  Future<void> aggiungiMembro(
    String aziendaId,
    String utenteId,
    String ruolo,
  ) {
    return _firestore
        .collection('membri')
        .doc('${aziendaId}_$utenteId')
        .set({
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
      batch.set(
        _firestore.collection('ruoli').doc(),
        {...r, 'azienda_id': aziendaId, 'created_at': _now()},
      );
    }

    final categorie = <Map<String, dynamic>>[
      {'nome': 'software', 'icona': '💻', 'ordine': 1},
      {'nome': 'servizi', 'icona': '🛠️', 'ordine': 2},
      {'nome': 'hardware', 'icona': '🖥️', 'ordine': 3},
    ];
    for (final c in categorie) {
      batch.set(
        _firestore.collection('categorie').doc(),
        {...c, 'azienda_id': aziendaId, 'created_at': _now()},
      );
    }

    final oggi = DateTime.now();
    final fine = oggi.add(const Duration(days: 14));
    batch.set(
      _firestore.collection('licenze').doc(aziendaId),
      {
        'azienda_id': aziendaId,
        'piano': 'trial',
        'stato': 'attiva',
        'data_inizio': _data(oggi),
        'data_fine': _data(fine),
        'max_utenti': 2,
        'max_preventivi': 20,
        'updated_at': _now(),
      },
      SetOptions(merge: true),
    );

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

    final utenti = await Future.wait(membri.docs.map((m) async {
      final uid = m.data()['utente_id'] as String?;
      if (uid == null) return null;
      final u = await _firestore.collection('utenti').doc(uid).get();
      if (!u.exists) return null;
      return UserProfile.fromMap(
        {...u.data()!, 'ruolo': m.data()['ruolo']},
        id: u.id,
      );
    }));

    return utenti.whereType<UserProfile>().toList();
  }

  /// Aggiorna il [ruolo] del membro [uid] nell'azienda attiva.
  ///
  /// Scrive `membri/{aziendaId}_{uid}` con merge, riproducendo i campi della
  /// vecchia app (`SP.aggiornaUtente`). Non fa nulla senza azienda attiva.
  Future<void> aggiornaRuoloUtente(String uid, String ruolo) {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return Future.value();
    return _firestore
        .collection('membri')
        .doc('${aziendaId}_$uid')
        .set({
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
      batch.update(
        _firestore.collection('giro_visite').doc(o.id),
        {'ordine': o.ordine},
      );
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
    await ref.set(
      {'azienda_id': _aziendaAttiva, 'updated_at': _now()},
      SetOptions(merge: true),
    );
    var n = 1;
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final valore =
          snap.exists ? (snap.data()?['valore'] as num? ?? 0).toInt() : 0;
      n = valore + 1;
      tx.set(
        ref,
        {
          'azienda_id': _aziendaAttiva,
          'valore': n,
          'updated_at': _now(),
        },
        SetOptions(merge: true),
      );
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
    final nuovoNumero =
        baseNum.isEmpty ? null : numeroRevisione(baseNum, nuovaRev);

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

  /// Costruisce il payload Firestore di un prodotto.
  ///
  /// `nome`/`categoria`/`descrizione` vengono ripuliti (trim); `prezzo` è
  /// numerico (omesso se assente), `immagine` è l'URL o assente se vuota,
  /// `attivo` vale `true` se non specificato. Se presenti, `figliIds` viene
  /// convertito in `figli_ids` (sanificato, senza [id]) e `figliAZero` in
  /// `figli_a_zero` (bool); se le chiavi mancano i campi non vengono aggiunti,
  /// così un aggiornamento parziale non cancella i figli esistenti.
  /// `azienda_id` è incluso solo se è impostata un'azienda attiva.
  Map<String, dynamic> _prodottoPayload(Map<String, dynamic> dati, {String? id}) {
    final payload = <String, dynamic>{
      'nome': _stringa(dati['nome']),
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
