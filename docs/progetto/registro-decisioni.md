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

## 2026-10-23 — Agenda, notifiche, chat e integrazioni

- Nuova area **Calendario + appuntamenti + task + promemoria**, collegata alle visite.
- Integrazioni richieste: Google Calendar/Meet, Microsoft 365/Outlook/Teams, SMTP per azienda, WhatsApp server Volty, Cloudflare R2 per le immagini.
- **Tutte le collezioni e le Security Rules nuove sono approvate** da Andrea (appuntamenti, task, promemoria, notifiche, dispositivi, allegati, impostazioni agenda/notifiche, integrazioni, slot, prenotazioni, chat).
- Notifiche: **in-app + push web/Android/iOS + WhatsApp operatore**; ogni operatore configura il proprio numero; orari di silenzio dinamici; tutti gli utenti possono inviare comunicazioni.
- Push iOS richiede **Apple Developer/APNs**: Andrea non ha ancora l'account, quindi iOS resta predisposto ma non attivo finché non viene fornito.
- WhatsApp: server Volty esistente; API key da spostare in secret lato server, non leggibile dal client.
- Email: **SMTP dedicato configurabile per ogni azienda**, con credenziali cifrate lato server.
- Allegati: **Cloudflare R2** (scelta di Andrea), non Firebase Storage.
- Call: creazione automatica di Google Meet/Teams; licenze e configurazioni Azure/Google da verificare.
- Chat interna: dirette 1-a-1 + gruppi, testo e immagini, letture, ricerca, soft delete, notifiche in-app/push; WhatsApp non usato per la chat.
- Stato: requisiti e architettura pronti; implementazione a micro-task, prima DBA poi modelli/UI, integrazioni all'arrivo delle credenziali.

## 2026-10-24 — Calendario classico predefinito

Richiesta di Andrea: nell'app l'agenda deve aprirsi con la classica vista a calendario, non con l'elenco a
card. Periodi disponibili: **giorno**, **settimana**, **mese**; lo stile **Card** esistente resta
selezionabile per tutti e tre i periodi. Scelta di partenza: calendario **mensile**, perché dà subito la
visione d'insieme; il periodo scelto dall'utente vale solo per la sessione. Nessuna nuova collezione, regola
o dipendenza: solo UI e funzioni pure, coperte da test.

## 2026-10-24 — Inviti appuntamento con conferma disponibilità

Richiesta di Andrea: condividere un appuntamento con un collega o un gruppo, inviare una notifica e
lasciare l'appuntamento **provvisorio** fino alla conferma. Scelte:

- nessuna nuova collezione: `invitati_uids`, `conferme` e `stato_condivisione` su `appuntamenti`;
- i gruppi sono le stanze chat di tipo `gruppo` già esistenti, selezionabili insieme alle singole persone;
- l'invitato conferma dal dettaglio aperto dalla notifica (`/calendario?appuntamento=…`); la risposta è
  registrata in transazione per non perdere conferme simultanee;
- la prima conferma porta lo stato a `confermato`; tutti i rifiuti a `rifiutato`; altrimenti `in_attesa`.
  Lo stato `stato` dell'appuntamento (da fare/fatto/annullato) resta separato.

## 2026-10-24 — Allegati e promemoria senza R2/Blaze

Cloudflare R2 non è abilitato sull’account e Firebase non è sul piano Blaze: non è possibile usare R2 né
Cloud Functions. Per non lasciare le funzioni incompiute:

- **Allegati**: file (immagini, video, PDF, email) nel KV del Worker `ALLEGATI`, max 10 MB per file;
  metadati in `allegati`. È una soluzione temporanea, da migrare a R2 quando sarà attivo.
- **Promemoria**: code nel KV `PROMEMORIA`, Cron del Worker ogni minuto; l’invio avviene via WhatsApp
  usando la configurazione del server. Non c’è ancora push/In-App programmato: per quello serve Blaze.
- **Privacy**: i dettagli degli appuntamenti privati sono in `appuntamenti/{id}/privato/dettagli`,
  leggibili solo da creatore, operatore e super admin; il documento principale resta redatto.

## 2026-10-24 — Audit completo e blocco nuove funzioni

**Decisione**: dopo i bug sfuggiti su WhatsApp, push e accesso, le nuove funzioni sono congelate. La squadra
esegue un audit per aree (`docs/progetto/test/audit-completa.md`) con test automatici, prova E2E reale nella
UI pubblicata, report tester e validazione. Un'area senza prova UI è `BLOCCATA`, non “SUPERATA con residuo”.

**Motivo**: i test precedenti coprivano pezzi isolati e non il flusso usato dall'utente. La fiducia si
ricostruisce con prove ripetibili, non con nuove funzioni.

**Effetto**: nessun rilascio e nessuna nuova funzione fino alla chiusura delle aree AU01–AU15.

## 2026-10-25 — Promemoria automatico al cliente

- Andrea ha chiesto che il cliente riceva il promemoria **automaticamente** al salvataggio e alla modifica
  di data/ora, su **WhatsApp, email o entrambi** in base ai recapiti presenti.
- Canali scelti per singolo appuntamento (interruttore "Avvisa il cliente" + WhatsApp/Email), predefiniti
  entrambi; il form scarta i canali senza recapito.
- L'invio non parte dal browser: il Worker legge appuntamento e cliente, compone il testo e chiama il server
  WhatsApp o il provider email. Nessun testo libero o destinatario arbitrario dal client.
- Email tramite **Resend** con un mittente unico di piattaforma configurato in **Super Admin → Server email**
  (API key nel KV `EMAIL_CONFIG`). È una scelta MVP: resta aperta la configurazione SMTP per singola azienda
  prevista dall'architettura.
- Idempotenza per appuntamento + impronta di data/ora e limite di frequenza per utente; nessun doppio invio
  sullo stesso orario.
- Stato: attivo su staging; l'email resta da attivare inserendo la API key Resend.

## 2026-10-25 — Correzioni agenda: lingua, luogo/note, ripetizione e WhatsApp

- Il calendario e i selettori di data usano **italiano** anche nei testi Material (mese, giorni, pulsanti),
  tramite `flutter_localizations` e locale `it`.
- **Luogo e note** è la sezione subito sotto data/ora; la ripetizione viene dopo.
- Il giorno di inizio di una ripetizione settimanale è sempre selezionato; cambiando la data il giorno
  automatico precedente viene sostituito, non aggiunto. I giorni scelti a mano restano.
- Il server WhatsApp in uso è **VOLTY** (`/invia`), non il vecchio `/send`: il Worker supporta entrambi e
  normalizza lo stato; l'invio manuale dal dettaglio permette di ritentare con conferma.
- Le regole `utenti` impediscono l'auto-assegnazione di `super_admin`, `ruolo` e `attivo`; test E2E su
  staging conferma 403.
- Aggiunto workflow GitHub Actions `Test automatici` per `flutter analyze`, `flutter test` e test Worker.
