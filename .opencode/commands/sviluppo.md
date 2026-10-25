---
description: "Avvia il flusso completo per un nuovo sviluppo"
agent: coordinatore
---

Segui `AGENTS.md`, `CLAUDE.md` e la skill `squadra-sviluppo`.

Richiesta di Andrea: $ARGUMENTS

1. `analista` -> requisiti e criteri di accettazione (una sola volta con Andrea, se servono scelte).
2. `architetto` / `dba` / `designer-frontend` solo se servono.
3. `sviluppatore-backend` e/o `sviluppatore-frontend`, su ramo `feature/...` creato da `staging`; PR verso
   `staging`, mai verso `main`.
4. Se si toccano accessi, ruoli, permessi, dati personali, pagamenti, file o input: carica la skill
   `squadra-sicurezza-app` e fai fare una seconda lettura a un agente diverso da chi ha scritto il codice.
5. `tester` (obbligatorio), poi `redattore-manuale`, poi `validatore`.
6. Accettazione indipendente: prova vera nel browser di OGNI criterio concordato con Andrea, scritta in
   `docs/progetto/test/`. Un criterio non provato blocca il rilascio.
7. Aggiorna `docs/progetto/da-validare.md` e i nodi di memoria; commit e PR. Non unire mai la PR.
8. Con APPROVATO, accettazione completa, CI verde e GO del `guardiano-produzione` il rilascio e' automatico:
   non serve un'altra approvazione di Andrea.

Riferisci a cose fatte, in italiano semplice. Non dichiarare completato senza SUPERATO e APPROVATO.
