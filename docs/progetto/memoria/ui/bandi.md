# Bandi e agevolazioni

**Quando leggerlo**: pagina Bandi, fonti, sync, import.
**File**: `js/bandi-data.js`, `js/app.js` (pagine Bandi/Import), `js/sp-firestore.js` (`getBandi`, `getFontiBandi`, `getSyncLog`, `avviaSyncBandi`), `scripts/sync-bandi-locale.js`.

## Punti fermi

- I bandi sono dati pubblici: la lettura non richiede login.
- `bandi_incentivi` contiene i bandi; `bandi_fonti` le fonti; `bandi_sync_log` i log.
- La sync automatica su GitHub è disattivata: si usa lo script locale.
- L'import manuale scrive un log e aggiorna la fonte.

## Test

- Aprire la pagina Bandi e verificare filtri e dettaglio.
- Eseguire un import di prova e controllare il log.

**Ultima revisione**: 2026-10-22
