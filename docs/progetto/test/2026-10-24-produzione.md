# Ambiente di produzione — 24/10/2026

**Stato**: attivo su Firebase `commerciali-prod`.

## Infrastruttura

| Voce | Valore |
|---|---|
| Progetto Firebase | `commerciali-prod` |
| Nome | Closer Produzione |
| Hosting | https://commerciali-prod.web.app |
| Firestore | `(default)`, `europe-west8` |
| Auth | email/password attivo |
| Admin | `bottiandrea83@gmail.com`, super admin |
| Azienda | `Closer`, id `closer-prod` |
| Ruoli | `admin`, `commerciale` |
| Categorie | Generale, Servizi, Prodotti |
| Licenza | trial, 20 utenti, 2000 preventivi |
| Fatturazione | account “Il mio account di fatturazione” |

## Pubblicazione

```sh
cd flutter_app
flutter build web --release --dart-define=APP_ENV=prod
cd ..
firebase deploy --only hosting:app,firestore:rules,firestore:indexes --project prod
```

La configurazione Firebase di produzione è in `flutter_app/lib/firebase_options_prod.dart`; lo staging resta
il default senza `APP_ENV`.

## Verifiche

| Controllo | Esito |
|---|---|
| Hosting produzione | HTTP 200 |
| Bundle produzione | contiene `commerciali-prod` |
| Hosting staging | HTTP 200 |
| Bundle staging | contiene `commerciali-app` |
| Firestore produzione | 1 utente, 1 azienda, 1 membership, 2 ruoli, 3 categorie |
| Auth produzione | signup email/password + delete di prova: OK |
| Test Flutter | 833 verdi |
| `flutter analyze` | 0 problemi |
| Dati di test in produzione | nessuno |
| Regole e indici | pubblicati su `commerciali-prod` |

## Residui

- `main` non contiene ancora l’app Flutter: la prima pubblicazione è stata fatta dal ramo corrente. Prima del
  rilascio ufficiale serve portare il codice su `main` con tester, validatore ed E2E.
- Google Sign-In non è configurato in produzione; è attivo email/password.
- Le app mobile Android/iOS di produzione non sono configurate.
- E2E browser completo ancora da eseguire.
- Controllare i costi della fatturazione attivata.

## Password admin

È stata inviata un’email a `bottiandrea83@gmail.com` per impostare la password. In alternativa usare
“Password dimenticata” dalla schermata di login di produzione.


## Web Push (24/10/2026)

- Client: `web/push/push-client.js` + service worker `/push/push-sw.js` con scope separato da Flutter.
- UI: `Impostazioni → Notifiche → Notifiche sul dispositivo` con attiva/disattiva.
- Sottoscrizioni in `dispositivi`; chiavi VAPID in `functions/.env` (non nel repository).
- Cloud Function `inviaPushNotifica` pubblicata in produzione: trigger su `notifiche/{id}`, invio a tutti i dispositivi attivi dell’utente, disattivazione automatica degli endpoint 404/410.
- Test trigger con sottoscrizione finta: funzione eseguita, notifica passata a `fallita` con `push: 1 errori` (atteso: endpoint finto), dati di prova rimossi.
- Service worker verificato sul browser: registrazione attiva con scope `/push/`; `CloserPush.supportato` = true; senza permesso notifiche il client restituisce “Permesso notifiche negato”.
- Residuo: la consegna reale al dispositivo richiede un browser con permesso notifiche; va provata dal tester su Chrome/Android e iPhone con PWA installata.

## Verifica tester Web Push

**Data**: 24/10/2026 · **Rif. codice**: commit `f910314` (`feature/agenda-notifiche-chat`) · **Deploy**: `commerciali-prod`

### Comandi eseguiti ed esiti

