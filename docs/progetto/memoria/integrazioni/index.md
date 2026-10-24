# Integrazioni esterne

**Quando leggerlo**: servizi esterni, proxy, API.
**File**: `worker/`, `js/sp-firestore.js`.

| Integrazione | Nodo | Stato |
|---|---|---|
| VIES (P.IVA) | `vies.md` | attiva, Cloudflare Worker |
| WhatsApp | `../ui/impostazioni.md` | server esterno configurato dal super admin |
| Bandi | — | dati pubblici, sync locale |
| Google Calendar/Meet | `google.md` (da creare) | UI impostazioni pronta; Worker OAuth da fare |
| Microsoft 365/Teams | `microsoft.md` (da creare) | UI impostazioni pronta; Worker OAuth da fare |
| SMTP | `smtp.md` (da creare) | card pronta; invio e secret nel Worker da fare |
| Cloudflare R2 | `r2.md` (da creare) | card pronta; upload firmato da fare |
| FCM/VAPID/APNs | `push.md` (da creare) | configurazione piattaforma superadmin |

**Ultima revisione**: 2026-10-24
