# Test — Calendario condiviso e OAuth aziendale, prima fetta (O01–O04)

**Data**: 24/10/2026
**Stato**: prima fetta implementata e pubblicata su staging; Worker OAuth e UI di condivisione ancora da fare.

## Perimetro

- O01: regole e indici `integrazioni_azienda`, `condivisioni_calendario`.
- O02: modelli `IntegrazioneAzienda`, `ConfigIntegrazioneProvider`, `CondivisioneCalendario`.
- O03: servizio integrazione e condivisioni.
- O04: schermata `Impostazioni → Calendario e integrazioni`.

## Esiti

| Controllo | Comando | Esito |
|---|---|---|
| Analisi | `flutter analyze` | 0 problemi |
| Test | `flutter test` | **778 verdi** |
| E2E regole | `python3 scripts/e2e-agenda.py` | PASS |
| Regole | deploy `firestore:rules` | completato |
| Indici | deploy `firestore:indexes` | completato |
| Hosting | deploy app + flutter | completato |

L’E2E verifica con due utenti reali della stessa azienda:

- appuntamento, task, chat, notifica;
- `integrazioni_azienda`: l’admin legge/scrive, il commerciale no; il campo `client_secret` viene rifiutato;
- `condivisioni_calendario`: il proprietario crea, il destinatario legge; un utente non può spacciarsi per il proprietario né revocare; dopo la revoca il destinatario non legge più.

## Cosa funziona

- Modelli con default e serializzazione senza `client_secret`/token.
- Servizio con lettura/salvataggio integrazione e CRUD condivisioni.
- Schermata admin con card Google, Microsoft, SMTP, WhatsApp, R2, Push.
- Dialog Google/Microsoft: modalità app Closer/app propria, Client ID, Tenant Microsoft, redirect URI, salvataggio non segreto.
- Voce e rotta `/impostazioni/integrazioni`.

## Residui dichiarati

- O05/O06/O07: Worker OAuth, inserimento Client Secret, test connessione reale.
- O08: connessioni utente Google/Microsoft.
- O09/O10: condivisione calendario lato UI e mascheramento eventi.
- O11: creazione evento e call Meet/Teams.
- O12/O13: E2E completo e validazione finale.
- SMTP, WhatsApp e R2: card presenti, configurazione server e invio ancora da fare.

## Verifica tester O01–O04

| Controllo | Comando | Esito |
|---|---|---|
| Analisi | `flutter analyze` | 0 problemi |
| Test | `flutter test` | 778 verdi |
| E2E regole | `python3 scripts/e2e-agenda.py` | PASS |
| Indice | `node scripts/controlla-indice.mjs` | INDICE OK |
| Regole | `firestore.rules` | admin-only per integrazioni, revoca non leggibile dal destinatario, secret rifiutato |
| Indici | `firestore.indexes.json` | due indici condivisioni presenti |
| UI | `/impostazioni/integrazioni` | rotta e voce presenti; nessun segnaposto nel percorso |
| Segreti | dialog e modelli | Client Secret disabilitato, nessun `client_secret`/token in Firestore |

**Verdetto tester: NON SUPERATO per rilascio** perché manca la prova E2E nel browser richiesta dalla DoD; la fetta tecnica O01–O04 è verificata, ma restano aperti O05–O13 e la prova UI reale. Non rilasciabile in produzione.

**Validazione (24/10/2026): APPROVATO TECNICO per staging** — fetta O01–O04 (schema/regole, modelli, servizio, schermata integrazioni) verificata. Non rilasciabile in produzione: manca E2E browser e restano obbligatori O05–O13.


## O10/O11 parziali (24/10/2026)

- Aggiunta `Impostazioni → Condivisione calendario` con creazione, livelli, revoca e condivisioni ricevute.
- Aggiunta sezione Call nel form appuntamento: provider, link manuale, copia/apertura e validazione http/https.
- `flutter analyze` 0; `flutter test` **790 verdi**; app pubblicata su staging.
- Residui: vista calendario condiviso e mascheramento “Occupato” (O09), creazione automatica Meet/Teams (O11), Worker OAuth (O06/O07), connessioni utente (O08), E2E browser (O12).

## Verifica tester O10/O11 (24/10/2026)

### Cosa ho provato

