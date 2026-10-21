# Preventivi

**Quando leggerlo**: creazione, modifica, PDF, revisioni, numerazione.
**File**: `js/app.js` (`preventiviPage`, `nuovoPreventivo`), `index.html` (sezione Preventivi), `js/sp-firestore.js` (`getPreventivi`, `inserisciPreventivo`, `aggiornaPreventivo`, `aggiornaStato`, `creaRevisione`, `eliminaPreventivo`), `docs/progetto/memoria/dati/contatori.md`.

## Punti fermi

- `numero` è `PRV-0001`, generato da un contatore transazionale per azienda.
- Le revisioni mantengono il numero base e aggiungono `-R1`, `-R2`.
- `righe` è un array di oggetti; i totali sono calcolati e salvati.
- `utente_id` è l'uid del profilo; i commerciali vedono solo i propri preventivi.
- Il PDF è generato nel browser (jsPDF).

## Test

- Creare un preventivo, verificare il numero, modificarlo, creare una revisione.
- Verificare i totali con sconto e IVA.

**Ultima revisione**: 2026-10-22
