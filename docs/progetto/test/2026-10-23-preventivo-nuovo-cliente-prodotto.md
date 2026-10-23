# Report — Nuovo cliente e nuovo prodotto dal preventivo

**Verdetto: SUPERATO**

## Nuovo cliente

- Nella card **Cliente e stato** del preventivo c'è il pulsante **Nuovo cliente**.
- Apre il form cliente, salva e torna al preventivo con il cliente selezionato.
- Prova reale: creato **Cliente Creato in Preventivo** e ritrovato selezionato.

## Nuovo prodotto

- Nel selettore **Dal catalogo** c'è il pulsante **Nuovo prodotto**.
- Apre il form prodotto con categorie e paniere, salva e torna al preventivo
  inserendo subito il prodotto nella riga.
- Prova reale: creato **Prodotto Nuovo in Quote**, inserito nella riga del preventivo.
  Screenshot: `docs/progetto/test/2026-10-23-preventivo-nuovo-cliente-prodotto.png`.

## Verifiche

| Controllo | Comando | Esito |
|---|---|---|
| Analisi | `cd flutter_app && flutter analyze` | 0 problemi |
| Test | `flutter test` | **517 verdi** |
| Deploy | hosting `commerciali-app` e `commerciali-flutter` | completato |

Nota: nella prova automatica il prezzo del prodotto è rimasto 0 perché il campo
prezzo non è stato compilato dall'automazione; la creazione e l'inserimento della
riga sono comunque avvenuti. I dati di prova sono stati eliminati.