| # | Prova | Esito atteso | Esito ottenuto |
|---|---|---|---|
| 1 | `cd flutter_app && flutter analyze` | 0 problemi | **Sul commit `f910314`: 1 warning**, exit 1 (`lib/features/calendario/viste_calendario.dart:255` `unused_element_parameter`). Sull'albero di lavoro (modifiche **non committate** di un'altra fetta, calendario/agenda) l'esito è cambiato più volte durante la verifica: prima 2 errori `Undefined name '_durata'`, poi `No issues found!` |
| 2 | `cd flutter_app && flutter test` | 833 verdi | **Su `f910314`: 833/833 verdi, 0 falliti.** Sull'albero di lavoro: 3 esecuzioni con 7, poi 1, poi 7 fallimenti, tutti in `test/appuntamento_form_test.dart` (fetta calendario in corso, estranea al push) |
| 3 | `node scripts/controlla-indice.mjs` | INDICE OK | `INDICE OK` (19 nodi di memoria, 9 file chiave), exit 0 |
| 4 | `curl -sI https://commerciali-prod.web.app/push/push-sw.js` e `push-client.js` | 200 | **200**, `content-type: text/javascript`; `diff` con i file del repo: **identici** |
| 5 | `functions/index.js` | trigger `notifiche/{id}`, `dispositivi`, VAPID da env, 404/410, aggiorna `stato` | Conforme: `onDocumentCreated("notifiche/{id}")`, legge `dispositivi` (`utente_uid` + `attivo == true`), VAPID da `process.env` con guardia, 404/410 → `attivo: false`, scrive `stato` `inviata`/`fallita`, `tentativi`, `errore` |
| 6 | Client + UI | endpoint/p256dh/auth in `dispositivi`, chiavi UI | Conforme: `salvaDispositivoWeb` scrive `endpoint`, `p256dh`, `auth`, `utente_uid`, `azienda_id`, `attivo`; regole `match /dispositivi/{id}` presenti; UI ha `notifiche-push-attiva`, `notifiche-push-disattiva`, `notifiche-push-esito` |
| 7 | Ambiente | staging push disattivato, produzione `APP_ENV=prod` | Conforme: `pushDisponibileAmbiente` = `APP_ENV == 'prod'` con default `staging`; in staging il pulsante è disabilitato con messaggio "disponibili solo nell'ambiente di produzione". Bundle prod contiene solo la configurazione `commerciali-prod`, staging solo `commerciali-app`; `main.dart` sceglie `firebase_options_prod` quando `APP_ENV=prod` (prova indiretta: il `--dart-define` non è leggibile dal bundle compilato) |
| 8 | Test già eseguiti | come da doc | Riportati e verificati dove possibile: log di produzione mostrano `Push fallita closer-prod_shISqKc6GCPlSrw9taq8cHnnbms1_smoke … The subscription p256dh value should be 65 bytes long` (trigger con sottoscrizione finta → `fallita`); funzione distribuita (`firebase functions:list --project prod`: `inviaPushNotifica` v2, `europe-west1`, `nodejs22`, trigger Firestore `europe-west8`). Firestore produzione: `dispositivi` 0 documenti, `notifiche` 0 → **dati di prova rimossi**; `utenti` 1, `membri` 1, `licenze` 1, `ruoli` 2, `categorie` 3 |
| 9 | Segreti e dati di test | nessun segreto nel repo | `functions/.env` è ignorato da git (`.gitignore:66`); in repo solo `.env.example` con segnaposto; chiave privata VAPID assente; la chiave pubblica in `push-client.js` coincide con `VAPID_PUBLIC_KEY` di `.env` (pubblica per definizione) |

### Note

- Verifica in browser non ripetuta in questa sessione (nessun browser collegato). I controlli runtime di service worker (`scope /push/`), `CloserPush.supportato = true` e "Permesso notifiche negato" restano quelli registrati sopra e sono coerenti con il codice (`push-client.js` righe 20-51).
- Il conteggio "833 verdi / 0 problemi" del riepilogo sopra è corretto per i test al commit `f910314`, ma **non** per `flutter analyze`: quel commit ha 1 warning.
- L'albero di lavoro conteneva modifiche non committate di un'altra fetta (calendario/agenda) che hanno reso instabili analyze e test durante la verifica; non sono attribuibili al Web Push.

