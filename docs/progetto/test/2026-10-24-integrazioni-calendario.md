# Test — Calendario condiviso e OAuth aziendale, prima fetta (O01–O04)

**Data**: 24/10/2026
**Stato**: prima fetta implementata e pubblicata su staging; Worker OAuth e UI di condivisione ancora da fare.

## Perimetro

- O01: regole e indici `integrazioni_azienda`, `condivisioni_calendario`.
- O02: modelli `IntegrazioneAzienda`, `ConfigIntegrazioneProvider`, `CondivisioneCalendario`.
- O03: servizio integrazione e condivisioni.
- O04: schermata `Impostazioni → Calendario e integrazioni`.

## Esiti

| Controllo | Comando | Esito |
|---|---|---|
| Analisi | `flutter analyze` | 0 problemi |
| Test | `flutter test` | **778 verdi** |
| E2E regole | `python3 scripts/e2e-agenda.py` | PASS |
| Regole | deploy `firestore:rules` | completato |
| Indici | deploy `firestore:indexes` | completato |
| Hosting | deploy app + flutter | completato |

L’E2E verifica con due utenti reali della stessa azienda:

- appuntamento, task, chat, notifica;
- `integrazioni_azienda`: l’admin legge/scrive, il commerciale no; il campo `client_secret` viene rifiutato;
- `condivisioni_calendario`: il proprietario crea, il destinatario legge; un utente non può spacciarsi per il proprietario né revocare; dopo la revoca il destinatario non legge più.

## Cosa funziona

- Modelli con default e serializzazione senza `client_secret`/token.
- Servizio con lettura/salvataggio integrazione e CRUD condivisioni.
- Schermata admin con card Google, Microsoft, SMTP, WhatsApp, R2, Push.
- Dialog Google/Microsoft: modalità app Closer/app propria, Client ID, Tenant Microsoft, redirect URI, salvataggio non segreto.
- Voce e rotta `/impostazioni/integrazioni`.

## Residui dichiarati

- O05/O06/O07: Worker OAuth, inserimento Client Secret, test connessione reale.
- O08: connessioni utente Google/Microsoft.
- O09/O10: condivisione calendario lato UI e mascheramento eventi.
- O11: creazione evento e call Meet/Teams.
- O12/O13: E2E completo e validazione finale.
- SMTP, WhatsApp e R2: card presenti, configurazione server e invio ancora da fare.

## Verifica tester O01–O04

| Controllo | Comando | Esito |
|---|---|---|
| Analisi | `flutter analyze` | 0 problemi |
| Test | `flutter test` | 778 verdi |
| E2E regole | `python3 scripts/e2e-agenda.py` | PASS |
| Indice | `node scripts/controlla-indice.mjs` | INDICE OK |
| Regole | `firestore.rules` | admin-only per integrazioni, revoca non leggibile dal destinatario, secret rifiutato |
| Indici | `firestore.indexes.json` | due indici condivisioni presenti |
| UI | `/impostazioni/integrazioni` | rotta e voce presenti; nessun segnaposto nel percorso |
| Segreti | dialog e modelli | Client Secret disabilitato, nessun `client_secret`/token in Firestore |

**Verdetto tester: NON SUPERATO per rilascio** perché manca la prova E2E nel browser richiesta dalla DoD; la fetta tecnica O01–O04 è verificata, ma restano aperti O05–O13 e la prova UI reale. Non rilasciabile in produzione.

**Validazione (24/10/2026): APPROVATO TECNICO per staging** — fetta O01–O04 (schema/regole, modelli, servizio, schermata integrazioni) verificata. Non rilasciabile in produzione: manca E2E browser e restano obbligatori O05–O13.
