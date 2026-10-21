# Processo — rilascio

**Quando leggerlo**: deploy o promozione.
**Riferimento**: `docs/progetto/ambienti.md`, `docs/progetto/produzione.md`, `firebase.json`.

## Oggi (solo staging)

```sh
firebase deploy --only hosting,firestore:rules --project commerciali-app
cd worker && npx wrangler deploy
```

- `guardiano-produzione` dà GO/NO-GO.
- La produzione non esiste: nessun deploy di produzione.

## Quando ci sarà la produzione

- Progetto Firebase separato, ramo `main`, credenziali solo in CI.
- Promozione `staging` → `main` con validazione di Andrea.

**Ultima revisione**: 2026-10-22
