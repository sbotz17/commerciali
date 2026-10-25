# Registro delle funzionalità — Closer staging

**Data**: 26/10/2026
**Build provata**: `v1.0.0+1 · 2026.10.25-2359 · 551c6c7` (live `https://commerciali-app.web.app`)
**Utente di prova**: `e2e-ui-kdl5c715@commerciali.test` (azienda `cg3EiOl20WDXIw0mjl03`)
**Metodo**: Chrome reale automatizzato (Playwright) sulla UI pubblicata, più lettura diretta di Firestore/REST
per confermare i permessi. Nessun dato preesistente modificato: solo record di prova aggiunti.
**Scopo**: censire **tutte** le funzioni implementate e il loro stato reale. Una funzione non provata resta
`DA PROVARE`, non diventa “OK” per il fatto che la schermata si apre.

## Legenda

`SUPERATA` = provata in UI con evidenza · `IN CORSO` = alcune voci provate · `FALLITA` = bug confermato ·
`BLOCCATA` = non provabile (manca ambiente, permesso o dato) · `DA PROVARE` = nessuna prova ancora.

## Quadro d'insieme

| ID | Area | Funzioni implementate | Stato | Evidenza / residuo |
|---|---|---|---|---|
| AU01 | Auth e onboarding | login email, login Google, Face ID/passkey, reset password, sessione, utente disattivato, onboarding, creazione azienda, primo admin, ruoli | IN CORSO | login email e persistenza dopo reload OK (26/10). Google, passkey, reset, onboarding e disattivato da provare |
| AU02 | Dashboard | conteggi, valore aperto, ultimi preventivi, azioni rapide, dati per azienda | IN CORSO | schermata e azioni rapide visibili; conteggi con dati reali da verificare |
| AU03 | Clienti | elenco, ricerca, creazione, modifica, eliminazione, duplicati, VIES, isolamento azienda, persistenza | SUPERATA (parziale) | creazione, elenco, ricerca, duplicato, VIES, modifica e persistenza OK (25/10). Eliminazione non provata |
| AU04 | Catalogo | prodotti, categorie, immagini, codici, panieri, filtri | SUPERATA (parziale) | categorie, prodotti, ricerca, filtro, paniere e persistenza OK (26/10). Immagine ed eliminazione non provate |
| AU05 | Preventivi | elenco, filtri, creazione, modifica, eliminazione, righe, sconti, IVA, totali, numero `PRV-`, revisioni, PDF, riapertura | IN CORSO | creazione, numero, totali, riapertura e PDF `PRV-0001.pdf` OK (26/10). Modifica, eliminazione, revisioni e invio da provare |
| AU06 | Visite | elenco per giorno, creazione, modifica, eliminazione, riordino, stati, calendario, filtri, promemoria | IN CORSO | creazione visita OK (26/10). Resto da provare |
| AU07 | Calendario e appuntamenti | giorno/settimana/mese, creazione, ricorrenza, tutto il giorno, privato, partecipanti, call, Maps, allegati, condivisione, promemoria | IN CORSO | creazione appuntamento OK (26/10). Ricorrenza, inviti, call, Maps, allegati, condivisione e promemoria da provare |
| AU08 | Task | elenco, filtri, creazione, modifica, eliminazione, scadenza, priorità, utente, completamento | IN CORSO | creazione e comparsa in elenco OK (26/10). **Accessibilità**: il testo delle card non entra nell'albero semantico (R-3). Modifica/eliminazione da provare |
| AU09 | Notifiche | centro, badge, lette/non lette, “segna tutte”, preferenze, push web, WhatsApp personale, silenzio, anteprima | FALLITA | centro e badge OK. **Preferenze**: `permission-denied` al primo accesso (R-2), schermata “Non hai i permessi” |
| AU10 | Chat | chat dirette, gruppi, messaggi, immagini, letture, badge, notifiche, isolamento | BLOCCATA | schermata OK; con un solo utente in azienda non è possibile creare una chat (serve un secondo utente) |
| AU11 | Bandi | elenco, ricerca, filtri, dettaglio, link, import superadmin | IN CORSO | elenco reale, ricerca e filtri OK (26/10). Dettaglio, link e import da provare |
| AU12 | Impostazioni | profilo, azienda, utenti, ruoli, licenze, superadmin, integrazioni, agenda, condivisione calendario, Face ID | IN CORSO | tutte le schermate si aprono. Errore CORS `passkeyElenco` visto alle 23:59, non più riprodotto alle 00:12 (funzioni ridepoyate). Face ID da provare |
| AU13 | Integrazioni | server WhatsApp, SMTP/email, push VAPID/FCM, Google/Microsoft, R2, errori e retry | DA PROVARE | schermata si apre; nessun invio reale provato |
| AU14 | Trasversale | permessi, multi-azienda, errori rete, mobile/desktop, reload, cache, segnaposto, deep link | IN CORSO | reload su rotta protetta mantiene la sessione OK. URL duplicato `/clienti#/clienti` da verificare. Mobile/desktop e multi-azienda da provare |
| AU15 | Produzione | progetto separato, Auth, DB, regole, hosting, dati vuoti, admin | BLOCCATA | progetto `commerciali-prod` non ancora creato; nessuna prova possibile |

