# Diario di lavoro

## 2026-10-21/22 — Migrazione a Firebase

- Creato progetto `commerciali-app`: Firestore `europe-west8`, Auth email/password + Google, Hosting.
- Nuovo data layer `js/sp-firestore.js` con la stessa interfaccia `SP` (70 funzioni).
- Nuovo `js/auth.js` con Firebase Auth e profilo `utenti/{uid}`.
- Regole Firestore multi-azienda in `firestore.rules`.
- Verifica P.IVA spostata su VIES tramite Cloudflare Worker (`worker/`).
- Test in locale: registrazione, onboarding, clienti, prodotti, utenti, impostazioni.
- Dati di test eliminati; database vuoto per la registrazione autonoma.
- Creato account super admin `bottiandrea83@gmail.com` e azienda di appoggio VOLTY.

## 2026-10-22 — Squadra e ambienti

- Introdotta la regola della squadra in `AGENTS.md` e i 14 agenti OpenCode.
- Creato il ramo `staging`, unico ambiente operativo con Firebase `commerciali-app`.
- La produzione sarà un progetto Firebase separato, da creare più avanti.

## 2026-10-22 — Task F01: scaffold Flutter

- `flutter create --org it.commerciali --project-name commerciali_app --platforms web,android,ios flutter_app` → OK (82 file).
- `flutter pub add firebase_core firebase_auth cloud_firestore google_sign_in flutter_riverpod go_router intl pdf printing url_launcher` → OK (56 dipendenze).
- `flutter analyze` dentro `flutter_app/` → esito: `No issues found! (ran in 2.5s)`.

## 2026-10-22 — Task F02b: avvio app Flutter con Firebase

- `lib/main.dart`: `main()` async con `WidgetsFlutterBinding.ensureInitialized()` + `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` + `runApp(const CommercialiApp())`.
- `CommercialiApp`: `MaterialApp` titolo "Commerciali", tema Material 3 (`ColorScheme.fromSeed` blu `#1D4ED8`), `home` la nuova `SplashScreen`.
- `lib/splash_screen.dart` (nuovo): widget stateless con nome "Commerciali" e testo "Caricamento…"; nessuna logica di auth/dati.
- `test/widget_test.dart`: widget test che monta `MaterialApp(home: SplashScreen())` e verifica "Commerciali" e "Caricamento…"; nessuna chiamata a Firebase nei test.
- `flutter analyze` → `No issues found! (ran in 2.4s)`; `flutter test` → `All tests passed!`.

## 2026-10-22 — Task F03: tema, router e shell Flutter

- `lib/core/theme/app_theme.dart`: Material 3 con `ColorScheme.fromSeed` blu `#1D4ED8`, colori semantici
  (ambra attesa, verde accettato, rosso errore, viola super admin), spazi 4/8, raggi card 16 e campi/pulsanti 12,
  breakpoint 600/1024, temi per AppBar, card, campi, pulsanti, chip, `NavigationBar`/`NavigationRail`.
- `lib/routing/app_router.dart`: `go_router` con `/login`, `/reset-password`, `/onboarding` fuori shell e
  `/`, `/clienti`, `/catalogo`, `/preventivi`, `/preventivi/nuovo`, `/visite`, `/bandi`, `/impostazioni`,
  `/superadmin` dentro la shell; schermate segnaposto con titolo pagina.
- `lib/features/shell/app_shell.dart`: sotto 600 px `NavigationBar`, da 600 px `NavigationRail`; voci
  Dashboard, Clienti, Preventivi, Visite, Altro; "Altro" apre il `Drawer` con Catalogo, Bandi, Impostazioni.
  Nessuna logica di auth, permessi o Firestore.
- `lib/core/ui/placeholder_screen.dart`: corpo segnaposto condiviso, senza duplicare le schermate.
- `lib/app.dart`: `MaterialApp.router` con tema e router, riutilizzabile nei test; `lib/main.dart` mantiene
  `Firebase.initializeApp` e monta `CommercialiApp`.
- `test/widget_test.dart`: monta l'app senza Firebase, verifica "Dashboard", `NavigationBar` sotto 600 px,
  `NavigationRail` da 600 px e drawer "Altro" con le voci secondarie.
