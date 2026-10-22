# Report — Scelta catalogo sulla riga articolo

**Verdetto: SUPERATO**

## Modifiche

- Aggiunta l'icona **Scegli dal catalogo** su ogni riga del preventivo:
  - card mobile, accanto al cestino;
  - tabella desktop, nella cella Descrizione.
- Selezionando un prodotto normale la riga viene compilata con nome, prezzo,
  unità `pz` e IVA 22; quantità e sconto restano quelli inseriti.
- Selezionando un prodotto padre (paniere), la riga viene sostituita dal padre
  e dai sotto-prodotti, con l'etichetta "Paniere: ...".
- Il prodotto scelto viene salvato in `prodottoId`; per i prodotti normali il
  paniere viene azzerato.
- Resta disponibile anche il pulsante generale "Dal catalogo".

## Verifiche

| Controllo | Comando | Esito |
|---|---|---|
| Analisi | `cd flutter_app && flutter analyze` | 0 problemi |
| Test | `flutter test` | **511 verdi** |
| Test mirati | `preventivo_riga_catalogo_test.dart`, `preventivo_edit_screen_test.dart`, `panieri_test.dart` | verdi |
| Deploy | hosting staging | completato |

Prova reale su staging: aperto un nuovo preventivo, aggiunta una riga, toccata
l'icona catalogo, scelto **Prodotto Riga Test** (123,00 €). La riga è stata
compilata e il totale è diventato **123,00 €**.
Screenshot: `docs/progetto/test/2026-10-23-riga-catalogo.png`.

Il prodotto e l'utente di prova sono stati eliminati dopo la verifica.

## Nota

Se il prodotto scelto è un padre, vengono inseriti anche i sotto-prodotti; è lo
stesso comportamento del pulsante generale "Dal catalogo".
