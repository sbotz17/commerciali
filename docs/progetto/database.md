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
| `appuntamenti` | Appuntamenti generici o collegati a visite | titolo, data, ora, durata_min, cliente_id/nome, operatore_id, luogo, note, stato, visita_id, call_provider/url, meeting_id, google_event_id, outlook_event_id, etag_esterno, invitati_uids, conferme, stato_condivisione |
| `task` | Attività e compiti | titolo, scadenza, operatore_id, priorita, note, cliente_id, appuntamento_id, stato, completato_da/at |
| `promemoria` | Eventi programmati da inviare | riferito_a, elemento_id, destinatario_tipo, canale, destinatario, quando_at, stato, inviato_at, tentativi, errore, idempotenza_key |
| `notifiche` | Consegne effettive in-app/push/WhatsApp | utente_uid, tipo, titolo, testo, target_tipo/id, canale, stato, programmata_at, inviata_at, letta_at, tentativi, errore, idempotenza_key |
| `dispositivi` | Token push per dispositivo | utente_uid, piattaforma, token_fcm, attivo, ultimo_uso_at |
| `impostazioni_notifiche/{aziendaId}_{uid}` | Preferenze personali | canali, tipi, numero WhatsApp, consenso, silenzio, fuso, anteprima |
| `contatti_notifiche/{aziendaId}_{uid}` | Rubrica aziendale per avvisi WhatsApp | numero, consenso, aggiornato_at; leggibile dai membri dell'azienda |
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

## 2026-10-24 — Integrazioni aziendali e condivisione calendario

**Stato: solo documento di progetto (DBA).** Nessuna modifica a `firestore.rules`, nessun indice
deployato, nessuna migrazione. Tutto è **additivo**: i nuovi documenti nascono al primo write, i campi
nuovi si leggono con default, nessun dato esistente viene toccato.

Scopo: configurare le integrazioni Google/Microsoft a livello di **azienda** (non solo di singolo
utente) e introdurre la **condivisione del calendario** tra utenti della stessa azienda, con livelli di
visibilità e mascheramento degli eventi esterni via Worker. **Nessun** token, refresh token, password o
client secret viene mai scritto in Firestore: i secret restano nel Worker (KV/secret), Firestore contiene
al massimo un `secret_ref` (riferimento opaco non utilizzabile direttamente).

### 1. `integrazioni_azienda/{aziendaId}` — configurazione aziendale dei provider

Un documento per azienda (id = `aziendaId`).

| Campo | Tipo | Note |
|---|---|---|
| `azienda_id` | string | isolamento, = id del documento |
| `google` | map | configurazione Google (campi sotto) |
| `microsoft` | map | configurazione Microsoft (campi sotto) |
| `call_predefinita` | string enum | `meet` \| `teams`, provider predefinito per le call |
| `condivisione_abilitata` | bool | switch master condivisione calendario |
| `livello_condivisione_predefinito` | string enum | default nuove condivisioni (`libero_occupato` \| `dettagli` \| `modifica`) |
| `updated_at` | timestamp | ultima modifica |

Mappe `google` e `microsoft` (campi identici, tranne `tenant_id` solo per Microsoft):

| Campo | Tipo | Note |
|---|---|---|
| `modalita` | string enum | `closer` (client condiviso gestito da Closer) \| `personalizzata` (client del cliente) |
| `attivo` | bool | integrazione attiva per il provider |
| `client_id` | string | **non segreto**, pubblico nel provider |
| `secret_ref` | string | riferimento opaco al secret nel Worker; **mai** il secret stesso |
| `redirect_uri` | string | URL callback OAuth |
| `tenant_id` | string | **solo Microsoft** (multi-tenant / tenant specifico) |
| `stato` | string enum | `non_configurata` \| `configurata` \| `errore` \| `da_rinnovare` |
| `configurato_da` | string | uid che ha avviato la configurazione |
| `configurato_at` | timestamp | quando è stato configurato |
| `ultimo_test_at` | timestamp | ultimo test di collegamento |
| `errore` | string \| null | ultimo errore, senza dettagli sensibili |

