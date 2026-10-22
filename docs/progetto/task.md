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
| F07c | Auth | Redirect di autenticazione | non loggato → login; senza azienda → onboarding; altrimenti shell | sviluppatore-frontend | RINVIATO (dopo F08) |
| F08 | Dashboard | Conteggi, valore aperto, ultimi 5, azioni rapide | numeri uguali alla vecchia app per lo stesso utente | sviluppatore-frontend | DA FARE |
| F09a | Clienti | Modello `Cliente` + CRUD `SpService` + duplicati | CRUD completo; isolamento per azienda; test | sviluppatore-backend | FATTO |
| F09b | Clienti | Schermata lista + form cliente | lista, ricerca, creazione/modifica/eliminazione | sviluppatore-frontend | FATTO |
| F09c | Clienti | Verifica P.IVA VIES | Ferrari valida, P.IVA falsa non valida | sviluppatore-backend | FATTO |
| F11a | Catalogo | Modelli `Prodotto`/`Categoria` + CRUD `SpService` | CRUD; isolamento azienda; test | sviluppatore-backend | FATTO |
| F11b | Catalogo | Schermata catalogo e categorie | lista, filtro, form, immagini URL | sviluppatore-frontend | FATTO |
| F12 | Preventivi | Lista, form, righe, totali, stati | totali uguali alla vecchia app; visibilità per utente | sviluppatore-frontend | DA FARE |
| F13 | Preventivi | Contatore transazionale e revisioni | serie continua; nessun numero duplicato; `-R1` senza consumare | sviluppatore-backend | FATTO |
| F14 | Preventivi | PDF con `pdf`/`printing` | stesso contenuto e totali; stampa/condivisione | sviluppatore-frontend | DA FARE |
| F15 | Visite | Lista, form, riordino, filtri | ordinamento `ordine`/`ora`; stati persistenti | sviluppatore-frontend | DA FARE |
| F16 | Bandi | Lista pubblica, filtri, dettaglio, import | pagina senza login; import scrive log | sviluppatore-frontend | DA FARE |
| F17 | Impostazioni | Utenti, ruoli, permessi, licenze | CRUD utenti; limiti piano; super admin | sviluppatore-backend | DA FARE |
| F18 | Super admin | Pannello aziende, licenze, piani | accesso a qualsiasi azienda; nessun dato fuori azienda | sviluppatore-frontend | DA FARE |
| F19 | Qualità | Parità multi-piattaforma e test | rapporti tester, `flutter test`, `flutter analyze` | tester | DA FARE |

## Regole di gestione

- Un task per volta; niente "riscrivi tutta l'app".
- Se un agente esaurisce i passi, il task è troppo grande: si spezza e si riparte dal punto raggiunto.
- Ogni task chiuso aggiorna il nodo di memoria dell'area e questo registro.
