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

1. **Login reale non eseguito**: non è stato fatto un accesso vero contro il progetto Firebase di staging.
   Va coperto in F06/F07.
2. **Dizione errore login**: il messaggio della nuova app dice "credenziali non corrette", la vecchia app dice
   "credenziali non valide". Differenza solo testuale, da allineare o accettare consapevolmente.
3. **Nessun test end-to-end** su browser contro dati reali: i test sono unitari/widget con Firebase simulato.
4. **`node scripts/controlla-indice.mjs`** non eseguito in questo task: va lanciato in validazione.
5. **Regressioni**: nessuna; radice e `firestore.rules` invariati rispetto a `origin/staging`.

## Chiusura

**SUPERATO con riserva**

Le fondamenta F01–F05 sono verdi su analisi, test e build, senza segreti né modifiche a regole o vecchia app.
La riserva riguarda il login reale su staging e l'allineamento della dizione dell'errore, da chiudere prima
della parità con la vecchia app.

## Resta da verificare

- Accesso reale email/password su staging (F06/F07).
- Login Google (F06).
- Comportamento su dispositivo mobile reale (Android/iOS), non solo web.
- Scelta sulla dizione "non corrette" / "non validi".
- Esecuzione di `node scripts/controlla-indice.mjs` in fase di validazione.
