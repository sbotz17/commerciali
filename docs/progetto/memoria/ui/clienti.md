# Clienti

**Quando leggerlo**: lista clienti, form, duplicati, verifica P.IVA.
**File**: `js/app.js` (`clientiPage`), `index.html` (sezione Clienti e modale VIES), `js/sp-firestore.js` (`getClienti`, `cercaDuplicatoCliente`, `inserisciCliente`, `aggiornaCliente`, `eliminaCliente`).

## Flusso

- Lista: `Alpine.store("db").clienti`, filtro `clientiFiltrati`.
- Creazione: `inserisciCliente` con `azienda_id` attivo; controllo duplicato per P.IVA o nome/CF.
- Verifica P.IVA: `SP.verificaPIVA` → Cloudflare Worker → VIES; la modale mostra ragione sociale, stato e indirizzo.
- Modifica/eliminazione: per id documento Firestore.

## Punti fermi

- Ogni cliente appartiene a un'azienda (`azienda_id`); le regole impediscono di leggere altre aziende.
- La P.IVA viene normalizzata (maiusc., senza `IT`).
- La modale VIES è solo informativa: non cambia i dati del cliente.

## Test

- Creare un cliente, riaprirlo, modificarlo, eliminarlo.
- P.IVA valida (Ferrari `00159560366`), P.IVA invalida, P.IVA duplicata.

**Ultima revisione**: 2026-10-22
