# Ambienti — Commerciali

## Staging (attivo ora)

| Cosa | Dove |
|---|---|
| Ramo | `staging` |
| Hosting | https://commerciali-app.web.app |
| Progetto Firebase | `commerciali-app` |
| Firestore | database `(default)`, regione `europe-west8` |
| Auth | email/password + Google |
| Proxy VIES | https://commerciali-vies.bottiandrea83.workers.dev |
| Vecchio backend | Supabase `segbfdfoqxrnitboeyof` — dismesso |

## Produzione (progetto creato, non ancora attivo)

Il 24/10/2026 è stato creato il progetto Firebase separato:

| Cosa | Dove |
|---|---|
| Progetto Firebase | `commerciali-prod` |
| Hosting riservato | https://commerciali-prod.web.app (non pubblicato) |
| Web app Firebase | `Closer Web` |
| Firestore | **non attivo**: la creazione del database `(default)` richiede billing |
| Auth | **non inizializzato**: richiede Identity Platform/billing |
| App pubblicata | no |
| Ramo previsto | `main`, ma oggi non contiene ancora l’app Flutter |

**Blocco attuale**: un progetto Firebase nuovo richiede l’attivazione della fatturazione per creare il database
Firestore `(default)` e inizializzare Auth. Non è stata attivata alcuna fatturazione e non è stata pubblicata
l’app. Staging resta l’unico ambiente operativo.

Per completare servono, nell’ordine:

1. autorizzazione all’uso di un account di fatturazione per `commerciali-prod`;
2. creazione del database `(default)` in `europe-west8` e deploy di regole/indici;
3. inizializzazione Auth e creazione del primo amministratore;
4. build Flutter con `APP_ENV=prod` e configurazione Firebase di produzione;
5. pubblicazione da `main` solo dopo tester, validatore ed E2E.

Le credenziali di produzione non vanno mai nel repository né nelle sessioni degli agenti.

## Pubblicazione staging

```sh
firebase deploy --only hosting,firestore:rules --project commerciali-app
```

Worker VIES:

```sh
cd worker && npx wrangler deploy
```


**Alias**: `commerciali-flutter.web.app` non è un secondo ambiente; reindirizza con 301 a `commerciali-app.web.app`. Non usarlo per test o login.
