# Ambienti — Commerciali

| Cosa | Dove |
|---|---|
| Repository | `sbotz17/commerciali` |
| Produzione | `main` → https://commerciali-app.web.app |
| Hosting | Firebase Hosting, progetto `commerciali-app` |
| Database | Firestore, regione `europe-west8`, database `(default)` |
| Auth | Firebase Auth: email/password + Google |
| Proxy VIES | https://commerciali-vies.bottiandrea83.workers.dev (Cloudflare Worker) |
| Vecchio backend | Supabase `segbfdfoqxrnitboeyof` — **dismesso, non esiste più** |

## Come si pubblica

```sh
firebase deploy --only hosting,firestore:rules --project commerciali-app
```

Il Worker VIES si pubblica da `worker/`:

```sh
cd worker && npx wrangler deploy
```

## Domini autorizzati Firebase Auth

`localhost`, `commerciali-app.firebaseapp.com`, `commerciali-app.web.app`. Un eventuale dominio custom va
aggiunto in Firebase → Authentication → Impostazioni → Domini autorizzati.
