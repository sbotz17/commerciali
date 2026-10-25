# Architettura — Commerciali

## Stack

- Frontend statico: HTML + Alpine.js + Tailwind (CDN), `index.html` + `js/`.
- Dati e auth: Firebase (Firestore, Auth, Hosting).
- Integrazione VIES: Cloudflare Worker.

## Flusso dati

`index.html` (Alpine) → `js/app.js` (store e pagine) → `JS SP` (`js/sp-firestore.js`) → Firestore.
`js/auth.js` gestisce Firebase Auth e il profilo `utenti/{uid}`.
Il Worker VIES è chiamato da `SP.cercaVIES` e `SP.verificaPIVA`.

## Multi-azienda

Ogni documento aziendale ha `azienda_id`. La membership è `membri/{aziendaId}_{uid}`.
Le regole Firestore verificano l'appartenenza; il super admin è `utenti/{uid}.super_admin`.

## Note

- `js/supabase.js` è legacy e non viene caricato.
- Non ci sono build step: il deploy è la copia dei file su Firebase Hosting.

## 2026-10-22 — Architettura Flutter

Nuova app `flutter_app/` (web + Android + iOS), stesso progetto Firebase `commerciali-app`, stesse
collezioni, regole, contatori e Worker VIES. **Nessuna** modifica a `firestore.rules`, `piani_config`,
contatori o Worker; nessuna nuova funzione; nessuna migrazione. La vecchia app Alpine resta in uso
finché la nuova non ha parità verificata area per area.

### 1. Struttura (feature-first)

```
flutter_app/
├── lib/
│   ├── main.dart / app.dart          # init Firebase, MaterialApp.router, tema
│   ├── core/                         # trasversale
│   │   ├── theme/                    # Material 3, colori, breakpoint
│   │   ├── utils/                    # formatta numero, normalizza P.IVA, date ISO
│   │   └── errori.dart               # errori SP e messaggi utente in italiano
│   ├── data/
│   │   ├── firebase/                 # opzioni per piattaforma, emulatori
│   │   ├── models/                   # Cliente, Prodotto, Preventivo, Visita, ...
│   │   ├── services/sp_service.dart  # replica 1:1 dell'interfaccia SP
│   │   ├── services/vies_service.dart# chiamata al Worker VIES
│   │   └── mappers/                  # Firestore Map <-> modello Dart
│   ├── state/                        # provider Riverpod (vedi §3)
│   ├── routing/                      # go_router + redirect auth
│   └── features/
│       ├── auth/                     # login, google, reset, onboarding
│       ├── dashboard/  clienti/  catalogo/  preventivi/
│       ├── visite/  bandi/  impostazioni/   # utenti, ruoli, licenze, superadmin
│       └── shell/                    # scaffold responsive (nav)
├── test/                             # unit + widget
├── integration_test/                 # e2e su emulatori
└── android/ ios/ web/                # generati da flutter create
```

### 2. Package consigliati

- `firebase_core`, `firebase_auth`, `cloud_firestore` — stesso backend, stesse regole.
- `google_sign_in` — login Google nativo su mobile (su web si usa il popup di `firebase_auth`).
- `flutter_riverpod` — state management reattivo e testabile, sostituisce `Alpine.store`.
- `go_router` — routing dichiarativo con `redirect` per auth/permessi e deep-link.
- `intl` — formati data/numero in italiano.
- `pdf` + `printing` — generazione e anteprima/stampa PDF lato client (sostituisce jsPDF).
- `url_launcher` — apertura bandi, WhatsApp, email.
- `image_picker` — solo se serve gestire immagini prodotto come file; altrimenti si usano URL come oggi.
- `mocktail` (dev) — mock nei test unit/widget di servizi e provider.

### 3. State management e routing

Provider principali (Riverpod, `AsyncNotifier` per i dati):
`firebaseProvider`, `authStateProvider` (onAuthStateChanged), `sessioneProvider` (profilo `utenti`),
`aziendaAttivaProvider` (corrisponde a `SP.setAziendaAttiva`), `membriProvider`,
`permessiProvider` (ruolo/permessi per azienda + `super_admin`), un provider dati per feature.

`go_router`: `/login`, `/reset-password`, `/onboarding`, `/` (shell con dashboard),
`/clienti`, `/catalogo`, `/preventivi`, `/preventivi/nuovo`, `/visite`, `/bandi`, `/impostazioni/*`.
`redirect` blocca le rotte senza sessione e le pagine senza permesso (come `puoAccedere`/`menu_utente`).
I bandi restano pubblici: la rotta `/bandi` non richiede login.

### 4. Service layer (replica di `SP`)

`SpService` espone **gli stessi nomi/metodi** di `js/sp-firestore.js` e lo stesso contratto di ritorno
(`{__errore}`, `{__errDuplicato}`, `{ok:true}`, `true/false`, `null`): `getAziendeUtente`, `creaAzienda`,
`aggiungiMembro`, `seedAzienda`, `getPianiConfig`, `getLicenzaAzienda`, `salvaLicenza`, `getWhatsappConfig`,
`salvaWhatsappConfig`, `inviaWhatsapp`, `setWhatsappAzienda`, `contaPreventivi`, `assicuraProfilo`,
`getProdotti/inserisciProdotto/aggiornaProdotto/eliminaProdotto`, `getCategorie/…`, `getClienti/…` +
`cercaDuplicatoCliente`, `getPreventivi/inserisciPreventivo/aggiornaPreventivo/aggiornaStato/creaRevisione/
eliminaPreventivo`, `getVisite/aggiungiVisita/aggiornaVisita/eliminaVisita/riordinaVisite/getVisiteCliente/
getVisitePeriodo`, `getBandi/upsertBandi`, `getFontiBandi/…/getSyncLog/scriviLogManuale`, `avviaSyncBandi`,
`cercaVIES/verificaPIVA`, `getUtenti/inserisciUtente/aggiornaUtente/eliminaUtente`, `getRuoli/…`,
`getImpostazioni/salvaImpostazione`.

- Collezioni piatte con `azienda_id`; ogni query replica `_scope()` filtrando l'azienda attiva.
- Modelli Dart con `fromMap`/`toMap` in `data/models`; i mapper convertono i documenti Firestore
  (id incluso) in modelli e viceversa, con date come stringhe ISO e prezzi numerici.
- `membri/{aziendaId}_{uid}` e `utenti/{uid}` restano la fonte di ruolo/permessi.
- Il contatore resta `contatori/preventivi_{aziendaId}` (vedi §6): **stessa chiave**, così la serie
  continua quella esistente.

### 5. Auth web vs mobile

