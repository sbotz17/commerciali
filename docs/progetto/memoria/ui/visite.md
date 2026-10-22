# Giro visite

**Quando leggerlo**: appuntamenti, visite, calendario, stati.
**File**: `js/app.js` (pagine visite), `js/sp-firestore.js` (`getVisite`, `aggiungiVisita`, `aggiornaVisita`, `eliminaVisita`, `riordinaVisite`, `getVisiteCliente`, `getVisitePeriodo`).

## Punti fermi

- Ogni visita ha `azienda_id`, `data`, `ora`, `ordine`, `stato`, `cliente_id`.
- Gli stati tipici: `da_fare`, `fatto`, altri stati applicativi.
- L'ordinamento è per `ordine` e poi `ora`.
- I promemoria sono campi della visita, non un servizio separato.

## Test

- Creare una visita, riordinarla, cambiare stato, filtrarla per data e cliente.

**Flutter**: `VisiteScreen` e `VisitaFormScreen` in `flutter_app/lib/features/visite/visite_screen.dart`; stessi campi e stesso ordinamento.

**Ultima revisione**: 2026-10-22
