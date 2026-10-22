# Report — Bandi: ATECO con punto e filtro provincia

**Verdetto: SUPERATO** (verifica automatica e deploy staging)

## Modifiche

- Campo ATECO mobile: tastiera decimale, formatter `[0-9.]`, massimo 8 caratteri, hint `es. 62.01`.
- `matchAtecoBando`: estrae solo le cifre, quindi `62.01` viene confrontato come prefisso `62`.
- Filtro Provincia con le 107 province italiane (`lib/data/province_italia.dart`).
- `matchProvinciaBando`: usa `Bando.province` se presente; altrimenti usa la regione della provincia.
- Nota UI quando il filtro provincia è attivo: i bandi open data non sempre indicano la provincia.
- Modello `Bando` e parser import aggiornati con `province`.

## Verifiche

| Controllo | Comando | Esito |
|---|---|---|
| Analisi | `cd flutter_app && flutter analyze` | 0 problemi |
| Test | `flutter test` | 509 verdi |
| Test mirati | `flutter test test/bandi_screen_test.dart` | 35 verdi |
| Deploy | `firebase deploy --only hosting:flutter` | completato su staging |

Test aggiunti: ATECO `62.01`; provincia esplicita (`MI` sì, `TO` no); fallback regione;
bandi `tutteRegioni`; filtro combinato.

## Limite dichiarato

I bandi open data attuali non contengono quasi mai la provincia: il filtro è preciso
solo quando il campo `province` è presente, altrimenti filtra la regione della provincia.
