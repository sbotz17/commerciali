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
