---
description: Prepara e verifica un rilascio
agent: coordinatore
---

Segui `AGENTS.md` e il protocollo produzione del manuale.

1. `guardiano-produzione` compila la checklist e dà GO/NO-GO.
2. Verifica backup/export Firestore, regole, hosting e rollback.
3. Se è un nuovo sviluppo, verifica che Andrea lo abbia validato.
4. Solo con GO: pubblica sullo **staging** (`firebase deploy --only hosting,firestore:rules --project commerciali-app`) e riporta l'esito ad Andrea.
5. La produzione non esiste ancora: non tentare deploy di produzione.
