# Creazione dal mese: appuntamento, visita o task

**Data**: 02/11/2026
**Ambiente**: staging `https://commerciali-app.web.app` (commit `373c5ce`)

## Criteri verificati

1. Nella vista **Mese** il tocco su un giorno apre la scelta, senza passare alla vista giorno.
2. La scelta propone **Appuntamento**, **Visita** e **Task**.
3. La data scelta viene passata al form aperto.
4. Il pulsante **+** apre la stessa scelta.
5. Il form del task accetta la data iniziale.

## Prove

| Prova | Esito |
|---|---|
| UI staging, tocco giorno 26 | resta sulla vista Mese; compare "Cosa vuoi creare il 26/10/2026?" con le tre voci |
| UI staging, scelta Visita | apre "Nuova visita" con data 26/10/2026 |
| UI staging, + poi Task | apre "Nuovo task" con la data del giorno mostrato (02/11/2026) |
| Test widget `calendario_test.dart` | la scelta restituisce `task`; le tre voci sono presenti |
| Test widget `task_form_test.dart` | `dataIniziale` precompila la scadenza |
| `flutter analyze` | 0 problemi |
| CI GitHub Actions | workflow "Test automatici" verde (Flutter e Worker) |

Screenshot: `2026-11-02-scelta-tipo.png`, `2026-11-02-task-data.png`.

## Residui

- La visita creata dal calendario si trova nella sezione **Visite**; non viene mostrata nella griglia del calendario (comportamento esistente).
