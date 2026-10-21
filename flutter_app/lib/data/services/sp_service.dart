import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/azienda.dart';
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
}
