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
