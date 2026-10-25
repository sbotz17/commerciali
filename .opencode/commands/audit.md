---
description: "Esegue l'audit-completa prima di un rilascio"
agent: coordinatore
---

Carica la skill `squadra-audit` e segui la procedura.

Ambito: $ARGUMENTS

1. Esegui l'audit a basso consumo: ondate, un tester e un validatore per ondata, massimo 2 tentativi per area.
2. Scrivi il report in `docs/progetto/test/audit-AAAA-MM-GG.md` con esito, aree BLOCCATE e residui.
3. Se un'area non e' provabile nella UI, dichiarala BLOCCATA (non "SUPERATA con residuo").
4. Riferisci ad Andrea in italiano semplice.
