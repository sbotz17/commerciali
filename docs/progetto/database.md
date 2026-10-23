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

### 6. Query aziendali: filtro server + ordinamento client

Le query aziendali (clienti, prodotti, categorie, preventivi) sono filtrate lato server per `azienda_id`
(`where('azienda_id', isEqualTo: ...)`) e **ordinate lato client in Dart**, senza `orderBy` server-side.
Così non servono indici compositi (`azienda_id` + campo di ordinamento): un filtro a campo singolo su
`azienda_id` copre tutti i casi, e l'ordinamento (`clienti`/`prodotti` per `nome`, `categorie` per `ordine`,
`preventivi` per `created_at` discendente) avviene in memoria. Eventuali filtri aggiuntivi (es. `soloUtenteId`
dei preventivi) si applicano anch'essi in Dart dopo la lettura. `firestore.indexes.json` resta vuoto.

## 2026-10-23 — Nuove collezioni pianificate: agenda, notifiche, chat

**Stato: regole definite (task H01), non ancora deployate.** Le Security Rules per le nuove collezioni sono pronte in `firestore.rules`; il deploy resta soggetto ad approvazione. Le collezioni nascono al primo write (nessuna "creazione" esplicita).

Tutte le collezioni hanno `azienda_id` e sono isolate per azienda.

| Collezione | Scopo | Campi principali |
|---|---|---|
| `appuntamenti` | Appuntamenti generici o collegati a visite | titolo, data, ora, durata_min, cliente_id/nome, operatore_id, luogo, note, stato, visita_id, call_provider/url, meeting_id, google_event_id, outlook_event_id, etag_esterno |
| `task` | Attività e compiti | titolo, scadenza, operatore_id, priorita, note, cliente_id, appuntamento_id, stato, completato_da/at |
| `promemoria` | Eventi programmati da inviare | riferito_a, elemento_id, destinatario_tipo, canale, destinatario, quando_at, stato, inviato_at, tentativi, errore, idempotenza_key |
| `notifiche` | Consegne effettive in-app/push/WhatsApp | utente_uid, tipo, titolo, testo, target_tipo/id, canale, stato, programmata_at, inviata_at, letta_at, tentativi, errore, idempotenza_key |
| `dispositivi` | Token push per dispositivo | utente_uid, piattaforma, token_fcm, attivo, ultimo_uso_at |
| `impostazioni_notifiche/{aziendaId}_{uid}` | Preferenze personali | canali, tipi, numero WhatsApp, consenso, silenzio, fuso, anteprima |
| `allegati` | Metadati immagini | elemento_tipo/id, nome, mime, dimensione, object_key R2, thumb_url |
| `impostazioni_agenda/{aziendaId}` | Configurazione aziendale | fuso, anticipo, orario invio cliente, canale, template, slot, limiti allegati, Maps |
| `integrazioni/{aziendaId}_{uid}` | Stato account Google/Microsoft | provider, calendar_id, tenant_id, stato, scopes (nessun token) |
| `slot/{token}` | Disponibilità condivise | operatore_id, data, ora, durata, stato, scade_at |
| `prenotazioni` | Prenotazioni ricevute | slot_id, nome, email, telefono, stato, appuntamento_id |
| `cache_eventi_esterni` | Eventi Google/Outlook importati | utente_id, provider, evento_id, inizio/fine, titolo, luogo, etag |
| `chat_stanze` | Conversazioni dirette e gruppi | azienda_id, tipo, nome, partecipanti_uids, creatore_uid, ultimo_messaggio, ultimo_messaggio_at |
| `chat_stanze/{id}/messaggi` | Messaggi della conversazione | mittente_uid, testo, tipo, image_key, created_at, eliminato, idempotenza_key |

### Indici

**Nessun indice composito.** Le query filtrano per singolo campo (`azienda_id` o `utente_uid`) e ordinano lato client, come per le altre collezioni aziendali. `firestore.indexes.json` resta vuoto.

### Regole implementate (task H01)

- `appuntamenti`/`task`/`promemoria`/`allegati`: read/create/update solo membro dell'azienda; delete anche super (il super non legge né aggiorna queste collezioni).
- `notifiche`: read/delete solo destinatario (`utente_uid`); create da membro con `mittente_uid == uid()` e destinatario membro dell'azienda; update solo destinatario e solo sul campo `letta_at`.
- `dispositivi`: solo il proprietario (`utente_uid`), in lettura, scrittura e cancellazione.
- `impostazioni_notifiche`: read proprietario o super; create/update/delete solo proprietario.
- `impostazioni_agenda/{az}`: read membro o super; write solo admin o super.
- `integrazioni`/`cache_eventi_esterni`: read proprietario/super o membro/super; nessuna scrittura client (`allow write: if false`), gestiti da Worker/Admin.
- `slot`/`prenotazioni`: read/write membro o super; il pubblico NON legge (il link pubblico passa dal Worker, l'Admin SDK bypassa le regole).
- `chat_stanze`: read/update membro e partecipante; create membro con `uid()` tra i partecipanti; delete creatore o super. I `messaggi` ereditano `azienda_id` e `partecipanti_uids` dalla stanza (via `get` sul padre); create richiede `mittente_uid == uid()`, update/delete solo mittente o super.
- upload immagini su Cloudflare R2 tramite URL firmato dal Worker.

**Approvazione**: Andrea ha autorizzato l'aggiunta delle nuove collezioni e regole il 23/10/2026.
