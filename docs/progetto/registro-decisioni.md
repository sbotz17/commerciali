# Registro decisioni

## 2026-10-22 — Squadra di sviluppo strutturata

Richiesta di Andrea: tutti gli sviluppi usano la squadra descritta in
`docs/progetto/squadra-agenti-manuale.md`. La regola è in `AGENTS.md`; il coordinatore non scrive codice e
delega a sotto-agenti. Tester e validatore sono obbligatori; i nuovi sviluppi richiedono la validazione di
Andrea. Stato: attiva.

## 2026-10-21 — Migrazione da Supabase a Firebase

Supabase non è più raggiungibile (NXDOMAIN). Si riparte da database vuoto con Firebase:
Firestore + Auth (email/password e Google) + Hosting. Gli utenti si registrano autonomamente.
Le password non sono migrabili. Stato: completato.

## 2026-10-21 — Verifica P.IVA tramite VIES

La verifica P.IVA usa l'API VIES della Commissione europea tramite un Cloudflare Worker
(`worker/`), perché il browser non può chiamare VIES direttamente per CORS. Nessun costo e nessuna carta.
Stato: attivo.

## 2026-10-21 — Account amministratore di piattaforma

`bottiandrea83@gmail.com` è super admin. L'accesso è email/password (la passkey non funziona nel browser
automatizzato). Google resta attivo per gli altri utenti. Stato: attivo.
