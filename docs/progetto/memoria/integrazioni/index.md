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
| Web Push | `../../test/2026-10-24-produzione.md` | VAPID + service worker + Cloud Function attiva in produzione |
| FCM/VAPID/APNs | `push.md` (da creare) | solo Web Push ora; mobile e APNs da fare |

**Ultima revisione**: 2026-10-24
