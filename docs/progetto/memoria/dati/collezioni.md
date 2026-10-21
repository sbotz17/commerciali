# Collezioni Firestore

**Quando leggerlo**: nuovi campi, nuove collezioni, query.
**File**: `js/sp-firestore.js`, `firestore.rules`, `docs/progetto/database.md`.

| Collezione | Chiave | Campi principali |
|---|---|---|
| `aziende` | auto | `nome`, `created_by`, `whatsapp_attivo`, anagrafica |
| `utenti` | uid Auth | `email`, `nome`, `ruolo`, `attivo`, `super_admin`, `menu_utente` |
| `membri` | `{aziendaId}_{uid}` | `azienda_id`, `utente_id`, `ruolo` |
| `ruoli` | auto | `azienda_id`, `nome`, `chiave`, `permessi`, `sconto_max` |
| `licenze` | aziendaId | `piano`, `stato`, `data_fine`, `max_utenti`, `max_preventivi` |
| `piani_config` | piano | `pagine`, `max_utenti`, `max_preventivi` |
| `whatsapp_config` | `1` | `url`, `api_key`, `numero`, `stato` |
| `impostazioni` | `{aziendaId}_{chiave}` | `chiave`, `valore` |
| `prodotti` | auto | `azienda_id`, `nome`, `categoria`, `prezzo`, `immagine` |
| `categorie` | auto | `azienda_id`, `nome`, `icona`, `ordine` |
| `clienti` | auto | `azienda_id`, anagrafica, `piva`, `codice_fiscale` |
| `preventivi` | auto | `azienda_id`, `numero`, `revisione`, `righe`, totali, `stato` |
| `giro_visite` | auto | `azienda_id`, `data`, `ora`, `ordine`, `stato`, `cliente_id` |
| `contatori` | `preventivi_{aziendaId}` | `azienda_id`, `valore` |
| `bandi_*` | varie | globali, lettura pubblica |

**Ultima revisione**: 2026-10-22
