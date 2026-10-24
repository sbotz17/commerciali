# Report — Base agenda, task, notifiche e chat (24/10/2026)

**Stato: base implementata e pubblicata su staging. E2E regole Firestore PASS; E2E UI da rifare con browser visibile.**

## Cosa è stato fatto

### Dati e regole
- Nuove collezioni: `appuntamenti`, `task`, `promemoria`, `notifiche`, `dispositivi`,
  `impostazioni_notifiche`, `allegati`, `impostazioni_agenda`, `integrazioni`, `slot`,
  `prenotazioni`, `cache_eventi_esterni`, `chat_stanze` e sottocollezioni `messaggi`/`letture`.
- Security Rules aggiornate, **compilate e pubblicate** su staging.
- Indice composito per `chat_stanze` pubblicato.

### Modelli e servizi
- `Appuntamento`, `TaskItem`, `Promemoria`, `Notifica`, `StanzaChat`, `MessaggioChat`.
- CRUD appuntamenti e task, completamento task.
- Notifiche: lettura, stream realtime, segna letta/tutte lette, preferenze.
- Chat: stanze dirette e gruppi, messaggi, letture, invio testo.
- Funzioni pure testate per filtri, raggruppamenti e ordinamenti.

### Schermate
- Calendario giorno/settimana con filtri, creazione appuntamento, dettaglio, Maps, modifica/eliminazione.
- Form appuntamento con cliente, operatore, luogo, indirizzo, Maps, stato.
- Pagina Task con periodi, filtri, completamento/riapertura, modifica/eliminazione.
- Form Task con scadenza, operatore, priorità, cliente, note.
- Centro notifiche con badge, filtro lette/non lette, deep link.
- Preferenze notifiche: push, WhatsApp, chat, silenzio, anteprima, numero operatore.
- Chat: lista conversazioni, nuova chat diretta, nuovo gruppo, thread testo, letture.

## Verifiche

| Controllo | Esito |
|---|---|
| `flutter analyze` | 0 problemi |
| `flutter test` | ****740 test verdi**** |
| Regole Firestore | compilate e pubblicate |
| Indice chat | pubblicato |
| Deploy hosting | `commerciali-app.web.app` (ufficiale); `commerciali-flutter.web.app` reindirizza |

## Cosa manca

- Push FCM web/Android/iOS e registrazione dispositivi.
- Scheduler Cloudflare Worker per promemoria e notifiche.
- Invio WhatsApp operatore e notifiche chat.
- SMTP per azienda e invio email.
- Google Calendar/Meet e Microsoft 365/Teams.
- Upload immagini su R2.
- Prenotazione pubblica e slot.
- Impostazioni agenda complete.
- E2E finale con browser su staging.

## Prova E2E regole (riuscita)

`python3 scripts/e2e-agenda.py` → **PASS**: con due utenti reali della stessa azienda ha verificato
creazione/lettura/modifica appuntamento, task, chat, messaggio e notifica; ha verificato che un utente
non possa leggere la notifica privata di un altro né inviare un messaggio spacciandosi per un collega.
Cleanup completo eseguito.

## Nota sulla prova E2E UI

La finestra del browser automatizzato non è più visibile nell'ambiente di lavoro attuale:
le schermate vengono caricate ma non è possibile acquisire screenshot o interagire
in modo affidabile. La base è coperta dai test automatici e dall'E2E regole; la prova UI
va rifatta appena la finestra browser è disponibile.

## File principali

- `flutter_app/lib/features/calendario/`
- `flutter_app/lib/features/task/`
- `flutter_app/lib/features/notifiche/`
- `flutter_app/lib/features/chat/`
- `flutter_app/lib/features/impostazioni/notifiche_preferenze_screen.dart`
- `firestore.rules`, `firestore.indexes.json`


## Verifica tester

| Controllo | Comando | Esito |
|---|---|---|
| Analisi | `flutter analyze` | 0 problemi |
| Test | `flutter test` | 740 verdi |
| E2E regole | `python3 scripts/e2e-agenda.py` | PASS |
| Indice | `node scripts/controlla-indice.mjs` | INDICE OK |
| Regole | `firestore.rules` | compilate e pubblicate; `letture` chat inclusa |
| Indici | `firestore.indexes.json` | indice chat pubblicato |
| Rotte | `/calendario`, `/task`, `/chat`, `/notifiche`, `/impostazioni/notifiche` | reali, nessun segnaposto |
| Sicurezza script | client secret rimosso | nessun segreto hardcoded |

**Verdetto base tecnica: SUPERATO.** Restano fuori da questa base:
H08 allegati/R2, push FCM, scheduler, WhatsApp, SMTP, Google/Microsoft,
prenotazione pubblica, notifiche chat e prova E2E UI (browser non visibile).
La DoD completa richiede ancora la prova UI: il milestone non è dichiarato rilasciabile in produzione.


## Aggiornamenti successivi (24/10/2026)

- Aggiunte **notifiche chat in-app**: ogni messaggio crea una notifica per gli altri partecipanti.
- Aggiunta schermata **Calendario e agenda** nelle Impostazioni: fuso, anticipo, orario invio cliente, template, slot, limiti allegati, Maps.
- Test aggiornati: **740 test verdi**, analyze 0.
- Restano push FCM, scheduler, WhatsApp, SMTP, Google/Microsoft, R2, prenotazione pubblica ed E2E UI.

