# Registro dei task

**Regola**: un task = un solo obiettivo verificabile (1 file, 1 schermata o 1 servizio).
Il coordinatore assegna un task alla volta. Stati: `DA FARE`, `IN CORSO`, `FATTO`, `BLOCCATO`.

## Migrazione Flutter

| ID | Area | Task | Criteri di accettazione | Agente | Stato |
|---|---|---|---|---|---|
| F01 | Fondamenta | Creare `flutter_app/` (web, Android, iOS) con dipendenze Firebase | `flutter create` ok, `pub get` ok, `flutter analyze` 0 errori | sviluppatore-backend | FATTO |
| F02 | Fondamenta | Configurare Firebase (`firebase_options.dart`, init in `main.dart`) | app web si avvia senza errori Firebase; `flutter analyze` 0 | sviluppatore-backend | FATTO |
| F03 | Fondamenta | Tema Material 3, router `go_router`, shell responsive vuota | rotte principali definite; shell telefono/desktop; analyze 0 | sviluppatore-frontend | FATTO |
| F04a | Auth | `AuthService` email/password, modello profilo e provider | login email validato con unit/widget test; profilo letto; analyze 0 | sviluppatore-backend | FATTO |
| F04b | Dati | `SpService` base: profilo, aziende, membri, azienda attiva | elenco aziende dell'utente; membership letta; analyze 0 | sviluppatore-backend | FATTO |
| F05 | Auth | Schermata login email/password | schermata validata con widget test; errore leggibile; login reale in F06 | sviluppatore-frontend | FATTO |
| F06a | Auth | Login Google web | pulsante Google, popup, errori in italiano, test | sviluppatore-backend | FATTO |
| F06b | Auth | Login Google mobile | `google_sign_in` 7 con `serverClientId`; credential Firebase; analyze 0 | sviluppatore-backend | FATTO |
| F06c | Auth | Prova reale login email su staging | login con utente di test; profilo letto; nessun errore | tester | FATTO |
| F07a | Auth | Schermata recupero password (invio link + nuova password) | reset link apre schermata; `oobCode` gestito; analyze 0 | sviluppatore-frontend | FATTO |
| F07b | Auth | Onboarding azienda | crea profilo, azienda, membro e seed; analyze 0 | sviluppatore-frontend | FATTO |
| F07c | Auth | Redirect di autenticazione | non loggato → login; senza azienda → onboarding; altrimenti shell | sviluppatore-frontend | FATTO |
| F08 | Dashboard | Conteggi, valore aperto, ultimi 5, azioni rapide | numeri uguali alla vecchia app per lo stesso utente | sviluppatore-frontend | FATTO |
| F09a | Clienti | Modello `Cliente` + CRUD `SpService` + duplicati | CRUD completo; isolamento per azienda; test | sviluppatore-backend | FATTO |
| F09b | Clienti | Schermata lista + form cliente | lista, ricerca, creazione/modifica/eliminazione | sviluppatore-frontend | FATTO |
| F09c | Clienti | Verifica P.IVA VIES | Ferrari valida, P.IVA falsa non valida | sviluppatore-backend | FATTO |
| F11a | Catalogo | Modelli `Prodotto`/`Categoria` + CRUD `SpService` | CRUD; isolamento azienda; test | sviluppatore-backend | FATTO |
| F11b | Catalogo | Schermata catalogo e categorie | lista, filtro, form, immagini URL | sviluppatore-frontend | FATTO |
| F12a | Preventivi | Lista, ricerca, stati | lista responsive; filtri; badge; analyze 0 | sviluppatore-frontend | FATTO |
| F12b-1 | Preventivi | Editor: cliente, righe, totali | UI completa; totali corretti; analyze 0 | sviluppatore-frontend | FATTO |
| F12b-2a | Preventivi | Salvataggio nuovo preventivo e modifica (`payloadPreventivoDaEditor`, pulsante Salva, `SpService`) | crea/aggiorna il documento; `sconto` incluso nella patch; errori in italiano; analyze 0 e test verdi | sviluppatore-frontend | FATTO |
| F12b-2 | Preventivi | Salvataggio, modifica e revisione | crea/modifica/revisione; numero transazionale | sviluppatore-frontend | FATTO |
| F13 | Preventivi | Contatore transazionale e revisioni | serie continua; nessun numero duplicato; `-R1` senza consumare | sviluppatore-backend | FATTO |
| F14 | Preventivi | PDF con `pdf`/`printing` | stesso contenuto e totali; stampa/condivisione | sviluppatore-frontend | FATTO |
| F15a | Visite | Modello `Visita` + query/CRUD `SpService` (`giro_visite`) | CRUD; isolamento azienda; ordinamento `ordine`/`ora`; riordino batch; test | sviluppatore-backend | FATTO |
| F15b | Visite | Schermata visite e form | lista per data, CRUD, riordino, stati | sviluppatore-frontend | FATTO |
| F16a | Bandi | Modelli `Bando`/`FonteBando` + `getBandi`/`getFontiBandi` in `SpService` | lettura pubblica `bandi_incentivi`/`bandi_fonti`; escluso `scaduto`; ordinamento `data_chiusura` (null in fondo); `fromMap`/`toMap`; test | sviluppatore-backend | FATTO |
| F16 | Bandi | Lista pubblica, filtri e dettaglio | dati reali da `bandi_incentivi`; ricerca, filtri stato/regione, dettaglio, link ufficiale; test | sviluppatore-frontend | FATTO |
| F16c | Bandi | Import manuale dei bandi | import JSON da file o URL, riservato al superadmin, con statistiche; test | sviluppatore-frontend | FATTO |
| F17a | Impostazioni | Profilo, azienda, accessi e logout | schermata responsive; test | sviluppatore-frontend | FATTO |
| F17b | Impostazioni | Utenti e ruoli | elenco membri, cambio ruolo, rimozione; ruoli in sola lettura; test | sviluppatore-frontend | FATTO |
| F17c | Impostazioni | Licenze | piano, stato, date e limiti dell'azienda attiva; test | sviluppatore-frontend | FATTO |
| F18 | Super admin | Pannello aziende | elenco aziende, ricerca e ingresso in un'azienda; accesso negato ai non super admin; test | sviluppatore-frontend | FATTO |
| F18b | Super admin | Modifica licenze e piani | form di modifica licenza dal pannello | sviluppatore-backend | DA FARE |
| F19 | Qualità | Parità multi-piattaforma e test | report E2E `docs/progetto/test/2026-10-22-e2e.md`, 383 test verdi, analyze 0 | tester | FATTO |
| F20 | Onboarding | Pagina introduttiva al primo accesso con istruzioni installazione | mostra una volta; “Ho capito” salva il flag; riapertura da Impostazioni; test | sviluppatore-frontend | FATTO |
| F21 | Onboarding | Intro interattiva: scelta dispositivo e demo animata | selettore funzionante; mockup animati offline; test | sviluppatore-frontend | FATTO |
| F22 | Prestazioni | Intro subito dopo il login, senza attendere profilo/aziende | `FirstRunGate` avvolge il contenuto appena c'è l'utente; aziende lette in parallelo; profilo per `uid` con fallback email; test | sviluppatore-frontend | FATTO |
| F23 | Brand | Rinomina dell'app in Closer e nuova icona | web/Android/iOS, UI, manifest e launcher icons; test | sviluppatore-frontend | FATTO |
| F24 | Dati | Azienda attiva dopo il login e scritture sicure | sync provider osservato da `AuthGate`; guardia senza azienda; contatore preventivi creato prima della transazione; test | sviluppatore-backend | FATTO |
| F25 | Bandi | Schermata Bandi | lista responsive, ricerca, filtri, dettaglio, link; test | sviluppatore-frontend | FATTO |
| F26a | Amministrazione | Modelli `Ruolo`/`Licenza` + query utenti/ruoli/licenze in `SpService` | `fromMap` con permessi e date; `getUtenti`/`aggiornaRuoloUtente`/`eliminaMembro`/`getRuoli`/`getLicenzaAzienda`/`getTutteAziende`; analyze 0; test verdi | sviluppatore-backend | FATTO |
| F26b | Amministrazione | Schermate Utenti e Ruoli | elenco, cambio ruolo, rimozione, riepilogo permessi; test | sviluppatore-frontend | FATTO |
| F27a | Amministrazione | Schermata Licenze | piano, stato effettivo, date, limiti, note; test | sviluppatore-frontend | FATTO |
| F27b | Amministrazione | Schermata Super admin | elenco aziende, ricerca, ingresso; accesso riservato; test | sviluppatore-frontend | FATTO |
| F28 | Qualità | E2E staging ripetibile | `scripts/e2e-staging.py` (CRUD con regole reali) e `scripts/e2e-ui-dati.py` (dati per la prova UI); prova reale login→cliente→preventivo | tester | FATTO |


