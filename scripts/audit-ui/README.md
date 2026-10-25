# Audit UI (Playwright)

Prove reali sulla UI pubblicata, usate dal tester per le ondate dell'audit.

## Preparazione

```bash
cd scripts/audit-ui
npm install
```

L'utente di prova si crea con `python3 scripts/e2e-ui-dati.py setup` (solo staging), che stampa email,
password e percorso del file di stato.

Ogni setup scrive un file di stato suo (`e2e-ui-<suffisso>.json`). Per pulire:

```bash
E2E_STATO=<file stampato> python3 scripts/e2e-ui-dati.py cleanup
```

Non usare un file di stato condiviso: due sessioni in parallelo si cancellerebbero l'utente a vicenda.

## Esecuzione

```bash
AUDIT_EMAIL="..." AUDIT_PASS="..." AUDIT_BASE="https://commerciali-app.web.app/" node clienti-b.js
AUDIT_EMAIL="..." AUDIT_PASS="..." node preventivi-e.js
```

- L'app è Flutter web su canvas: `helpers.js` attiva l'albero di accessibilità (`flt-semantics-placeholder`)
  e interagisce con i nodi semantici, non con il canvas.
- I campi di testo vanno svuotati con `Meta+A` (macOS) prima di scrivere, altrimenti Flutter concatena.
- Gli elementi dentro i menu si trovano per `aria-label` (`cliccaAria`), i pulsanti per testo (`cliccaTesto`).
- Nessuna credenziale nel repository: sempre da variabili d'ambiente.

## Cosa NON fa

- Non modifica dati di produzione: usare solo `AUDIT_BASE` di staging.
- Non sostituisce il giudizio del tester sui criteri di accettazione.

## Esito noto

- `clienti-b.js`: crea un cliente, verifica elenco, persistenza e duplicato.
- `preventivi-e.js`: crea un preventivo con riga e sconto, salva, verifica numero `PRV-` e persistenza.
