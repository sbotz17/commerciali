# Motore dei modelli — costi e scelte

Ultimo aggiornamento: 2026-10-22.

## Modelli disponibili

| Modello | Input $/M | Output $/M | Cache read $/M | Uso |
|---|---:|---:|---:|---|
| `deepseek/deepseek-flash` | 0,15 | 0,60 | 0,003 | lavori frequenti e a basso rischio |
| `deepseek/deepseek-v4-pro` | 0,66 | 1,98 | 0,022 | decisioni, sicurezza, codice critico |
| `google/gemini-3.8-flash` | 0,75 | 3,75 | 0,075 | non usato: più caro di DeepSeek Pro |
| `google/gemma-4-31b-it` | 0 | 0 | 0 | non usato: qualità insufficiente per codice |

## Assegnazione per ruolo

| Agente | Modello | Variante | Perché |
|---|---|---|---|
| coordinatore | Flash | high | orchestra, non scrive codice |
| analista | Flash | low | requisiti e criteri brevi |
| architetto | V4 Pro | high | scelte strutturali |
| dba | V4 Pro | high | regole Firestore e sicurezza |
| designer-frontend | Flash | low | layout e componenti |
| sviluppatore-backend | V4 Pro | high | logica, dati, integrazioni |
| sviluppatore-frontend | Flash | high | UI e collegamento dati |
| tester | Flash | low | esegue test e scrive report |
| validatore | V4 Pro | high | revisione finale |
| gestore-ritorni | Flash | low | classifica segnalazioni |
| risolutore-bug | V4 Pro | high | correzione precisa |
| guardiano-produzione | V4 Pro | high | GO/NO-GO |
| redattore-manuale | Flash | low | testi utente |
| marketing | Flash | low | materiali su richiesta |

## Costo indicativo di uno sviluppo medio

Con questa assegnazione: **circa 0,09–0,12 $** per sviluppo completo (analisi, architettura, backend,
frontend, test, validazione, documentazione). Tutto V4 Pro costerebbe circa 0,25 $; tutto Flash circa 0,03 $,
ma con più errori su dati e sicurezza.

La cache di DeepSeek è quasi gratuita: mantenere stabili `AGENTS.md` e il manuale aiuta a ridurre i costi.

## Regole pratiche

1. **Flash** per: requisiti, design, UI, test, classificazioni, manuale, marketing, stato.
2. **V4 Pro** per: architettura, database/regole, backend, validazione, bug, produzione.
3. Non usare Pro per riassunti o testi; non usare Flash per sicurezza e dati.
4. Passare ai subagenti solo il contesto necessario: file toccati, requisiti e criteri, non intere cartelle.
5. Riusare i documenti in `docs/progetto/` invece di rileggere il repository.
6. `steps` è limitato per ruolo per evitare loop costosi.
7. Misurare con `opencode stats --cost` e correggere se un ruolo consuma troppo.

## Come cambiare un modello

Modifica il campo `model:` in `.opencode/agents/<ruolo>.md`. I nomi validi si vedono con `opencode models`.
Le varianti disponibili per DeepSeek sono `#none`, `#low`, `#high`, `#max`.

Non cambiare modello durante un lavoro senza motivo: la scelta è già ottimizzata per costo/qualità.