**Vincolo invalicabile**: nessun campo `token`, `refresh_token`, `access_token`, `client_secret`,
`password` o simile. I secret vivono solo nel Worker.

### 2. `condivisioni_calendario/{aziendaId}_{proprietarioUid}_{destinatarioUid}` — condivisione tra utenti

Id **deterministico** `{aziendaId}_{proprietarioUid}_{destinatarioUid}`: al massimo un documento per
coppia (proprietario → destinatario) nella stessa azienda, quindi niente duplicati.

| Campo | Tipo | Note |
|---|---|---|
| `azienda_id` | string | isolamento |
| `proprietario_uid` | string | chi condivide il proprio calendario |
| `destinatario_uid` | string | chi riceve la condivisione (membro della **stessa** azienda) |
| `livello` | string enum | `libero_occupato` \| `dettagli` \| `modifica` |
| `stato` | string enum | `attiva` \| `revocata` |
| `creato_da` | string | uid (proprietario o admin) |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |
| `revoked_at` | timestamp \| null | valorizzato alla revoca |
| `revoked_by` | string \| null | uid che ha revocato |

La revoca è un **update** (`stato="revocata"`, `revoked_at`, `revoked_by`), non una cancellazione
fisica: conserva traccia e, grazie all'id deterministico, impedisce di riattivare inavvertitamente la
coppia senza passare dal flusso previsto.

### 3. Estensione `integrazioni/{aziendaId}_{uid}` (per utente)

Estensione **additiva** del documento esistente (già definito il 23/10: `provider`, `calendar_id`,
`tenant_id`, `stato`, `collegato_at`, `scopes`). Nuovi campi:

| Campo | Tipo | Note |
|---|---|---|
| `azienda_id` | string | **aggiunto**: serve per il read admin (`isAdminOf`) |
| `account_email` | string | email dell'account Google/Microsoft collegato |
| `calendar_id` | string | esistente; id calendario per sync/eventi |
| `calendar_nome` | string | nome leggibile del calendario |
| `stato` | string enum | esistente; allineare i valori (`collegato` \| `revocato` \| `errore` \| `da_rinnovare`) |
| `collegato_at` | timestamp | esistente |
| `ultimo_sync_at` | timestamp \| null | ultimo sync eventi esterni riuscito |
| `errore` | string \| null | ultimo errore, senza dettagli sensibili |

**Nessun token/refresh/secret**: come da regola esistente, il client vede solo lo stato; i token stanno
nel Worker.

⚠️ **Allineamento campo proprietario**: le regole attuali leggono `utente_uid`, mentre `architettura.md`
cita `utente_id`. Prima di applicare le regole, uniformare il nome (consigliato `utente_uid`, coerente
con `condivisioni_calendario.proprietario_uid/destinatario_uid`).

### 4. Estensione `impostazioni_agenda/{aziendaId}`

Nuovi campi **additivi** (default compatibili: campo assente → default lato client):

| Campo | Tipo | Default | Note |
|---|---|---|---|
| `condivisione_abilitata` | bool | `false` | opt-in, disattivata di default |
| `livello_condivisione_predefinito` | string enum | `libero_occupato` | default più restrittivo |
| `consenti_modifica_condivisa` | bool | `false` | permette di offrire il livello `modifica` |

Coerenza: `integrazioni_azienda` porta gli stessi flag `condivisione_abilitata`/
`livello_condivisione_predefinito` come snapshot per provider; la **fonte di verità per i default UI**
resta `impostazioni_agenda` (letta da tutti i membri), mentre `integrazioni_azienda` è admin-only.

### 5. Security Rules proposte (NON applicate)

Il Worker usa l'Admin SDK: bypassa le regole e scrive i campi operativi (`stato`, `configurato_at`,
`ultimo_test_at`, `errore`, `secret_ref`, `ultimo_sync_at`); i token vivono solo lì. Le regole client
devono essere **allowlist**: verificare i campi scrivibili con `diff(...).affectedKeys().hasOnly([...])`
per impedire di scrivere campi secret o estranei.

