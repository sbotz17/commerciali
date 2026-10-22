# Requisiti

_Una voce per sviluppo: data, obiettivo, user story, criteri di accettazione, fuori ambito._

## 2026-10-22 — Riscrittura Flutter

**Obiettivo**: riscrivere l'app Commerciali in Flutter per web, Android e iOS (Windows opzionale) usando lo stesso
backend Firebase (Firestore + Auth), senza migrare dati e senza aggiungere funzioni.

**User story**
Come titolare/amministratore di una PMI voglio usare la stessa app Commerciali su browser, telefono e tablet con
interfaccia nativa e stessa logica di oggi, così posso lavorare da ufficio e da fuori senza cambiare abitudini.
Come commerciale voglio ritrovare clienti, catalogo, preventivi, visite e bandi esattamente come ora, così il
passaggio alla nuova app non richiede formazione né reinserimento dati.

**Perimetro e strategia**
- Piattaforme: web, Android, iOS. Windows è opzionale e solo dopo la parità delle tre principali.
- Nuova app in `flutter_app/`, stesso progetto Firebase `commerciali-app`, stesse collezioni, regole, contatori
  e Worker VIES. Nessun backend nuovo.
- La vecchia app Alpine/Tailwind resta su staging e in uso finché la nuova non ha parità verificata area per area.
- Nessuna migrazione: la nuova app legge e scrive gli stessi documenti. Le due app possono convivere durante la
  transizione, ma non devono essere usate in parallelo sulla stessa operazione critica (numerazione preventivi).
- Il rilascio sostitutivo avviene solo dopo rapporto del tester, APPROVATO del validatore e validazione di Andrea.

**Parità funzionale e criteri di accettazione**
1. **Auth e onboarding** — Login email/password, Google, logout, recupero password, ripristino sessione, lettura
   profilo `utenti` per email, onboarding con creazione azienda/membro/seed, blocco utente `attivo=false`,
   super admin. *Criteri*: le tre piattaforme completano login e logout; il link di reset apre la schermata
   corretta; un utente disabilitato viene riportato al login; nessuna password è salvata nel database;
   l'onboarding di un'azienda nuova produce gli stessi documenti di oggi.
2. **Dashboard** — Saluto, conteggi preventivi (totale, in attesa, accettati), valore aperto, ultimi 5 preventivi,
   azioni rapide, elenco utenti attivi per gli admin. *Criteri*: per lo stesso utente e la stessa azienda i numeri
   coincidono con la vecchia app; i commerciali vedono solo i propri preventivi; nessun dato di altre aziende.
3. **Clienti + VIES** — Lista, ricerca, creazione, modifica, eliminazione, controllo duplicati per P.IVA o
   nome/codice fiscale, modale VIES informativa, normalizzazione P.IVA. *Criteri*: CRUD completo; P.IVA Ferrari
   `00159560366` valida con ragione sociale e indirizzo; P.IVA `00000000000` non valida; duplicato rilevato come
   oggi; la modale VIES non modifica il cliente; isolamento per `azienda_id`.
4. **Catalogo** — Prodotti e categorie con `azienda_id`, prezzo numerico, categoria per nome, `ordine` e `icona`,
   immagine gestita come nell'app attuale senza storage nuovo. *Criteri*: CRUD prodotto e categoria; filtro per
   categoria e ricerca per nome; ordinamento categorie e prezzo corretti; immagini visualize come oggi.
5. **Preventivi + PDF** — Creazione, modifica, eliminazione, stati, righe e totali con sconto e IVA, numerazione
   `PRV-0001` da contatore transazionale, revisioni `-R1`/`-R2` senza consumare il contatore, visibilità per
   utente, PDF generato dal client. *Criteri*: il primo numero dopo il passaggio continua la serie esistente;
   due creazioni simultanee non producono numeri duplicati; una revisione mantiene il numero base; totali e PDF
   coincidono con quelli della vecchia app per lo stesso preventivo; il commerciale non vede preventivi altrui.
