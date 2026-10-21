# Registro dei task

**Regola**: un task = un solo obiettivo verificabile (1 file, 1 schermata o 1 servizio).
Il coordinatore assegna un task alla volta. Stati: `DA FARE`, `IN CORSO`, `FATTO`, `BLOCCATO`.

## Migrazione Flutter

| ID | Area | Task | Criteri di accettazione | Agente | Stato |
|---|---|---|---|---|---|
| F01 | Fondamenta | Creare `flutter_app/` (web, Android, iOS) con dipendenze Firebase | `flutter create` ok, `pub get` ok, `flutter analyze` 0 errori | sviluppatore-backend | IN CORSO |
| F02 | Fondamenta | Configurare Firebase (`firebase_options.dart`, init in `main.dart`) | app web si avvia senza errori Firebase; `flutter analyze` 0 | sviluppatore-backend | DA FARE |
| F03 | Fondamenta | Tema Material 3, router `go_router`, shell responsive vuota | rotte principali definite; shell telefono/desktop; analyze 0 | sviluppatore-frontend | DA FARE |
| F04 | Auth | `AuthService` + `SpService` per profilo/aziende/membri | login email/password reale su staging; profilo letto; analyze 0 | sviluppatore-backend | DA FARE |
| F05 | Auth | Schermata login email/password | login riuscito, errore leggibile, logout; widget test | sviluppatore-frontend | DA FARE |
| F06 | Auth | Login Google web e mobile | popup web e Google nativo mobile; stesso profilo | sviluppatore-backend | DA FARE |
| F07 | Auth | Recupero password + onboarding azienda | reset link apre schermata; onboarding crea azienda/membro/seed | sviluppatore-frontend | DA FARE |
| F08 | Dashboard | Conteggi, valore aperto, ultimi 5, azioni rapide | numeri uguali alla vecchia app per lo stesso utente | sviluppatore-frontend | DA FARE |
| F09 | Clienti | Lista, ricerca, form, duplicati | CRUD completo; isolamento per azienda | sviluppatore-frontend | DA FARE |
| F10 | Clienti | Verifica P.IVA VIES | Ferrari valida, P.IVA falsa non valida; nessuna modifica al cliente | sviluppatore-backend | DA FARE |
| F11 | Catalogo | Prodotti e categorie | CRUD, filtro, ordinamento, immagini URL | sviluppatore-frontend | DA FARE |
| F12 | Preventivi | Lista, form, righe, totali, stati | totali uguali alla vecchia app; visibilità per utente | sviluppatore-frontend | DA FARE |
| F13 | Preventivi | Contatore transazionale e revisioni | serie continua; nessun numero duplicato; `-R1` senza consumare | sviluppatore-backend | DA FARE |
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