## Panieri di prodotti (F29)

| ID | Area | Task | Criteri di accettazione | Agente | Stato |
|---|---|---|---|---|---|
| P01 | Dati | Modello `Prodotto` con `figli_ids` e `figli_a_zero` | campi con default, `fromMap`/`toMap`, compatibilità documenti vecchi; test | sviluppatore-backend | FATTO |
| P02 | Dati | Payload prodotti e sanitizzazione figli | `figli_ids` senza self/duplicati/vuoti; aggiornamento parziale non cancella i figli; test | sviluppatore-backend | FATTO |
| P03 | Dati | Riga preventivo con paniere | `paniereId`/`paniereNome` in `fromMap`/`toMap` e `copyWith`; test | sviluppatore-backend | FATTO |
| P04 | Dati | Funzione pura `inserisciPaniere` | padre+figli, quantità, zero, adozione, altri panieri, self/mancanti; 8 test | sviluppatore-backend | FATTO |
| P05 | Catalogo | Form prodotto con sezione Paniere | selezione multipla, flag zero, ricerca figli, salvataggio `figli_ids`; test | sviluppatore-frontend | FATTO |
| P06 | Catalogo | Badge e colonna Paniere | etichette “Paniere: N sotto-prodotti” e “N figli”; test | sviluppatore-frontend | FATTO |
| P07 | Preventivo | Scelta prodotto dal catalogo e inserimento paniere | ricerca prodotto, padre+figli, avviso figli mancanti; test | sviluppatore-frontend | FATTO |
| P08 | Preventivo | Etichetta e rientro righe figlie | “Paniere: <padre>” in card e tabella; test | sviluppatore-frontend | FATTO |
| P09 | PDF | Etichetta paniere nel PDF | testo sotto la descrizione, prezzi/totali invariati; test | sviluppatore-frontend | FATTO |
| P10 | Qualità | E2E staging panieri | padre+2 figli, prezzo/zero, quantità, reinserimento, Firestore; report | tester | FATTO |


