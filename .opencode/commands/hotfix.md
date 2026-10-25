---
description: "Correzione urgente con la stessa strada sicura"
agent: coordinatore
---

Segui `AGENTS.md`, `CLAUDE.md` e la skill `squadra-ritorni`.

Urgenza: $ARGUMENTS

1. `gestore-ritorni` verifica che sia un malfunzionamento reale.
2. `risolutore-bug` applica la correzione minima su `hotfix/R-<n>`.
3. `tester` e `validatore` obbligatori.
4. `guardiano-produzione` da' GO/NO-GO.
5. PR verso `staging`; poi la promozione e il rilascio li fa la CI.
6. Avvisa subito Andrea (informativo): l'urgenza non richiede il suo via libera.
7. Se serve una migrazione o una zona protetta e' uno sviluppo: passa dall'accettazione indipendente con
   priorita', senza aspettare Andrea.