- `integrazioni_azienda/{az}`:
  - `read`: `isAdminOf(az) || isSuper()` — configurazione amministrativa; i membri non ne hanno bisogno
    (i default di condivisione stanno in `impostazioni_agenda`).
  - `write`: `isAdminOf(az) || isSuper()`, limitato ai soli campi di configurazione (`google.modalita`,
    `google.attivo`, `google.client_id`, `google.redirect_uri`, `microsoft.*`, `call_predefinita`,
    `condivisione_abilitata`, `livello_condivisione_predefinito`, `updated_at`); **mai** `secret_ref`/
    `stato`/`configurato_at`/`errore` via client (li scrive solo il Worker).
  - Nessun secret: rifiutare esplicitamente chiavi come `client_secret`, `refresh_token`, `access_token`,
    `token`, `password`.
- `condivisioni_calendario/{id}`:
  - `read`: `memberOf(az) && (proprietario_uid == uid() || destinatario_uid == uid() || isAdminOf(az)) || isSuper()`.
  - `create`: `(proprietario_uid == uid() && memberOf(az)) || isAdminOf(az) || isSuper()`, con
    **destinatario membro della stessa azienda** (`exists(membri/{az}_{destinatario_uid})`),
    `destinatario_uid != proprietario_uid`, `stato == "attiva"` e id documento = `az_proprietario_destinatario`.
  - `update`: solo proprietario/admin della stessa azienda, e **solo per la revoca** (transizione
    `stato` → `revocata` + `revoked_at`/`revoked_by`).
  - `delete`: solo proprietario/admin della stessa azienda.
  - Isolamento: `azienda_id` presente e coerente; nessun cross-company.
- `integrazioni/{id}` (per utente):
  - `read`: **self** (`utente_uid == uid()`) **o admin della stessa azienda** (`isAdminOf(resource.data.azienda_id)`)
    **o super**. *Motivazione*: l'admin deve verificare lo stato dei collegamenti dei propri operatori
    (supporto/configurazione) e il `calendar_id` per la gestione aziendale; l'esposizione è limitata
    (nessun token, solo `account_email`, `calendar_id`, `calendar_nome`, `stato`). Se `account_email`
    risultasse troppo sensibile, declassare a self+super (punto da confermare con Andrea).
  - `write`: `if false` (client); solo Worker/Admin SDK scrive. Nessun token.
- `impostazioni_agenda/{az}`:
  - `read`: `memberOf(az) || isSuper()` (invariata).
  - `write`: `isAdminOf(az) || isSuper()` (invariata). I tre nuovi campi rientrano nella scrittura admin
    esistente.

**Nota privacy sugli `appuntamenti` Closer**: restano leggibili da tutta l'azienda come oggi. La
condivisione con mascheramento (libero/occupato → dettagli) riguarda gli **eventi esterni** via Worker,
che applica il livello di visibilità fuori da Firestore. Se si vuole privacy anche sui documenti
`appuntamenti` (es. un operatore che nasconde i propri impegni ai colleghi), serve un **task separato**
con regola restrittiva su `appuntamenti` e analisi d'impatto su visite/task/promemoria: non incluso qui.

### 6. Indici

Gli id deterministici (`integrazioni_azienda/{az}`, `condivisioni_calendario/{az}_{prop}_{dest}`,
`integrazioni/{az}_{uid}`, `impostazioni_agenda/{az}`) non richiedono indici per i lookup puntuali.

Servono **due indici compositi** su `condivisioni_calendario`:
- “condivisi con me”: `(azienda_id, destinatario_uid, stato)`;
- “da me condivisi”: `(azienda_id, proprietario_uid, stato)`.

Esempio `firestore.indexes.json` (NON applicare):