## Amministrazione, ruoli e bandi (F30)

| ID | Area | Task | Criteri di accettazione | Agente | Stato |
|---|---|---|---|---|---|
| A01 | Dati | Rinominare l'azienda di appoggio VOLTY in Closer | dato Firestore aggiornato, nessun dato cancellato; test aggiornati | dba | FATTO |
| A02 | Auth | Creare account e profilo con sessione secondaria | utente creato, profilo scritto prima del logout, app secondaria eliminata sempre; test | sviluppatore-backend | FATTO |
| A03 | Dati | Servizio ruoli e rinomina azienda | `inserisciRuolo`/`aggiornaRuolo`/`eliminaRuolo`, `rinominaAzienda`, `getUtentePerEmail`; test chiave | sviluppatore-backend | FATTO |
| A04 | UI | Ruoli modificabili | nuovo/modifica/elimina con permessi per area, ruoli di sistema non eliminabili; test | sviluppatore-frontend | FATTO |
| A05 | UI | Nuovo utente con ruolo | form nome/email/ruolo/invito o password, profilo+membership, test | sviluppatore-frontend | FATTO |
| A06 | UI | Nuova azienda con primo admin | azienda+membership superadmin+seed+account admin+membership, test | sviluppatore-frontend | FATTO |
| B01 | UI | Filtro ATECO nei bandi | prefisso 2 cifre, `tutti_ateco`, test | sviluppatore-frontend | FATTO |
| B02 | UI | Bandi nel menu principale | Dashboard/Clienti/Preventivi/Bandi/Altro, Visite in Altro; test | sviluppatore-frontend | FATTO |
| B03 | Dati | Parser import bandi | JSON/Solr, normalizzazione, stato, ATECO, id stabile; test | sviluppatore-backend | FATTO |
| B04 | UI | Import bandi da file/URL | solo superadmin, file JSON, URL, progresso e statistiche; test | sviluppatore-frontend | FATTO |
| B05 | Qualità | E2E amministrazione e bandi | ruolo, utente, azienda, import URL, filtro ATECO; report | tester | FATTO |
| C01 | Bandi | ATECO con punto | campo mobile con tastiera decimale, formatter `[0-9.]`, match sulle cifre (`62.01`); test | sviluppatore-frontend | FATTO |
| C02 | Bandi | Filtro provincia | tendina province, match su `province` o fallback regione; nota esplicativa; test | sviluppatore-frontend | FATTO |
| D01 | Preventivi | Scelta catalogo sulla singola riga | icona "Scegli dal catalogo" su card e tabella; riempie descrizione/prezzo; paniere inserisce i figli; test | sviluppatore-frontend | FATTO |
| E01 | Catalogo | Codice prodotto nei dati | `Prodotto.codice`, payload, codice riportato nella riga preventivo; test | sviluppatore-backend | FATTO |
| E02 | Catalogo | Codice prodotto in UI | campo nel form, colonna tabella, sottotitolo e selettore preventivo; test | sviluppatore-frontend | FATTO |
| F01 | Visite | Nuovo cliente dal giro visite | pulsante nel form visita, ritorno al form con cliente selezionato; test | sviluppatore-frontend | FATTO |
| G01 | Preventivi | Nuovo cliente dal preventivo | pulsante nella card cliente, creazione, ricarica e selezione automatica; test | sviluppatore-frontend | FATTO |
| G02 | Preventivi | Nuovo prodotto dal catalogo del preventivo | pulsante nel selettore, form prodotto, ritorno e inserimento nella riga; test | sviluppatore-frontend | FATTO |

