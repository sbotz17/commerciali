# Diario di lavoro

## 2026-10-21/22 — Migrazione a Firebase

- Creato progetto `commerciali-app`: Firestore `europe-west8`, Auth email/password + Google, Hosting.
- Nuovo data layer `js/sp-firestore.js` con la stessa interfaccia `SP` (70 funzioni).
- Nuovo `js/auth.js` con Firebase Auth e profilo `utenti/{uid}`.
- Regole Firestore multi-azienda in `firestore.rules`.
- Verifica P.IVA spostata su VIES tramite Cloudflare Worker (`worker/`).
- Test in locale: registrazione, onboarding, clienti, prodotti, utenti, impostazioni.
- Dati di test eliminati; database vuoto per la registrazione autonoma.
- Creato account super admin `bottiandrea83@gmail.com` e azienda di appoggio VOLTY.

## 2026-10-22 — Squadra e ambienti

- Introdotta la regola della squadra in `AGENTS.md` e i 14 agenti OpenCode.
- Creato il ramo `staging`, unico ambiente operativo con Firebase `commerciali-app`.
- La produzione sarà un progetto Firebase separato, da creare più avanti.

## 2026-10-22 — Task F01: scaffold Flutter

- `flutter create --org it.commerciali --project-name commerciali_app --platforms web,android,ios flutter_app` → OK (82 file).
- `flutter pub add firebase_core firebase_auth cloud_firestore google_sign_in flutter_riverpod go_router intl pdf printing url_launcher` → OK (56 dipendenze).
- `flutter analyze` dentro `flutter_app/` → esito: `No issues found! (ran in 2.5s)`.
