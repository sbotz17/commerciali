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

- Web: `flutter build web` → nuova target Hosting separata (es. `flutter-commerciali-app.web.app`) nello
  stesso progetto `commerciali-app`; la vecchia app resta sulla target attuale finché non c'è parità
  validata, poi il passaggio sostituisce la target principale. Non usare in parallelo sulla stessa
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
