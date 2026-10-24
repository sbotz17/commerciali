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
| Test Flutter | 822 verdi |
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
