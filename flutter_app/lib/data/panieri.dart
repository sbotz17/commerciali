// Funzioni pure per la gestione dei panieri nei preventivi.
//
// Non toccano Firebase né la UI: ricevono i dati in ingresso e restituiscono
// nuove strutture, senza effetti collaterali. Servono all'inserimento di un
// prodotto "paniere" (con figli collegati tramite `figliIds`) nelle righe di
// un preventivo.

import 'package:commerciali_app/data/models/preventivo.dart';
import 'package:commerciali_app/data/models/prodotto.dart';

/// Restituisce i prodotti figli del [padre], nell'ordine di
/// [Prodotto.figliIds].
///
/// Prende solo i prodotti attivi, esclude il padre stesso e i duplicati
/// (se un id compare più volte in [Prodotto.figliIds] conta solo la prima
/// occorrenza). Gli id che non esistono in [tutti] vengono ignorati.
List<Prodotto> figliDelPaniere(Prodotto padre, List<Prodotto> tutti) {
  final perId = <String, Prodotto>{};
  for (final p in tutti) {
    perId[p.id] = p;
  }

  final risultato = <Prodotto>[];
  final visti = <String>{};
  for (final id in padre.figliIds) {
    if (id == padre.id) continue; // esclude il padre stesso
    if (!visti.add(id)) continue; // esclude i duplicati
    final prodotto = perId[id];
    if (prodotto == null) continue; // non esiste
    if (!prodotto.attivo) continue; // non attivo
    risultato.add(prodotto);
  }
  return risultato;
}

/// Id in [Prodotto.figliIds] che non esistono in [tutti] o non sono attivi
/// (escluso il padre).
///
/// Segue lo stesso ordine e la stessa deduplicazione di [figliDelPaniere]:
/// ogni id viene elencato al massimo una volta.
List<String> figliMancanti(Prodotto padre, List<Prodotto> tutti) {
  final perId = <String, Prodotto>{};
  for (final p in tutti) {
    perId[p.id] = p;
  }

  final risultato = <String>[];
  final visti = <String>{};
  for (final id in padre.figliIds) {
    if (id == padre.id) continue; // esclude il padre stesso
    if (!visti.add(id)) continue; // esclude i duplicati
    final prodotto = perId[id];
    if (prodotto == null || !prodotto.attivo) {
      risultato.add(id);
    }
  }
  return risultato;
}

/// Inserisce (o incrementa) il [padre] e i suoi [figli] nelle [righe] di un
/// preventivo, restituendo la nuova lista.
///
/// [figli] deve essere già filtrato (senza il padre); eventuali figli non
/// idonei vengono comunque ignorati. Le righe esistenti non vengono mai
/// ricalcolate nel prezzo: cambia solo la quantità e, se serve, il
/// collegamento al paniere. Il padre non ricalcola mai il proprio prezzo.
List<PreventivoRiga> inserisciPaniere({
  required Prodotto padre,
  required List<Prodotto> figli,
  required List<PreventivoRiga> righe,
}) {
  final risultato = List<PreventivoRiga>.of(righe);

  // 1. Riga padre: riga con `prodottoId == padre.id` e `paniereId == null`.
  //    Se esiste → qty+1; altrimenti si aggiunge la riga padre.
  final num padreQty;
  final idxPadre = _indiceRiga(risultato, padre.id, paniereId: null);
  if (idxPadre != null) {
    final riga = risultato[idxPadre];
    risultato[idxPadre] = riga.copyWith(qty: riga.qty + 1);
    padreQty = riga.qty + 1;
  } else {
    risultato.add(PreventivoRiga(
      prodottoId: padre.id,
      nome: padre.nome,
      prezzo: padre.prezzo ?? 0,
      immagine: padre.immagine,
      qty: 1,
      um: 'pz',
      ivaPerc: 22,
    ));
    padreQty = 1;
  }

  // 2. Figli (già filtrati, senza il padre).
  for (final figlio in figli) {
    if (figlio.id == padre.id) continue; // difensivo

    // Riga già sotto questo paniere → qty+1, prezzo invariato.
    final idxStessoPaniere =
        _indiceRiga(risultato, figlio.id, paniereId: padre.id);
    if (idxStessoPaniere != null) {
      final riga = risultato[idxStessoPaniere];
      risultato[idxStessoPaniere] = riga.copyWith(qty: riga.qty + 1);
      continue;
    }

    // Riga libera (stesso prodotto, paniereId == null) → la si adotta.
    final idxLibera = _indiceRiga(risultato, figlio.id, paniereId: null);
    if (idxLibera != null) {
      final riga = risultato[idxLibera];
      risultato[idxLibera] = riga.copyWith(
        qty: riga.qty + 1,
        paniereId: padre.id,
        paniereNome: padre.nome,
      );
      continue;
    }

    // Riga con stesso prodotto ma sotto un altro paniere, oppure nessuna riga
    // → si aggiunge una nuova riga figlia per questo paniere.
    risultato.add(PreventivoRiga(
      prodottoId: figlio.id,
      nome: figlio.nome,
      prezzo: padre.figliAZero ? 0 : (figlio.prezzo ?? 0),
      immagine: figlio.immagine,
      qty: padreQty,
      um: 'pz',
      ivaPerc: 22,
      paniereId: padre.id,
      paniereNome: padre.nome,
    ));
  }

  return risultato;
}

/// Indice della prima riga con `prodottoId == [prodottoId]` e `paniereId`
/// uguale a [paniereId] (passare `null` per cercare le righe libere).
///
/// Restituisce `null` se non esiste una riga corrispondente.
int? _indiceRiga(
  List<PreventivoRiga> righe,
  String prodottoId, {
  String? paniereId,
}) {
  for (var i = 0; i < righe.length; i++) {
    final r = righe[i];
    if (r.prodottoId == prodottoId && r.paniereId == paniereId) return i;
  }
  return null;
}
