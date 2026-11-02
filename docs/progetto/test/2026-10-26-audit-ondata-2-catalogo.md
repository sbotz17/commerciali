# Audit ondata 2 — Catalogo (staging)

**Data**: 26/10/2026
**Ambiente**: canale di anteprima `https://commerciali-app--r1-preventivo-a20lnjm1.web.app` (staging non toccato)
**Utente di prova**: `e2e-ui-9ho57ki9@commerciali.test` (azienda creata dall'app al primo accesso)
**Metodo**: Chrome reale automatizzato (Playwright) + verifica di persistenza dopo ricarica.

## AU04 — Catalogo: SUPERATA (con due voci non provate)

| Prova | Esito | Evidenza |
|---|---|---|
| Creazione categoria | OK | `Categoria AU04`, ordine 2, visibile nella scheda Categorie |
| Creazione prodotto con nome, codice, prezzo e categoria | OK | `AU04-1/2/3`, 10/20/30 €, categoria assegnata |
| Elenco prodotti con codice, categoria, prezzo | OK | colonne valorizzate per tutti e tre |
| Ricerca per nome | OK | cercando "Due" resta solo `Prodotto AU04 Due` |
| Filtro per categoria senza prodotti | OK | filtro `Generale` → "Nessun prodotto trovato" con suggerimento |
| Ritorno a "Tutte le categorie" | OK | tornano i tre prodotti |
| Paniere: selezione sotto-prodotti | OK | `Prodotto AU04 Uno` con Due e Tre selezionati |
| Badge paniere in elenco | OK | colonna figli = `2 figli` |
| Persistenza dopo ricarica completa | OK | prodotti, categorie e `2 figli` riletti da Firestore |
| Immagine prodotto (URL) | non provata | campo presente, non caricata un'immagine reale |
| Eliminazione prodotto/categoria | non provata | da coprire prima del rilascio |

Nessun errore console, nessuna richiesta fallita, nessun `permission-denied`.

## Dati di prova

Creati su staging e rimossi a fine prova con `e2e-ui-dati.py cleanup` (file di stato dedicato):
utente `e2e-ui-9ho57ki9@commerciali.test`, 1 categoria, 3 prodotti, paniere con 2 figli.

## Verdetto

**AU04 Catalogo**: `SUPERATA` per le voci provate. Restano da coprire immagini ed eliminazione.

## Stato ondata 2

| Area | Esito |
|---|---|
| AU03 Clienti | SUPERATA |
| AU04 Catalogo | SUPERATA (immagini ed eliminazione da provare) |
| AU05 Preventivi | IN CORSO — R-1 chiuso; restano revisioni e PDF |
