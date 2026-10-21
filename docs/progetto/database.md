# Database — Firestore

## Collezioni

| Collezione | Chiave | Note |
|---|---|---|
| `aziende` | id automatico | `created_by` per la prima membership |
| `utenti` | uid Firebase Auth | profilo, `super_admin` |
| `membri` | `{aziendaId}_{uid}` | ruolo per azienda |
| `ruoli` | id automatico | `azienda_id`, permessi |
| `licenze` | `{aziendaId}` | piano e limiti |
| `prodotti`, `categorie`, `clienti`, `preventivi`, `giro_visite` | id | `azienda_id` |
| `impostazioni` | `{aziendaId}_{chiave}` | chiave/valore |
| `contatori` | `preventivi_{aziendaId}` | numero progressivo preventivi |
| `bandi_*`, `piani_config`, `whatsapp_config` | varie | globali |

## Regole

`firestore.rules`: lettura/scrittura solo ai membri dell'azienda; super admin per le funzioni di piattaforma;
bandi leggibili pubblicamente. Ogni modifica alle regole va provata e deployata con
`firebase deploy --only firestore:rules`.

## Numerazione preventivi

Il contatore è aggiornato in transazione. Non riutilizzare numeri e non modificare il contatore a mano.
