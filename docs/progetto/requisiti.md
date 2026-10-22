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

## 2026-10-22 — Panieri di prodotti (Closer Flutter)

_Documento dedicato previsto in `docs/progetto/panieri-prodotti.md`: non creato perché il ruolo analista può
scrivere solo questo file. Contenuto completo qui sotto._

**Obiettivo**: vendere un gruppo di prodotti come un unico "paniere", inserendo nel preventivo il solo prodotto
padre e facendo comparire i figli come righe già pronte.
**Utenti**: admin/titolare che configura i panieri; commerciale che li usa nei preventivi; chi genera il PDF.

**User story**
- Catalogo: come admin voglio indicare su un padre quali prodotti sono suoi figli e se entrano a prezzo zero.
- Preventivo: come commerciale voglio scegliere dal catalogo un prodotto e ritrovare i figli già inseriti con la
  stessa quantità.
- PDF: come commerciale voglio che le righe figlie siano riconoscibili come parte del paniere.

**Criteri di accettazione**
1. Il padre salva l'elenco figli in `figli_ids` (id di prodotti della stessa azienda); nessun campo nuovo sui
   figli, nessun documento duplicato.
2. `figli_ids` assente o vuoto = prodotto normale, comportamento identico a oggi.
3. `figli_a_zero` (booleano sul padre): attivo = figli a prezzo 0; spento = prezzo di anagrafica. Il padre usa
   sempre il proprio prezzo di anagrafica e non lo ricalcola.
4. Nell'editor preventivi Flutter si può cercare e scegliere un prodotto dal catalogo dell'azienda attiva.
5. Inserendo un padre con figli, ogni figlio diventa una riga singola con la stessa quantità del padre.
6. Le righe figlie mostrano il riferimento al padre (etichetta "Paniere: <padre>" o indentazione).
7. Dopo l'inserimento le quantità sono indipendenti: modificarne una non tocca le altre.
8. Padre già presente: si incrementano la sua quantità e quella dei figli già presenti; nessun duplicato.
9. Figlio già presente come riga singola: viene incrementato e marcato, senza duplicati.
10. Il totale è la somma delle righe, comprese quelle a prezzo 0.
11. Nel PDF le righe figlie sono riconoscibili; prezzi e totali coincidono con l'app.
12. Solo figli con lo stesso `azienda_id` del padre.
13. Nessuna modifica a `firestore.rules`: si usano le regole attuali.

**Casi limite**
- Figlio eliminato dal catalogo: riga non creata, avviso non bloccante, paniere valido con i figli esistenti.
- Padre senza figli: prodotto normale.
- Flag `figli_a_zero`: vale all'inserimento, non ricalcola righe già inserite.
- Più padri per lo stesso figlio: riga unica incrementata; etichetta del primo paniere (da confermare).
- Padre con se stesso in `figli_ids`: l'id viene ignorato.
- Quantità del padre modificata dopo l'inserimento: i figli non vengono ricalcolati.
- Quantità del padre portata a 0: i figli restano invariati (da confermare).

**Fuori ambito**
- Prezzo del paniere come somma dei figli, sconti o prezzi derivati.
- Panieri annidati (figlio che è a sua volta padre) in questa prima versione.
- Modifica in blocco dei figli, riordino o esclusione di singoli figli già inseriti.
- Eliminazione a cascata: cancellare padre o figlio non tocca i preventivi esistenti.
- Nuove collezioni, indici, migrazioni, Security Rules; restyling PDF; vecchia app Alpine.

**Impatto dati esistenti**: i prodotti attuali non hanno i nuovi campi e vengono letti come prodotti normali;
nessuna migrazione e nessuna scrittura di default; i campi si scrivono solo alla modifica del prodotto.

**Domande aperte per Andrea**
1. Un figlio può essere padre a sua volta (panieri annidati)?
2. Nel PDF i figli a prezzo 0 vanno mostrati "0,00 €" o "incluso"?
3. Etichetta "Paniere: <padre>" o indentazione (o entrambe)?
4. Se un figlio appartiene a due padri, quale nome si mostra nella riga?
5. Padre già presente con quantità 5 e reinserito: i figli vanno +1 o +5?
6. Limite al numero di figli? I figli devono essere attivi per essere scelti?


### Decisioni finali panieri (22/10/2026)

1. Niente panieri annidati in questa versione.
2. Figli a zero mostrati come `0,00 €` con etichetta del paniere.
3. Etichetta “Paniere: <padre>” più rientro visivo.
4. Se un figlio è in più panieri, ogni padre inserito crea la propria riga con il proprio nome.
5. Reinserendo un padre con quantità 5, padre e figli già presenti incrementano di 1.
6. Nessun limite al numero di figli; nella scelta si vedono solo prodotti attivi.

## 2026-10-22 — Amministrazione, ruoli e bandi

- L'azienda di appoggio VOLTY è stata rinominata **Closer**; non è un'azienda di produzione.
- Il superadmin può creare aziende con primo amministratore, ruoli seed, categorie e licenza trial.
- Il superadmin viene aggiunto come membro admin dell'azienda creata per poter gestire ruoli e categorie.
- La creazione di un utente usa una sessione Firebase secondaria: il profilo viene scritto dal nuovo utente,
  poi la sessione viene chiusa e l'app secondaria eliminata.
- I ruoli personalizzati hanno nome, descrizione, sconto massimo e permessi per area; i ruoli di sistema non si eliminano.
- L'import bandi è riservato al superadmin, accetta JSON open data da file o URL e aggiorna/aggiunge i bandi.
- L'import da URL può richiedere il file locale se il sito remoto blocca le richieste dal browser (CORS).
- Bandi è nel menu principale; il filtro ATECO usa il prefisso di 2 cifre e considera i bandi aperti a tutti.
- Resta fuori perimetro la modifica di licenze e piani (F18b) e l'import CSV.
