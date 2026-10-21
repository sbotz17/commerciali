---
description: Correzione urgente con la stessa strada sicura
agent: coordinatore
---

Segui `AGENTS.md` e il protocollo hotfix del manuale.

Urgenza: $ARGUMENTS

1. `gestore-ritorni` verifica che sia un malfunzionamento reale.
2. `risolutore-bug` applica la correzione minima.
3. `tester` e `validatore` obbligatori.
4. `guardiano-produzione` dà GO/NO-GO.
5. PR verso `staging`; la produzione, quando esisterà, seguirà la promozione.
5. Se serve una migrazione o una zona protetta: è uno sviluppo, avvisa Andrea e fermati.
