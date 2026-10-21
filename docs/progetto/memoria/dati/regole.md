# Regole Firestore e multi-azienda

**Quando leggerlo**: permessi, sicurezza, nuove collezioni, super admin.
**File**: `firestore.rules`, `firebase.json`, `docs/progetto/database.md`.

## Punti fermi

- `memberOf(aziendaId)` verifica `membri/{aziendaId}_{uid}`.
- Ogni lettura/scrittura aziendale passa da `azienda_id` e dalla membership.
- `super_admin` è `utenti/{uid}.super_admin == true`.
- La prima membership è consentita solo a chi ha creato l'azienda (`created_by`).
- `licenze` e `ruoli` hanno regole più strette (admin/super admin).
- I bandi sono pubblici in lettura; la scrittura è riservata al super admin.
- `whatsapp_config` è leggibile dagli autenticati: contiene una API key, non esporla.

## Deploy

```sh
firebase deploy --only firestore:rules --project commerciali-app
```

**Ultima revisione**: 2026-10-22
