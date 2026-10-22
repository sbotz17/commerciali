# Registro decisioni

## 2026-10-22 — Redirect di autenticazione rinviato

Il redirect a livello di router (F07c) rischia di rompere i 92 test esistenti e di duplicare la logica di
sessione. Si implementa con un `AuthGate` dedicato dopo le prime schermate dati (F08+), prima della parità.
Nel frattempo la sicurezza dei dati resta garantita dalle regole Firestore.

## 2026-10-22 — Regola task piccoli e nodo dashboard

Su richiesta di Andrea, `AGENTS.md` introduce l'obbligo di spezzare ogni lavoro in task piccoli (1 file,
1 schermata o 1 servizio) e assegna un task alla volta. È un'aggiunta organizzativa: non modifica le
sezioni 2–19 del manuale della squadra. Aggiunto anche il nodo mancante `memoria/ui/dashboard.md`,
emerso durante l'analisi Flutter: era una lacuna documentale, non un cambio di perimetro.

## 2026-10-22 — Un solo ambiente: staging

Per ora esiste solo l'ambiente di **staging** (`staging` + progetto Firebase `commerciali-app`). La produzione
sarà un progetto Firebase separato, da creare quando il prodotto sarà pronto. Fino ad allora non ci sono
credenziali né deploy di produzione. Le PR vanno verso `staging`; `main` resta il futuro ramo di produzione.

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
