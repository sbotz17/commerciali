# Report — Base agenda, task, notifiche e chat (24/10/2026)

**Stato: base implementata e pubblicata su staging. E2E finale ancora da eseguire.**

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
| `flutter test` | **720 test verdi** |
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

## Nota sulla prova E2E

La finestra del browser automatizzato non è più visibile nell'ambiente di lavoro attuale:
le schermate vengono caricate ma non è possibile acquisire screenshot o interagire
in modo affidabile. La base è coperta dai test automatici; la prova E2E va rifatta
appena la finestra browser è disponibile.

## File principali

- `flutter_app/lib/features/calendario/`
- `flutter_app/lib/features/task/`
- `flutter_app/lib/features/notifiche/`
- `flutter_app/lib/features/chat/`
- `flutter_app/lib/features/impostazioni/notifiche_preferenze_screen.dart`
- `firestore.rules`, `firestore.indexes.json`
