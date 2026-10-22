# Report — Codice prodotto e nuovo cliente dal giro visite

**Verdetto: SUPERATO**

## Codice prodotto

- Aggiunto `Prodotto.codice` (Firestore `codice`), salvato dal form catalogo.
- Il catalogo mostra la colonna **Codice** e il codice nel sottotitolo della lista.
- Il selettore prodotti del preventivo mostra il codice prima del prezzo.
- Scegliendo un prodotto, la riga del preventivo riceve `prodottoId` e `codice`.
- Prova reale: prodotto **Prodotto Codice Test** con codice **PRD-777** visibile in catalogo.
  Screenshot: `docs/progetto/test/2026-10-23-codice-prodotto.png`.

## Nuovo cliente dal giro visite

- Nel form **Nuova visita**, sotto la tendina Cliente, c'è il pulsante **Nuovo cliente**.
- Apre il form cliente esistente; dopo il salvataggio ricarica i clienti e seleziona
  automaticamente quello appena creato, senza perdere la visita.
- Prova reale: creato **Cliente da Visita** dal form visita e ritrovato selezionato
  nella tendina della visita.
  Screenshot: `docs/progetto/test/2026-10-23-visite-nuovo-cliente.png`.

## Verifiche

| Controllo | Comando | Esito |
|---|---|---|
| Analisi | `cd flutter_app && flutter analyze` | 0 problemi |
| Test | `flutter test` | **517 verdi** |
| Deploy | hosting staging | completato |

I dati di prova (cliente, prodotto PRD-777, utente temporaneo) sono stati eliminati.
