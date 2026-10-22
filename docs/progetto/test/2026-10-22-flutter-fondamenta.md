# Test — Flutter, fondamenta (F01–F05)

**Data**: 2026-10-22
**Area**: `flutter_app/` — scaffold, Firebase, tema/router/shell, auth email/password, login
**Nodi letti**: `indice.md`, `memoria/flutter/index.md`
**Ambiente**: locale (macOS), build web; nessun deploy

## Perimetro

- F01 scaffold e dipendenze
- F02 configurazione Firebase (web/Android/iOS) e avvio app
- F03 tema Material 3, router, shell responsive
- F04a auth email/password e profilo utente
- F04b `SpService` base (aziende, membri, seed)
- F05 schermata di login email/password

Fuori perimetro: F06 login Google e deploy.

## Comandi ed esiti

| Comando / verifica | Esito atteso | Esito ottenuto |
|---|---|---|
| `flutter analyze` | nessun errore o warning | `No issues found!` |
| `flutter test` | suite verde | 35 test, tutti verdi |
| `flutter build web` | build completata | `✓ Built build/web` |
| Test senza Firebase reale | nessuna credenziale richiesta | confermato, nessuna credenziale usata |
| `git diff origin/staging -- firestore.rules` | nessuna differenza | nessuna differenza |
| Vecchia app in radice | intatta | intatta |
| Ricerca segreti nel codice | nessun segreto | nessuno; solo configurazione client Firebase pubblica |
| Shell a 400 px | `NavigationBar` visibile | test verde |
| Shell a 900 px | `NavigationRail` visibile | test verde |
| Login su `/#/login` | schermata renderizzata | schermata renderizzata dal build web, screenshot confermato |
| Validazione form e widget test login | errori e stati corretti | test verdi |

## Problemi e limiti

1. **Login reale non eseguito**: nessun accesso vero contro il progetto Firebase di staging. La prova reale è
   spostata esplicitamente al task F06.
2. **Dizione errore login**: "credenziali non corrette" (nuova) vs "non valide" (vecchia); solo testuale.
3. **Nessun test end-to-end** su browser contro dati reali: i test sono unitari/widget con Firebase simulato.
4. **Milestone committato**: F01–F05 è nel commit `300904c` (`feat(flutter): F05 login e allineamento criteri
   milestone`); criteri F04a/F05 allineati, login email validato con unit/widget test.
5. **Indice**: `node scripts/controlla-indice.mjs` eseguito dal coordinatore → `INDICE OK` (19 nodi, 9 file chiave).
6. **Modifiche documentali**: regola task piccoli in `AGENTS.md` e nodo `memoria/ui/dashboard.md` giustificati in
   `docs/progetto/registro-decisioni.md`.
7. **Regressioni**: nessuna; radice e `firestore.rules` invariati rispetto a `origin/staging`.

## Chiusura

**SUPERATO con riserva**

F01–F05 verdi su analisi, test e build (`300904c`), senza segreti né modifiche a regole o vecchia app; indice OK.
La riserva è limitata a: login reale su staging e login Google (F06) e prova su dispositivo mobile reale.

## Resta da verificare

- Accesso reale email/password su staging (F06).
- Login Google (F06).
- Comportamento su dispositivo mobile reale (Android/iOS), non solo web.
- Dizione "non corrette" / "non validi" (solo testuale).