## Bug confermati in questa sessione

### R-2 — Preferenze notifiche: “Non hai i permessi” al primo accesso (P1)

- Riproduzione: utente nuovo senza documento `impostazioni_notifiche/{azienda}_{uid}` → Impostazioni →
  Notifiche → “Preferenze non disponibili · Non hai i permessi per cambiare le notifiche”.
- Verifica diretta: `GET` Firestore sul documento inesistente con il token dell'utente → **HTTP 403**
  `PERMISSION_DENIED`.
- Causa: la regola legge `resource.data.utente_uid` anche quando il documento non esiste; Firestore nega.
- Correzione: `allow read` accetta anche `resource == null`; il servizio tratta `permission-denied` come
  “nessuna preferenza salvata” e usa i valori predefiniti. Il documento viene creato al primo salvataggio.

### R-3 — Task: titolo e dettagli non leggibili dall'albero di accessibilità (P2)

- Riproduzione: Task → Nuovo task → “Audit Task 2026-10-25” → la card è visibile a schermo, ma il testo
  semantico contiene solo “Senza scadenza · 2 · Azioni”.
- Effetto: screen reader e test UI non leggono il contenuto della card; il controllo automatico non può
  verificare i task creati.
- Correzione da fare: avvolgere la card in `Semantics`/`MergeSemantics` con titolo e dettagli.

## Osservazioni di processo (causa dei bug che arrivano ad Andrea)

1. **Staging non è fermo su una versione**: pubblicato alle 23:34, 23:46, 23:59 e 00:03 mentre l'audit era in
   corso. La build provata cambia sotto i piedi e i difetti “spariscono” o “ricompaiono” senza una correzione.
2. **La regola del gate non è applicata dallo strumento**: “niente deploy senza audit” è scritto, ma il
   comando `firebase deploy` non controlla nulla. Servono un blocco tecnico e un'unica corsia di rilascio.
3. **Test E2E fragili e non in CI**: gli script cercavano “Tab 4 of 10”, l'interfaccia ora dice “Scheda 4 di
   10”; nessuno se n'è accorto. I test UI vanno nella CI o vengono eseguiti a ogni ondata con etichette stabili.
4. **Lavoro in parallelo sulla stessa cartella**: più sessioni scrivono e committano gli stessi file; una
   sessione ha già incluso per errore il lavoro di un'altra (`git add -A`). Serve un lavoro per worktree.
5. **Il ramo `staging` non contiene l'app Flutter**: il deploy parte dalla cartella locale del ramo di
   sviluppo. Non esiste un legame tra commit, build e sito pubblicato.

## Prossime prove (in ordine)

1. Chiudere AU05: modifica, eliminazione, revisione, invio.
2. Chiudere AU01: Google, passkey, reset password, onboarding, utente disattivato.
3. AU09: preferenze notifiche dopo la correzione R-2; push reale; WhatsApp personale.
4. AU07/AU06: ricorrenza, inviti, call, Maps, allegati, condivisione, promemoria.
5. AU12/AU13: utenti, ruoli, licenze, superadmin, integrazioni reali.
6. AU08/AU10/AU11/AU14/AU15.

Ogni voce chiusa richiede: prova UI con screenshot o log, persistenza dopo reload, nessun errore console,
tester `SUPERATO` e validatore `APPROVATO`.
