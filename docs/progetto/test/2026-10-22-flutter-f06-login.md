# Test — Flutter F06 Login Google (2026-10-22)

Ambito: F06a (login Google web), F06b (login Google mobile), F06c (prova reale su staging).
Non sono stati eseguiti altri comandi oltre a quelli già riportati dal coordinatore.

## Cosa è stato provato

| # | Prova | Esito atteso | Esito ottenuto |
|---|---|---|---|
| 1 | `flutter analyze` | 0 problemi | 0 problemi |
| 2 | `flutter test` | suite verde | 52 test verdi |
| 3 | `flutter build web` | build completata | ok |
| 4 | F06a — web: pulsante "Accedi con Google" | pulsante visibile e cliccabile | presente |
| 5 | F06a — popup Firebase | popup aperto dall'azione utente | popup avviato |
| 6 | F06a — traduzione errori | errori Firebase in italiano | tradotti |
| 7 | F06a — copertura | 9 unit test + widget test | come atteso |
| 8 | F06b — mobile: `google_sign_in` 7 + `serverClientId` | configurazione con client ID web pubblico | presente |
| 9 | F06b — dispatcher `kIsWeb` | ramo web/mobile separato | presente |
| 10 | F06b — errori tradotti | errori in italiano | tradotti |
| 11 | F06b — verifica | solo analisi statica | eseguita |
| 12 | F06c — staging: login email utente temporaneo | login riuscito, arrivo alla Dashboard | utente `e2e-flutter@commerciali.test` loggato, Dashboard raggiunta |
| 13 | F06c — pulizia dati | utente e profilo rimossi | rimossi |
| 14 | Isolamento/regole | nessuna modifica a `firestore.rules` | nessuna modifica |
| 15 | Vecchia app e configurazioni | nessuna modifica | nessuna modifica |
| 16 | Segreti e dati di test nel codice | assenti | assenti |
| 17 | `node scripts/controlla-indice.mjs` | `INDICE OK` | `INDICE OK` (19 nodi, 9 file chiave) |

## Problemi e limiti

1. Il popup Google reale non è stato eseguito con un account Google reale: verificato solo l'avvio del flusso.
2. Il flusso mobile reale non è stato provato su dispositivo: F06b verificato solo in analisi statica.
3. Manca un test E2E automatico ripetibile: la prova F06c è stata manuale.

Nessuna regressione rilevata sulle funzioni esistenti. Nessun codice corretto dal tester.

## Esito

**SUPERATO con riserva** — riserva limitata a: login Google reale (popup con account reale) e login mobile
su dispositivo reale. Da colmare prima del rilascio in produzione.
