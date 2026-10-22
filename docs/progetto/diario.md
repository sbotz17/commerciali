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