6. **Visite** — Elenco e calendario, creazione, modifica, eliminazione, riordino, stati, filtro per data e cliente,
   campi promemoria. *Criteri*: ordinamento per `ordine` poi `ora`; cambio stato persistente; filtri corretti;
   nessuna visita di altre aziende.
7. **Bandi** — Consultazione pubblica senza login, lista, filtri, dettaglio, fonti, log di sincronizzazione,
   import manuale per super admin. *Criteri*: la pagina si apre senza autenticazione; filtri e dettaglio mostrano
   gli stessi contenuti; l'import scrive log e aggiorna la fonte come oggi; nessuna sync automatica su GitHub.
8. **Impostazioni, utenti, ruoli, licenze, super admin** — Membership `membri/{aziendaId}_{uid}`, ruoli e
   permessi, limiti di piano (`max_utenti`, `max_preventivi`), `piani_config`, visibilità pagine, gestione utenti,
   accesso super admin a tutte le aziende, `whatsapp_config` consultabile senza esporre la API key.
   *Criteri*: creazione/modifica utente e cambio ruolo; i limiti di piano bloccano come oggi; il super admin entra
   in una qualsiasi azienda; un utente senza permesso non vede la pagina né i dati; la API key WhatsApp non è
   mostrata in chiaro.
9. **Trasversale** — Testi in italiano, layout utilizzabile su telefono e desktop, stessi permessi di oggi.
   *Criteri*: nessuna azione disponibile senza permesso; nessuna lettura o scrittura fuori dall'azienda attiva;
   errori di rete mostrati con messaggio comprensibile; le regole Firestore restano invariate.

**Cosa NON è in ambito**
- Nuove funzioni, nuove schermate, nuovi campi, nuove collezioni, nuovi indici.
- Modifiche a `firestore.rules`, `piani_config`, contatori o Worker VIES.
- Migrazione, conversione o riscrittura dei dati esistenti.
- Restyling grafico oltre a quanto serve per una UI Flutter coerente.
- Sostituzione della vecchia app prima della parità validata.
- Produzione e ramo `main` (non esistono ancora); notifiche push, modalità offline e sincronizzazioni nuove non
  sono richieste e non vanno aggiunte.

**Rischi e dipendenze**
- Parità del PDF: il PDF attuale è generato con jsPDF nel browser; in Flutter serve un motore equivalente.
- Differenze SDK Firebase tra web e mobile (persistenza sessione, login Google, popup vs nativo).
- Contatore preventivi condiviso: un'implementazione diversa dalla transazione attuale può duplicare numeri.
- Doppia manutenzione durante la transizione e rischio di correzioni fatte solo su una delle due app.
- Assenza di suite automatica: la parità va verificata a mano su tre piattaforme, con costo di test elevato.
- Dipendenza dal Worker VIES e dalla rete; nessuna modifica al Worker è prevista.
- Gestione immagini prodotto e allegati: va confermato il comportamento attuale prima di replicarlo.

**Fasi consigliate**
1. Fondamenta: progetto `flutter_app/`, Firebase, auth, routing, permessi, tema, test su web/Android/iOS.
2. Anagrafiche: clienti + VIES, catalogo prodotti e categorie.
3. Preventivi: creazione, contatore, revisioni, totali, PDF.
4. Visite e bandi.
5. Impostazioni, utenti, ruoli, licenze, super admin.
6. Parità trasversale, prove multi-piattaforma, correzioni.
7. Tester, validatore, validazione Andrea, passaggio su staging.

**Domande aperte per Andrea**
1. Windows è richiesto davvero o resta opzionale senza data?
2. Il PDF deve essere graficamente identico o basta stesso contenuto e stessi totali?
3. Quale piattaforma va consegnata per prima (web, Android, iOS)?
4. Le immagini prodotto restano URL/immagini incorporate come oggi o servono caricamenti su storage?
5. Cosa deve fare l'app senza connessione: solo messaggio di errore o anche consultazione dei dati già caricati?
6. Dopo il passaggio, la vecchia app resta accessibile in parallelo o va dismessa subito?
7. I promemoria delle visite restano semplici campi o servono notifiche (non presenti oggi)?

