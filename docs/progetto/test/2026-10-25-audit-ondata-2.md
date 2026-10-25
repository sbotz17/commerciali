# Audit ondata 2 — Clienti e Preventivi (staging)

**Data**: 25/10/2026
**Ambiente**: staging `https://commerciali-app.web.app` (progetto `commerciali-app`)
**Utente di prova**: `e2e-ui-09pimd6b@commerciali.test`, azienda `oBhf4oI5Ngi36k5MeSwX`
**Metodo**: browser reale automatizzato (Chrome + Playwright) sulla UI pubblicata, più lettura diretta di
Firestore per confermare la persistenza. Nessuna modifica ai dati di produzione.

## AU03 — Clienti: SUPERATA

| Prova | Esito | Evidenza |
|---|---|---|
| Creazione cliente (ragione sociale, P.IVA, indirizzo, CAP, città, email, telefono) | OK | cliente `Audit Cliente 2026-10-25` in elenco |
| Comparsa in elenco | OK | riga con ragione sociale e comune |
| Persistenza dopo ricarica completa della pagina | OK | cliente presente dopo `reload` |
| Ricerca per nome | OK | filtro su "Audit" mostra il cliente |
| Ricerca senza risultati | OK | stato vuoto "Nessun cliente" |
| Duplicato | OK | avviso di cliente già esistente, nessun doppione creato |
| VIES con P.IVA valida (`00159560366`) | OK | "P.IVA valida — FERRARI S.P.A., VIA EMILIA EST 1163, 41122 MODENA MO" |
| VIES con P.IVA non valida (`00000000000`) | OK | "P.IVA non valida" |
| Modifica cliente (telefono) | OK | valore salvato e riletto dopo riapertura (`029999888`) |
| Eliminazione | non provata in questa ondata | rimandata alla prova di pulizia dati |

Nessun errore in console, nessuna richiesta fallita.

## AU05 — Preventivi: FALLITA (bug confermato)

### Cosa funziona

| Prova | Esito | Evidenza |
|---|---|---|
| Creazione preventivo con cliente, riga, quantità, prezzo, sconto | OK | documento `preventivi/vSIzlNVigkQjffxgmgDi` |
| Numerazione | OK | `PRV-0001` |
| Totali con sconto riga 2% | OK | subtotale 98,00 € (100 − 2%) |
| Salvataggio e comparsa in elenco | OK | riga `PRV-0001 · Audit Cliente 2026-10-25 · Bozza · 98,00 €` |
| Persistenza dopo ricarica | OK | `PRV-0001` ancora in elenco |

### Bug confermato

**Riaprire un preventivo esistente apre un editor vuoto "Nuovo preventivo".**

- Riproduzione: Preventivi → clic sulla riga `PRV-0001` → si apre l'editor con titolo "Nuovo preventivo",
  cliente "Seleziona un cliente", nessuna riga, totali a 0,00 €.
- Il preventivo salvato resta in elenco e su Firestore: i dati non sono persi, ma dall'interfaccia non è
  possibile riaprirlo né modificarlo.
- Causa nel codice: `flutter_app/lib/features/preventivi/preventivi_screen.dart:160-162`

```dart
void _apriPreventivo(Preventivo _) {
  context.go('/preventivi/nuovo');
}
```

Il parametro del preventivo viene ignorato e si naviga sempre alla rotta di creazione.

- Gravità: **alta** (P0 dell'audit: impedisce modifica e revisione dei preventivi esistenti).
- Correzioni successive: rigenerazione PDF di un preventivo esistente, revisioni e invio restano
  irraggiungibili dalla lista.

### Osservazione da chiarire (non ancora un bug)

Nel preventivo salvato la riga ha `ivaPerc: 22`, ma i totali hanno `iva: 0` e `totale_iva` uguale
all'imponibile. Il modello calcola l'IVA solo quando il documento è marcato "IVA inclusa"
(`flutter_app/lib/data/models/preventivo.dart:296-307`). Va verificato con i requisiti se è il
comportamento voluto o se manca un'informazione nella UI.

## Dati di prova creati (staging)

| Oggetto | Identificativo |
|---|---|
| Utente | `e2e-ui-09pimd6b@commerciali.test` |
| Azienda | `oBhf4oI5Ngi36k5MeSwX` |
| Cliente | `xKBhY92L0ulvEQvScS2w` — "Audit Cliente 2026-10-25" |
| Preventivo | `vSIzlNVigkQjffxgmgDi` — `PRV-0001`, 98,00 € |

## Nota: instabilità degli account di prova (chiarita)

Durante le prove due utenti creati dallo script sono spariti e l'onboarding è sembrato incoerente. Causa:
**due sessioni di lavoro hanno usato lo stesso file di stato** (`/tmp/opencode/e2e-ui.json`); il `cleanup`
di una sessione ha cancellato utente e azienda dell'altra mentre la prova era in corso.

Non è un difetto dell'app. Verificato con una prova dedicata: un utente creato con lo stesso metodo è
ancora presente e funzionante dopo 10 minuti.

Correzione nello strumento: `scripts/e2e-ui-dati.py` ora crea un file di stato per esecuzione
(`e2e-ui-<suffisso>.json`) e `cleanup` accetta `E2E_STATO=<file>`. Le sessioni in parallelo non si
cancellano più a vicenda.

## Verdetto

- **AU03 Clienti**: `SUPERATA`.
- **AU05 Preventivi**: `FALLITA` — bug confermato, da correggere prima del rilascio.
- L'audit completo resta **BLOCCATO**: AU01 e AU09 ancora aperti, AU02, AU04, AU06–AU08, AU10–AU15 da fare.