| Controllo | Comando / verifica | Esito atteso | Esito ottenuto |
|---|---|---|---|
| Analisi statica | `cd flutter_app && flutter analyze` | 0 problemi | `No issues found!` (0) |
| Suite completa | `flutter test` | 790 verdi | **790 verdi**, `All tests passed!` |
| Test mirati | `flutter test test/condivisione_calendario_screen_test.dart test/appuntamento_form_test.dart` | verdi | 31 verdi, `All tests passed!` |
| E2E regole | `python3 scripts/e2e-agenda.py` | PASS | `PASS: appuntamenti, task, chat, notifiche, integrazioni e condivisioni rispettano le regole` |
| Indice memoria | `node scripts/controlla-indice.mjs` | INDICE OK | 19 nodi, 9 file chiave, `INDICE OK` |
| Rotta | `lib/routing/app_router.dart` | `/impostazioni/condivisioni-calendario` | presente (riga 145) → `CondivisioneCalendarioScreen` |
| Voce impostazioni | `lib/features/impostazioni/impostazioni_screen.dart` | key `impostazioni-voce-condivisioni` | presente, apre `/impostazioni/condivisioni-calendario` |
| Segnaposto nel percorso | grep `PlaceholderScreen` | nessuno | unico uso in `_PaginaAutonoma` (login/reset/onboarding), fuori dal percorso |
| Servizio condivisione | `condivisione_calendario_screen.dart` | 5 metodi richiesti | usa `getUtenti`, `getCondivisioniCalendario`, `getCondivisioniRicevute`, `condividiCalendario`, `revocaCondivisione` |
| Livello predefinito | modello + schermata | `dettagli` | `livelloPredefinitoCondivisione = 'dettagli'`; modello normalizza i valori non validi a `dettagli` |
| Form call | `appuntamento_form_screen.dart` | provider, link, copia/apertura, http/https | provider (`google_meet`/`teams`/nessuna), link, pulsanti copia e apri, validazione `http`/`https` con host |
| Persistenza call | form + modello | `call_provider`/`call_url` | salvati come `call_provider`/`call_url`; `nessuna`/vuoto → `null` |
| Segreti/dati di test | grep su file nuovi e test | nessuno | nessun segreto; test con fixture locali |

### Problemi

- Nessun problema bloccante sulla fetta tecnica: analisi, test, E2E e indice sono verdi, rotta e voce raggiungibili, nessun segnaposto nel percorso.
- Nota documentale (non bloccante): `docs/progetto/memoria/flutter/index.md` ha `Ultima revisione: 2026-10-22` e non cita ancora le schermate di condivisione calendario e call nel form appuntamento. Da aggiornare a cura dello sviluppatore dell'area.

### Residui dichiarati (fuori da questa fetta)

- Vista calendario condiviso e mascheramento eventi “Occupato” (O09): **assente**.
- Creazione automatica link Google Meet / Microsoft Teams (O11): **assente**, il link è solo manuale.
- Worker OAuth e inserimento Client Secret (O06/O07), connessioni utente Google/Microsoft (O08): **assenti**.
- Prova E2E nel browser richiesta dalla DoD (O12): **non eseguita** in questa verifica.

**Verdetto tester: SUPERATO per la fetta tecnica O10 parziale + call manuale O11**, con tutte le prove sopra verdi. **NON rilasciabile in produzione**: mancano vista calendario condiviso e mascheramento, creazione automatica Meet/Teams, O06–O08 e la prova E2E nel browser.


**Validazione (24/10/2026): APPROVATO TECNICO per staging** — sola fetta O10 parziale + call manuale O11 verificata. Non rilasciabile in produzione: manca E2E browser; restano obbligatori O05–O09, O11 automatico, O12–O13.

## Verifica tester menu laterale

**Perimetro**: solo la modifica del menu laterale in `flutter_app/lib/features/shell/app_shell.dart` (+ `flutter_app/test/app_shell_test.dart`). Nessuna correzione apportata dal tester, nessun commit.

### Cosa ho provato e esiti

