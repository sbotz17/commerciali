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

## 2026-10-22 — Parità Flutter

Verifica per la nuova app `flutter_app/` che riusa lo stesso Firestore (`commerciali-app`) senza
migrazioni e senza modifiche a `firestore.rules`.

### 1. Collezioni e campi
Tutte le collezioni usate da `SP` esistono e hanno regole: `aziende`, `utenti`, `membri`, `ruoli`,
`licenze`, `piani_config`, `whatsapp_config`, `impostazioni`, `prodotti`, `categorie`, `clienti`,
`preventivi`, `giro_visite`, `contatori`, `bandi_fonti`, `bandi_incentivi`, `bandi_sync_log`.
**Nessun gap funzionale**: nessuna collezione o campo mancante per la nuova app. Gap solo documentali
(campi scritti/letti da `SP` ma non enumerati in `memoria/dati/collezioni.md`):
`utenti.username/avatar`; `ruoli.descrizione/sistema`; `licenze.data_inizio/note`;
`prodotti.descrizione/attivo`; `preventivi.cliente_id/cliente_nome/utente_id/sconto/note/subtotale/
imp_sconto/imponibile/iva/totale_iva`; `giro_visite.utente_id/cliente_nome/telefono/indirizzo/note/
visita_padre_id/promemoria_*`.

### 2. Membership e super admin
`membri/{aziendaId}_{uid}` è la fonte del ruolo per azienda; `utenti/{uid}.super_admin == true` è il
super admin. Isolamento per `azienda_id` + `_scope()`; il super admin accede a tutte le aziende.
Nota: le letture a intera collezione (`getTutteAziende`) funzionano solo per il super admin — le regole
di lettura fanno fallire atomically le query che includono documenti non leggibili.

### 3. Contatore preventivi
`contatori/preventivi_{aziendaId}` con campo `valore`, incremento in `runTransaction`, numero `PRV-` +
4 cifre, revisioni `-R{n}` senza consumare il contatore. Stessa chiave, stesso comportamento; vietato
scrivere il contatore fuori dalla transazione.

### 4. Indici
**Nessun indice nuovo necessario.** `SP` usa solo filtri a campo singolo (`azienda_id`, `utenti.email`,
`membri.utente_id`, `membri.azienda_id`) e ordina in memoria; l'unico `orderBy` (`bandi_sync_log.
avviato_il desc`) è a campo singolo. Nessun `where`+`orderBy` composto, nessun `collectionGroup`,
nessun `array-contains`. `firestore.indexes.json` resta vuoto. ⚠️ Se Flutter introducesse query
server-side composte (`where azienda_id` + `orderBy`), servirebbero indici compositi: NON previsti,
mantenere il sorting client-side per la parità.

### 5. Operazioni che richiederebbero una regola diversa (segnalate, NON modificate)
- `inserisciUtente` crea `utenti/{id_generato}` con `.add()`; la regola consente la create solo con
  `userId == uid()`. La creazione di un profilo altrui da parte dell'admin è bloccata dalle regole
  attuali (andrebbe fatta su `utenti/{authUid}` o con regola diversa).
- `aggiornaUtente` aggiorna `utenti/{id}` di un altro utente (`nome`, `attivo`, `avatar`, `menu_utente`);
  la regola consente l'update solo con `userId == uid() || isSuper()`. Un admin di azienda che disabilita
  o rinomina un membro verrebbe bloccato.
Replicare in Flutter il comportamento attuale e portare entrambi i casi ad Andrea. `eliminaUtente`
(rimozione del solo documento `membri`) è coerente con le regole: nessuna segnalazione.