```json
{
  "indexes": [
    {
      "collectionGroup": "condivisioni_calendario",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "azienda_id", "order": "ASCENDING" },
        { "fieldPath": "destinatario_uid", "order": "ASCENDING" },
        { "fieldPath": "stato", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "condivisioni_calendario",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "azienda_id", "order": "ASCENDING" },
        { "fieldPath": "proprietario_uid", "order": "ASCENDING" },
        { "fieldPath": "stato", "order": "ASCENDING" }
      ]
    }
  ]
}
```

Gli indici a campo singolo (`azienda_id`, `destinatario_uid`, `proprietario_uid`, `stato`) sono
automatici in Firestore.

### 7. Migrazione

**Nessuna migrazione.** Tutto additivo:
- i nuovi documenti nascono al **primo write** (`integrazioni_azienda`, `condivisioni_calendario`);
- i documenti esistenti (`integrazioni/{az}_{uid}`, `impostazioni_agenda/{az}`) ricevono i **campi nuovi
  solo se scritti**;
- i campi mancanti si leggono con **default** lato client (`false`, `libero_occupato`, `null`);
- nessun `DELETE`, nessun `DROP`, nessuna riscrittura di massa, nessun dato esistente toccato.

### 8. Rischi

| Rischio | Mitigazione |
|---|---|
| Query che richiedono indice composito | deployare i 2 indici prima di usare le query “condivisi con me”/“da me condivisi”, altrimenti la query fallisce |
| Regole con OR su proprietario/destinatario limitano le query | la lista “tutte le condivisioni dell'azienda” (admin) non è esprimibile come filtro unico coerente con la regola → per l'admin servirebbe una query dedicata o la lettura via Worker/Admin SDK, oppure una regola admin più ampia (da valutare) |
| Regole troppo permissive | allowlist dei campi con `diff(...).affectedKeys().hasOnly([...])`; rifiuto esplicito delle chiavi secret; test positivi/negativi sotto |
| `secret_ref` vs secret | `secret_ref` è solo una stringa opaca; il vero secret resta nel Worker. Non accettare campi `*_secret`/`token` nelle regole |
| Utente disattivato | il destinatario deve essere membro **attivo**; alla disattivazione la condivisione resta ma non è più leggibile (o va revocata dal flusso di disattivazione). Verificare `membri` e `utenti.attivo` |
| Revoca immediata | la revoca è un update `stato="revocata"`; l'effetto è immediato, ma il Worker deve riverificare `stato` a ogni accesso (niente cache di vecchie condivisioni) |
| Divergenza `integrazioni_azienda` vs `impostazioni_agenda` | unica fonte di verità per i default = `impostazioni_agenda`; `integrazioni_azienda` come snapshot admin; documentare e testare la sincronizzazione |
| Id deterministico riusato | dopo una revoca, una nuova create sulla stessa coppia riusa lo stesso id: il flusso deve azzerare `revoked_*` e reimpostare `stato="attiva"` in modo esplicito e tracciato |

### Tabella riassuntiva

| Collezione / documento | Chiave | Chi legge | Chi scrive | Note |
|---|---|---|---|---|
| `integrazioni_azienda` | `{aziendaId}` | admin, super | admin, super (config) + Worker (campi operativi) | nessun secret; solo `secret_ref` |
| `condivisioni_calendario` | `{az}_{prop}_{dest}` | proprietario, destinatario, admin, super | create: proprietario/admin; update/delete: proprietario/admin | revoca = update; no cross-company |
| `integrazioni` | `{az}_{uid}` | self, admin (stessa az), super | solo Worker/Admin SDK (`write: false` client) | nessun token |
| `impostazioni_agenda` | `{aziendaId}` | membro, super | admin, super | +3 campi nuovi |

### Criteri di test per le regole (casi positivi e negativi)

