# Impostazioni, utenti, ruoli, super admin

**Quando leggerlo**: utenti, permessi, ruoli, licenze, piani, WhatsApp, pannello super admin.
**File**: `js/app.js` (store `sessione`, pagine impostazioni/utenti/ruoli/superadmin), `js/sp-firestore.js` (utenti, membri, ruoli, licenze, piani, WhatsApp), `index.html`.

## Punti fermi

- Ruolo e permessi sono per azienda (`membri/{aziendaId}_{uid}`).
- Il super admin vede tutte le aziende e può entrare in una qualsiasi.
- Le licenze hanno piano, stato, date e limiti (`max_utenti`, `max_preventivi`).
- `piani_config` definisce pagine e limiti per piano.
- `whatsapp_config/1` contiene URL e API key del server WhatsApp.
- `Impostazioni → Calendario e integrazioni`: card Google/Microsoft (modalità app Closer o app propria) e stato SMTP/WhatsApp/R2/Push. I segreti non sono in Firestore: il Client Secret si attiverà con il Worker.
- `Impostazioni → Condivisione calendario`: condivisione con colleghi, livelli libero/occupato/dettagli/modifica, revoca e “Condivisi con me”.
- `integrazioni_azienda/{aziendaId}`: configurazione azienda; `condivisioni_calendario/{az}_{prop}_{dest}`: condivisione calendario.

## Test

- Creare/modificare un utente e cambiare ruolo.
- Verificare i limiti del piano e l'accesso del super admin a un'azienda.

**Ultima revisione**: 2026-10-24
