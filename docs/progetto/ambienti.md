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
| Proxy WhatsApp | stesso Worker, endpoint `/whatsapp/*`; URL/API key nel KV `WHATSAPP_CONFIG` |
| Vecchio backend | Supabase `segbfdfoqxrnitboeyof` — dismesso |

## Produzione (attiva)

| Cosa | Dove |
|---|---|
| Ramo previsto | `main` (da aggiornare; oggi la produzione è stata pubblicata dal ramo Flutter corrente) |
| Hosting | https://commerciali-prod.web.app |
| Progetto Firebase | `commerciali-prod` |
| Firestore | database `(default)`, regione `europe-west8` |
| Auth | email/password attivo; Google non ancora configurato |
| Admin | `bottiandrea83@gmail.com` (super admin) |
| Azienda | `Closer`, id `closer-prod` |
| Fatturazione | account “Il mio account di fatturazione” |

La produzione ha un progetto Firebase separato, quindi **non condivide dati, utenti o regole con lo staging**.
L’app è pubblicata con `--dart-define=APP_ENV=prod` e `firebase_options_prod.dart`.

**Nota di processo**: `main` non contiene ancora l’app Flutter. La prima pubblicazione è stata fatta dal ramo
corrente per rendere operativo l’ambiente; prima del rilascio ufficiale il codice va portato su `main` con
tester, validatore ed E2E. Google Sign-In in produzione va configurato prima di abilitarlo nell’interfaccia.

## Pubblicazione produzione

```sh
cd flutter_app
flutter build web --release --dart-define=APP_ENV=prod
cd ..
firebase deploy --only hosting:app,firestore:rules,firestore:indexes --project prod
```

## Pubblicazione staging

```sh
firebase deploy --only hosting,firestore:rules --project commerciali-app
```

Worker VIES:

```sh
cd worker && npx wrangler deploy
```


**Alias**: `commerciali-flutter.web.app` non è un secondo ambiente; reindirizza con 301 a `commerciali-app.web.app`. Non usarlo per test o login.