- Web: `signInWithPopup` (Google), email/password, `sendPasswordResetEmail`.
- Mobile: `google_sign_in` nativo → `OAuthCredential` → `signInWithCredential`; email/password uguale.
- Ripristino sessione all'avvio con `onAuthStateChanged` (replica `ripristinaSessione`) + ricarica profilo
  `utenti` per email; profilo `attivo=false` → logout immediato.
- Super admin: flag `utenti/{uid}.super_admin`; il pannello super admin entra in una qualsiasi azienda.
- Reset password: su web il link con `oobCode` apre la schermata dedicata; su mobile si usano
  `ActionCodeSettings`/deep-link. Nessuna password salvata in Firestore.

### 6. PDF e numerazione transazionale

- `pdf` genera i byte del PDF nel client (stesso contenuto e stessi totali di jsPDF), `printing` per
  anteprima/stampa/condivisione. La grafica può essere coerente ma non necessariamente identica (vedi
  domanda aperta requisiti §2).
- Numerazione: `inserisciPreventivo` esegue `Firestore.runTransaction` su
  `contatori/preventivi_{aziendaId}` incrementando `valore` e scrivendo `PRV-000n` con `padStart(4,"0")`,
  identica a `_nextNumeroPreventivo`. Le revisioni (`creaRevisione`) NON consumano il contatore e usano
  `{base}-R{n}`. Vietato scrivere il contatore fuori dalla transazione.

### 7. Responsive e Material 3

- `useMaterial3: true`, `ThemeData` unico, testi in italiano.
- Breakpoint: <600 telefono (bottom navigation / drawer, colonna singola); 600–1024 tablet;
  >1024 desktop (`NavigationRail` o drawer permanente, griglie multi-colonna).
- Il gating usa `LayoutBuilder`/`MediaQuery`, non branch di piattaforma: una sola UI adattiva.

### 8. Testing e criteri di done

- Unit: modelli, mapper, utility, `SpService` con `mocktail` (mock di Firestore/Auth).
- Widget: rendering e stati delle schermate con provider mockati.
- Integration (`integration_test`): flussi chiave (login, cliente, preventivo+numerazione, revisione)
  su **Firebase Emulator Suite** (Auth + Firestore) per non toccare i dati di staging.
- Criteri di done: parità area per area verificata dal tester su web/Android/iOS; `firestore.rules`
  invariate; nessun numero duplicato; rapporto tester + APPROVATO validatore + validazione Andrea.

### 9. Deployment e convivenza

- Web: `flutter build web` → target Hosting `app` del progetto `commerciali-app`, pubblicata su
  `https://commerciali-app.web.app`. L’alias `commerciali-flutter.web.app` reindirizza alla principale e
  non è un secondo ambiente. Non usare in parallelo sulla stessa
  operazione critica (numerazione preventivi).
- Android/iOS: build di release (firma, bundle); web resta il riferimento per lo sviluppo rapido.
- Nessun deploy di `firestore.rules`, contatori o Worker in questa attività.

### 10. Fasi e rischi

Fasi: (1) fondamenta `flutter_app/` + Firebase + auth + routing + permessi + tema + test base;
(2) anagrafiche clienti/VIES e catalogo; (3) preventivi + contatore + revisioni + PDF; (4) visite e
bandi; (5) impostazioni/utenti/ruoli/licenze/super admin; (6) parità trasversale multi-piattaforma;
(7) tester → validatore → validazione Andrea → passaggio su staging.

Rischi: parità PDF (jsPDF vs `pdf`); differenze SDK Firebase web/mobile (sessione, Google);
duplicazione numeri se la transazione del contatore differisce; doppia manutenzione durante la
transizione; assenza di suite automatica (costo di test manuale su 3 piattaforme); dipendenza dal
Worker VIES; gestione immagini prodotto da confermare prima di replicarla.

## 2026-10-22 — Super admin: aziende, utenti, ruoli, import bandi, ATECO

Obiettivo: dare al super admin le funzioni oggi solo nella vecchia app Alpine
(`creaAziendaCompleta`, licenze, `creaAccountLogin`, import bandi). **Non serve toccare
`firestore.rules`**: le regole attuali già coprono tutti i flussi (vedi verifiche). Nessuna nuova
collezione, nessuna migrazione, nessuna funzione cloud.

### Verifiche sulle regole (esito)

1. **Profilo utente** — Confermato. Con `Firebase.initializeApp(name: 'crea-utente-…')` +
   `FirebaseFirestore.instanceFor(app)` l'utente appena creato è loggato sulla **seconda** app e può
   scrivere `utenti/{proprioUid}` perché `allow create: if userId == uid()`. Il profilo va scritto
   **prima** del `signOut()` (e prima di `app.delete()`); la membership è scritta invece dal super
   admin sulla app primaria (ordine indipendente dal profilo).
2. **Creazione azienda** — Confermata la sequenza corretta. `aziende` create passa con
   `created_by == uid()` (super admin). Ma `ruoli` create richiede `isAdminOf` (non `isSuper`) e
   `categorie` create richiede `memberOf` (non `isSuper`): il super admin **da solo** non può fare il
   seed. Sequenza: (a) crea azienda → (b) aggiungi membership `membri/{az}_{superUid}` ruolo `admin`
   (consentita da `canManage`/`isSuper`) → (c) `seedAzienda` (ruoli+categorie+licenza, ora è
   admin/membro) → (d) crea account admin nuovo → (e) profilo nuovo (app secondaria) → (f) membership
   admin nuovo.
3. **Licenza** — OK. `licenze` create: `isSuper()` oppure creatore con `piano == "trial"`. Il super
   admin può creare qualsiasi piano; l'onboarding self-service solo trial.
4. **Email invito** — Confermato. `sendPasswordResetEmail(email)` sulla app primaria manda il link di
   set password a un **altro** utente senza cambiare la sessione corrente. Funziona solo se l'account
   Auth esiste (creato prima). Da chiamare dopo `app.delete()` della secondaria.
5. **Import bandi** — Confermato. `bandi_incentivi`, `bandi_fonti`, `bandi_sync_log` hanno write solo
   `isSuper()`. La pagina di import va riservata al super admin (gate su `superAdmin == true`, come
   `SuperAdminScreen`); la sola consultazione resta pubblica.
6. **Ruoli personalizzati** — Confermato. `ruoli` create/update richiedono `isAdminOf`. Il super admin
   deve avere membership `admin` nell'azienda (vale sia per aziende nuove, step (b), sia per
   intervenire su aziende esistenti dove non è ancora membro).
