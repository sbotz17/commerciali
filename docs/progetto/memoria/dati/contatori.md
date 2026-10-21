# Contatori e numerazione preventivi

**Quando leggerlo**: numeri `PRV-`, revisioni, migrazioni.
**File**: `js/sp-firestore.js` (`_nextNumeroPreventivo`, `inserisciPreventivo`, `creaRevisione`).

## Punti fermi

- Il contatore è `contatori/preventivi_{aziendaId}` con campo `valore`.
- L'incremento avviene in una transazione Firestore.
- Il numero è `PRV-` + 4 cifre.
- Le revisioni non consumano il contatore: usano il numero base + `-R{n}`.
- Non modificare il contatore a mano: si rischia di duplicare numeri.

**Ultima revisione**: 2026-10-22
