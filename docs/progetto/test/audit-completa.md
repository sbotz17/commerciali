# Audit completo dell'applicazione — piano di verifica

**Data**: 24/10/2026
**Stato**: in corso — due audit bloccanti aperti
**Regola**: nessuna nuova funzione e nessun rilascio finché un'area non ha report tester + validatore.
**Responsabilità**: la squadra esegue i test; Andrea riceve solo la validazione finale.

## Perché questo audit

I bug su API key WhatsApp, stato “non connesso”, salvataggio preferenze e accesso non sono stati
intercettati perché la squadra ha verificato i pezzi separati (unit test, endpoint, curl) e ha rinviato
l'E2E della UI. Un test unitario con una risposta inventata non dimostra che la schermata funzioni.

Da qui in avanti, per ogni funzione valgono tutte queste prove:

1. test unit/widget automatico;
2. test del contratto con la risposta reale del servizio;
3. prova E2E nella UI pubblicata, con login reale e screenshot/log;
4. verifica di persistenza dopo reload;
5. nessun `permission-denied`;
6. report in `docs/progetto/test/` e validazione.

Se manca una prova, l'area è **BLOCCATA**, non “SUPERATA con residuo”.

## Aree e funzioni da verificare

| ID | Area | Funzioni da provare | Priorità |
|---|---|---|---|
| AU01 | Auth e onboarding | login email, reset password, login Google, sessione, utente disattivato, onboarding, creazione azienda, primo admin, ruoli | P0 |
| AU02 | Dashboard | conteggi, valore aperto, ultimi preventivi, azioni rapide, dati per azienda | P1 |
| AU03 | Clienti | CRUD, ricerca, duplicati, VIES, isolamento azienda, persistenza | P1 |
| AU04 | Catalogo | prodotti, categorie, immagini, codici, panieri, filtri | P1 |
| AU05 | Preventivi | creazione, modifica, eliminazione, righe, sconti, IVA, totali, numero `PRV-`, revisioni, PDF | P0 |
| AU06 | Visite | CRUD, riordino, stati, calendario, filtri, cliente, promemoria | P1 |
| AU07 | Calendario e appuntamenti | giorno/settimana/mese, creazione, ricorrenza, tutto il giorno, privato, partecipanti, call, Maps, allegati | P0 |
| AU08 | Task | CRUD, scadenze, priorità, operatore, completamento, filtri | P1 |
| AU09 | Notifiche | centro, badge, lette/non lette, preferenze, push web, WhatsApp personale, silenzio, anteprima | P0 |
| AU10 | Chat | dirette, gruppi, messaggi, immagini, letture, badge, notifiche, isolamento | P1 |
| AU11 | Bandi | lista pubblica, ricerca, filtri, dettaglio, import superadmin | P2 |
| AU12 | Impostazioni | profilo, azienda, utenti, ruoli, licenze, superadmin, integrazioni, agenda, condivisione calendario | P0 |
| AU13 | Integrazioni | server WhatsApp, SMTP, push VAPID/FCM, Google/Microsoft, R2, errori e retry | P1 |
| AU14 | Trasversale | permessi, multi-azienda, errori rete, mobile/desktop, reload, cache, nessun segnaposto | P0 |
| AU15 | Produzione | progetto separato, Auth, DB, regole, hosting, dati vuoti, accesso admin | P0 |

## Audit bloccanti (prima di nuovi sviluppi)

1. `audit-google-produzione.md` — **BLOCCATO**: manca client OAuth produzione.
2. `audit-push-dispositivo.md` — **BLOCCATO**: manca prova di consegna con permesso reale.

Nessuna nuova funzione può partire finché questi due audit non sono chiusi con prova UI.

## Ordine di esecuzione

1. **Blocco accesso**: AU01, AU12, AU15.
2. **Dati economici**: AU03, AU05, AU04.
3. **Agenda e comunicazioni**: AU07, AU08, AU09, AU10.
4. **Resto**: AU02, AU06, AU11, AU13, AU14.

## Criteri di chiusura di un'area

- report con passi, dati usati, esito atteso/ottenuto e prova (screenshot o log);
- test automatici verdi e test che fallisce senza la correzione;
- E2E reale su staging o produzione, con utente di test creato e poi rimosso;
- nessun dato di test residuo;
- tester: `SUPERATO`; validatore: `APPROVATO`;
- aggiornamento di `task.md`, diario e memoria.

## Bug già noti da chiudere durante l'audit

- stato WhatsApp “non connesso” — corretto, normalizzazione `connesso`/`numero`;
- API key WhatsApp non caricata — corretto, lettura `apiKey` e fallback Worker;
- salvataggio preferenze WhatsApp poco visibile — aggiunto pulsante nella card;
- push non attivabile su alcuni browser/PWA — messaggio esplicito, prova reale da fare;
- Google login in produzione — provider OAuth non configurato, da completare;
- onboarding/creazione azienda — da verificare con un utente senza azienda.

## Regola per la squadra

Nessun task è `FATTO` perché “i test unitari passano”. Un'area è chiusa solo quando la funzione è stata
provata **come la usa Andrea**, nella UI pubblicata, con dati reali di test.
