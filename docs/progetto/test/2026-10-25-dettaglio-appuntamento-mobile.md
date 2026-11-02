# Dettaglio appuntamento su telefono e tablet

**Data**: 25/10/2026
**Ambiente**: staging `https://commerciali-app.web.app` (progetto Firebase `commerciali-app`)

## Criteri verificati

1. Su telefono il dettaglio occupa quasi tutto lo schermo e il contenuto scorre.
2. Le sezioni sono leggibili: Panoramica, Cliente, Condivisione, Dettagli, Allegati.
3. La X in alto a destra chiude il dettaglio.
4. Le azioni sono allineate a tutta larghezza e non escono dallo schermo.
5. Su tablet la finestra è più larga e i gruppi di azioni restano separati a destra.

## Modifiche

- `DettaglioElementoDialog` sostituisce l'`AlertDialog` stretto: intestazione con titolo, data/ora, stato e
  pulsante di chiusura; contenuto in `SingleChildScrollView`; barra azioni fissa con divisore.
- Su schermi sotto 600 px le azioni sono in colonna (`Confermo`, `Non disponibile`, `Modifica`, `Elimina`);
  sopra i 600 px sono due `Wrap` affiancati, allineati a destra.
- Larghezza della finestra: `min(560, larghezza schermo - 24)`.
- **Apri in Google Maps**, **Apri call** e **Modifica cliente** sono pulsanti nel contenuto.

## Prove

| Prova | Esito |
|---|---|
| `flutter analyze` | 0 problemi |
| `flutter test` | 867 test verdi |
| `flutter test test/calendario_test.dart` | 33 test verdi, inclusi layout telefono/tablet, allineamento e chiusura |
| Chrome reale 390×844 (DPR 2) | dettaglio leggibile, azioni impilate e allineate, nessun overflow |
| Chrome reale 900×900 | finestra 560 px, due gruppi di azioni a destra |
| Dati di prova | utente/azienda/cliente/appuntamento temporanei creati e poi eliminati |

Screenshot: `2026-10-25-dettaglio-appuntamento-telefono.png`,
`2026-10-25-dettaglio-appuntamento-tablet.png`.
