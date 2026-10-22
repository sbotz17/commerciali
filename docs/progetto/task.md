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
| F16c | Bandi | Import manuale dei bandi | import con log (non presente nella UI attuale) | sviluppatore-frontend | DA FARE |
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

## Regole di gestione

- Un task per volta; niente "riscrivi tutta l'app".
- Se un agente esaurisce i passi, il task è troppo grande: si spezza e si riparte dal punto raggiunto.
- Ogni task chiuso aggiorna il nodo di memoria dell'area e questo registro.
