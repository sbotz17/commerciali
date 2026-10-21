# Data layer — interfaccia SP

**Quando leggerlo**: qualsiasi modifica a dati, query o persistenza.
**File**: `js/sp-firestore.js`, `js/firebase.js`.

## Convenzioni

- L'app chiama `SP.<metodo>`; non usare Firestore direttamente nelle pagine.
- Collezioni piatte con `azienda_id`; `_scope()` filtra l'azienda attiva.
- Gli id documento sono stringhe; per i dati migrati coincidono con i vecchi id numerici.
- Gli errori di scrittura tornano `{ __errore: "..." }`, non eccezioni.
- Date e timestamp sono stringhe ISO.
- `SP` non conosce l'interfaccia: nessun accesso a DOM o Alpine.

## Aggiungere un metodo

1. Aggiungi il metodo in `SP` con lo stesso stile (try/catch, `_scope`, `_now`).
2. Aggiorna `docs/progetto/memoria/dati/collezioni.md`.
3. Aggiorna le regole se serve un nuovo campo/collezione.
4. Aggiungi il test o la verifica manuale nel nodo dell'area.

**Ultima revisione**: 2026-10-22
