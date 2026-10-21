---
description: "Prepara un export Firestore verificato"
agent: coordinatore
model: deepseek/deepseek-flash#low
---

Chiama `guardiano-produzione` e prepara un export Firestore verificato dello staging.

1. Elenca cosa si sta per modificare.
2. Esegui l'export su un bucket dedicato.
3. Verifica che l'export sia leggibile e completo.
4. Registra data, dimensione e responsabile in `docs/progetto/produzione.md`.

Non cancellare né sovrascrivere backup. Se l'export non è verificabile, fermati.
