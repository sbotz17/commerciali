# Promemoria automatico al cliente — WhatsApp ed email

**Data**: 25/10/2026
**Ambiente**: staging `https://commerciali-app.web.app` (progetto `commerciali-app`)
**Stato**: funzione attiva su staging; email da attivare con API key Resend.

## Criteri verificati

1. Alla creazione l'avviso parte se c'è almeno un recapito e il canale è attivo.
2. Alla modifica parte solo se cambiano data o ora; lo stesso orario non viene inviato due volte.
3. Con telefono ed email il cliente riceve entrambi; senza un recapito quel canale non parte.
4. Il testo è composto dal Worker con data, ora e luogo; il titolo non esce per gli appuntamenti privati.
5. Un errore non blocca il salvataggio; l'esito è visibile nel dettaglio e dopo il salvataggio.
6. Nessun invio verso aziende/clienti diversi: il Worker verifica membership e legge il documento.
7. Email configurabile dal super admin; senza configurazione risulta "non configurata".

## Prove automatiche

| Prova | Esito |
|---|---|
| `node --test worker/test/promemoria.test.mjs worker/test/whatsapp.test.mjs` | 13 test verdi (testo, data, numeri, email, canali e contratto WhatsApp VOLTY/legacy) |
| `flutter test` | 900 test verdi |
| `flutter analyze` | 0 problemi |
| E2E locale Worker + WhatsApp finto | primo invio `inviato`; seconda chiamata `gia_inviato`; cambio data invia il testo "nuova data"; log Firestore corretto |
| E2E locale Worker + email finta | `/email/config`, `/email/test` e invio con mittente/nome corretti |
| E2E locale sicurezza | utente estraneo: 403; `/email/config` non super admin: 403 |
| UI staging reale | form con Avviso al cliente, WhatsApp disabilitato senza telefono, invio al cambio data, avviso "Promemoria cliente: Non inviato: Email non configurata", log nel dettaglio |
| Server WhatsApp reale | stato `connected: true`, numero `393516722792`; invio di prova riuscito con `messageId` |
| Regole `utenti` | auto-assegnazione `super_admin`/`ruolo`/`attivo` bloccata con 403; modifica `nome` consentita |
| Data picker | mese e giorni in italiano ("ottobre 2026", "lunedì") |
| Ripetizione | giorno di inizio protetto, sostituzione al cambio data, anteprima date |

Screenshot: `2026-10-25-promemoria-cliente-form.png`, `2026-10-25-promemoria-cliente-esito.png`, `2026-10-25-form-luogo-note-ordine.png`, `2026-10-25-date-picker-italiano.png`.
I dati di prova (utenti, aziende, clienti, appuntamenti) sono stati eliminati; backup staging di
`appuntamenti` e `clienti` eseguito prima delle prove.

## Residui noti

- L'email non è configurata in staging: serve una API key Resend e un mittente con dominio verificato.
- Il promemoria **programmato** (giorno prima) per il cliente non è ancora implementato: questa funzione invia
  subito al salvataggio/modifica.
- Lo SMTP per singola azienda resta da fare; l'MVP usa un mittente unico di piattaforma.
