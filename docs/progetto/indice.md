# Indice del progetto — Commerciali

> **Radice della memoria ad albero.** Si legge questo file, poi **solo** i nodi pertinenti.
> Non serve rileggere tutto il repository.

## Come si legge

1. Trova la richiesta nella tabella qui sotto.
2. Apri solo i nodi indicati.
3. Apri i file citati dal nodo, non l'intero progetto.
4. Se un nodo non basta, apri il nodo padre (es. `memoria/ui/index.md`).

## Albero

```
docs/progetto/
├── indice.md                     ← questo file (radice)
├── ambienti.md                   ← staging/produzione, URL, deploy
├── produzione.md                 ← backup e operazioni
├── registro-decisioni.md         ← decisioni e sospensioni
├── da-validare.md                ← sviluppi in attesa di Andrea
├── catalogo.md                   ← inventario oggetti (no duplicati)
├── requisiti.md                  ← user story e criteri
├── architettura.md               ← struttura tecnica
├── database.md                   ← schema Firestore
├── design.md                     ← layout e componenti
├── diario.md                     ← log del lavoro
├── ritorni.md                    ← segnalazioni R-
├── motore-modelli.md             ← modelli e costi
├── task.md                       ← registro dei task piccoli
└── memoria/
    ├── ui/
    │   ├── index.md              ← mappa delle schermate
    │   ├── login.md              ← accesso, Google, recupero, onboarding
    │   ├── dashboard.md          ← conteggi, valore aperto, ultimi preventivi
    │   ├── clienti.md            ← lista, form, P.IVA, duplicati
    │   ├── catalogo.md           ← prodotti e categorie
    │   ├── preventivi.md         ← preventivi, revisioni, numerazione
    │   ├── visite.md             ← giro visite
    │   ├── bandi.md              ← bandi, fonti, sync
    │   └── impostazioni.md       ← impostazioni, utenti, ruoli, super admin
    ├── dati/
    │   ├── index.md              ← interfaccia SP e convenzioni
    │   ├── collezioni.md         ← collezioni e campi
    │   ├── regole.md             ← firestore.rules e multi-azienda
    │   └── contatori.md          ← numerazione preventivi
    ├── integrazioni/
    │   ├── index.md              ← integrazioni esterne
    │   └── vies.md               ← verifica P.IVA
    └── processi/
        ├── sviluppo.md           ← flusso nuovo sviluppo
        ├── bug.md                ← flusso ritorni
        └── rilascio.md           ← staging e futura produzione
```

## Mappa richiesta → nodi

| Richiesta | Nodi da leggere |
|---|---|
| Login, registrazione, Google, password | `ui/login.md` |
| Dashboard, conteggi, ultimi preventivi | `ui/dashboard.md` |
| Clienti, P.IVA, duplicati | `ui/clienti.md`, `integrazioni/vies.md` |
| Prodotti, categorie, prezzi | `ui/catalogo.md` |
| Preventivi, PDF, revisioni, numeri | `ui/preventivi.md`, `dati/contatori.md` |
| Giro visite, appuntamenti | `ui/visite.md` |
| Bandi, fonti, import | `ui/bandi.md` |
| Utenti, ruoli, permessi, licenze | `ui/impostazioni.md`, `dati/regole.md` |
| Nuova collezione o campo | `dati/collezioni.md`, `dati/regole.md` |
| Dati, query, `SP` | `dati/index.md`, `dati/collezioni.md` |
| Verifica P.IVA / VIES | `integrazioni/vies.md` |
| Rilascio o deploy | `processi/rilascio.md`, `ambienti.md` |
| Bug o segnalazione | `processi/bug.md` |

## Manutenzione

- Ogni modifica al codice aggiorna il nodo dell'area (max 50 righe) e la data `Ultima revisione`.
- Se nasce un'area nuova, crea il nodo e aggiungilo qui.
- Il coordinatore può modificare solo `indice.md` e `memoria/`; il resto va delegato.
- Nodi obsoleti o file mancanti vanno segnalati, non ignorati.