7. **Rischi** — email già usata → `email-already-in-use`: non bloccare, prosegui con membership/profilo
   e avvisa (come la vecchia app). Sessione secondaria: `await app.delete()` **sempre** in `finally`,
   mai sulla app default. Password temporanea: generare ≥ 10 char e farla impostare via link. Ordine
   profilo: scrivere `utenti` mentre il nuovo utente è loggato, prima del logout. Permessi: entrare in
   un'azienda (`context.go('/')`) non crea membership; per modificare ruoli in aziende esistenti serve
   prima la membership admin del super admin. ATECO: il filtro agisce su `Bando.codiciAteco` +
   `tuttiAteco` (il modello esiste già); l'azienda oggi **non** ha un campo `ateco` → il codice si
   inserisce a mano nel filtro (eventuale campo `aziende.ateco` = punto aperto, non tocca le regole).

## 2026-10-23 — Calendario, appuntamenti, task, promemoria, integrazioni

Architettura dell'area agenda. Decisioni Andrea: si parte con tutto ma a micro-task; promemoria
cliente via WhatsApp subito (server Volty) ed email con SMTP dedicato per azienda; operatori = utenti
Closer con login; call Meet/Teams create subito; allegati, Maps, sync Google/M365, slot e prenotazione
pubblica richiesti. Obiettivo: semplicità per inesperti.

### 1. Modello dati (tutte con `azienda_id`)

- `appuntamenti/{id}`: tipo (visita|appuntamento), titolo, data `YYYY-MM-DD`, ora/fine `HH:MM`,
  durata_min, cliente_id + cliente_nome (denormalizzato), operatore_id (uid), luogo, note, stato
  (da_fare|fatto|annullato), visita_id (collegamento opzionale), call_provider
  (google_meet|teams|manuale), call_url, meeting_id, google_event_id, outlook_event_id, etag_esterno,
  created_by/at, updated_at. Non cancella visite/task collegati.
- `task/{id}`: titolo, scadenza (data+ora), operatore_id, priorita (normale|urgente), note,
  cliente_id, appuntamento_id, stato (aperto|completato), completato_da, completato_at, created_by/at.
- `promemoria/{id}`: riferito_a (appuntamento|task|visita), elemento_id, destinatario_tipo
  (operatore|cliente), canale (whatsapp|email|inapp), destinatario, quando_at (timestamp UTC
  assoluto), stato (programmato|in_elaborazione|inviato|fallito|annullato), inviato_at, tentativi,
  errore, idempotenza_key, created_at. Spostare l'elemento ricalcola `quando_at`; se già inviato ne
  nasce uno nuovo. I campi `promemoria_*` di `giro_visite` restano intatti.
- `allegati/{id}`: elemento_tipo (appuntamento|task), elemento_id, nome, tipo_mime, dimensione, url
  (Storage), thumb_url, created_by/at. Le immagini si vedono solo dentro l'azienda.
- `impostazioni_agenda/{aziendaId}` (1 doc per azienda): fuso_orario, anticipo_default_min,
  orario_invio_cliente, canale_cliente, template_* (non segreti), durata_slot, finestra_slot,
  scadenza_link_giorni, allegati_max_kb, allegati_num_max, maps_attivo.
- `integrazioni/{aziendaId}_{utenteId}`: utente_id, provider (google|ms), calendar_id, tenant_id,
  stato (collegato|revocato), collegato_at, scopes. **Nessun token/secret in Firestore**: stanno nel
  Worker (KV/secret), il client vede solo lo stato.
- `slot/{token}` (id = token casuale 128-bit): operatore_id, data, ora, durata_min, stato
  (aperto|prenotato|scaduto|annullato), scade_at, created_by/at.
- `prenotazioni/{id}`: slot_id, nome, email, telefono, stato (confermato|annullato), appuntamento_id,
  confermato_at.
- `cache_eventi_esterni/{id}`: utente_id, provider, evento_id, data_inizio, data_fine, titolo, luogo,
  ricorrente, etag, aggiornato_at. Sola lettura.

**Indici composti** (da creare in console): `appuntamenti(azienda_id, data, ora)`,
`(azienda_id, operatore_id, data)`, `(azienda_id, stato, data)`; `task(azienda_id, scadenza)`,
`(azienda_id, operatore_id, stato)`; `promemoria(azienda_id, quando_at, stato)`,
`(azienda_id, elemento_id)`; `cache_eventi_esterni(azienda_id, utente_id, data_inizio, data_fine)`;
`slot(azienda_id, operatore_id, data, ora)`; `prenotazioni(azienda_id, slot_id)`.

**Lettura/scrittura**: operatore legge/scrive appuntamenti/task/promemoria/allegati della propria
azienda; admin scrive `impostazioni_agenda`; super admin gestisce integrazioni; il cliente vede solo
lo slot via link (tramite Worker, non Firestore).

### 2. Security Rules — NUOVE, serve approvazione di Andrea

Servono regole per: `appuntamenti`, `task`, `promemoria`, `allegati`, `impostazioni_agenda`,
`integrazioni`, `slot`, `prenotazioni`, `cache_eventi_esterni` (oggi assenti). Schema base uguale a
`prodotti`: read `memberOf(resource.data.azienda_id) || isSuper()`, create
`memberOf(request.resource.data.azienda_id)`, update/delete `memberOf(...) || isSuper()`.
Eccezioni: `impostazioni_agenda` write solo `isAdminOf`/`canManage`; `integrazioni` read solo
`utente_id == uid()` e **write solo server/Worker** (nessun client scrive token); `slot` e
`prenotazioni` **non leggibili dal pubblico** (il pubblico passa dal Worker); più le **Storage
Security Rules** per `allegati/{aziendaId}/...`. Da chiedere ad Andrea prima di applicare.

### 3. Scheduler senza Blaze

Confronto: (a) **Cloudflare Worker + Cron Triggers** — gratuito sul piano free, stesso posto del VIES,
polling di Firestore via REST/service account; (b) server Volty con cron — dipende da un server di
terzi da verificare; (c) client-side — inaffidabile (device spento/niente rete = promemoria perso),
usabile solo come fallback in-app. **Raccomandazione: (a)**. Retry con backoff esponenziale e massimo
N tentativi poi `fallito`; idempotenza con `runTransaction` su `promemoria/{id}` (claim
`programmato→in_elaborazione→inviato`, `idempotenza_key` unico). Fuso: `quando_at` salvato in UTC
assoluto calcolato dal `fuso_orario` azienda; il cron legge un intervallo UTC. Niente Cloud
Functions/Blaze.

### 4bis. Promemoria automatico al cliente (WhatsApp + email)

