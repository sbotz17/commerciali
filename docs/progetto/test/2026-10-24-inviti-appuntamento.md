# Report — Nuovo cliente e inviti appuntamento

**Data**: 24/10/2026
**Perimetro**: form appuntamento, condivisione con persone/gruppi chat, notifica di invito, conferma
disponibilità, apertura dell'appuntamento dalla notifica.

## Verifiche automatiche

| Verifica | Esito |
|---|---|
| `flutter analyze` | 0 problemi |
| `flutter test` | 822 test verdi |
| `scripts/e2e-agenda.py` su staging | PASS: l'invitato B legge e aggiorna `conferme`/`stato_condivisione`; A vede la conferma; notifiche private rispettate |
| `scripts/controlla-indice.mjs` | INDICE OK |

## Copertura dei test aggiunti

- `test/appuntamento_condivisione_test.dart`: parsing dei campi, stato `in_attesa`/`confermato`/`rifiutato`,
  risposte singole, filtri dei gruppi chat.
- `test/appuntamento_form_test.dart`: pulsante nuovo cliente e apertura del dialogo di condivisione.
- `test/calendario_test.dart`: badge e colore della condivisione.
- `test/notifiche_screen_test.dart`: rotta verso `/calendario?appuntamento=…`.

## Prova manuale da fare su staging

1. Creare un appuntamento con un cliente nuovo dal **+** accanto al cliente.
2. Invitare una persona e un gruppo della chat.
3. Accedere con l'account invitato: verificare la notifica, aprirla e confermare.
4. Controllare che l'appuntamento passi da **In attesa di conferma** a **Confermato**.
5. Ripetere con **Non disponibile** e con un secondo invitato.

## Residui

- La notifica push non è inclusa: l'invito arriva nel centro notifiche In-App.
- L'aggiornamento del calendario dell'organizzatore non è realtime: si aggiorna alla riapertura o alla
  ricarica della schermata.
