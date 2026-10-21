# Impostazioni, utenti, ruoli, super admin

**Quando leggerlo**: utenti, permessi, ruoli, licenze, piani, WhatsApp, pannello super admin.
**File**: `js/app.js` (store `sessione`, pagine impostazioni/utenti/ruoli/superadmin), `js/sp-firestore.js` (utenti, membri, ruoli, licenze, piani, WhatsApp), `index.html`.

## Punti fermi

- Ruolo e permessi sono per azienda (`membri/{aziendaId}_{uid}`).
- Il super admin vede tutte le aziende e può entrare in una qualsiasi.
- Le licenze hanno piano, stato, date e limiti (`max_utenti`, `max_preventivi`).
- `piani_config` definisce pagine e limiti per piano.
- `whatsapp_config/1` contiene URL e API key del server WhatsApp.

## Test

- Creare/modificare un utente e cambiare ruolo.
- Verificare i limiti del piano e l'accesso del super admin a un'azienda.

**Ultima revisione**: 2026-10-22