Il client chiama `POST /promemoria-cliente` dopo il salvataggio dell'appuntamento. Il Worker:
1. verifica utente e appartenenza all'azienda;
2. legge `appuntamenti/{id}` (e, se privato, `privato/dettagli`) con il token dell'utente;
3. ricava recapiti da `cliente_telefono`/`cliente_email` o dalla scheda `clienti`;
4. compone il testo dal documento (mai da un testo libero del client);
5. invia su WhatsApp con il server configurato e su email con Resend;
6. scrive su `promemoria_cliente` solo stati e data, senza recapiti.

L'idempotenza usa una chiave KV `cliente-fatto:{progetto}:{appuntamento}:{hash(data,ora,fine,tutto_il_giorno)}`,
quindi lo stesso orario non parte due volte e una nuova data/ora genera un nuovo invio. C'è un limite di
20 invii al minuto per utente. L'email usa `EMAIL_CONFIG` (KV) con `{apiKey, from, nome}`; l'endpoint
`/email/config` e `/email/test` è riservato al super admin. Per gli appuntamenti privati il titolo non
compare nel messaggio.

### 4. Email SMTP per azienda

Campi in `impostazioni_agenda` (o `integrazioni`): smtp_host, smtp_port, smtp_user, mittente,
smtp_secure; la **password** va cifrata lato server o in Worker secret per `azienda_id`, mai in chiaro
e mai leggibile dal client. Chi la usa: solo il Worker (endpoint `POST /email/send`); il client
chiama il Worker, mai SMTP dal browser. Template in `impostazioni_agenda` con segnaposto
`{{data}} {{ora}} {{luogo}} {{azienda}} {{riferimento}} {{link_slot}}`. Retry nel loop promemoria,
rispetto dei limiti del provider. Nessuna credenziale nel codice.

### 5. WhatsApp Volty

Contratto esistente: `POST {url}/send`, header `x-api-key`, body `{to, message, mediaUrl}` →
`{ok, id}` o `{error}`; config in `whatsapp_config/1`. **Da spostare lato server**: oggi
`whatsapp_config` è leggibile da qualsiasi utente loggato (regola `read: if signedIn()`), quindi la
api_key è esposta → spostare l'invio in un endpoint Worker (`/whatsapp/send`) che legge la chiave da
Worker secret e stringere la regola. Messaggi dai template con segnaposto; errori HTTP/`error` mappati
a `fallito` con retry. Invio immediato riusa lo stesso endpoint.

### 6. Google Calendar / Meet

OAuth Authorization Code + PKCE (web e mobile). Scope minimi: `calendar.events` (create/update) e
`calendar.events.readonly` (sync); Meet si ottiene creando l'evento con `conferenceDataVersion: 1`
(richiede account Workspace con licenza — **non è gratis, da verificare**). Token: `refresh_token`
sul Worker (KV/secret), `access_token` breve solo in memoria; mai in Firestore. Creazione evento:
`POST /calendar/v3/calendars/primary/events` con `conferenceData`; sync lettura `events.list` per
intervallo; scrittura/aggiorna/cancella mappati su `google_event_id` + `etag`. Conflitti: se `etag`
esterno differisce, avvisa e non sovrascrive in silenzio.

### 7. Microsoft 365 / Teams

Azure app registration; permessi Graph minimi: `Calendars.ReadWrite`, `OnlineMeetings.ReadWrite`,
`User.Read`; tenant e licenza M365/Teams obbligatorie (**a pagamento**). OAuth delegated + tenant.
Online meeting: `POST /users/{id}/onlineMeetings` (o evento con `isOnlineMeeting: true`,
`onlineMeetingProvider: teamsForBusiness`). Sync Outlook via Calendar Graph; conflitti con
`@odata.etag`/`changeKey`, avviso e non sovrascrittura.

### 8. Allegati

**Scelta di Andrea: Cloudflare R2** (free tier) con upload firmato dal Worker. Firebase Storage e
Firestore base64 sono stati scartati (Blaze/costi/limiti). Metadati in `allegati` (`object_key`,
`thumb_key`, mime, dimensione); limiti dimensione/numero configurabili; URL firmati a scadenza;
immagini solo per i membri dell'azienda. Privacy/GDPR: foto = dati personali; cancellazione
dell'oggetto R2 quando l'allegato viene eliminato e scansione periodica degli orfani.

### 9. Prenotazione pubblica

Link `.../#/prenota/{token}` con token = id slot casuale non indovinabile. Pagina senza login (come
`/bandi`) che legge lo slot da un endpoint pubblico Worker (`GET /slot/{token}`), non da Firestore.
Conferma: `POST /prenota` → transazione sul doc slot: stato `aperto`→`prenotato`, crea `prenotazione`
+ `appuntamento`, invia conferma, avvisa l'operatore. Doppia prenotazione impedita dalla transazione
sul doc (claim atomico). Scadenza: `scade_at` verificato, scaduto → messaggio e stato `scaduto`.

### 10. UI/UX

Schermate: **Calendario** (giorno/settimana, filtri operatore/tipo/stato, "Oggi", tocco spazio vuoto
→ nuovo appuntamento precompilato, elementi senza ora in "Senza orario"), **Task** (elenco per
scadenza, filtri, ricerca), **Dettaglio appuntamento** (call, allegati, Maps, invio cliente, stato),
**Visite** (esistente, resta). Voce menu: aggiungere Calendario e Task alla shell. **Impostazioni →
Calendario e appuntamenti** (solo chi gestisce). Form semplici: pochi campi obbligatori (titolo+data),
pulsanti grandi, testi italiani, esito di ogni azione esterna sempre visibile.

### 11. Micro-task (1 file/servizio, in ordine)

Subito (nessuna credenziale): 1 modelli Dart (Appuntamento/Task/Promemoria/Allegato/Slot/Prenotazione/
ImpostazioneAgenda/EventoEsterno) · 2 SpService CRUD appuntamenti · 3 SpService CRUD task · 4 SpService
promemoria (crea/ricalcola/annulla) · 5 SpService impostazioni_agenda (validazione) · 6 schermata
Calendario · 7 form appuntamento · 8 schermata/form Task · 9 Maps icona auto (`url_launcher`) · 10
export ICS Flutter (replica js) · 11 menu shell Calendario+Task · 12 sezione Impostazioni agenda.
WhatsApp (Volty esistente): 13 endpoint Worker `/whatsapp/send` (secret) · 14 invio immediato cliente
via Worker · 15 template messaggio cliente. Scheduler: 16 Worker cron scan promemoria + idempotenza ·
17 retry/backoff + stato fallito. SMTP (credenziali): 18 Worker `/email/send` · 19 impostazioni SMTP
per azienda (secret/cifrato) · 20 template email + invio programmato. Google (credenziali): 21 OAuth
PKCE + token su Worker · 22 crea evento + Meet · 23 sync lettura + cache_eventi_esterni · 24 conflitti
etag. Microsoft (credenziali): 25 Azure app + OAuth Graph + token · 26 online meeting Teams · 27 sync
Outlook + conflitti. Storage: 28 upload/preview/delete + Storage Rules · 29 limiti dimensione/numero.
Prenotazione: 30 slot + token + `GET /slot/{token}` · 31 Worker `POST /prenota` (transazione,
doppia prenotazione, scadenza) · 32 pagina pubblica + conferma. Ogni task: input, file, criteri di
accettazione, test (unit/widget) e tester. Criteri di done: 0 `permission-denied`, esito esterno
visibile, nessun segreto esposto.