## Regole di gestione

- Un task per volta; niente "riscrivi tutta l'app".
- Se un agente esaurisce i passi, il task è troppo grande: si spezza e si riparte dal punto raggiunto.
- Ogni task chiuso aggiorna il nodo di memoria dell'area e questo registro.

## Agenda, notifiche e chat (F31)

Piano micro-task. Un task = un obiettivo verificabile. Stato iniziale: `DA FARE`; nessuno parte senza DBA e regole approvate.

| ID | Area | Task | Criteri di accettazione | Agente | Stato |
|---|---|---|---|---|---|
| H01 | DBA | Collezioni agenda/notifiche/chat e regole | schema, indici e regole approvate; nessun dato esistente toccato | dba | FATTO |
| H02 | Dati | Modelli `Appuntamento`, `Task`, `Promemoria`, `Notifica` | fromMap/toMap, default, test | sviluppatore-backend | FATTO |
| H03 | Dati | `SpService`: CRUD appuntamenti e task | query per azienda, filtro operatore, test | sviluppatore-backend | FATTO |
| H04 | UI | Schermata Calendario giorno/settimana | viste, filtri, oggi, senza orario, test | sviluppatore-frontend | FATTO |
| H04b | UI | Calendario classico giorno/settimana/mese e stile card | vista predefinita calendario; selettori periodo e stile; griglia ore, mese, “Senza orario”, creazione con ora; test | sviluppatore-frontend | FATTO |
| H04c | UI | Nuovo cliente dal form appuntamento e condivisione con colleghi/gruppi | pulsante `+` accanto al cliente; inviti con notifica; conferma disponibilità; stato provvisorio visibile; test | sviluppatore-frontend | FATTO |
| H04d | Notifiche | Risposta invito a creatore/operatore con In-App e WhatsApp | notifica di conferma a chi ha creato o gestisce l'appuntamento; recapito WhatsApp aziendale con consenso; test e E2E; nessun test richiesto ad Andrea | sviluppatore-backend | FATTO |
| H04e | UI | Form appuntamento: inizio/fine, tutto il giorno, ripetizione, notifica, privato | campi data/ora inizio e fine, flag tutto il giorno, ricorrenze con giorni, notifica configurabile, mascheramento privacy; test | sviluppatore-frontend | FATTO |
| H04f | Full stack | Allegati, promemoria e privacy reale | file su KV Worker, promemoria WhatsApp via Cron, dettagli privati in sotto-collezione e regole; test/E2E | sviluppatore-backend + frontend | FATTO |
| H05 | UI | Form appuntamento | titolo/data, cliente, operatore, luogo, Maps, call, promemoria | sviluppatore-frontend | FATTO |
| H06 | UI | Pagina Task | lista per scadenza, filtri, completa/riapri, test | sviluppatore-frontend | FATTO |
| H07 | UI | Form task | scadenza, operatore, priorità, cliente/appuntamento, note | sviluppatore-frontend | FATTO |
| H08 | UI | Dettaglio appuntamento/task con allegati | upload/download/eliminazione nel KV Worker, form appuntamento, max 10 MB (R2 resta il target finale) | sviluppatore-frontend | FATTO |
| H09 | Notifiche | Centro notifiche e badge in-app | elenco, lette/non lette, deep link, test | sviluppatore-frontend | FATTO |
| H10 | Notifiche | Preferenze notifiche per utente | canali, tipi, silenzio, numero WhatsApp, test | sviluppatore-frontend | FATTO |
| H11 | Push | Dispositivi e token FCM web/Android/iOS | registrazione, logout, token scaduto | sviluppatore-backend | DA FARE |
| H12 | Worker | Scheduler promemoria e notifiche | Cron Worker ogni minuto, KV `PROMEMORIA`, invio WhatsApp; push/In-App richiede Blaze | sviluppatore-backend | IN CORSO |
| H13 | WhatsApp | Invio operatore via server Volty | endpoint, secret, template, errore/retry | sviluppatore-backend | IN CORSO |
| H13b | WhatsApp | Configurazione Super Admin e proxy Worker | URL/API key nel KV, QR/stato, invio autenticato, rubrica consenso; test app + E2E Worker | sviluppatore-backend | FATTO |
| H13c | WhatsApp + Email | Promemoria automatico al cliente | avviso alla creazione e al cambio data/ora, WhatsApp+email, idempotenza, log nel dettaglio, config Resend; test | sviluppatore-backend + frontend | FATTO |
| H14 | Email | SMTP per azienda e invio prova | settings, secret server, template, retry; oggi c'è il mittente unico Resend, lo SMTP per azienda resta da fare | sviluppatore-backend | IN CORSO |
| H15 | Google | OAuth Google Calendar/Meet | collega/scollega, evento+Meet, sync, conflitti | sviluppatore-backend | DA FARE |
| H16 | Microsoft | OAuth Microsoft/Teams | collega/scollega, online meeting, sync, conflitti | sviluppatore-backend | DA FARE |
| H17 | R2 | Upload immagini firmato | limiti, formati, URL firmati, pulizia | sviluppatore-backend | DA FARE |
| H18 | Prenotazione | Slot e pagina pubblica | token, scadenza, doppia prenotazione, conferma | sviluppatore-backend | DA FARE |
| H19 | Chat | Modelli e stanze/messaggi | dirette senza duplicati, gruppi, partecipanti | sviluppatore-backend | FATTO |
| H20 | Chat | Lista conversazioni e thread | realtime, non letti, letture, immagini, soft delete | sviluppatore-frontend | FATTO |
| H21 | Chat | Notifiche chat in-app/push | notifiche in-app create per i destinatari; push FCM ancora da fare | sviluppatore-backend | IN CORSO |
| H22 | Impostazioni | Sezione Calendario e notifiche | fuso, promemoria, template, slot, allegati, Maps; test | sviluppatore-frontend | FATTO |
| H23 | Qualità | E2E agenda/notifiche/chat | appuntamento, task, promemoria, chat, Maps, push | tester | DA FARE |
| H24 | Qualità | Test automatici in CI | workflow GitHub Actions: `flutter analyze`, `flutter test`, controlli e test Worker | sviluppatore-backend | FATTO |

