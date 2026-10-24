# Audit Google login — produzione

**Data**: 25/10/2026
**Stato**: **BLOCCATO**
**Area**: AU01 — Auth e onboarding

## Cosa è stato verificato

- progetto produzione: `commerciali-prod`;
- Auth email/password: attivo;
- provider Google in produzione: **assente** (`defaultSupportedIdpConfigs` vuoto);
- provider Google in staging: presente, con client OAuth del progetto `commerciali-app`;
- il client OAuth dello staging **non è riutilizzabile** in produzione: Google rifiuta il redirect
  `https://commerciali-prod.firebaseapp.com/__/auth/handler` con `redirect_uri_mismatch`;
- il pulsante “Accedi con Google” in produzione apre il flusso ma il provider non è configurato, quindi
  l’accesso non può riuscire.

## Perché è bloccato

Serve un **client OAuth Web** creato nel progetto Google Cloud `commerciali-prod`, con redirect autorizzato:

```text
https://commerciali-prod.firebaseapp.com/__/auth/handler
```

La creazione del client non è disponibile via API con le credenziali attuali: Google ha chiuso l’API
programmatica IAP e la Console richiede una sessione browser dell’account Google. Non è stato inventato né
copiato un client di un altro progetto.

## Cosa non è stato fatto

- non è stato attivato un client OAuth di staging in produzione;
- non è stato modificato `authDomain` per aggirare il problema;
- non è stata dichiarata la funzione SUPERATA.

## Per chiudere l’audit

1. creare il client OAuth Web nel progetto `commerciali-prod`;
2. aggiungere il redirect URI sopra;
3. fornire Client ID e Secret al superadmin (mai nel repository);
4. abilitare Google in Firebase Auth produzione;
5. provare login Google reale e registrazione con un account di test;
6. tester + validatore.

Fino ad allora **Google login in produzione è BLOCCATO** e nessuna nuova funzione può partire.
