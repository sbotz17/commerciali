# Dashboard

**Quando leggerlo**: conteggi, valore aperto, ultimi preventivi, azioni rapide.
**File**: `js/app.js` (`dashboardPage`), `index.html` (sezione Dashboard), `js/sp-firestore.js` (dati da store).

## Contenuti

- Conteggi preventivi visibili: totale, bozze, inviati, accettati, rifiutati.
- Valore aperto: somma di `totale_iva` per bozze e inviati.
- Ultimi 5 preventivi.
- Utenti attivi (solo per chi ha il permesso utenti).
- Azioni rapide: nuovo preventivo, nuovo cliente, cerca bandi, catalogo.

## Punti fermi

- I commerciali vedono solo i propri preventivi; gli admin quelli dell'azienda.
- I numeri derivano dallo store `db`, non da query separate.
- Nessun dato di altre aziende.

## Test

- Confrontare i conteggi con la lista preventivi per lo stesso utente.
- Verificare che un commerciale non veda preventivi altrui.

**Ultima revisione**: 2026-10-22
