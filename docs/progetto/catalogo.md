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
| Modello Prodotto | `flutter_app/lib/data/models/prodotto.dart` | `Prodotto` (`id`, `aziendaId`, `nome`, `categoria`, `prezzo` numerico, `descrizione`, `immagine` URL, `attivo`) con `fromMap`/`toMap` snake_case |
| Modello Categoria | `flutter_app/lib/data/models/categoria.dart` | `Categoria` (`id`, `aziendaId`, `nome`, `icona`, `ordine`) con `fromMap`/`toMap` snake_case |
| Servizio dati catalogo | `flutter_app/lib/data/services/sp_service.dart` | `getProdotti`/`inserisciProdotto`/`aggiornaProdotto`/`eliminaProdotto` e `getCategorie`/`inserisciCategoria`/`aggiornaCategoria`/`eliminaCategoria` (scope azienda attiva) |
| Modello Preventivo | `flutter_app/lib/data/models/preventivo.dart` | `Preventivo` (id, `aziendaId`, `clienteId`/`clienteNome`, `utenteId`, `numero`, `revisione`, `righe`, totali, `stato`, `createdAt`) e `PreventivoRiga` con `fromMap`/`toMap`; funzioni pure `totaleRiga`, `calcolaTotali`/`PreventivoTotali`, `formatoNumeroPreventivo`, `numeroBasePreventivo`, `numeroRevisione` |
| Servizio dati preventivo | `flutter_app/lib/data/services/sp_service.dart` | `getPreventivi` (filtro `azienda_id` + ordinamento client per `created_at` desc; `soloUtenteId` in memoria), `contaPreventivi`, `inserisciPreventivo` (progressivo transazionale `PRV-0001`), `aggiornaPreventivo`, `aggiornaStato`, `eliminaPreventivo`, `creaRevisione` (`-R{n}` senza consumare il contatore) |
| Test preventivo | `flutter_app/test/preventivo_test.dart` | Unit test di `PreventivoRiga`/`Preventivo` (`fromMap`/`toMap`/default), calcolo totali e funzioni di numero/revisione |
| Test catalogo | `flutter_app/test/catalogo_test.dart` | Unit test `fromMap`/`toMap`/default di `Prodotto` e `Categoria` |
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
