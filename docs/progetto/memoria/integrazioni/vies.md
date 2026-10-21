# VIES — verifica Partita IVA

**Quando leggerlo**: verifica P.IVA, errori VIES, proxy.
**File**: `worker/src/index.js`, `worker/wrangler.toml`, `js/sp-firestore.js` (`_vies`, `cercaVIES`, `verificaPIVA`), `index.html` (modale VIES).

## Flusso

1. L'app chiama `POST https://commerciali-vies.bottiandrea83.workers.dev/` con `{ piva }`.
2. Il Worker normalizza la P.IVA (11 cifre, senza `IT`) e chiama
   `https://ec.europa.eu/taxation_customs/vies/rest-api/ms/IT/vat/{piva}`.
3. Risposta normalizzata: `{ ok, valido, piva, name, address, requestDate, fonte }`.
4. `verificaPIVA` mappa la risposta per la modale (`ragioneSociale`, `stato`, `indirizzo`).

## Punti fermi

- Il browser non può chiamare VIES direttamente (CORS): serve il Worker.
- Nessuna credenziale: VIES è pubblico.
- P.IVA non valida: `ok: true`, `valido: false`, nome e indirizzo vuoti.
- Errori di rete: `ok: false` con messaggio; la modale li mostra.

## Test

- `IT00159560366` → Ferrari S.p.A., valida.
- `00000000000` → non valida.
- Worker: `cd worker && npx wrangler deploy`.

**Ultima revisione**: 2026-10-22