## Calendario per operatore, condivisione e OAuth aziendale (F32)

Decisioni confermate da Andrea il 24/10/2026. Un task = un obiettivo verificabile. Primo blocco eseguibile senza credenziali esterne: O01–O05 e O08–O10 con stub; O06/O07/O11 richiedono le credenziali e il Worker.

| ID | Area | Task | Criteri di accettazione | Agente | Stato |
|---|---|---|---|---|---|
| O01 | DBA | Schema e regole `integrazioni_azienda`, `condivisioni_calendario`, estensioni `integrazioni`/`impostazioni_agenda` | schema, indici e regole approvati; nessun secret in Firestore; test positivi/negativi; nessuna migrazione | dba | FATTO |
| O02 | Dati | Modelli `IntegrazioneAzienda` e `CondivisioneCalendario` | `fromMap`/`toMap`, default compatibili, livelli e stati validati; test | sviluppatore-backend | FATTO |
| O03 | Dati | `SpService`: lettura/salvataggio integrazioni azienda e CRUD condivisioni | admin legge/salva; utente legge proprie condivisioni; revoca; test | sviluppatore-backend | FATTO |
| O04 | UI | `Impostazioni → Integrazioni`: card Google, Microsoft, SMTP, WhatsApp, R2, Push | stati, modalità app Closer/app propria, campi, secret mascherati, test widget | sviluppatore-frontend | FATTO |
| O05 | UI | Procedura guidata Google/Microsoft (passi, copia redirect, test connessione) | 6 passi, errori comprensibili, nessun secret mostrato dopo il salvataggio; test | sviluppatore-frontend | DA FARE |
| O06 | Worker | OAuth Google: start, callback, token KV, refresh, revoca, test connessione | token mai al client; state firmato; scope minimi; test con mock | sviluppatore-backend | DA FARE |
| O07 | Worker | OAuth Microsoft/Graph: app multi-tenant, token, Teams, test connessione | consenso tenant, token KV, online meeting; test con mock | sviluppatore-backend | DA FARE |
| O08 | UI | `Impostazioni utente → Connessioni` Google/Microsoft | collega/ricollega/scollega, calendario scelto, stato; test | sviluppatore-frontend | DA FARE |
| O09 | Dati/Worker | Condivisione calendario e mascheramento eventi esterni | livelli libero/occupato/dettagli/modifica; stesso azienda; revoca; nessun dato mascherato al client; test | sviluppatore-backend | DA FARE |
| O10 | UI | Condivisione calendario e sezione "Condivisi con me" | dialog, livelli, revoca, badge, eventi "Occupato"; test | sviluppatore-frontend | IN CORSO |
| O11 | Worker | Creazione evento e call Meet/Teams sul calendario dell'operatore | evento sul calendario corretto, cliente invitato, link salvato, conflitti; test | sviluppatore-backend | IN CORSO |
| O12 | Qualità | E2E staging calendario condiviso e OAuth | connessione, evento, call, condivisione, revoca, 0 `permission-denied`, nessun secret esposto | tester | DA FARE |
| O13 | Qualità | Validazione finale F32 | report tester, DoD, approvazione; residui dichiarati | validatore | DA FARE |

