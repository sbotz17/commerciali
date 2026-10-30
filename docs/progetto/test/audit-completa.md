# Audit completo dell'applicazione — piano di verifica

**Data**: 24/10/2026 — **riaperto il 29/10/2026**
**Stato**: AU03 è `PROVATA` (29/10). Le altre aree restano `DA RIFARE`, tranne AU10 e AU15 `BLOCCATA`. R-2, R-3 e R-4 sono chiusi come ritorni, ma non bastano a chiudere le aree.
**Standard**: `skills/squadra-audit` — criterio scritto prima, prova UI reale, persistenza, caso negativo,
risposta reale del servizio, test che fallisce se la funzione si rompe (esecuzione rossa), evidenza con
build/commit, tester e validatore in sessioni distinte.
**Gate**: obbligatorio prima di **ogni pubblicazione su staging e produzione**.
**Regola**: nessuna nuova funzione e nessun rilascio finché un'area non ha report tester + validatore.
**Responsabilità**: la squadra esegue i test; Andrea riceve solo la validazione finale.

## Gate di pubblicazione

Staging è un ambiente di rilascio, non una sandbox: è ciò che Andrea apre per vedere il prodotto.
Le prove si fanno su build locale o canale di anteprima; su staging si pubblica solo a gate chiuso.

Nessun deploy hosting su staging o produzione è consentito senza:

1. audit-completa eseguito e report aggiornato;
2. **nessuna area diversa da `PROVATA`**: `BLOCCATA`, `DA RIFARE` e `FALLITA` bloccano;
3. tester `SUPERATO`;
4. validatore `APPROVATO`;
5. per la produzione: guardiano `GO`, backup verificato e rollback pronto.

Se un'area non è provata, il deploy è **BLOCCATO**. Non esiste “pubblico con residuo”.

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

## Revisione del 29/10/2026 — audit riaperti

Andrea ha stabilito che **se trova un guasto, il test era sbagliato** e che tutti gli audit vanno rivisti.
Nessuna area è più `PROVATA`; le prove precedenti restano come storia, non come chiusura.

| Area | Stato | Perché |
|---|---|---|
| AU01 | DA RIFARE | Google, Face ID, reset e utente disattivato non provati; prove precedenti non ripetibili |
| AU02 | DA RIFARE | solo schermata e conteggi base; mancano dati pieni e casi negativi |
| AU03 | **PROVATA** | 29/10: CRUD, duplicati, VIES, isolamento RLS, persistenza e pulizia; report `2026-10-29-AU03-clienti.md`; tester SUPERATO, validatore APPROVATO |
| AU04 | DA RIFARE | immagine ed eliminazione non provate; paniere parziale |
| AU05 | DA RIFARE | modifica, eliminazione, revisioni e invio non provati |
| AU06 | DA RIFARE | modifica, eliminazione, riordino, stati e promemoria non provati |
| AU07 | DA RIFARE | ricorrenza, inviti, call, Maps, allegati, condivisione non provati |
| AU08 | DA RIFARE | modifica, eliminazione, completamento e filtri non provati |
| AU09 | DA RIFARE | salvataggio preferenze, push reale, WhatsApp personale e silenzio non provati |
| AU10 | BLOCCATA | serve un secondo utente in azienda |
| AU11 | DA RIFARE | dettaglio, link e import non provati |
| AU12 | DA RIFARE | utenti, ruoli, licenze, superadmin e integrazioni non provati |
| AU13 | DA RIFARE | nessun invio reale WhatsApp/email/push |
| AU14 | DA RIFARE | mobile/desktop, multi-azienda, errori di rete non provati |
| AU15 | BLOCCATA | progetto di produzione non ancora creato |

**Regola**: un'area passa a `PROVATA` solo quando **tutte** le sue funzioni hanno il report completo e
tester/validatore indipendenti. Fino ad allora il deploy è vietato.

**Gate tecnico**: prima di ogni deploy eseguire `python3 scripts/controlla-audit.py`. Oggi esce **1**:
nessuna area è `PROVATA`, quindi il deploy è bloccato. Il test del gate è in
`scripts/test_controlla_audit.py` (`python3 -m unittest`).

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

## Esecuzione a basso consumo

- L'audit è un indice: ogni ondata legge solo la sezione e i file dell'area.
- Un tester e un validatore per ondata, sessione riusata; niente agenti nuovi per ogni area.
- Test automatici una volta per blocco; poi test mirati.
- Output riassunto; log completi solo sui fallimenti.
- Screenshot solo per fallimenti o prova finale.
- Massimo 2 tentativi per area; poi `BLOCCATA` e si passa avanti.
- Modelli: Flash per test/UI/report; V4 Pro solo per bug complessi, dati, architettura e produzione.
- Controllo costi con `opencode stats --cost`.
