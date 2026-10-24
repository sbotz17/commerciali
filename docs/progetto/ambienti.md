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

## Produzione (da creare)

Non esiste ancora. Quando servirà:

1. Creare un **progetto Firebase separato** (es. `commerciali-prod`), con Firestore, Auth e Hosting propri.
2. Aggiungere il dominio di produzione ai domini autorizzati Auth.
3. Promuovere `staging` → `main` e pubblicare da `main`.
4. Le credenziali di produzione non vanno mai nel repository né nelle sessioni degli agenti.

## Pubblicazione staging

```sh
firebase deploy --only hosting,firestore:rules --project commerciali-app
```

Worker VIES:

```sh
cd worker && npx wrangler deploy
```


**Alias**: `commerciali-flutter.web.app` non è un secondo ambiente; reindirizza con 301 a `commerciali-app.web.app`. Non usarlo per test o login.
