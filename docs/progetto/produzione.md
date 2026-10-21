# Produzione — inventario e operazioni

> **Stato attuale: produzione non ancora creata.** L'unico ambiente è lo staging (`commerciali-app`).
> Questo file diventa operativo quando nascerà il progetto Firebase di produzione.

## Inventario

- Hosting statico Firebase: `index.html`, `js/`, asset.
- Firestore `(default)` in `europe-west8`.
- Firebase Auth (utenti email/password e Google).
- Cloudflare Worker `commerciali-vies`.

## Backup

Prima di qualsiasi modifica ai dati:

1. Export Firestore (Google Cloud → Firestore → Import/Export) su bucket dedicato.
2. Verifica che l'export sia leggibile e completo.
3. Registra data, dimensione e responsabile in questo file.

Non cancellare mai un backup.

## Operazioni

- Deploy hosting/regole: `firebase deploy --only hosting,firestore:rules`.
- Deploy Worker: `cd worker && npx wrangler deploy`.
- Rollback hosting: Firebase Hosting → Versioni → rollback alla versione precedente.
- Rollback regole: ripristinare `firestore.rules` dal commit precedente e rideployare.

## Registro operazioni

| Data | Operazione | Esito | Note |
|---|---|---|---|
| 2026-10-21 | Creazione progetto Firebase, Firestore, Auth, Hosting | OK | Migrazione da Supabase |
| 2026-10-22 | Deploy Worker VIES | OK | Piano gratuito Cloudflare |
