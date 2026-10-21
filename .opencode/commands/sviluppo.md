---
description: Avvia il flusso completo per un nuovo sviluppo
agent: coordinatore
---

Segui `AGENTS.md` e `docs/progetto/squadra-agenti-manuale.md`.

Richiesta di Andrea: $ARGUMENTS

Avvia il flusso completo:
1. `analista` → requisiti e criteri di accettazione.
2. `architetto` / `dba` / `designer-frontend` solo se servono.
3. `sviluppatore-backend` e/o `sviluppatore-frontend`.
4. `tester` (obbligatorio), poi `redattore-manuale`, poi `validatore`.
5. Se è un nuovo sviluppo, aggiorna `docs/progetto/da-validare.md` e fermati in attesa di Andrea.
6. Prepara il commit e apri una PR verso `staging`; non unire mai la PR.

Riferisci a cose fatte, in italiano semplice. Non dichiarare completato senza SUPERATO e APPROVATO.
