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
| Servizio dati preventivo | `flutter_app/lib/data/services/sp_service.dart` | `getPreventivi` (filtro `azienda_id` + ordinamento client per `created_at` desc; `soloUtenteId` in memoria), `contaPreventivi`, `inserisciPreventivo` (progressivo transazionale `PRV-0001`), `aggiornaPreventivo` (patch con `sconto`), `aggiornaStato`, `eliminaPreventivo`, `creaRevisione` (`-R{n}` senza consumare il contatore) |
| Editor preventivo | `flutter_app/lib/features/preventivi/preventivo_edit_screen.dart` | `PreventivoEditScreen`: cliente/stato, righe modificabili (card telefono, tabella desktop), note e sconto, riepilogo totali, pulsante "Salva preventivo" (`Key('salva-preventivo')`, spinner durante il salvataggio) ed errore `Key('preventivo-salvataggio-errore')`; funzioni pure `rigaPreventivoDaCampi`, `totaliEditorPreventivo`, `payloadPreventivoDaEditor`, `datiServizioPreventivo`, `messaggioErroreSalvataggioPreventivo` |
| Test editor preventivo | `flutter_app/test/preventivo_edit_screen_test.dart` | Unit test dei formati numerici, righe da campi, totali, `payloadPreventivoDaEditor` (chiavi, righe serializzate, totali con/senza sconto) e `datiServizioPreventivo` |
| Test preventivo | `flutter_app/test/preventivo_test.dart` | Unit test di `PreventivoRiga`/`Preventivo` (`fromMap`/`toMap`/default), calcolo totali e funzioni di numero/revisione |
| Test catalogo | `flutter_app/test/catalogo_test.dart` | Unit test `fromMap`/`toMap`/default di `Prodotto` e `Categoria` |
| Test login Google | `flutter_app/test/google_auth_test.dart` | Unit test `messaggioErroreGoogle` (`FirebaseAuthException` + `GoogleSignInException`) + widget test pulsante Google |
| Test onboarding | `flutter_app/test/onboarding_screen_test.dart` | Widget test di `OnboardingScreen` (campi, pulsante, errori su campi vuoti/corti) + unit test dei validatori e di `messaggioErroreOnboarding` |
| Modello Ruolo | `flutter_app/lib/data/models/ruolo.dart` | `Ruolo` (`id`, `aziendaId`, `nome`, `chiave`, `descrizione`, `scontoMax`, `permessi`, `sistema`) con `fromMap` snake_case |
| Modello Licenza | `flutter_app/lib/data/models/licenza.dart` | `Licenza` (`id`, `aziendaId`, `piano`, `stato`, `dataInizio`, `dataFine`, `maxUtenti`, `maxPreventivi`, `note`) con `fromMap` snake_case |
| Servizio dati amministrazione | `flutter_app/lib/data/services/sp_service.dart` | `getUtenti` (membri + profili con ruolo), `aggiornaRuoloUtente`, `eliminaMembro`, `getRuoli`, `getLicenzaAzienda`, `getTutteAziende` |
| Test amministrazione | `flutter_app/test/amministrazione_test.dart` | Unit test `fromMap` di `Ruolo` e `Licenza` (permessi e date) |
| Schermata Bandi | `flutter_app/lib/features/bandi/bandi_screen.dart` | Lista bandi con ricerca, filtri stato/regione, card/table responsive, dettaglio e link ufficiale |
| Schermata Utenti | `flutter_app/lib/features/impostazioni/utenti_screen.dart` | Membri dell'azienda, cambio ruolo e rimozione con conferma |
| Schermata Ruoli | `flutter_app/lib/features/impostazioni/ruoli_screen.dart` | Ruoli e permessi in sola lettura, con riepilogo per area |
| Schermata Licenze | `flutter_app/lib/features/impostazioni/licenze_screen.dart` | Piano, stato effettivo (data fine), date, limiti e note |
| Schermata Super admin | `flutter_app/lib/features/superadmin/superadmin_screen.dart` | Elenco aziende, ricerca e ingresso; guardia `superAdmin` |
| Sync azienda attiva | `flutter_app/lib/state/azienda_providers.dart` | `aziendaAttivaSyncProvider`: imposta la prima azienda dopo il login e rispetta la scelta del super admin |
| Test provider azienda | `flutter_app/test/azienda_providers_test.dart` | Unit test della sincronizzazione e del caso super admin |
| Test schermate amministrazione | `flutter_app/test/utenti_screen_test.dart`, `ruoli_screen_test.dart`, `licenze_screen_test.dart`, `superadmin_screen_test.dart`, `bandi_screen_test.dart` | Test di funzioni pure, stati vuoti e layout |
| E2E permessi | `scripts/e2e-staging.py` | Crea utente/azienda temporanei, verifica CRUD cliente con le Security Rules reali e pulisce |
| E2E UI dati | `scripts/e2e-ui-dati.py` | Prepara e pulisce utente/azienda/ruoli/licenza per la prova manuale su staging |
| Panieri — modello | `flutter_app/lib/data/models/prodotto.dart` | Campi `figliIds` (`figli_ids`) e `figliAZero` (`figli_a_zero`) |
| Panieri — riga preventivo | `flutter_app/lib/data/models/preventivo.dart` | `paniereId`/`paniereNome` nella riga e `copyWith` |
| Panieri — inserimento | `flutter_app/lib/data/panieri.dart` | `figliDelPaniere`, `figliMancanti`, `inserisciPaniere` (funzioni pure) |
| Panieri — catalogo | `flutter_app/lib/features/catalogo/catalogo_screen.dart` | Sezione Paniere nel form, badge e colonna “Paniere” |
| Panieri — preventivo | `flutter_app/lib/features/preventivi/preventivo_edit_screen.dart` | Ricerca prodotto dal catalogo, inserimento padre+figli, etichetta/rientro |
| Panieri — PDF | `flutter_app/lib/data/services/preventivo_pdf.dart` | Etichetta “Paniere: …” sotto la descrizione |
| Test panieri | `flutter_app/test/prodotto_panieri_test.dart`, `prodotti_panieri_service_test.dart`, `preventivo_panieri_test.dart`, `panieri_test.dart`, `catalogo_panieri_test.dart`, `catalogo_panieri_badge_test.dart`, `preventivo_panieri_ui_test.dart` | Serializzazione, sanitizzazione, inserimento, UI catalogo/preventivo |
| Report panieri | `docs/progetto/test/2026-10-22-panieri.md` | E2E con prezzo pieno, figli a zero, reinserimento e verifica Firestore |
| Account secondario | `flutter_app/lib/data/services/auth_service.dart` | `creaAccountConProfilo`, `inviaEmailAccesso`, `EmailGiaRegistrataException`; crea utente senza perdere la sessione |
| Ruoli modificabili | `flutter_app/lib/features/impostazioni/ruoli_screen.dart`, `ruolo_form_screen.dart` | Creazione/modifica/eliminazione ruoli e permessi per area |
| Nuovo utente | `flutter_app/lib/features/impostazioni/nuovo_utente_screen.dart` | Nome, email, ruolo, invito o password temporanea |
| Nuova azienda | `flutter_app/lib/features/impostazioni/nuova_azienda_screen.dart` | Azienda + primo amministratore + seed + licenza |
| Import bandi | `flutter_app/lib/features/bandi/import_bandi_screen.dart`, `flutter_app/lib/data/bandi_import.dart` | Import JSON da file o URL, normalizzazione e statistiche |
| Import service | `flutter_app/lib/data/services/sp_service.dart` | `importaBandi`, `rinominaAzienda`, `inserisciRuolo`/`aggiornaRuolo`/`eliminaRuolo`, `getUtentePerEmail` |
| Bandi ATECO | `flutter_app/lib/features/bandi/bandi_screen.dart` | Filtro ATECO per prefisso, menu principale |
| Province italiane | `flutter_app/lib/data/province_italia.dart` | 107 province con sigla e regione per il filtro territoriale dei bandi |
| Codice prodotto | `flutter_app/lib/data/models/prodotto.dart` | Campo `codice` usato in catalogo e righe preventivo |
| Nuovo cliente da preventivo | `flutter_app/lib/features/preventivi/preventivo_edit_screen.dart` | Pulsante nella card cliente e selezione automatica dopo la creazione |
| Agenda — modelli | `flutter_app/lib/data/models/appuntamento.dart`, `task_item.dart`, `promemoria.dart`, `notifica.dart` | Modelli dati dell'area agenda |
| Chat — modelli | `flutter_app/lib/data/models/stanza_chat.dart`, `messaggio_chat.dart` | Stanze dirette/gruppi e messaggi |
| Calendario | `flutter_app/lib/features/calendario/calendario_screen.dart`, `calendario_logica.dart`, `viste_calendario.dart`, `appuntamento_form_screen.dart` | Calendario classico giorno/settimana/mese (predefinito) e stile card; creazione appuntamento con data/ora, dettaglio, Maps |
| Calendario — logica | `flutter_app/lib/features/calendario/calendario_logica.dart` | `VistaAgenda`/`StileAgenda`, `ElementoAgenda`, raggruppamento, periodi, griglia del mese, posizionamento eventi sovrapposti |
| Calendario — viste classiche | `flutter_app/lib/features/calendario/viste_calendario.dart` | `VistaMeseCalendario` e `VistaGrigliaOraria` per giorno/settimana, con “Senza orario” e tocco su spazio vuoto |
| Test calendario | `flutter_app/test/calendario_test.dart` | Unit test di periodi e griglia oraria + widget test di mese, giorno e settimana |
| Task | `flutter_app/lib/features/task/task_screen.dart`, `task_form_screen.dart` | Lista per periodi, filtri, completamento, form |
| Notifiche | `flutter_app/lib/features/notifiche/notifiche_screen.dart`, `campanella_notifiche.dart` | Centro notifiche, badge, preferenze |
| Chat UI | `flutter_app/lib/features/chat/chat_screen.dart`, `chat_thread_screen.dart` | Lista conversazioni, nuove chat/gruppi, thread |
| Preferenze notifiche | `flutter_app/lib/features/impostazioni/notifiche_preferenze_screen.dart` | Push, WhatsApp, chat, silenzio, anteprima |
| Nuovo prodotto da preventivo | `flutter_app/lib/features/preventivi/preventivo_edit_screen.dart` | Pulsante nel selettore catalogo e inserimento immediato nella riga |
| Nuovo cliente da visite | `flutter_app/lib/features/visite/visite_screen.dart`, `flutter_app/lib/features/clienti/clienti_screen.dart` | Callback `onSalvato` del form cliente e ritorno alla visita con cliente selezionato |
| Integrazioni aziendali | `flutter_app/lib/features/impostazioni/impostazioni_integrazioni_screen.dart`, `data/models/integrazione_azienda.dart` | Card Google/Microsoft/SMTP/WhatsApp/R2/Push, modalità app Closer/app propria, nessun secret in Firestore |
| Condivisione calendario | `flutter_app/lib/features/impostazioni/condivisione_calendario_screen.dart`, `data/models/condivisione_calendario.dart` | Condivisione con colleghi, livelli, revoca, “Condivisi con me” |
| Call manuale | `flutter_app/lib/features/calendario/appuntamento_form_screen.dart` | Provider Meet/Teams/altro, link, copia, apertura, validazione |
| Report integrazioni/calendario | `docs/progetto/test/2026-10-24-integrazioni-calendario.md` | O01–O04, E2E regole, 778 test verdi |
| Report amministrazione/bandi | `docs/progetto/test/2026-10-22-amministrazione-bandi.md` | E2E ruoli, utenti, azienda, import e ATECO |

## Collezioni Firestore

`aziende`, `utenti`, `membri`, `ruoli`, `licenze`, `piani_config`, `whatsapp_config`, `impostazioni`,
`prodotti`, `categorie`, `clienti`, `preventivi`, `giro_visite`, `bandi_fonti`, `bandi_incentivi`,
`bandi_sync_log`, `contatori`, `appuntamenti`, `task`, `promemoria`, `notifiche`, `chat_stanze`,
`integrazioni_azienda`, `integrazioni`, `condivisioni_calendario`, `impostazioni_agenda`.

## Memoria ad albero

| Oggetto | Percorso | Scopo |
|---|---|---|
| Indice radice | `docs/progetto/indice.md` | mappa del progetto e regole di lettura |
| Nodi di memoria | `docs/progetto/memoria/**` | conoscenza per area, max 50 righe per nodo |
| Controllo | `scripts/controlla-indice.mjs` | verifica nodi, date e file chiave non mappati |
