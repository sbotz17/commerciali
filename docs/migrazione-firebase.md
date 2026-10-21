# Migrazione da Supabase a Firebase — piano di lavoro

Stato: in preparazione. Ramo `feature/firebase-migrazione`.

## Scelte

- **Nessuna riscrittura dell'app**: resta l'interfaccia `SP` in `js/supabase.js`; cambia solo
  l'implementazione dietro (Firestore + Firebase Auth). `js/app.js` non va riscritto.
- **Firebase Auth**: email + password e Google Sign-In.
- **Firestore** al posto delle tabelle Postgres.
- **Cloud Functions** al posto delle Edge Functions `creditsafe` e `sync-bandi`.
- **Hosting**: da decidere; il sito è statico e può restare dov'è.

## Fasi

1. **Progetto Firebase** (serve login Google e, per le Cloud Functions, piano Blaze).
   - Firestore in modalità nativa, regione `europe-west8` (Milano) o `eur3`.
   - Auth: abilitare Email/Password e Google.
   - App web: copiare la configurazione (`apiKey`, `authDomain`, `projectId`, `appId`).
2. **Adapter Firestore** dietro `SP` (70 funzioni), a gruppi:
   - aziende, membri, utenti, ruoli, licenze, piani, impostazioni;
   - prodotti, categorie, clienti;
   - preventivi (attenzione al numero progressivo e alle revisioni);
   - giro visite, bandi, whatsapp.
3. **Firebase Auth** in `js/auth.js`: login, registrazione, recupero password, logout, sessione,
   creazione account da parte dell'admin.
4. **Security Rules** che riproducono le RLS: isolamento per azienda, super admin, ruoli.
5. **Proxy VIES**:
   - `worker/` è un Cloudflare Worker (piano gratuito, nessuna carta) che inoltra le richieste
     all'API VIES della Commissione europea: il browser non può chiamarla direttamente per CORS.
   - Endpoint: `https://commerciali-vies.bottiandrea83.workers.dev`
   - Le Cloud Functions Firebase non sono usate (richiederebbero il piano Blaze).
6. **Migrazione dati** da Supabase (produzione).
7. **Collaudo** su Firebase Emulator Suite prima del passaggio reale.
8. **Taglio**: configurazione Firebase in produzione, blocco scritture su Supabase, verifica.

## Modello dati proposto

Collezioni "piatte" con il campo `azienda_id`: è il modello più vicino alle tabelle attuali, richiede meno
modifiche al codice e permette query semplici. Le regole verificano l'appartenenza tramite `membri/{aziendaId}_{uid}`.

| Supabase | Firestore |
|---|---|
| `aziende` | `aziende/{aziendaId}` |
| `membri` | `membri/{aziendaId}_{uid}` (campo `ruolo`) |
| `utenti` | `utenti/{uid}` (uid Firebase Auth; `email` indicizzata) |
| `ruoli` | `ruoli/{id}` + `azienda_id` |
| `licenze` | `licenze/{aziendaId}` (documento unico) |
| `piani_config` | `piani_config/{piano}` |
| `whatsapp_config` | `whatsapp_config/1` |
| `impostazioni` | `impostazioni/{aziendaId}_{chiave}` |
| `prodotti` | `prodotti/{id}` + `azienda_id` |
| `categorie` | `categorie/{id}` + `azienda_id` |
| `clienti` | `clienti/{id}` + `azienda_id` |
| `preventivi` | `preventivi/{id}` + `azienda_id` |
| `giro_visite` | `giro_visite/{id}` + `azienda_id` |
| `bandi_fonti` | `bandi_fonti/{id}` (globali) |
| `bandi_incentivi` | `bandi_incentivi/{id}` (globali) |
| `bandi_sync_log` | `bandi_sync_log/{id}` (globali) |

### ID e numerazione

- Gli ID esistenti vengono importati come ID documento **stringa** (`"12"`), così i riferimenti
  (`cliente_id`, `utente_id`, `azienda_id`) restano validi.
- I nuovi documenti usano ID automatici, ma i preventivi hanno bisogno del numero progressivo
  `PRV-0001`: serve un contatore per azienda (`aziende/{id}/contatori/preventivi`) aggiornato in
  transazione. La migrazione deve inizializzare il contatore al massimo numero esistente.
- Le revisioni (`-R1`, `-R2`) restano un campo `revisione` + `numero`.

### Autenticazione e profili

- `utenti/{uid}` con `email`, `nome`, `username`, `attivo`, `super_admin`, `menu_utente`.
- `super_admin` può stare come campo sul profilo (letto dalle regole) oppure come custom claim.
  Consiglio: custom claim per le regole + campo per l'interfaccia.
- Il collegamento attuale per email va sostituito con l'uid di Firebase Auth.
- **Le password Supabase non sono migrabili**: Supabase usa bcrypt, Firebase non importa hash bcrypt.
  Gli utenti dovranno reimpostare la password al primo accesso (o usare Google). Va comunicato.

## Cosa serve da te

1. Login Google alla CLI Firebase (`firebase login`).
2. Creare/abilitare il piano **Blaze** se vogliamo le Cloud Functions (creditsafe).
3. Per l'export dei dati: una chiave **service role** Supabase o la stringa di connessione del database,
   messa in un file locale non versionato (mai in chat, mai nel repository).
4. Le credenziali Creditsafe restano nei secrets Firebase, non nel codice.

## Rischi e note

- Firestore non è relazionale: i `select` con join (`aziende(nome)`, `utenti(nome)`) vanno risolti con
  letture separate o campi denormalizzati. Sono pochi e concentrati in `getAziendeUtente`,
  `getTutteAziende`, `getUtenti`.
- Le RLS diventano Security Rules: vanno scritte e provate con gli emulatori, non improvvisate.
- I costi dipendono da letture/scritture: l'app oggi ricarica intere collezioni (`select("*")`), va
  tenuto d'occhio.
- Il workflow `sync-bandi` su GitHub era già disattivato; la sincronizzazione gira da PC locale.
