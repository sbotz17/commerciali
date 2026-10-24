# Report — Nuovo cliente e inviti appuntamento

**Data**: 24/10/2026
**Perimetro**: form appuntamento, condivisione con persone/gruppi chat, notifica di invito, conferma
disponibilità, apertura dell'appuntamento dalla notifica.

## Verifiche automatiche

| Verifica | Esito |
|---|---|
| `flutter analyze` | 0 problemi |
| `flutter test` | 857 test verdi |
| `scripts/e2e-agenda.py` su staging | PASS: invito e conferma tra due utenti, notifiche private e rubrica `contatti_notifiche` |
| `scripts/e2e-whatsapp-worker.py` | PASS: config, allegati upload/link/download/delete e promemoria registra/annulla |
| `scripts/controlla-indice.mjs` | INDICE OK |

## Copertura dei test aggiunti

- `test/appuntamento_condivisione_test.dart`: parsing dei campi, stato `in_attesa`/`confermato`/`rifiutato`,
  risposte singole, filtri dei gruppi chat.
- `test/appuntamento_form_test.dart`: pulsante nuovo cliente e apertura del dialogo di condivisione.
- `test/calendario_test.dart`: badge e colore della condivisione.
- `test/notifiche_screen_test.dart`: rotta verso `/calendario?appuntamento=…`.
- `test/whatsapp_server_screen_test.dart`: schermata riservata al super admin.
- `test/whatsapp_service_test.dart`: normalizzazione numero e URL del Worker.
- `test/appuntamento_ricorrenza_test.dart`: inizio/fine, tutto il giorno, occorrenze (giorno/settimana/bisettimana/mese/anno/personalizzata), mascheramento privacy e redazione dei dati.

## Verifica funzionale per Andrea (dopo i test della squadra)

Questa non è una richiesta di eseguire test tecnici: analyze, test e regole sono già stati eseguiti dalla
squadra. Serve solo la conferma dell'esperienza:

1. Creare un appuntamento con un cliente nuovo dal **+** accanto al cliente.
2. Invitare una persona e un gruppo della chat.
3. Accedere con l'account invitato: verificare la notifica, aprirla e confermare.
4. Controllare che l'appuntamento passi da **In attesa di conferma** a **Confermato**.
5. Ripetere con **Non disponibile** e con un secondo invitato.

## Residui

- La notifica push non è inclusa: l'invito arriva nel centro notifiche In-App.
- WhatsApp è implementato; serve configurarlo e avere numeri/consensi per inviti e promemoria.
- I promemoria sono inviati via WhatsApp dal Cron del Worker; il push/In-App programmato richiede Blaze.
- L'aggiornamento del calendario dell'organizzatore non è realtime: si aggiorna alla riapertura o alla
  ricarica della schermata.
