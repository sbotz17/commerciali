---
description: "Prepara e verifica un rilascio con la CI"
agent: coordinatore
---

Segui `AGENTS.md`, `CLAUDE.md` e la skill `squadra-rilascio`.

Richiesta: $ARGUMENTS

1. `guardiano-produzione` compila la checklist e da' GO/NO-GO.
2. Verifica: APPROVATO del `validatore`, accettazione indipendente (per gli sviluppi), backup verificato,
   rollback provato, CI verde, deploy di test verde per intero.
3. La promozione e il rilascio li fa SOLO la CI con la sua chiave dedicata. Gli agenti non usano credenziali
   di produzione e non fanno deploy manuali.
4. Se la CI non e' configurata o un controllo manca: NO-GO, decisione in sospeso in `registro-decisioni.md`,
   avviso ad Andrea.
5. Dopo il rilascio: verifica in sola lettura e prova del sito. Anomalia: rollback del codice e avviso
   immediato ad Andrea.

Riferisci l'esito in italiano semplice.
