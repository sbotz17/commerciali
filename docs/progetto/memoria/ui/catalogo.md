# Catalogo prodotti e categorie

**Quando leggerlo**: prodotti, prezzi, categorie, immagini.
**File**: `js/app.js` (pagine catalogo/categorie), `js/sp-firestore.js` (`getProdotti`, `inserisciProdotto`, `aggiornaProdotto`, `eliminaProdotto`, `getCategorie`, ...).

## Punti fermi

- Prodotti e categorie hanno `azienda_id`.
- Il prezzo è numerico; la categoria è il nome della categoria.
- Le categorie hanno `ordine` e `icona`.
- Le immagini sono URL, non file caricati.

## Test

- Creare/modificare/eliminare prodotto e categoria; verificare ordinamento e prezzo.

**Ultima revisione**: 2026-10-22