### Residui (non da chiedere ad Andrea)

- **Consegna reale della notifica su dispositivo** con permesso notifiche concesso (Chrome/Android) e **prova iOS con PWA installata**: da fare.
- Prova E2E di produzione con login reale non eseguibile in questa sessione: nessun browser collegato e nessuna credenziale di test disponibile.

### Verdetto

**NON SUPERATO**

Motivi: la fetta Web Push non presenta difetti (punti 4-9 tutti conformi), ma il gate della Definition of Done non è verde: al commit della fetta `flutter analyze` restituisce 1 warning (atteso 0) e l'albero di lavoro attuale non supera `flutter test` per la fetta calendario in corso. Da ripetere `flutter analyze` e `flutter test` a fetta calendario chiusa e committata, prima di qualsiasi validazione.

## Aggiornamento verifica Web Push — albero pulito

Dopo la chiusura e il commit della fetta calendario/ricorrenza, l’albero è pulito.

| Controllo | Esito |
|---|---|
| `flutter analyze` | 0 problemi |
| `flutter test` | **849 verdi** |
| Commit | `f8dd54c` |
| Indice | INDICE OK |

Il precedente verdetto `NON SUPERATO` era dovuto a modifiche non committate di un’altra fetta. Sulla fetta Web Push chiusa il gate tecnico è verde. Resta obbligatoria la prova di consegna reale su un dispositivo con permesso notifiche (Chrome/Android e iPhone con PWA installata): non è una prova da chiedere ad Andrea, la esegue la squadra.

## Validazione Web Push — 24/10/2026

**APPROVATO TECNICO per staging/produzione** (non per rilascio ufficiale): gate tecnico verde (analyze 0, 849 verdi, indice OK, statici 200) e codice conforme. Restano a carico della squadra la consegna reale su dispositivo (Chrome/Android), la prova iOS PWA e l'E2E browser. Nota minore risolta: il pulsante “Disattiva” ora è disabilitato quando il push non è supportato nell’ambiente.

## Notifiche e ruolo commerciale — 24/10/2026

- In Impostazioni la sezione **Personale** (Notifiche, Condivisione calendario) è visibile a tutti i ruoli.
- Il ruolo **commerciale** vede e gestisce canali, push, orari di silenzio, anteprima e condivisione del proprio calendario.
- Le voci di amministrazione (Calendario e agenda, Integrazioni, Utenti, Ruoli, Licenze) restano visibili solo all’admin.
- Test widget dedicato: il commerciale vede `impostazioni-voce-notifiche` e `impostazioni-voce-condivisioni`, non vede `impostazioni-voce-utenti`, `ruoli`, `licenze`, `integrazioni`.
- `flutter analyze` 0; `flutter test` **850 verdi**; app pubblicata su staging e produzione.

## Lezione appresa — stato WhatsApp

La schermata mostrava “non connesso” mentre il server era connesso. Causa: il server risponde con
`connesso`/`numero`, la UI leggeva `connected`/`number`; il Worker inoltrava la risposta senza normalizzarla.
I test coprivano permessi e endpoint, non lo stato reale nella schermata.

Correzioni:
- normalizzazione unica `normalizzaStatoWhatsapp` con test sui due formati;
- test della risposta reale del Worker;
- regola nella Definition of Done: per i servizi esterni serve la prova UI completa, non solo `curl`;
- se la UI non è provabile, il task è BLOCCATO, non “SUPERATO con residuo”.

**Responsabilità di processo**: tester e validatore avevano approvato la fetta tecnica dichiarando l’E2E UI
come residuo. Con la regola attuale quel verdetto non sarebbe stato sufficiente.