### 12. Prerequisiti da chiedere ad Andrea

Google: OAuth client web+mobile (client ID/secret), redirect URI (Hosting Flutter + reverse client
id mobile), account Workspace/licenza Meet. Microsoft: tenant ID, client ID/secret, permessi Graph,
licenza M365/Teams. SMTP: host/porta/user/password/mittente per azienda (o provider unico). WhatsApp
Volty: URL `/send`, api key, numero (e conferma per spostare la chiave in Worker secret). Storage:
conferma Firebase Storage Spark (5 GB) o R2. Dominio redirect OAuth e fuso orario aziendale default.

### 13. Rischi e cose da NON fare

NON mettere segreti (api_key WhatsApp, password SMTP, client secret, refresh token) in Firestore
leggibile dai client o nel codice. NON usare Cloud Functions/Blaze. NON fare sync bidirezionale
silenziosa (perdita dati) → conflitti con avviso. NON esporre slot/prenotazioni Firestore al pubblico
(usare Worker). NON assumere gratis Google/Azure/SMTP/WhatsApp (licenze e limiti da verificare). NON
cancellare dati: eliminare un appuntamento non cancella visita/task/riunione esterna. NON migrare
`giro_visite` (convivono). NON creare due appuntamenti per doppia prenotazione (transazione sul slot).
GDPR: consenso per email/WhatsApp, link non indovinabili, cancellazione foto. Fuso orario/ora legale
da gestire esplicitamente.
8. **VOLTY → Closer** — non è codice: è il `nome` del documento `aziende` di appoggio, rinominato dal
   super admin (`rinominaAzienda`, da replicare in `SpService`). Il brand "Closer" è già ovunque nel
   Flutter; resta solo il dato Firestore e il test `superadmin_screen_test.dart` che usa il literal
   `'VOLTY'`.

### Task piccoli (1 file principale ciascuno)

1. **`SpService`: seconda app Auth/Firestore** (`sp_service.dart`): metodo `creaUtenteConProfilo(email,
   nome, {aziendaId, ruolo})` che inizializza app secondaria, crea account, scrive `utenti/{uid}` sulla
   secondaria, signOut e `delete()` in `finally`. Criterio: nessuna app residua, profilo con email
   normalizzata. Test: unit con mock Firestore/Auth (niente rete).
2. **`SpService`: creaAziendaSuper** (`sp_service.dart`): orchestrazione sequenza (b)–(f) di §2, con
   gestione `email-already-in-use` e invio reset. Criterio: azienda + 2 membership + seed + profilo +
   email. Test: unit sul flusso con mock.
3. **`superadmin_screen.dart`: form nuova azienda + admin** (solo UI + callback). Criterio: campi
   obbligatori nome/email/password, stati caricamento/errore, chiavi di test. Test: widget.
4. **`superadmin_screen.dart`: form nuovo utente con ruolo** (solo UI + callback). Criterio: scelta
   ruolo da `ruoli` azienda, conferma. Test: widget.
5. **`SpService`: ruoli custom** (`sp_service.dart`): `inserisciRuolo`/`aggiornaRuolo` con
   `azienda_id`, replicando `SP`. Criterio: create/update passano `isAdminOf`. Test: unit.
6. **`ruoli_screen.dart`: abilita modifica/creazione** (sostituisce `_NotaSolaLettura`). Criterio:
   solo admin vede i comandi; `sistema` non eliminabile. Test: widget + unit (permessi).
7. **`bandi_screen.dart`: filtro ATECO** (pure function `filtraBandiAteco` + tendina/campo). Criterio:
   match su prefisso codice + `tutti_ateco`. Test: unit sulla funzione pura.
8. **`superadmin_screen.dart`: import bandi** (scegli file JSON o URL → parser → `upsertBandi`).
   Criterio: solo `superAdmin`; mapping campo snake_case già nel modello `Bando`. Test: unit sul parser.
9. **`app_shell.dart`: Bandi nel menu principale** (spostare `/bandi` dalle voci secondarie alle
   principali). Criterio: raggiungibile senza "Altro". Test: widget navigazione.
10. **Rinomina azienda** (`sp_service.dart` `rinominaAzienda` + azione in `superadmin_screen.dart`):
    conferma e `update({nome})` su `aziende/{id}` (permesso `canManage`/`isSuper`). Criterio: VOLTY →
    Closer. Test: unit + aggiornare `superadmin_screen_test.dart`.

### Test minimi

- **Unit**: pure function filtro ATECO, parser import JSON, payload/mapping `Bando`/ruolo,
  `creaUtenteConProfilo` e `creaAziendaSuper` con mock (verificano ordine chiamate e `delete()` in
  finally), `rinominaAzienda`.
- **Widget**: form nuova azienda/utente, ruoli modificabili, import bandi, voce menu Bandi.
- **E2E staging** (login super admin, azienda attiva): crea azienda → crea utente admin → ricezione
  email reset → login nuovo utente senza `permission-denied` → crea ruolo custom → importa 1 bando JSON
  → filtro ATECO restituisce il bando giusto → nessun documento `utenti` orfano.

## 2026-10-23 — Notifiche push e WhatsApp all'operatore

Estensione dell'agenda: avvisare l'operatore di appuntamenti, task, promemoria e comunicazioni.
Tre canali: in-app (sempre, senza permessi), push (web/Android/iOS), WhatsApp (server Volty).

### 1. Modello dati (tutte con `azienda_id`)

- `notifiche/{id}`: utente_uid, tipo (appuntamento|task|promemoria|comunicazione), titolo, testo,
  target_tipo, target_id, canale (inapp|push|whatsapp), stato (programmata|inviata|letta|fallita),
  programmata_at, inviata_at, letta_at, tentativi, errore, idempotenza_key.
- `dispositivi/{id}`: utente_uid, piattaforma (web|android|ios), token_fcm, user_agent, attivo,
  ultimo_uso_at.
