# Processo — bug e ritorni

**Quando leggerlo**: segnalazione di malfunzionamento.
**Riferimento**: `docs/progetto/squadra-agenti-manuale.md`, `docs/progetto/ritorni.md`.

```
segnalazione → gestore-ritorni → CONFERMATO → risolutore-bug → tester → validatore → rilascio
```

- Solo i `CONFERMATO` producono codice.
- La correzione ripristina il comportamento documentato: niente funzioni nuove.
- Se serve una migrazione o una zona protetta, diventa uno sviluppo.
- Aggiorna il nodo dell'area e il registro `ritorni.md`.

**Ultima revisione**: 2026-10-22
