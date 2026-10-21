# Architettura — Commerciali

## Stack

- Frontend statico: HTML + Alpine.js + Tailwind (CDN), `index.html` + `js/`.
- Dati e auth: Firebase (Firestore, Auth, Hosting).
- Integrazione VIES: Cloudflare Worker.

## Flusso dati

`index.html` (Alpine) → `js/app.js` (store e pagine) → `JS SP` (`js/sp-firestore.js`) → Firestore.
`js/auth.js` gestisce Firebase Auth e il profilo `utenti/{uid}`.
Il Worker VIES è chiamato da `SP.cercaVIES` e `SP.verificaPIVA`.

## Multi-azienda

Ogni documento aziendale ha `azienda_id`. La membership è `membri/{aziendaId}_{uid}`.
Le regole Firestore verificano l'appartenenza; il super admin è `utenti/{uid}.super_admin`.

## Note

- `js/supabase.js` è legacy e non viene caricato.
- Non ci sono build step: il deploy è la copia dei file su Firebase Hosting.