- `impostazioni_notifiche/{aziendaId}_{uid}`: canali attivi, tipi attivi, silenzio_da/a, fuso_orario,
  numero_whatsapp, consenso_whatsapp, canale_default. (Non nel profilo: sono per azienda+utente.)
- `promemoria` = evento programmato (cosa/quando, già in agenda); `notifica` = consegna effettiva su un
  canale. Un promemoria genera una notifica per ogni canale attivo.

### 2. Indici e Security Rules

Indici composti: `notifiche(azienda_id, utente_uid, programmata_at)`, `(azienda_id, utente_uid, stato)`,
`(azienda_id, canale, stato, programmata_at)`; `dispositivi(azienda_id, utente_uid, attivo)`.

Regole: `notifiche` e `dispositivi` read/write solo `utente_uid == uid()` (self); `impostazioni_notifiche`
read self, write self o admin; creazione delle notifiche programmate **solo server/Worker** (nessun client
scrive `inviata_at`/`tentativi`). Da approvare da Andrea.

### 3. Flusso

Evento creato/assegnato → notifica in-app immediata (client) +, se attivi, push e WhatsApp (Worker).
Scheduler Worker (cron) legge i `promemoria` con `quando_at` nel prossimo intervallo UTC → crea la
notifica per ogni canale → consegna: in-app (write Firestore, realtime via listener), push (FCM),
WhatsApp (`POST /whatsapp/send`). Retry con backoff fino a N tentativi poi `fallita`; idempotenza con
`runTransaction` sul doc + `idempotenza_key` unico; `stato` progredisce programmata→inviata→letta.
Deep link: `target_tipo`+`target_id` → rotta; elemento mancante → messaggio comprensibile, nessun errore.

### 4. FCM

- Web/PWA: VAPID (coppia chiavi), `firebase-messaging-sw.js`, permesso browser, HTTPS; su iOS Safari il
  push web arriva solo se la PWA è aggiunta a Home, non garantito ad app chiusa.
- Android: `google-services.json`, un token FCM per installazione.
- iOS: APNs + Apple Developer (account a pagamento da verificare), chiave `.p8`, limiti di consegna.
- Token per dispositivo salvato in `dispositivi`; logout → `attivo=false`; token scaduto/rimosso → il
  Worker intercetta l'errore `NotRegistered` e disattiva il dispositivo.

### 5. WhatsApp operatore

Numero + consenso esplicito in `impostazioni_notifiche`; formato internazionale validato. Invio solo dal
Worker (`/whatsapp/send`) che legge la chiave da secret (come agenda §5), mai dal client. Template con
segnaposto (titolo, data/ora) da `impostazioni_agenda`; testo breve e generico, niente dati sensibili.
Errori HTTP/`error` → `fallita` + retry; opt-out con interruttore.

### 6. UI

Centro notifiche (elenco con data/ora, tipo, titolo, stato letto), badge non lette sulla shell, "segna
letta"/"segna tutte lette", tocco = deep link. Sezione Impostazioni → Notifiche: canali, tipi, orari
silenzio, fuso, numero WhatsApp + consenso, canale default.

### 7. Micro-task (1 file/servizio, in ordine)

Subito: 1 modello Dart Notifica/Dispositivo/PreferenzeNotifiche · 2 SpService notifiche (crea/leggi/segna
letta) · 3 centro notifiche + badge (schermata) · 4 preferenze Impostazioni · 5 notifica in-app su
assegnazione · 6 deep link da notifica. Configurazione (dopo credenziali): 7 endpoint Worker
`/whatsapp/send` operatore · 8 Worker cron promemoria→notifiche + retry/idempotenza · 9 FCM web/PWA
(VAPID + SW + permesso) · 10 FCM Android · 11 FCM iOS · 12 token dispositivo + pulizia scaduti. Ogni
task: input, file, criteri, test (unit/widget + tester); done: 0 `permission-denied`, esito visibile,
nessun segreto esposto.

### 8. Prerequisiti da chiedere ad Andrea

Piattaforme push prioritarie (web/PWA, Android, iOS?); account Apple Developer (se iOS); chiavi VAPID/FCM
(web) e `google-services.json` (Android); numero WhatsApp (uno per operatore o aziendale?) e chi lo
inserisce; consenso WhatsApp (in app o admin?); orari di silenzio e fuso; testo push/WhatsApp standard o
personalizzabile; chi può inviare le comunicazioni manuali.

### 9. Rischi