## Verifica tester finale (24/10/2026)

Milestone verificato: **Base agenda, task, notifiche e chat** (H01–H07, H09–H10, H19–H22).
Riferimenti letti: questo report, `docs/progetto/task.md` §F31, `docs/progetto/definition-of-done.md`,
`docs/progetto/indice.md`. Nessuna modifica al codice, nessun commit.

| # | Controllo | Comando / verifica | Esito atteso | Esito ottenuto |
|---|---|---|---|---|
| 1 | Analisi statica | `cd flutter_app && flutter analyze` | 0 problemi | `No issues found!` (0) |
| 2 | Test automatici | `cd flutter_app && flutter test` | 740 verdi | `+740: All tests passed!` |
| 3 | E2E regole Firestore | `python3 scripts/e2e-agenda.py` | PASS | `PASS: appuntamenti, task, chat e notifiche rispettano le regole` |
| 4 | Indice di memoria | `node scripts/controlla-indice.mjs` | INDICE OK | `Nodi di memoria: 19 / File chiave controllati: 9 / INDICE OK` |
| 5 | Regole H01 | `git diff staging -- firestore.rules` | nuove collezioni con isolamento azienda | `appuntamenti`, `task`, `promemoria`, `notifiche`, `dispositivi`, `impostazioni_notifiche`, `allegati`, `impostazioni_agenda`, `integrazioni`, `slot`, `prenotazioni`, `cache_eventi_esterni` con `memberOf(azienda_id)`; `integrazioni` e `cache_eventi_esterni` in sola lettura |
| 6 | Letture chat | `git diff staging -- firestore.rules` | `messaggi`/`letture` accessibili solo ai partecipanti | `chat_stanze` con `uid() in partecipanti_uids`; `messaggi` via `partecipanteStanza()` + `mittente_uid == uid()`; `letture` solo per se stessi (`utenteId == uid()`) |
| 7 | Indice chat | `git diff staging -- firestore.indexes.json` | indice composito per `chat_stanze` | `chat_stanze`: `azienda_id ASC` + `partecipanti_uids ARRAY CONTAINS` |
| 8 | Segreti negli script | `grep -rn "j9iVZfS8kkCEFUPaAeJV0sAi" scripts` | vuoto | vuoto. `client_secret` letto da `FIREBASE_CLI_CLIENT_SECRET`; le `API_KEY` Firebase nei file client sono identificatori pubblici, non segreti |
| 9 | Rotte reali | `lib/routing/app_router.dart` | rotte reali, nessun segnaposto | `/calendario`→`CalendarioScreen`, `/task`→`TaskScreen`, `/chat`→`ChatScreen`, `/notifiche`→`NotificheScreen`, `/impostazioni/notifiche`→`NotifichePreferenzeScreen`, `/impostazioni/agenda`→`ImpostazioniAgendaScreen` |
| 10 | Segnaposto | `grep -rn "in preparazione" flutter_app/lib` | solo error page | unica occorrenza in `core/ui/placeholder_screen.dart`, usata solo dal `_PaginaAutonoma` dell'`errorBuilder` ("Pagina non trovata"); nessuna rotta del perimetro è un segnaposto |
| 11 | Isolamento multi-azienda e permessi | `scripts/e2e-agenda.py` | nessuna lettura/scrittura cross-azienda | PASS: un utente non legge la notifica privata di un altro e non invia messaggi spacciandosi per un collega; cleanup completo |

### Residui dichiarati (fuori da questa base)

Restano **non implementati e quindi non verificabili**: H08 allegati/R2, H11 push FCM, H12 scheduler,
H13 WhatsApp, H14 SMTP, H15 Google, H16 Microsoft, H17 R2, H18 prenotazione pubblica.
H21 è `IN CORSO`: notifiche chat in-app fatte, push FCM mancante. H23 (E2E agenda/notifiche/chat) è `DA FARE`.

### Verdetto

**SUPERATO** — base tecnica del milestone (H01–H07, H09–H10, H19–H22): analisi 0, 740 test verdi,
E2E regole PASS, indice OK, regole e indice chat presenti, nessun segreto, rotte reali, nessun segnaposto.

**Non rilasciabile in produzione.** Restano aperti, e vanno chiusi prima del rilascio:
1. **E2E UI browser su staging** (login reale, azienda attiva, CRUD cliente e preventivo, navigazione delle
   sei rotte del perimetro, nessun permission-denied): non eseguibile in questa sessione perché la finestra
   del browser automatizzato non è visibile/interagibile. La DoD la richiede esplicitamente.
2. **Integrazioni esterne** (push FCM, scheduler, WhatsApp, SMTP, Google/Microsoft, R2, prenotazione pubblica):
   non sviluppate, quindi non testabili.
3. H21 e H23 non sono `FATTO`: il task board non può essere dichiarato completo.

Il milestone resta in attesa della prova E2E UI e della validazione del validatore prima di qualsiasi rilascio.

**Validazione (24/10/2026): APPROVATO per staging, non per produzione** — base tecnica H01–H07, H09–H10, H19–H22 verificata (regole, indice chat, rotte, E2E regole, nessun segreto). Restano aperti prima di qualsiasi rilascio: E2E UI su staging, H08 allegati/R2, H11–H18 integrazioni, push FCM (H21) e H23. Non rilasciabile in produzione.
