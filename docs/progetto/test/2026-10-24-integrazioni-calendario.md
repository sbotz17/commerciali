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