| # | Collezione | Operazione | Attore | Esito atteso |
|---|---|---|---|---|
| P1 | `integrazioni_azienda` | read | admin azienda | ✅ consentito |
| P2 | `integrazioni_azienda` | write (config) | admin azienda | ✅ consentito |
| P3 | `integrazioni_azienda` | write (campi operativi) | Worker (Admin SDK) | ✅ bypassa regole |
| P4 | `condivisioni_calendario` | create | proprietario → destinatario membro stessa azienda | ✅ consentito |
| P5 | `condivisioni_calendario` | read | destinatario | ✅ consentito |
| P6 | `condivisioni_calendario` | update (revoca) | proprietario | ✅ consentito |
| P7 | `condivisioni_calendario` | delete | admin azienda | ✅ consentito |
| P8 | `integrazioni` | read | self | ✅ consentito |
| P9 | `integrazioni` | read | admin stessa azienda | ✅ consentito (per decisione motivata) |
| P10 | `integrazioni` | write | Worker (Admin SDK) | ✅ consentito |
| P11 | `impostazioni_agenda` | read | membro | ✅ consentito |
| P12 | `impostazioni_agenda` | write | admin | ✅ consentito |
| N1 | `integrazioni_azienda` | read | membro non admin | ❌ negato |
| N2 | `integrazioni_azienda` | write | membro non admin | ❌ negato |
| N3 | `integrazioni_azienda` | write campo `client_secret`/`token` | chiunque via client | ❌ negato (allowlist) |
| N4 | `condivisioni_calendario` | create | destinatario fuori azienda | ❌ negato (cross-company) |
| N5 | `condivisioni_calendario` | create | terzo utente non proprietario/admin | ❌ negato |
| N6 | `condivisioni_calendario` | update (modifica livello) | destinatario | ❌ negato (solo revoca) |
| N7 | `condivisioni_calendario` | read | utente estraneo all'azienda | ❌ negato |
| N8 | `integrazioni` | read | membro non admin, non self | ❌ negato |
| N9 | `integrazioni` | write | client (anche self) | ❌ negato (`write: false`) |
| N10 | `impostazioni_agenda` | write | membro non admin | ❌ negato |
| N11 | `condivisioni_calendario` | read | utente disattivato (ex-membro) | ❌ negato |

## 2026-10-24 — Inviti agli appuntamenti

Campi aggiunti (facoltativi) a `appuntamenti`, senza nuova collezione e senza modifiche alle regole:

- `invitati_uids`: elenco di uid di colleghi della stessa azienda;
- `conferme`: mappa `uid → { stato: confermato|rifiutato, at }`;
- `stato_condivisione`: `non_condiviso` | `in_attesa` | `confermato` | `rifiutato`.

L'invitato aggiorna il documento con una transazione (già consentita dalla regola `update` per i membri);
la notifica In-App usa la collezione `notifiche` esistente con `target_tipo = appuntamento` e
`target_id = id` dell'appuntamento. Nessun indice nuovo.

### Rubrica WhatsApp aziendale (`contatti_notifiche`)

Per inviare un avviso WhatsApp a un collega, il client deve conoscere il suo numero. Le preferenze
`impostazioni_notifiche` restano private; viene quindi creata una rubrica aziendale ridotta:

- documento `contatti_notifiche/{aziendaId}_{uid}`;
- campi `azienda_id`, `utente_uid`, `numero_whatsapp`, `consenso_whatsapp`, `updated_at`;
- leggibile dai membri dell'azienda, scrivibile e cancellabile solo dall'interessato;
- viene aggiornata da `salvaPreferenzeNotifiche` e cancellata se il consenso o il canale WhatsApp vengono
  disattivati.

Regole aggiunte in `firestore.rules` e verificate con `scripts/e2e-agenda.py` (lettura tra colleghi,
divieto di modifica del recapito altrui). Nessun indice nuovo.

### Configurazione WhatsApp nel Worker

La `whatsapp_config` di Firestore non è più usata dalla nuova app: URL e API key del server WhatsApp
vivono nel **KV del Worker Cloudflare** (`WHATSAPP_CONFIG`, chiave `server`). Il Worker li restituisce solo
al super admin autenticato e li usa per gli invii richiesti dagli utenti autenticati. La regola Firestore
`whatsapp_config` è stata quindi ristretta al solo super admin. I numeri/consensi restano in
`contatti_notifiche`, letti dal Worker con il token del chiamante.