| # | Controllo | Comando / file | Esito atteso | Esito ottenuto |
|---|---|---|---|---|
| 1 | Analisi statica | `cd flutter_app && flutter analyze` | 0 problemi | **0 problemi** — `No issues found! (ran in 1.8s)` |
| 2 | Test mirati shell | `flutter test test/app_shell_test.dart` | 6 verdi | **6 verdi** — `All tests passed!` |
| 3 | Suite completa | `flutter test` | verdi (atteso 792 dal task) | **805 verdi**, `All tests passed!` — discrepanza di conteggio, vedi Problemi |
| 4a | Rail desktop usa `_vociLaterali` | `app_shell.dart` righe 110–171, 254–261 | sì, 10 pagine | **sì**: `_vociLaterali` con Dashboard, Clienti, Catalogo, Preventivi, Visite, Calendario, Task, Chat, Bandi, Notifiche; `_Rail(voci: _vociLaterali)` |
| 4b | Nessun `Icons.more_horiz` nella rail | grep `more_horiz` | assente dalla rail | **assente**: le 2 occorrenze residue sono in `_vociTelefono` (barra inferiore telefono), la rail non ne usa |
| 4c | Rotella `rail-impostazioni` in fondo → `/impostazioni` | `app_shell.dart` righe 326–340 | presente e navigante | **presente**: `IconButton(key: Key('rail-impostazioni'), onPressed: onImpostazioni)`; `onImpostazioni: () => context.go('/impostazioni')` (riga 260); icona piena se rotta `/impostazioni*` |
| 4d | Telefono: `NavigationBar` a 5 voci + drawer “Altro” | `app_shell.dart` righe 266–285, 244–249 | 5 voci + drawer | **sì**: Dashboard, Clienti, Preventivi, Bandi, Altro; il tap su “Altro” apre `_DrawerAltro` con 7 voci (Catalogo, Calendario, Visite, Task, Chat, Notifiche, Impostazioni) |
| 5a | Nessuna voce “Altro” nella rail | test widget + grep | 0 | **0** nella rail; “Altro” esiste solo come destinazione della `NavigationBar` telefono e come titolo del drawer |
| 5b | Impostazioni fuori dalle 10 destinazioni | test widget (riga 154–160) | assente | **assente** dalla rail: `find.descendant(NavigationRail, text('Impostazioni'))` → `findsNothing`; rotella separata come `trailing` |
| 6 | Rotte delle 10 voci | `lib/routing/app_router.dart` | tutte raggiungibili | **tutte presenti**: `/catalogo`, `/visite`, `/calendario`, `/task`, `/chat`, `/bandi`, `/notifiche`, `/impostazioni` (+ `/`, `/clienti`, `/preventivi`) |
| 7 | Regressioni | test shell desktop/telefono | nessuna | nessuna: selezione corretta per `/calendario` (indice 5), `/bandi` (indice 3), `/visite` e `/chat` sotto “Altro”, `/impostazioni/agenda` → rotella selezionata e `selectedIndex` null |
| 8 | Segnaposto / dati di test / segreti | grep `TODO`/`FIXME`/`Schermata in preparazione`; grep chiavi/token | nessuno | **nessuno** nella shell; nessun segreto o dato di test nel file |
| 9 | Indice memoria | `node scripts/controlla-indice.mjs` | OK | **INDICE OK** — 19 nodi, 9 file chiave |

### Problemi

- **Conteggio test diverso dall'atteso (non bloccante)**: il task indicava **792** verdi, la suite reale dà **805 verdi** con `All tests passed!`. Nessun test rosso o saltato; l'aumento è coerente con i test aggiunti nel frattempo sulle altre fette (il report precedente ne registrava 790). Il criterio sostanziale (suite interamente verde, nessuna regressione) è soddisfatto, ma il numero va riallineato nella DoD/task board.
- **Nodo di memoria non aggiornato (non bloccante)**: `docs/progetto/memoria/flutter/index.md` ha `Ultima revisione: 2026-10-24` ma non descrive la nuova struttura del menu (10 voci nella rail, Impostazioni come rotella in fondo, drawer “Altro” su telefono). Va integrato dallo sviluppatore dell'area; il controllo dell'indice non lo rileva perché il file esiste.
- Nessun problema funzionale rilevato: nessuna doppia voce “Altro”, nessuna duplicazione di Impostazioni, selezione corretta in tutti i percorsi provati.

### Residuo generale (non di questa modifica)

- Prova E2E nel browser su staging richiesta da `docs/progetto/definition-of-done.md` (login reale, azienda attiva, CRUD cliente e preventivo, nessun permission-denied): **non eseguita**. Resta un residuo generale dell'intero progetto e non è imputabile alla modifica del menu; il giudizio qui sotto riguarda solo la verifica statica/widget della modifica UI.

**Verdetto tester: SUPERATO per la modifica del menu laterale** (analisi 0, 6/6 test mirati verdi, suite completa verde, rail a 10 voci senza “Altro” e senza Impostazioni, rotella `rail-impostazioni` funzionante, barra telefono a 5 voci con drawer “Altro”). L'E2E browser su staging resta un residuo generale del progetto, dichiarato sopra.

**Validazione (24/10/2026): APPROVATO TECNICO per staging** — modifica del menu laterale verificata (rail desktop a 10 voci senza "Altro" né Impostazioni, rotella `rail-impostazioni` in fondo, barra telefono a 5 voci con drawer "Altro", selezione corretta delle rotte). Non rilasciabile in produzione: resta il residuo generale E2E browser (O12).


## Pulizia dati di test (24/10/2026)

- Trovati e rimossi due utenti E2E rimasti in Closer: `Agenda A` e `Agenda B` (`@commerciali.test`), con membership, dati personali e account Auth.
- Verificato che in `Closer` resti solo l’utente reale e che non ci siano altre aziende/utenti con marcatori `e2e`/`test`.
- Aggiunto `scripts/pulisci-dati-test.py`; eseguito: “Nessun utente di test trovato”.
- `flutter analyze` 0; `flutter test` 806 verdi; app ripubblicata.
