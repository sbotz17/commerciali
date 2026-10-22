import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/azienda.dart';
import '../models/categoria.dart';
import '../models/cliente.dart';
import '../models/prodotto.dart';
import '../models/user_profile.dart';

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

  // ---------- aziende / membri ----------

  /// Elenco delle aziende a cui l'utente appartiene.
  ///
  /// Legge `membri` filtrando per [uid] (`utente_id`), poi per ogni voce legge
  /// `aziende/{azienda_id}` e fonde il ruolo della membership.
  Future<List<Azienda>> getAziendeUtente(String uid) async {
    final membri = await _firestore
        .collection('membri')
        .where('utente_id', isEqualTo: uid)
        .get();

    final out = <Azienda>[];
    for (final m in membri.docs) {
      final aziendaId = m.data()['azienda_id'] as String?;
      if (aziendaId == null) continue;
      final az = await _firestore.collection('aziende').doc(aziendaId).get();
      if (!az.exists) continue;
      out.add(
        Azienda.fromMap(
          {
            ...az.data()!,
            'ruolo': m.data()['ruolo'],
          },
          id: az.id,
        ),
      );
    }
    return out;
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

  // ---------- clienti ----------

  /// Elenco dei clienti dell'azienda attiva, ordinati per [nome].
  ///
  /// Ritorna una lista vuota se non è impostata un'azienda attiva.
  Future<List<Cliente>> getClienti() async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return [];
    final snap = await _firestore
        .collection('clienti')
        .where('azienda_id', isEqualTo: aziendaId)
        .orderBy('nome')
        .get();
    return snap.docs
        .map((d) => Cliente.fromMap(d.data(), id: d.id))
        .toList();
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

  // ---------- catalogo: prodotti ----------

  /// Elenco dei prodotti dell'azienda attiva, ordinati per [nome].
  ///
  /// Ritorna una lista vuota se non è impostata un'azienda attiva.
  Future<List<Prodotto>> getProdotti() async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return [];
    final snap = await _firestore
        .collection('prodotti')
        .where('azienda_id', isEqualTo: aziendaId)
        .orderBy('nome')
        .get();
    return snap.docs
        .map((d) => Prodotto.fromMap(d.data(), id: d.id))
        .toList();
  }

  /// Crea un prodotto normalizzando i dati e aggiungendo `azienda_id` e
  /// `created_at`. Il prezzo è salvato come numero, l'immagine come URL o
  /// `null`.
  Future<Map<String, dynamic>> inserisciProdotto(
    Map<String, dynamic> dati,
  ) async {
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
    final patch = _prodottoPayload(dati);
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

  /// Elenco delle categorie dell'azienda attiva, ordinate per [ordine].
  ///
  /// Ritorna una lista vuota se non è impostata un'azienda attiva.
  Future<List<Categoria>> getCategorie() async {
    final aziendaId = _aziendaAttiva;
    if (aziendaId == null) return [];
    final snap = await _firestore
        .collection('categorie')
        .where('azienda_id', isEqualTo: aziendaId)
        .orderBy('ordine')
        .get();
    return snap.docs
        .map((d) => Categoria.fromMap(d.data(), id: d.id))
        .toList();
  }

  /// Crea una categoria normalizzando i dati e aggiungendo `azienda_id` e
  /// `created_at`.
  Future<Map<String, dynamic>> inserisciCategoria(
    Map<String, dynamic> dati,
  ) async {
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

  /// Costruisce il payload Firestore di un prodotto.
  ///
  /// `nome`/`categoria`/`descrizione` vengono ripuliti (trim); `prezzo` è
  /// numerico (omesso se assente), `immagine` è l'URL o assente se vuota,
  /// `attivo` vale `true` se non specificato. `azienda_id` è incluso solo se
  /// è impostata un'azienda attiva.
  Map<String, dynamic> _prodottoPayload(Map<String, dynamic> dati) {
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
}