- `flutter analyze` → `No issues found! (ran in 4.2s)`; `flutter test` → `All tests passed!` (4 test).

## 2026-10-22 — Task F04a-fix: chiusura F04a

- `lib/state/auth_providers.dart`: sostituito `valueOrNull` con `asData?.value` (Riverpod 3 non espone `valueOrNull`).
- `lib/data/services/auth_service.dart`: parametri inizializzanti `this._auth`/`this._firestore` (lint `prefer_initializing_formals`);
  i nomi pubblici restano `auth`/`firestore` (Dart rimuove l'underscore), quindi il chiamante non cambia.
- `flutter analyze` → `No issues found! (ran in 3.9s)`; `flutter test` → `All tests passed!` (11 test).

## 2026-10-22 — Task F04b: servizio dati base Flutter

- `lib/data/models/azienda.dart` (nuovo): campi `id`, `nome`, `logo`, `ruolo`, `whatsappAttivo`; `fromMap` con
  default `nome="Azienda"`, `ruolo="commerciale"`, `whatsappAttivo=false`; il campo Firestore `whatsapp_attivo`
  è esposto in camelCase, coerente con `UserProfile`.
- `lib/data/services/sp_service.dart` (nuovo): `SpService(FirebaseFirestore)` con `setAziendaAttiva`/`getAziendaAttiva`,
  `getAziendeUtente` (query `membri` per `utente_id` + lettura `aziende/{id}`), `assicuraProfilo` (cerca `utenti`
  per email, altrimenti crea `utenti/{uid}` con uid da `FirebaseAuth.instance.currentUser`), `creaAzienda`
  (`created_by`, `created_at`, anagrafica base), `aggiungiMembro` (`membri/{aziendaId}_{utenteId}` con merge) e
  `seedAzienda` (batch con 2 ruoli, 3 categorie e licenza trial: stessi dati di `SP.seedAzienda`).
- `lib/state/azienda_providers.dart` (nuovo): `spServiceProvider`, `aziendaAttivaProvider` (`StateProvider<String?>`,
  da `flutter_riverpod/legacy.dart`), `aziendeUtenteProvider` (`FutureProvider<List<Azienda>>` che osserva `profileProvider`).
- `test/azienda_test.dart` (nuovo): 6 test di `Azienda.fromMap`.
- `flutter analyze` → `No issues found! (ran in 3.6s)`; `flutter test` → `All tests passed!` (17 test).

## 2026-10-22 — Task F05: schermata login Flutter

- Creata `LoginScreen` (email/password, validazione, loading, errori in italiano, link reset).
- `AuthService` usato solo al submit; nessun provider Firebase nel build.
- Test: 13 test sui validator + 5 widget test; `flutter analyze` e `flutter test` verdi (35 test).
- Aggiornati router, task board, catalogo e memoria Flutter.

## 2026-10-22 — Task F06a: test login Google (chiusura)

- `test/google_auth_test.dart` (nuovo): 9 unit test di `messaggioErroreGoogle` (7 codici noti + fallback
  per codice sconosciuto + errore generico non `FirebaseAuthException`) e 1 widget test che monta il login
  in `ProviderScope` e verifica il pulsante `pulsante-google` e il testo "Accedi con Google".
- `flutter analyze` → `No issues found!`; `flutter test` → `All tests passed!` (45 test).
- Nessuna modifica a `lib/`; aggiornati task board, catalogo e diario.

## 2026-10-22 — Task F06b: login Google mobile (chiusura)

- `lib/features/auth/login_screen.dart`: sostituito `servizio.signInWithGoogleWeb()` con
  `servizio.signInWithGoogle()`, così il flusso usa il popup sul web e il flusso nativo `google_sign_in` su mobile.
- `test/google_auth_test.dart`: aggiunti 7 unit test di `messaggioErroreGoogle` per `GoogleSignInException`
  con codici `canceled`, `interrupted`, `clientConfigurationError`, `providerConfigurationError`,
  `uiUnavailable`, `userMismatch`, `unknownError`.
- `flutter analyze` → `No issues found!`; `flutter test` → `All tests passed!` (52 test).

## 2026-10-22 — Milestone F01–F05 APPROVATO

- Tester: `SUPERATO con riserva` (login reale e Google spostati a F06; prova su mobile reale ancora da fare).
- Validatore: `APPROVATO` dopo allineamento dei criteri F04a/F05.
- Verifiche: `flutter analyze` 0, 35 test verdi, `flutter build web` OK, `firestore.rules` invariato, vecchia app intatta.
- Prossimo: F06 (Google + login reale su staging) e F07 (recupero password + onboarding).

## 2026-10-22 — F06a/F06b/F06c: login Google e prova reale

- F06a: login Google web con popup, pulsante dedicato e traduzione errori; 9 test.
- F06b: login Google mobile con `google_sign_in` 7 e `serverClientId`; analisi statica verde (flusso mobile reale da provare su dispositivo).
- F06c: prova reale su staging con utente temporaneo: login email riuscito e arrivo alla Dashboard; utente e profilo eliminati dopo il test.
- `flutter analyze` 0, `flutter test` 52 verdi.
- `node scripts/controlla-indice.mjs` → INDICE OK (19 nodi, 9 file chiave).

## 2026-10-22 — F07a: recupero password Flutter

- `ResetPasswordScreen`: invio link via email e, con `oobCode`, verifica codice + nuova password.
- `AuthService`: `verifyResetCode` e `confirmPasswordReset`.
- Router: `/reset-password` passa `oobCode` alla schermata.
- `flutter analyze` 0, `flutter test` 71 verdi.

## 2026-10-22 — F07b: test onboarding azienda

- `test/onboarding_screen_test.dart` (nuovo): 3 widget test che montano
  `CommercialiApp(initialLocation: '/onboarding')` in `ProviderScope` (campi "Il tuo nome" e "Nome azienda",
  pulsante "Crea azienda e inizia", errori "Inserisci il tuo nome" / "Inserisci il nome dell'azienda" a campi
  vuoti, errori di lunghezza minima) + 18 unit test puri di `validaNomeUtente`, `validaNomeAzienda` e
  `messaggioErroreOnboarding` (codici `permission-denied`, `unavailable`, `network-request-failed`,
  `unauthenticated`, codice sconosciuto e errore non Firebase).
- Nessuna modifica a `lib/`; nessun `dart format` su file altrui.
- `flutter analyze` → `No issues found!`; `flutter test` → `All tests passed!` (92 test).
- Aggiornati task board (F07b `FATTO`), catalogo (`OnboardingScreen`, `AvvisoErrore`, test onboarding).

## 2026-10-22 — Task F09a: modello Cliente e CRUD (backend)

- `lib/data/models/cliente.dart` (nuovo): modello `Cliente` con `id`, `aziendaId`, `tipoCliente`, `nome`,
  `referente`, `email`, `telefono`, `piva`, `codiceFiscale`, `indirizzo`, `civico`, `cap`, `citta`, `provincia`,
  `ateco`, `settore`, `regione`, `note`; `fromMap`/`toMap` con campi Firestore in snake_case (coerente con
  `Azienda`/`UserProfile`). Nello stesso file le funzioni pure `normalizzaPiva` (maiuscola, senza `IT`, trim)
  e `clienteDuplicato` (cascata P.IVA → nome esatto → codice fiscale, come la vecchia app) e la classe
  `DuplicatoClienteException implements Exception`.
- `lib/data/services/sp_service.dart`: aggiunti `getClienti` (query `clienti` per `azienda_id` attiva + `orderBy nome`),
  `cercaDuplicatoCliente` (piva/nome/codiceFiscale/escludiId), `inserisciCliente` (normalizza P.IVA, controlla
  duplicato e lancia `DuplicatoClienteException`, aggiunge `azienda_id`/`created_at`), `aggiornaCliente`
  (duplicato escludendo l'id, `updated_at`, non tocca `azienda_id`), `eliminaCliente`. Helper `_clientePayload`
  (stessi campi e default della vecchia app) e `_stringa` (trim con fallback).
- `test/cliente_test.dart` (nuovo): `fromMap` (campi + default), `toMap`, `normalizzaPiva`, `clienteDuplicato`
  (P.IVA, nome, codice fiscale, nessun duplicato, P.IVA assente).
- `flutter analyze` → `No issues found!`; `flutter test` → `All tests passed!` (104 test).
- Nessuna UI (F09b), nessuna VIES (F09c), nessuna modifica a vecchia app/Firebase/regole, nessun commit/push.

## 2026-10-22 — Task F11a: modelli Prodotto/Categoria e CRUD catalogo (backend)

- `lib/data/models/prodotto.dart` (nuovo): modello `Prodotto` con `id`, `aziendaId`, `nome`, `categoria`,
  `prezzo` (`num?`), `descrizione`, `immagine` (URL o null), `attivo` (default `true`); `fromMap`/`toMap`
  con campi Firestore in snake_case (coerente con `Azienda`/`Cliente`/`UserProfile`).
- `lib/data/models/categoria.dart` (nuovo): modello `Categoria` con `id`, `aziendaId`, `nome`, `icona`,
  `ordine` (`int?`, `num` convertito a `int`); `fromMap`/`toMap`.
- `lib/data/services/sp_service.dart`: aggiunti `getProdotti` (query `prodotti` per `azienda_id` attiva +
  `orderBy nome`), `inserisciProdotto`, `aggiornaProdotto`, `eliminaProdotto`; `getCategorie` (query
  `categorie` per `azienda_id` attiva + `orderBy ordine`), `inserisciCategoria`, `aggiornaCategoria`,
  `eliminaCategoria`. Payload helper `_prodottoPayload` (prezzo numerico, immagine URL o assente, `attivo`
  default true) e `_categoriaPayload` (`ordine` intero default 0); helper `_stringaNull`, `_numero`, `_intero`.
  `created_at` in inserimento, `updated_at` in aggiornamento; `azienda_id` mai modificato in aggiornamento.
- `test/catalogo_test.dart` (nuovo): 8 test di `fromMap`/`toMap`/default dei due modelli.
- `flutter analyze` → `No issues found!`; `flutter test` → `All tests passed!` (112 test).
- Nessuna UI (F11b), nessuna modifica a vecchia app/Firebase/regole, nessun commit/push.

## 2026-10-22 — F09b/F11a: clienti e catalogo dati

- `ClientiScreen` + `ClienteFormScreen`: lista responsive, ricerca, CRUD, duplicati.
- Modelli `Prodotto` e `Categoria` + CRUD in `SpService`.
- Test clienti (validazioni/form) e catalogo (modelli).
- `flutter analyze` 0, `flutter test` verdi.

## 2026-10-22 — F09c/F11b: VIES e catalogo

- `ViesService` chiama il Worker VIES; pulsante "Verifica P.IVA" nel form cliente con dialogo e autofill se vuoto.
- `CatalogoScreen`: tab Prodotti/Categorie, ricerca, filtro, form completo, eliminazione con conferma.
- Estratti `StatoCentrato` e `MenuAzioni`; rimosse le classi private duplicate.
- `flutter analyze` 0, test verdi (modelli, validazioni, form).

## 2026-10-22 — F13: preventivi e indici Firestore (backend)

- `lib/data/services/sp_service.dart`: rimosso l'`orderBy` server-side da `getClienti`, `getProdotti`,
  `getCategorie` e `getPreventivi` (avrebbero richiesto indici compositi `azienda_id` + campo di ordinamento).
  Ora le quattro query filtrano solo per `azienda_id` e ordinano in Dart: clienti/prodotti per `nome`,
  categorie per `ordine`, preventivi per `created_at` decrescente. Il filtro `soloUtenteId` di `getPreventivi`
  resta applicato in memoria dopo la lettura.
- `docs/progetto/database.md`: nuova nota «Query aziendali: filtro server + ordinamento client» (niente indici
  compositi, `firestore.indexes.json` vuoto).
- `flutter analyze` → `No issues found!`; `flutter test` → `All tests passed!` (171 test).
- Aggiornati task board (F13 `FATTO`), catalogo (oggetti preventivo) e database; nessun commit/push.

## 2026-10-22 — F12a: lista preventivi

- `PreventiviScreen`: lista responsive, ricerca, badge stato, stati vuoto/caricamento/errore.
- Funzioni pure per stato e filtro; 18 test dedicati.
- `flutter analyze` 0, `flutter test` 189 verdi.

## 2026-10-22 — F12b-1: editor preventivi

- `PreventivoEditScreen`: cliente, stato, note, sconto, righe modificabili, totali e layout responsive.
- Rotte `/preventivi/nuovo` e `/preventivi/:id` (caricamento in F12b-2).
- Test delle funzioni pure (numeri, sconto, righe, totali); 197 test verdi.

## 2026-10-22 — F12b-2a: salvataggio preventivo

- `PreventivoEditScreen`: pulsante `FilledButton.icon` "Salva preventivo" in fondo alla schermata
  (`Key('salva-preventivo')`), disabilitato con spinner e testo "Salvataggio…" durante `_salvataggio`;
  errore dell'ultimo tentativo mostrato con `AvvisoErrore` (`Key('preventivo-salvataggio-errore')`) usando
  `messaggioErroreSalvataggioPreventivo`.
- `SpService.aggiornaPreventivo`: aggiunto `sconto` alla patch (`_numero(dati['sconto']) ?? 0`), finora assente
  e quindi non aggiornato in modifica.
- `test/preventivo_edit_screen_test.dart`: aggiunti test di `payloadPreventivoDaEditor` (chiavi Firestore, dati
  ripuliti, righe serializzate in camelCase, totali con e senza sconto) e di `datiServizioPreventivo`.
- `flutter analyze` → `No issues found!`; `flutter test` → `All tests passed!` (204 test).
- Aggiornati task board (F12b-2a `FATTO`) e catalogo; nessun commit/push.

## 2026-10-22 — F12b-2b: caricamento preventivo e revisione

- `SpService.getPreventivo(id)`; editor carica il documento da `/preventivi/:id`.
- Pulsante "Crea revisione" per preventivi inviati/accettati/rifiutati; nuova revisione senza consumare il contatore.
- Gestione stati caricamento/non trovato/errore; `flutter analyze` 0, 206 test verdi.

## 2026-10-22 — F14: PDF preventivo

- `generaPdfPreventivo` con pdf: intestazione, righe, totali, note; pulsante PDF e condivisione.
- Test PDF (%PDF, byte non vuoti) e formati; `flutter analyze` 0, 212 test verdi.

## 2026-10-22 — F08/F15a: dashboard e visite dati

- Dashboard con 6 statistiche, valore aperto, ultimi 5, azioni rapide; responsive.
- Modello `Visita` e CRUD `SpService` per giro visite.
- Test dashboard (conteggi e widget) e visite (modello); `flutter analyze` 0, 237 test verdi.

## 2026-10-22 — F15b: schermata visite

- `VisiteScreen` + `VisitaFormScreen`: data, lista, CRUD, stati, riordino con frecce, layout responsive.
- Test funzioni pure e widget; `flutter analyze` 0, 262 test verdi.

## 2026-10-22 — F07c: AuthGate

- `AuthGate` nel `ShellRoute`: login se non autenticato, onboarding senza profilo/azienda, altrimenti shell.
- Invalidazione del profilo dopo l'onboarding per evitare loop.
- Test con provider sovrascritti; `flutter analyze` 0, 265 test verdi.

## 2026-10-22 — F16a/F17a: bandi dati e impostazioni

- Modelli `Bando`/`FonteBando` e `getBandi`/`getFontiBandi`.
- `ImpostazioniScreen` con profilo, azienda, accessi e logout; AuthGate già attivo.
- `flutter analyze` 0, 283 test verdi.

## 2026-10-22 — F20: pagina introduttiva installazione

- `IntroScreen` con istruzioni Android/Chrome, iPhone/iPad e desktop.
- `FirstRunGate` con `shared_preferences`: mostra l'intro una sola volta, poi la shell.
- Voce "Come installare l'app" in Impostazioni; rotta `/intro`.
- `flutter analyze` 0, 287 test verdi.

## 2026-10-22 — F21: intro interattiva

- Selettore Android/iPhone/Desktop con pannello animato e mockup che mostrano dove toccare.
- Animazioni Flutter native (nessuna GIF esterna, funziona offline).
- Test aggiornati; `flutter analyze` 0, 289 test verdi.

## 2026-10-22 — F22: intro subito dopo il login

- `AuthGate` avvolge con `FirstRunGate` appena c'è l'utente: l'intro non aspetta profilo e aziende.
- `getAziendeUtente` legge le aziende in parallelo; `loadProfile` prova prima `utenti/{uid}` e poi l'email.
- Test specifico con provider in caricamento; `flutter analyze` 0, 290 test verdi.

## 2026-10-22 — F23: rinomina in Closer e nuova icona

- Nome visibile "Closer" su web, Android, iOS, login, splash, intro e PDF.
- Icona fornita da Andrea convertita in 1024×1024, foreground adattivo e launcher icons generati per web/Android/iOS.
- Icona usata anche nelle schermate di login e intro.
- `flutter analyze` 0, 290 test verdi, deploy staging completato.

## 2026-10-22 — F26a: modelli Ruolo/Licenza e query amministrazione (backend)

- `lib/data/models/ruolo.dart` (nuovo): `Ruolo` con `id`, `aziendaId`, `nome`, `chiave`, `descrizione`,
  `scontoMax` (int, default 0), `permessi` (mappa, default vuota), `sistema` (bool, default false); `fromMap`
  con campi Firestore in snake_case (`sconto_max`), coerente con `Azienda`/`UserProfile`.
- `lib/data/models/licenza.dart` (nuovo): `Licenza` con `id`, `aziendaId`, `piano` (default `trial`),
  `stato` (default `attiva`), `dataInizio`/`dataFine` (`YYYY-MM-DD`, null se assenti), `maxUtenti`/
  `maxPreventivi` (int?, null se assenti), `note`; `fromMap` con `azienda_id` che ricade sull'id documento.
- `lib/data/services/sp_service.dart`: aggiunti `getUtenti` (membri dell'azienda attiva + profili `utenti`
  con il `ruolo` della membership, come `SP.getUtenti`), `aggiornaRuoloUtente` (merge su
  `membri/{aziendaId}_{uid}`), `eliminaMembro` (delete del documento membro), `getRuoli` (ruoli
  dell'azienda attiva ordinati per `nome`), `getLicenzaAzienda` (legge `licenze/{aziendaId}` → `Licenza?`)
  e `getTutteAziende` (tutte le `aziende` ordinate per `nome`, per il super admin).
- `test/amministrazione_test.dart` (nuovo): 11 test di `fromMap` di `Ruolo` e `Licenza` (permessi e date).
- `flutter test test/amministrazione_test.dart` → `All tests passed!` (11 test); `dart analyze` sui file
  toccati → `No issues found!`.
- Nota: `flutter analyze`/`flutter test` globali falliscono per errori preesistenti in
  `lib/features/bandi/bandi_screen.dart` (file non tracciato, del task F16 frontend in corso), non in
  questo task. Nessuna UI, nessuna modifica a vecchia app/Firebase/regole, nessun commit/push.

## 2026-10-22 — F24-F28: azienda attiva, niente segnaposto, E2E reale

- **Causa del permission-denied**: dopo il login l'app non impostava l'azienda attiva; le scritture
  partivano con `azienda_id: null` e Firestore le negava. Aggiunto `aziendaAttivaSyncProvider`, osservato
  da `AuthGate`, che imposta la prima azienda dell'utente e non sovrascrive la scelta manuale del super admin.
- Aggiunte guardie in `SpService` per le scritture senza azienda e un errore chiaro.
- **Secondo bug trovato dall'E2E**: il primo preventivo falliva per `permission-denied` sulla lettura del
  contatore `contatori/preventivi_{azienda}` (documento inesistente, `resource` null nelle regole). Il
  contatore ora viene creato/aggiornato con `azienda_id` prima della transazione.
- Sostituiti tutti i segnaposto del perimetro: Bandi, Utenti, Ruoli, Licenze e Super admin, con test.
- Aggiunti `scripts/e2e-staging.py` (CRUD cliente con regole reali) e `scripts/e2e-ui-dati.py` (dati per la
  prova UI, con pulizia completa).
- **Prova reale su staging** con utente temporaneo: login → intro → dashboard → cliente creato e persistito
  → preventivo `PRV-0001` creato e persistito → Bandi/Utenti/Ruoli/Licenze raggiungibili → Super admin
  negato al non super admin. Nessun errore di permessi.
- Cache del browser: aggiunti header `no-cache` per `index.html`, `flutter_bootstrap.js`, `main.dart.js` e
  `flutter_service_worker.js`, più versione nei nomi caricati, per evitare che una build vecchia resti in uso.
- `flutter analyze` 0; `flutter test` 383 verdi.

2026-10-22 — F24–F28 validati (`APPROVATO`). Analyze 0, 383 test verdi, E2E staging PASS, indice memoria OK; rotte `/bandi`, `/impostazioni/utenti`, `/impostazioni/ruoli`, `/impostazioni/licenze`, `/superadmin` reali (nessun segnaposto); residui F16c/F18b dichiarati fuori perimetro.

## 2026-10-22 — Panieri di prodotti

- Il prodotto padre ora ha `figli_ids` e `figli_a_zero`; i figli restano prodotti normali e
  possono appartenere a più padri.
- Nel catalogo il form prodotto ha la sezione “Paniere (sotto-prodotti)” con selezione multipla,
  ricerca e flag “Vendi i sotto-prodotti a prezzo zero”; lista e tabella mostrano il conteggio figli.
- Nell'editor preventivi c'è “Dal catalogo”: scelto un prodotto, se è un padre inserisce padre e figli
  come righe singole, con etichetta “Paniere: <padre>”, quantità del padre e prezzi pieni o zero.
- Il padre non ricalcola il prezzo; figli già presenti vengono adottati o incrementati senza duplicati;
  un figlio sotto un altro paniere crea una riga separata.
- PDF: le righe figlie riportano l'etichetta del paniere.
- Verifiche: `flutter analyze` 0, **420 test verdi**, E2E staging con PRV-0001 (180,00 €) e PRV-0002
  (200,00 € con figli a zero e quantità 2). Report: `docs/progetto/test/2026-10-22-panieri.md`.
- Nessuna modifica a `firestore.rules`, collezioni o indici.
- Validazione panieri: **APPROVATO** (22/10/2026); P01-P10 coerenti, regole invariate, nessun segnaposto.

## 2026-10-22 — Aziende, utenti, ruoli e import bandi

- Rinominata l'azienda di appoggio **VOLTY → Closer**.
- Superadmin: creazione nuova azienda con primo amministratore, ruoli seed, categorie e licenza trial.
- Utenti: creazione con ruolo tramite seconda app Firebase; la sessione dell'amministratore resta attiva.
- Ruoli: creazione e modifica con permessi per area; i ruoli di sistema non sono eliminabili.
- Bandi: nuova pagina **Importa bandi** (JSON da file o URL, solo superadmin), parser e upsert in batch.
- Bandi spostati nel menu principale; aggiunto filtro **ATECO** per prefisso.
- Verifiche: `flutter analyze` 0, **499 test verdi**, E2E con ruolo Tecnico E2E, utente tecnico,
  azienda E2E, import di un bando ATECO 62 e filtro ATECO. Report:
  `docs/progetto/test/2026-10-22-amministrazione-bandi.md`.
- Nessuna modifica a `firestore.rules`, collezioni o indici.
- Validazione amministrazione/bandi: **APPROVATO** (22/10/2026); prove pulite, PRV di test eliminato, contatore azzerato.

## 2026-10-22 — Bandi: ATECO con punto e filtro provincia

- Il campo ATECO accetta ora anche il punto (`62.01`), con tastiera decimale su mobile, formatter `[0-9.]` e massimo 8 caratteri.
- Il matching ATECO usa solo le cifre e confronta il prefisso di 2 cifre, quindi `62`, `62.0` e `62.01` funzionano.
- Aggiunto il filtro **Provincia** con tutte le 107 province italiane; se il bando espone `province` il confronto è preciso, altrimenti si usa la regione della provincia (i dati open data spesso non hanno la provincia). Una nota nella UI lo spiega.
- Modello `Bando` e parser di import aggiornati con il campo opzionale `province`.
- Verifiche: `flutter analyze` 0, **509 test verdi**, deploy staging.
