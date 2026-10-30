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
| `appuntamenti` | auto | `azienda_id`, `data`, `ora`, `operatore_id`, `cliente_id`, `call_*`, id esterni |
| `task` | auto | `azienda_id`, `scadenza`, `operatore_id`, `stato`, `priorita` |
| `notifiche` | auto | `azienda_id`, `utente_uid`, `tipo`, `stato`, `letta_at` |
| `chat_stanze` | auto | `azienda_id`, `tipo`, `partecipanti_uids`, `ultimo_messaggio` |
| `chat_stanze/{id}/messaggi` | auto | `mittente_uid`, `testo`, `created_at`, `eliminato` |
| `integrazioni_azienda` | `{aziendaId}` | modalità Google/Microsoft, client ID pubblico, `secret_ref`, stato, call predefinita, condivisione |
| `integrazioni` | `{aziendaId}_{uid}` | account/calendario collegato, stato, ultimo sync; **nessun token** |
| `condivisioni_calendario` | `{az}_{prop}_{dest}` | livello, stato, creato/revocato, audit |
| `impostazioni_agenda` | `{aziendaId}` | fuso, promemoria, template, slot, limiti, condivisione |

**Ultima revisione**: 2026-10-24