Duplicati (idempotenza obbligatoria); permessi push negati (resta l'in-app); token scaduti/dispositivi
muti; dati sensibili in push/WhatsApp (solo testo generico); costo account Apple e limiti FCM/APNs; fuso
orario/ora legale; server Volty non raggiungibile; più dispositivi = più token da gestire.
NON mettere segreti (VAPID privata, api_key Volty, chiave APNs) in Firestore o nel codice.

## 2026-10-23 — Chat interna

Chat dirette 1-a-1 e gruppi, solo utenti attivi della stessa azienda, nessun esterno. Testo + immagini
su R2. Notifiche in-app + push; mai WhatsApp per la chat. Conferme di lettura, non letti, ricerca
semplice, soft delete dei propri messaggi. Esclusi: presenza online, vocali, thread, chiamate.

### 1. Modello dati
- `chat_stanze/{id}`: tipo (diretta|gruppo), azienda_id, nome (solo gruppo), partecipanti_uids[],
  creatore_uid, ultimo_messaggio, ultimo_messaggio_at, created_at, updated_at.
- Messaggi in sottocollezione `chat_stanze/{id}/messaggi` (non top-level): query per stanza naturali,
  ordinate per `created_at` con indice single-field; le regole verificano la membership con `get` sulla
  stanza; cancellare la stanza cancella i messaggi. Top-level richiederebbe indice composto
  (stanza_id, created_at) e un campo in più, senza vantaggi. Campi: mittente_uid, testo, tipo
  (testo|immagine), image_url, created_at, eliminato (soft delete), idempotenza_key.
- Letture: doc separato `chat_stanze/{id}/letture/{uid}` con `ultima_lettura_at` (non un campo sulla
  stanza: evita contese di scrittura e serve alle conferme). "Letto da P" = `created_at <= P.ultima_lettura_at`.
- Chat dirette senza duplicati: id deterministico `diretta_{aziendaId}_{uidMin}_{uidMax}` (uid ordinati
  lessicograficamente) → chiunque inizi riusa la stessa stanza.

### 2. Indici e Security Rules
- Indici: `chat_stanze(azienda_id, partecipanti_uids, updated_at)` per la lista conversazioni; i messaggi
  si ordinano per `created_at` (single-field, automatico). Da creare in console.
- Regole: `chat_stanze` read se `memberOf(azienda_id)` e `uid() in partecipanti_uids`; create stesso +
  mittente tra i partecipanti e stessa azienda; update solo partecipanti (nome/partecipanti/ultimo
  messaggio); delete admin/creatore. `messaggi` read se membro della stanza; create solo
  `mittente_uid == uid()` e partecipante; update solo `eliminato=true` e solo mittente; delete vietato.
  `letture/{uid}` write solo il proprio doc. Da approvare da Andrea.

### 3. Realtime e notifiche
- Realtime: listener su `messaggi` della stanza aperta (nuovi messaggi) e su `chat_stanze` per lista/badge.
- In-app: il badge non letti È la notifica in-app (nessun doc `notifiche` separato): il client confronta
  `ultimo_messaggio_at` con `letture/{uid}.ultima_lettura_at`. Niente scritture cross-utente né duplicati.
- Push: Worker Cloudflare con cron che polla i messaggi nuovi (`created_at` > cursore in `chat_sync_log`)
  e invia FCM ai destinatari (token in `dispositivi`). Dedup con `idempotenza_key` + cursore. Semplice e
  senza Blaze (niente trigger Firestore). Anteprima generica "Nuovo messaggio"; il client sopprime la push
  se la chat è aperta; silenzio notturno e fuso da `impostazioni_notifiche`. WhatsApp mai usato.

### 4. Immagini R2
Upload: il client chiede al Worker un URL firmato (`PUT` presigned) e carica direttamente su R2; il
Worker registra `image_url` (proxy `GET /chat/img/{key}`). Limiti da `impostazioni_chat` (max ~5 MB,
1 immagine per messaggio, jpg/png/webp). Soft delete → rimozione dell'oggetto R2; scan periodica per gli
orfani. Nessuna credenziale R2 nel client.

### 5. UI/UX
Lista conversazioni (nome, ultimo messaggio, ora, badge non letti) · chat aperta (bolle, stato "in
invio", spunta/ora di lettura) · composer testo + icona immagine · anteprima fullscreen · ricerca
conversazioni per nome e messaggi per testo · creazione gruppo (nome + partecipanti) · preferenze
notifiche (anteprima sì/no, silenzio). Voce "Chat" nella shell.

### 6. Casi limite
Utente rimosso: esce, messaggi restano, gruppo continua; gruppo senza attivi: sola lettura, niente
invio; offline/doppio invio: `idempotenza_key` → un solo messaggio, stato "in invio"; messaggio
eliminato: sparisce e l'immagine R2 è rimossa, conteggi coerenti; notifiche duplicate: cursore +
idempotenza; ricerca senza full-text: solo client-side sui messaggi caricati.

### 7. Micro-task (1 file/servizio, in ordine)
1 modelli Dart (Stanza/Messaggio/Lettura/Preferenze) → 2 SpService chat (stanza diretta con id
deterministico, gruppi, inviaMessaggio con idempotenza, softDelete, getStanze/getMessaggi, segnaLetto)
→ 3 lista conversazioni + badge → 4 chat aperta (thread, composer, stato invio, conferme lettura) →
5 ricerca client-side → 6 gruppi (crea/aggiungi/rimuovi) → 7 Worker R2 upload firmato + limiti +
pulizia → 8 Worker push FCM (cron messaggi, dedup, anteprima, silenzio). Dipendenze: 1→2→3→4→5, 6 dopo
2, 7 e 8 dopo 2. Test: unit modelli/service con mock; widget schermate; E2E staging (due utenti stessa
azienda: messaggio, badge, lettura, immagine, soft delete, 0 permission-denied).

### 8. Prerequisiti
Bucket R2 + Worker (endpoint firmati, stesso Worker VIES); FCM/VAPID (web) e google-services (Android)
già previsti in sezione notifiche; nuove Security Rules + indici da approvare Andrea; nessun costo
WhatsApp (la chat non lo usa). R2 free tier da verificare (10 GB, egress gratuito).

### 9. Rischi / NON fare
NON usare Cloud Functions/Blaze (niente trigger Firestore) · NON esporre segreti R2/FCM nel client ·
NON hard-delete messaggi (solo soft) · NON WhatsApp per la chat · NON presenza/thread/vocali/chiamate ·
NON ricerca full-text server (costo) · NON consentire esterni. Rischi: duplicati notifiche, limiti/costi
R2, privacy immagini (dati personali), utenti senza permesso.

## 2026-10-24 — OAuth aziendale e calendario condiviso

Completa l'area calendario (sezione 2026-10-23) con il collegamento OAuth ai calendari esterni
(Google Calendar/Meet, Microsoft 365/Teams) e la condivisione del calendario **dentro** Closer.
Vale il principio già fissato: i token/secret non stanno mai in Firestore né nel client, ma solo nel
Worker (Cloudflare KV/secret).

### 1. Modello a tre livelli

- **App OAuth** (livello piattaforma) — l'identità Closer registrata presso il provider (client ID/
  client secret, redirect URI). Una sola per provider in modalità default.
- **Connessione utente** (livello persona) — il singolo operatore autorizza l'app ad accedere al
  *proprio* calendario; il Worker conserva un set di token per `azienda/uid/provider` in KV/secret.
  In Firestore resta solo lo stato (`integrazioni/{aziendaId}_{uid}`: `stato`, `scopes`, `calendar_id`,
  `tenant_id`).
- **Calendario/evento** (livello operativo) — gli eventi creati/sincronizzati appartengono all'account
  dell'operatore; Closer mantiene i riferimenti (`google_event_id`/`outlook_event_id`, `etag`, URL call)
  su `appuntamenti`.

### 2. Default e opzione per azienda

Default: **una app OAuth Closer verificata** per provider, usata da tutte le aziende (nessuna
configurazione da parte dell'azienda, solo il consenso dell'utente). Opzione avanzata: un'azienda può
usare la **propria app** (`modalita: closer|personalizzata`) dichiarata in `integrazioni_azienda/{az}`
con `client_id`, `secretRef` (riferimento al secret, mai il valore) e `redirect_uri`. In modalità
`personalizzata` il Worker risolve i riferimenti dell'azienda invece di quelli di piattaforma.

### 3. Provider: Google e Microsoft

- **Google** — app OAuth **External + verifica** per il multi-azienda (consenso utente, schermata di
  verifica OAuth, scope sensibili dichiarati); app **Internal** accettabile solo per una singola azienda
  su Google Workspace. Meet richiede la licenza Workspace (a pagamento, da verificare).
- **Microsoft** — registrazione app **multi-tenant** con consenso amministratore; per una singola
  azienda si può vincolare l'app al proprio tenant. Graph con permessi delegati; Teams/online meeting
  richiedono licenza M365 (a pagamento).

### 4. Flusso OAuth

1. **start** — il client chiede al Worker l'URL di autorizzazione; il Worker genera `state` firmato
   (+ `nonce`/PKCE `code_challenge`) e lo lega a `azienda/uid/provider`.
2. **redirect** — il provider reindirizza al **callback Worker** con `code` e `state`.
3. **callback** — verifica firma e scadenza di `state`, scambia `code` (con `code_verifier` PKCE) con
   `access_token` + `refresh_token`.
4. **storage** — token salvati in KV/secret con chiave `azienda/uid/provider`; il client riceve solo lo
   stato "collegato".
5. **refresh** — il Worker rinnova con `refresh_token` prima della scadenza; su errore di grant marca la
   connessione da riconnettere.
6. **revoca** — endpoint esplicito: revoca presso il provider e cancella i token dal KV.
Il client **non vede mai** token o secret: tutte le chiamate passano dal Worker.

### 5. Perimetro token (scope minimi)

- Google: `calendar.events` (creazione/modifica) + `calendar.events.readonly` (sync) — oppure
  `calendar.readonly` se serve solo lettura; Meet ottenuto con `conferenceDataVersion=1` sull'evento.
- Microsoft Graph: `User.Read`, `Calendars.ReadWrite`, `OnlineMeetings.ReadWrite`, `offline_access`
  (refresh). Niente scope di posta/file: solo calendario e meeting.
- **PKCE** obbligatorio dove il provider lo supporta; redirect URI rigoroso (allowlist esatta nel
  Worker, niente wildcard).

### 6. Creazione evento e call

L'evento nasce sul **calendario dell'operatore** (non su un calendario aziendale unico); il cliente è
aggiunto come invitato. Meet: `conferenceDataVersion=1` restituisce `hangoutLink`/`conferenceId`;
Teams: `isOnlineMeeting: true` con `onlineMeetingProvider: teamsForBusiness` oppure
`POST /users/{id}/onlineMeetings`. Su `appuntamenti` si salvano `call_url`, `meeting_id`,
`google_event_id`/`outlook_event_id`, `etag`; aggiornamenti e cancellazioni passano dagli id esterni con
controllo `etag` (conflitto → avviso, nessuna sovrascrittura silenziosa).

### 7. Condivisione calendario dentro Closer

Nuova collezione `condivisioni_calendario/{id}`: `azienda_id`, `proprietario_uid`, `destinatario_uid`,
`livello`, `created_by/at`, `revocato_at`, `audit`. Livelli: `libero_occupato` | `dettagli` | `modifica`.
Default `dettagli` (sola lettura). Vincoli: solo stessa azienda; il proprietario crea/revoca; il
destinatario **non** ri-condivide; ogni azione tracciata (audit). La condivisione riguarda gli eventi
esterni dell'account del proprietario, non i documenti Firestore.

### 8. Privacy e visibilità

- `libero_occupato`: mostra solo blocchi occupato/libero, maschera titolo/cliente/note/luogo.
- `dettagli`: mostra data/ora/titolo/cliente/luogo; le note private sono escluse.
- `modifica`: come `dettagli` + possibilità di intervento, con audit.
- Distinzione obbligatoria: gli **eventi esterni** (Worker, token del proprietario) seguono i livelli di
  condivisione sopra; gli **appuntamenti Closer** oggi sono visibili a tutta l'azienda per le regole
  attuali (`appuntamenti` read `memberOf`). ⚠️ Per limitare la visibilità dei secondi (es. visibilità
  per operatore) serve una **regola più restrittiva** da definire in un task separato, non in questa
  attività.

### 9. Worker: endpoint

`/oauth/start`, `/oauth/callback`, `/calendario/condiviso`, `/calendario/evento`, `/calendario/revoca`,
`/integrazioni/test`. Tutti autenticati con **Firebase ID token** (Authorization Bearer) e autorizzati
per membership (`azienda_id` + `uid`). Rate limit per endpoint; logging senza segreti (mai token,
`code`, `client_secret`, `state` integrale nei log).

### 10. Settings (chi configura cosa)

- **Admin azienda**: SMTP, Google/Microsoft (modalità, `client_id`, `secretRef`, redirect URI, "test
  connessione"), WhatsApp/R2 **se** configurati per azienda (altrimenti piattaforma).
- **Utente**: connessioni OAuth personali e condivisioni del proprio calendario.
- **Super admin**: configurazioni di piattaforma (FCM/VAPID/APNs, app OAuth Closer default, secret di
  piattaforma).

### 11. Sicurezza

Secret (client secret, refresh token, password SMTP, api key) solo in **Cloudflare KV/secret**, con
cifratura at-rest, rotazione, revoca e audit; **nessun** secret in Firestore, log o browser. `state`
OAuth firmato + `nonce`; allowlist dei redirect URI; scope minimi (nessun scope in più del necessario).
Il client interagisce solo tramite Worker e non possiede mai credenziali.

### 12. Fasi (micro-task, ordinate)

F1 modello/regole/service (collezioni `condivisioni_calendario`, `integrazioni_azienda`, campi su
`integrazioni` e `appuntamenti`) → F2 UI Impostazioni (admin) e Connessioni/Condivisione (utente) →
F3 Worker Google (OAuth + eventi + sync) → F4 Worker Microsoft (Azure app + Graph + Teams) → F5
condivisione calendario e livelli di visibilità → F6 creazione call e inviti (cliente invitato) →
F7 test/E2E staging (connessione reale, evento, call, condivisione, 0 `permission-denied`, nessun
secret esposto).

### 13. Rischi

Verifica Google (tempi e requisiti della schermata di consenso); scadenza dei secret Azure
(`client_secret` con data di scadenza, da ruotare); tenant Microsoft restrittivi (consenso admin
negato); licenze Meet/Teams a pagamento; quote/limiti API dei provider; token revocati/utente che
scollega (gestire `refresh` fallito e stato da riconnettere); privacy della condivisione (fuoriuscita
di dati tra operatori); costo di supporto per configurazioni `personalizzate`.

### 14. NON fare

NON fare uno store/app per singolo utente (un'app per provider, default Closer). NON salvare token in
Firestore né nel browser. NON sync bidirezionale silenziosa (conflitti con avviso, mai sovrascrittura
cieca). NON obbligare Google Workspace: la modalità default deve funzionare anche con account Google
consumer, salvo le funzioni Meet che richiedono licenza. NON estendere gli scope oltre il minimo.