**Dipendenze**: O01 → O02/O03 → O04/O05; O06/O07 richiedono credenziali Google/Azure e Worker; O08 dopo O06/O07; O09/O10 dopo O01/O03; O11 dopo O06/O07; O12/O13 alla fine.

**Prima fetta**: O01 + O02 + O03 + O04, con O06/O07 simulati da un `Test connessione` stub che non chiama servizi esterni. Serve a rendere visibili e salvabili le configurazioni senza credenziali.

## Audit completo dell'applicazione (AU)

**Decisione 24/10/2026**: nuove funzioni congelate fino alla chiusura dell'audit. Ogni area richiede test
automatici, prova E2E reale nella UI, report tester e validazione. Piano: `docs/progetto/test/audit-completa.md`.

| ID | Area | Criterio | Agente | Stato |
|---|---|---|---|---|
| AU01 | Auth e onboarding | login/reset/Google/onboarding/ruoli provati nella UI | tester | BLOCCATO (Google OAuth) |
| AU02 | Dashboard | conteggi e dati corretti per azienda | tester | DA FARE |
| AU03 | Clienti | CRUD, VIES, duplicati, persistenza | tester | FATTO (SUPERATA, report 25/10) |
| AU04 | Catalogo | prodotti, categorie, panieri, immagini | tester | DA FARE |
| AU05 | Preventivi | numero, totali, revisioni, PDF | tester | IN CORSO (R-1 corretto e verificato; restano revisioni e PDF) |
| AU06 | Visite | CRUD, riordino, stati, calendario | tester | DA FARE |
| AU07 | Calendario | viste, ricorrenza, privato, partecipanti, call, allegati | tester | DA FARE |
| AU08 | Task | CRUD, scadenze, completamento, filtri | tester | DA FARE |
| AU09 | Notifiche | centro, preferenze, push, WhatsApp, silenzio | tester | BLOCCATO (prova dispositivo) |
| AU10 | Chat | dirette, gruppi, letture, immagini, notifiche | tester | DA FARE |
| AU11 | Bandi | lista, filtri, dettaglio, import | tester | DA FARE |
| AU12 | Impostazioni | profilo, utenti, ruoli, licenze, superadmin, integrazioni | tester | DA FARE |
| AU13 | Integrazioni | WhatsApp, SMTP, push, Google/Microsoft, R2 | tester | DA FARE |
| AU14 | Trasversale | permessi, multi-azienda, errori, mobile/desktop | tester | DA FARE |
| AU15 | Produzione | progetto, Auth, DB, regole, hosting, admin | tester | DA FARE |
