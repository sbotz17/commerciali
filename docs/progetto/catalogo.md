# Catalogo degli oggetti del progetto

Prima di creare un componente, una funzione o una collezione, cerca qui e nel codice. Registra ogni nuovo
oggetto con nome, percorso, scopo e dove è usato.

## File principali

| Oggetto | Percorso | Scopo |
|---|---|---|
| App | `index.html` | Layout, schermate Alpine.js, modali |
| Logica UI | `js/app.js` | Store Alpine, pagine, azioni |
| Data layer | `js/sp-firestore.js` | Interfaccia `SP` su Firestore |
| Auth | `js/auth.js` | Login, Google, sessione, profilo |
| Firebase | `js/firebase.js` | Configurazione e client |
| Regole | `firestore.rules` | Sicurezza multi-azienda |
| Worker VIES | `worker/src/index.js` | Proxy verifica P.IVA |

## Flutter (`flutter_app/`)

| Oggetto | Percorso | Scopo |
|---|---|---|
| App/root | `flutter_app/lib/app.dart` | `MaterialApp.router` con tema e router |
| Tema | `flutter_app/lib/core/theme/app_theme.dart` | Colori, spazi, raggi, breakpoint e Material 3 |
| Router | `flutter_app/lib/routing/app_router.dart` | Rotte `go_router` e pagine segnaposto |
| Shell | `flutter_app/lib/features/shell/app_shell.dart` | `NavigationBar`/`NavigationRail` responsive e drawer |
| Segnaposto | `flutter_app/lib/core/ui/placeholder_screen.dart` | Corpo condiviso per schermate non ancora implementate |
| Avviso errore | `flutter_app/lib/core/ui/avviso_errore.dart` | `AvvisoErrore(testo: ...)`: messaggio di errore in italiano con colori semantici e `liveRegion`; chiave passata dal chiamante per i test |
| Onboarding | `flutter_app/lib/features/auth/onboarding_screen.dart` | `OnboardingScreen` (rotta `/onboarding`): primo avvio, crea profilo, azienda, membership admin e seed; validatori puri `validaNomeUtente`, `validaNomeAzienda`, `messaggioErroreOnboarding` |
| Test login Google | `flutter_app/test/google_auth_test.dart` | Unit test `messaggioErroreGoogle` (`FirebaseAuthException` + `GoogleSignInException`) + widget test pulsante Google |
| Test onboarding | `flutter_app/test/onboarding_screen_test.dart` | Widget test di `OnboardingScreen` (campi, pulsante, errori su campi vuoti/corti) + unit test dei validatori e di `messaggioErroreOnboarding` |

## Collezioni Firestore

`aziende`, `utenti`, `membri`, `ruoli`, `licenze`, `piani_config`, `whatsapp_config`, `impostazioni`,
`prodotti`, `categorie`, `clienti`, `preventivi`, `giro_visite`, `bandi_fonti`, `bandi_incentivi`,
`bandi_sync_log`, `contatori`.

## Memoria ad albero

| Oggetto | Percorso | Scopo |
|---|---|---|
| Indice radice | `docs/progetto/indice.md` | mappa del progetto e regole di lettura |
| Nodi di memoria | `docs/progetto/memoria/**` | conoscenza per area, max 50 righe per nodo |
| Controllo | `scripts/controlla-indice.mjs` | verifica nodi, date e file chiave non mappati |
