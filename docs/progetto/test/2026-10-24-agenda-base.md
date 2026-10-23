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
| Deploy hosting | `commerciali-app.web.app` e `commerciali-flutter.web.app` |

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
