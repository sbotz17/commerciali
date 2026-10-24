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

## 2026-10-23 — Calendario, appuntamenti, task e promemoria

**Obiettivo**: aggiungere a Closer un'agenda semplice che unisca visite, appuntamenti, task e promemoria,
collegabile a Google/Outlook e condivisibile col cliente, senza appesantire l'uso quotidiano.

**Utenti**: commerciale (crea e consulta), operatore (riceve task e promemoria), titolare/admin (configura),
super admin (integrazioni), cliente finale (riceve promemoria e prenota, senza account).

**Punto di partenza verificato**: esistono `giro_visite` (`data`, `ora`, `ordine`, `stato`, `cliente_id`,
`note`, `promemoria_*`), l'export ICS della vecchia app e `whatsapp_config/1` (`url`, `api_key`, `numero`,
`stato`) usato da `inviaWhatsapp` verso `/send`. Non esistono collezioni per task, allegati, token OAuth o
prenotazioni: vanno progettate prima di stimare (architetto/dba).

**Regole comuni**: 1. ogni dato ha `azienda_id` e si vede solo l'azienda attiva; 2. i permessi restano quelli
attuali; 3. testi in italiano semplice; 4. ogni azione esterna mostra esito (inviato, non inviato, da
riprovare); 5. nessun segreto visibile in schermate, log o link condivisi.

### 1. Calendario

**US**: come commerciale voglio vedere in un'unica agenda visite, appuntamenti e task del giorno e della
settimana.

**Criteri**
1. Voce "Calendario" nel menu accanto a Visite; viste giorno e settimana.
2. Ogni elemento mostra orario, cliente o titolo, operatore e stato; il tocco apre il dettaglio, il tocco su
   uno spazio vuoto crea un appuntamento con data e ora precompilate.
3. Filtri per operatore, tipo e stato; "Oggi" riporta alla data corrente.
4. Le visite esistenti compaiono senza migrazione e restano modificabili da "Visite"; un elemento senza ora
   va in "Senza orario".

**Aggiornamento 2026-10-24 (approvato da Andrea)**: si aggiunge la vista mese; il calendario classico
(giorno, settimana, mese) è la vista predefinita e sostituisce l'apertura a card. L'elenco a card esistente
resta selezionabile per tutti e tre i periodi.

**Aggiornamento 2026-10-24 — condivisione appuntamento**: nel form si possono invitare colleghi e gruppi
della chat. Ogni invitato riceve una notifica e conferma o rifiuta la disponibilità; l'appuntamento resta
**in attesa** finché non arriva la prima conferma. Il dettaglio mostra le risposte; nessuna nuova collezione.

**Casi limite**: fuso orario del dispositivo diverso da quello aziendale (mostrare l'ora aziendale con nota);
molti elementi nel periodo (limite di query); elemento di altra azienda mai visibile.

### 2. Appuntamenti

**US**: come commerciale voglio creare appuntamenti generici o legati a un cliente, con luogo, durata,
operatore e note.

**Criteri**
1. Titolo e data obbligatori; ora, durata, cliente, operatore, luogo/indirizzo e note facoltativi.
2. Tipo visita e tipo appuntamento distinti; un appuntamento può nascere da una visita e restare collegato
   (`visita_id`).
3. Modifica, eliminazione con conferma, stati da fare / fatto / annullato.
4. Nessun salvataggio con data non valida o fine precedente all'inizio; eliminare l'appuntamento non cancella
   cliente, visita o task collegati.

**Casi limite**: cliente eliminato ("Cliente non disponibile"); operatore disabilitato; modifica simultanea
da due dispositivi (vince l'ultimo salvataggio, con avviso).

### 3. Task

**US**: come titolare voglio assegnare attività semplici a un operatore e ritrovarle in una pagina Task.

**Criteri**
1. Pagina "Task" con elenco per scadenza, filtri stato/operatore/cliente e ricerca per titolo.
2. Task con titolo, scadenza facoltativa, operatore, priorità normale/urgente, note e collegamento
   facoltativo a cliente o appuntamento.
3. Un task creato da un appuntamento compare in entrambe le viste con lo stesso stato; completarlo registra
   data/ora e autore e si può riaprire.
4. Solo chi ha permesso assegna ad altri; l'operatore vede i propri task e quelli non assegnati (da
   confermare).

**Casi limite**: scadenza nel passato (evidenza, non blocco); operatore rimosso dall'azienda; task simile già
presente (avviso, non blocco).

### 4. Promemoria

**US**: come utente voglio un promemoria per appuntamento o task, così non me lo dimentico.

**Criteri**
1. Promemoria con anticipo configurabile (15/30/60 minuti, 1 giorno).
2. Destinatario interno (operatore) e canale secondo configurazione.
3. Stato visibile: programmato, inviato, fallito; l'invio riuscito è registrato una sola volta.
4. Spostare data/ora ricalcola il promemoria; se già inviato ne nasce uno nuovo.
5. I campi `promemoria_*` delle visite attuali restano validi e non vengono sovrascritti.

**Casi limite**: dispositivo spento o senza rete; ora legale; appuntamento annullato (promemoria annullato).

### 5. Allegati (foto e immagini)

**US**: come operatore voglio allegare foto a un appuntamento o task, così ho tutto il necessario.

**Criteri**
1. Aggiunta di una o più immagini da fotocamera o galleria, su appuntamento e task.
2. Anteprima, apertura a schermo intero, eliminazione con conferma; dimensione e tipo visibili.
3. Limite di dimensione e numero per elemento configurabile; oltre il limite, messaggio chiaro e nessun
   caricamento.
4. Immagini visibili solo agli utenti dell'azienda; il cliente non le vede.

**Casi limite**: caricamento interrotto (riprova senza duplicati); formato non supportato; spazio esaurito;
cosa succede agli allegati quando l'elemento viene eliminato (da decidere).

### 6. Mappe (icona auto)

**US**: come commerciale voglio aprire il navigatore sull'indirizzo dell'appuntamento con un tocco.

**Criteri**
1. Se c'è un indirizzo, accanto compare un'icona auto con etichetta accessibile "Apri in Google Maps".
2. Il tocco apre Google Maps (app se installata, altrimenti web) con l'indirizzo come destinazione.
3. Senza indirizzo l'icona non compare; indirizzo incompleto apre la ricerca con il testo disponibile.
4. L'apertura non richiede permessi di localizzazione e non invia dati a Closer.

**Casi limite**: indirizzo con caratteri speciali; nessuna app mappe; link non apribile (messaggio).

### 7. Notifiche al cliente (email/WhatsApp)

**US**: come commerciale voglio avvisare il cliente dell'appuntamento subito e a un orario prestabilito,
senza riscrivere ogni volta il messaggio.

**Criteri**
1. Se l'appuntamento ha email o telefono, l'app propone l'invio; il testo è un template modificabile.
2. Invio immediato dopo la creazione solo con conferma dell'utente (o automatico se l'impostazione è attiva:
   da decidere).
3. Invio programmato all'orario configurato (es. giorno prima alle 18:00) con traccia di invio o errore.
4. Il messaggio contiene data, ora, luogo, nome azienda e riferimento; nessun dato di altri clienti.
5. Senza email/telefono o senza canale configurato il pulsante è disabilitato con spiegazione.
6. Un invio fallito non blocca l'appuntamento e può essere ritentato.
7. Nessun messaggio parte verso clienti di altre aziende o senza consenso registrato (vedi GDPR).

**Casi limite**: email non valida; numero senza prefisso internazionale; più appuntamenti lo stesso giorno;
orario di invio già passato.

### 8. Sincronizzazione Google Calendar / Microsoft 365

**US**: come utente voglio vedere gli impegni Closer anche nel calendario che uso già, e viceversa.

**Criteri**
1. Collegamento e scollegamento account Google e Microsoft dalle impostazioni, con stato visibile.
2. Gli appuntamenti Closer compaiono nel calendario esterno scelto; gli eventi esterni del periodo
   compaiono in Closer in sola lettura (MVP).
3. Modifica o eliminazione in Closer aggiorna l'evento esterno; se l'evento è stato modificato fuori, l'app
   avvisa del conflitto e non sovrascrive in silenzio.
4. Sincronizzazione per utente, non condivisa, limitata a un intervallo di date configurabile.
5. Token scaduto o permesso revocato: avviso "Ricollega l'account", dati Closer intatti, nessun errore
   tecnico mostrato.
6. Nessun evento duplicato dopo sincronizzazioni ripetute.

**Casi limite**: due utenti sincronizzano lo stesso cliente; evento esterno ricorrente (solo lettura); fuso
orario; evento eliminato fuori; quota API raggiunta.

### 9. Call Teams / Google Meet

**US**: come commerciale voglio creare un link di call dentro l'appuntamento e condividerlo col cliente.

**Criteri**
1. Nell'appuntamento si sceglie "Call Teams" o "Google Meet"; il link viene creato e salvato.
2. Se l'integrazione non è collegata, l'app spiega cosa manca e permette di incollare un link manuale.
3. Il link è copiabile e incluso nel promemoria al cliente; prima della condivisione è visibile solo
   all'azienda.
4. Spostare data/ora non rompe il link; eliminare l'appuntamento non elimina la riunione esterna (avviso).

**Casi limite**: licenza Teams/Workspace assente; link scaduto; riunione creata ma salvataggio fallito
(riprova senza duplicati).

### 10. Slot di disponibilità e prenotazione

**US**: come commerciale voglio inviare al cliente uno o più slot liberi via email o WhatsApp, così prenota
da solo.

**Criteri**
1. Si scelgono data, durata e numero di slot; l'app mostra gli orari liberi in base agli impegni
   dell'operatore.
2. L'invio avviene via email o WhatsApp con un link; il link mostra solo gli slot proposti, senza dati
   interni.
3. Il cliente sceglie uno slot e riceve conferma; l'appuntamento appare in Closer e l'operatore è avvisato.
4. Uno slot già scelto non è più prenotabile; due prenotazioni simultanee non creano due appuntamenti.
5. Il link scade dopo un periodo configurabile e l'operatore può annullarlo.
6. Se il cliente non prenota, l'operatore vede "in attesa" e può sollecitare.

**Casi limite**: link aperto da più persone; slot nel passato; il cliente chiede una modifica (nessuna
auto-gestione in MVP); fuso orario del cliente.

### 11. Impostazioni

**US**: come admin voglio configurare le funzioni dell'agenda in un solo posto, con voci comprensibili.

**Criteri**
1. Nuova sezione "Calendario e appuntamenti" nelle Impostazioni, visibile solo a chi gestisce l'azienda.
2. Ogni voce della tabella sotto è modificabile e salvata; i campi segreti non sono più mostrati in chiaro
   dopo il salvataggio.
3. Disattivare un'integrazione nasconde le azioni collegate ma non cancella i dati.
4. Valori non validi (URL, email, orari) bloccano il salvataggio con messaggio chiaro.

**Casi limite**: configurazione parziale; modifica concorrente; ritorno ai valori predefiniti.

**Configurazioni in Impostazioni**

| Nome | Cosa configura | Obbligatoria | Segreta |
|---|---|---|---|
| Fuso orario aziendale | ora usata da calendario e promemoria | sì | no |
| Anticipo promemoria predefinito | minuti/giorni prima dell'elemento | no | no |
| Orario invio cliente | ora del giorno dell'invio programmato | sì se notifiche attive | no |
| Canale cliente | email, WhatsApp o entrambi | sì se notifiche attive | no |
| Template messaggi | testo promemoria e slot con segnaposto | sì se notifiche attive | no |
| Email mittente / provider | indirizzo e servizio di invio | sì per email | chiave: sì |
| WhatsApp server Volty | URL, numero, stato; API key in `whatsapp_config/1` | sì per WhatsApp | sì |
| Numero WhatsApp operatore | destinatario dei promemoria interni | no | no (dato personale) |
| Google Calendar | abilita e account collegato | no | sì (token OAuth) |
| Microsoft 365 | abilita, tenant e account collegato | no | sì (client secret/token) |
| Call | provider predefinito Teams/Meet | no | sì (token) |
| Prenotazione | durata slot, giorni, finestra, scadenza link | sì se attiva | no |
| Allegati | abilitati, dimensione max, numero max | no | no |
| Mappe | icona auto, app preferita | no | no |

**Fasi consigliate**
- **MVP — funziona senza servizi a pagamento**: calendario giorno/settimana, appuntamenti, task, promemoria
  interni in-app, allegati entro i limiti gratuiti Firebase (**da verificare**), icona auto/Maps, export ICS,
  condivisione manuale di un link slot via WhatsApp/email esistente. Nessuna sync Google/Microsoft, nessuna
  creazione automatica di call, nessuna prenotazione pubblica.
- **Fase 2 — integrazioni**: sync Google/Outlook in sola lettura degli eventi esterni, invio programmato
  (richiede scheduler, probabilmente piano Firebase a consumo), creazione link Teams/Meet.
- **Fase 3 — automazioni evolute**: prenotazione pubblica con conferma, sync bidirezionale, conflitti,
  ricorrenze, durata viaggio, promemoria push.

**Dipendenze esterne e rischi**
- OAuth Google (verifica app, redirect web/mobile) e Azure/Microsoft Graph (permessi, tenant, licenze).
- Teams e Google Meet richiedono licenze adeguate; i costi e i limiti vanno verificati, non sono gratis per
  definizione.
- Invio email: deliverability, provider a pagamento o con limiti; nessuna credenziale nel codice.
- WhatsApp: dipende dal server Volty già esistente (`/send`, `x-api-key`); oggi la API key sta in
  `whatsapp_config/1` → valutare secret lato server. Disponibilità e costi del server da verificare.
- Archiviazione allegati: **Cloudflare R2** (scelta di Andrea); limiti free tier, URL firmati, immagini = dati personali.
- Fuso orario e ora legale; sincronizzazioni e conflitti; token scaduti e riconnessione.
- Privacy/GDPR: consenso per email/WhatsApp, foto di luoghi/persone, link pubblici non indovinabili,
  conservazione e cancellazione.
- Limiti Firebase gratuiti (query, funzioni programmate): da verificare prima delle stime; allegati su R2.

**Domande aperte per Andrea**
1. Nell'MVP le visite attuali diventano appuntamenti o restano due cose separate?
2. L'"operatore" è un utente Closer con login o anche un contatto esterno senza account?
3. Il promemoria al cliente va via email, WhatsApp o entrambi? Con quale indirizzo mittente?
4. La creazione di appuntamenti/task è per tutti o solo per chi ha un permesso dedicato?
5. ~~Serve la vista mese nell'MVP o bastano giorno e settimana?~~ **Sì: approvata il 24/10/2026,** insieme alle viste classiche e allo stile card.
6. Per Teams/Meet basta incollare il link nell'MVP, con creazione automatica in Fase 2?
7. La pagina di prenotazione deve essere pubblica senza login?Chi conferma lo slot?
8. Quanti allegati e quale dimensione massima per appuntamento/task?
9. Google e Microsoft: un solo account aziendale o ogni utente collega il proprio?
10. Il promemoria al cliente deve partire automaticamente o sempre dopo conferma dell'utente?

**Funzionalità aggiuntive consigliate**
- **Utile subito**: rilevamento conflitti di orario, durata predefinita, conferma cliente con un tocco,
  link di annullamento, template messaggi, etichette colorate, vista per operatore, export/import ICS,
  checklist nel task, note.
- **Rinviabile**: durata viaggio e ottimizzazione percorso, ricorrenze, note vocali, promemoria push,
  statistiche appuntamenti, integrazione con preventivi.

**Fuori ambito**
- Sostituire Google Calendar/Outlook o copiare tutte le loro funzioni.
- Videochiamata interna (si condivide solo il link), fatturazione, CRM avanzato, intelligenza artificiale.
- Sync bidirezionale e prenotazione pubblica nell'MVP; modifica di regole, piani o dati esistenti.

### Notifiche push e WhatsApp all'operatore

_Aggiunta del 2026-10-23 alla voce sopra._

**Obiettivo**: avvisare l'operatore di appuntamenti, task, promemoria e comunicazioni con data/ora, così non
perde scadenze; ogni canale ha costi e configurazione diversi.

**I tre canali**
- **In-app**: compare nel centro notifiche di Closer, funziona sempre e senza permessi, ma si vede solo aprendo l'app.
- **Push**: avviso su web/PWA, Android o iOS; richiede permesso e configurazione, può arrivare ad app chiusa ma non è garantito.
- **WhatsApp**: messaggio al numero dell'operatore via server Volty; richiede numero valido, consenso e server attivo; arriva senza app ma è esterno e può costare.

**US**: come operatore voglio un avviso chiaro che apre subito l'elemento; come admin voglio scegliere canali e tipi senza esporre dati sensibili.

**Criteri di accettazione**
1. **Centro notifiche**: elenco con data/ora, tipo, titolo e stato letto; badge delle non lette; tocco che apre l'elemento; "segna letta" e "segna tutte lette".
2. **Preferenze per utente**: canali attivi (in-app, push, WhatsApp), tipi (appuntamenti, task, promemoria, comunicazioni), orari di silenzio e fuso orario; ogni modifica è salvata.
3. **Numero WhatsApp operatore**: campo dedicato con consenso esplicito, verifica del formato internazionale e interruttore per disattivarlo.
4. **Una notifica per evento**: creata una sola volta, con stato programmata/inviata/fallita e retry secondo il ritardo configurato, senza duplicati.
5. **Deep link**: la notifica apre appuntamento, task o promemoria; se l'elemento non esiste più, messaggio comprensibile e nessun errore tecnico.
6. **Assegnazione**: quando un task o un appuntamento viene assegnato, l'operatore riceve subito la notifica in-app e, se attivi, push e WhatsApp.
7. **Promemoria**: parte alla data/ora configurata (anticipo) nel fuso orario scelto; spostare l'elemento ricalcola l'invio.
8. **Niente rumore**: nessuna notifica per elementi annullati, completati o eliminati; restano solo le comunicazioni esplicite inviate da un utente.
9. **Privacy**: push e WhatsApp contengono solo un testo breve e generico con invito ad aprire l'app; nessun dato sensibile (importi, note, altri clienti, allegati, link permanenti).
10. **Esito visibile**: per ogni notifica si legge inviata, fallita o da riprovare, con il canale usato; un errore non blocca l'app.

**Casi limite**: permesso push negato (resta l'in-app); token scaduto o dispositivo rimosso; app chiusa o telefono spento
(consegna non garantita); offline (invio alla riconnessione, senza duplicati); operatore senza numero o numero non valido;
senza consenso; fuso orario e ora legale; più dispositivi; notifica duplicata; server WhatsApp non configurato o non raggiungibile.

**Configurazioni in Impostazioni**

| Nome | Cosa configura | Obbligatoria | Segreta |
|---|---|---|---|
| Notifiche in-app | attive per l'azienda, tipi inclusi | no | no |
| Push web / PWA | attiva, chiave VAPID pubblica, service worker | sì per push web | parte: sì |
| Push Android | attiva, progetto FCM, file di configurazione | sì per Android | sì |
| Push iOS | attiva, APNs/Apple Developer, chiave | sì per iOS | sì |
| Numero WhatsApp operatore | destinatario dei promemoria interni, con consenso | no | dato personale |
| Template messaggi operatore | testo breve con segnaposto (titolo, data/ora) | sì se WhatsApp attivo | no |
| Orari di silenzio | fascia in cui non inviare push/WhatsApp | no | no |
| Tipi attivi | appuntamenti, task, promemoria, comunicazioni | sì | no |
| Ritardo retry | minuti tra un tentativo e il successivo | no | no |
| Canale predefinito | in-app, push o WhatsApp | sì | no |

**Prerequisiti tecnici e costi da verificare**: FCM è gratuito, ma il push web richiede VAPID, service worker e HTTPS;
Android richiede `google-services`; iOS richiede APNs e account Apple Developer a pagamento (da verificare); ogni
dispositivo è un token da salvare e pulire; WhatsApp dipende dal server Volty (costi e disponibilità da verificare);
consenso, privacy e conservazione dei numeri vanno gestiti come dati personali.

**Fasi consigliate**
1. **Subito**: centro notifiche in-app, notifica di assegnazione, promemoria e WhatsApp all'operatore col server Volty esistente.
2. **Poi**: push web/PWA e Android, con preferenze per tipo e orari di silenzio.
3. **Dopo verifica Apple**: push iOS.
4. **Infine**: preferenze complete, retry configurabile e canale predefinito per utente.

**Domande aperte per Andrea**
1. Quali piattaforme push servono per prime: web/PWA, Android o entrambe?
2. Il numero WhatsApp è uno per operatore o uno aziendale condiviso? Chi lo inserisce?
3. Le notifiche arrivano anche fuori orario o si fermano nella fascia di silenzio?
4. Chi può inviare le comunicazioni manuali: tutti, solo admin o chi ha un permesso?
5. Il testo di push e WhatsApp è standard o personalizzabile per azienda?
6. Il consenso WhatsApp si raccoglie in app o bastano le impostazioni dell'admin?

**Fuori ambito**: notifiche al cliente (già nella voce 7), marketing, gruppi WhatsApp, notifiche tra aziende,
sostituzione di FCM/APNs con servizi a pagamento, modifica delle regole Firestore.

### Chat interna

_Aggiunta del 2026-10-23 alla voce sopra._

**Obiettivo**: dare ai dipendenti un modo semplice per scriversi dentro Closer, con chat dirette e gruppi aziendali, senza usare WhatsApp personale.
**Utenti**: solo utenti Closer attivi della stessa azienda (titolare, admin, commerciale, operatore); nessun ospite esterno.

**User story**: come utente Closer voglio scrivere a un collega o a un gruppo dell'azienda, vedere subito le risposte e i messaggi non letti, così resto aggiornato senza usare canali personali.

**Criteri di accettazione**
1. **Chat diretta**: dalla lista degli utenti attivi si apre una chat 1-a-1; se esiste già si riusa, senza duplicati.
2. **Gruppo**: si crea un gruppo con nome e almeno un altro partecipante attivo della stessa azienda; si possono aggiungere o rimuovere partecipanti.
3. **Invio**: si invia un messaggio di testo; compare subito nella chat e resta "in invio" finché non è salvato.
4. **Realtime**: un messaggio nuovo compare senza ricaricare la pagina, in tutte le chat aperte.
5. **Non letti**: ogni chat mostra il numero dei messaggi non letti; aprendola e leggendola il contatore si azzera.
6. **Lettura**: l'autore vede se e quando il messaggio è stato letto dai partecipanti (conferme di lettura).
7. **Ricerca**: si cercano conversazioni per nome e messaggi per testo, solo nelle chat a cui si appartiene.
8. **Immagini**: si invia un'immagine da galleria o fotocamera, caricata su Cloudflare R2, con anteprima e apertura a schermo intero.
9. **Eliminazione**: l'autore elimina un proprio messaggio; soft delete, il messaggio sparisce ma resta traccia tecnica.
10. **Notifiche**: nuovo messaggio → notifica in-app e, se attiva, push; WhatsApp non si usa per la chat.
11. **Permessi**: si legge e si scrive solo nelle chat di cui si è partecipanti e solo per la propria azienda; nessun dato di altre aziende.
12. **Utente disattivato**: un utente con `attivo=false` non può leggere né scrivere e compare come "Utente non disponibile".

**Casi limite e rischi**
- Utente rimosso dall'azienda: esce dalle chat, i suoi messaggi restano; il gruppo continua senza di lui.
- Gruppo senza partecipanti attivi: resta visibile in sola lettura, non si inviano messaggi, avviso chiaro.
- Messaggio duplicato o inviato offline: un solo messaggio salvato con identificatore unico; alla riconnessione parte una volta.
- Immagine non caricata: il messaggio resta "da riprovare" e non blocca il testo; nessun file orfano.
- Notifica mentre la chat è aperta: nessun push, si aggiorna solo il contatore.
- Silenzio notturno: push sospeso nella fascia scelta; i messaggi restano e si vedono all'apertura, l'in-app resta.
- Messaggio eliminato: sparisce dalla chat e il contenuto non è più leggibile; conteggi e notifiche restano coerenti.
- Rischi: costi e limiti R2, dimensione immagini, privacy dei contenuti, notifiche duplicate, utenti senza permesso.

**Impostazioni**
- Notifiche chat attive/inattive per utente; canali in-app e push.
- Anteprima del testo nella notifica: sì/no (se no, solo "Nuovo messaggio").
- Orari di silenzio, con fuso orario aziendale.
- Immagini attive/inattive e dimensione massima per file, con messaggio chiaro oltre il limite.

**Fasi consigliate**
1. **Subito**: chat dirette, gruppi, testo, realtime, non letti, conferme di lettura, notifiche in-app, ricerca.
2. **Poi**: immagini su R2, push, preferenze e silenzio notturno, soft delete con pulizia periodica.

**Fuori ambito**
- Presenza online, chiamate interne, messaggi vocali, thread, reazioni, modifica dei messaggi.
- Chat con clienti o ospiti esterni, WhatsApp, email, notifiche tra aziende.
- Modifiche a regole Firestore, dati esistenti o vecchia app Alpine senza approvazione.

**Domande aperte per Andrea**
1. Le chat dirette sono libere tra tutti i colleghi o solo tra ruoli che collaborano?
2. Chi crea i gruppi: tutti o solo admin/titolare? I gruppi sono modificabili da tutti i membri?
3. Le conferme di lettura sono obbligatorie o si possono disattivare?
4. Quale dimensione massima per le immagini e per quanti giorni si conservano i messaggi eliminati?

## 2026-10-24 — Calendario per operatore, condivisione e OAuth aziendale

**Obiettivo**: dare a ogni operatore un calendario personale collegato al proprio account Google o Microsoft,
condivisibile in sola lettura o in modifica con i colleghi della stessa azienda, usando di default l'app OAuth
Closer e, solo se l'azienda lo sceglie, un'app OAuth propria.

**Punto di partenza verificato nel codice**
- Esiste `appuntamenti` con `operatore_id`, `cliente_id`, `cliente_nome`, `luogo`, `note`, `call_provider`,
  `call_url`, `meeting_id`, `google_event_id`, `outlook_event_id`, `created_by`, `created_at`, `updated_at`.
- Esiste `integrazioni/{aziendaId}_{utenteId}` con provider, calendario, tenant, stato e date; le regole
  attuali la fanno leggere solo al proprietario e la fanno scrivere solo al server.
- Esiste `impostazioni_agenda/{aziendaId}` per le impostazioni dell'agenda; `giro_visite` resta separata.
- Il Worker Cloudflare oggi espone solo il proxy VIES: non ci sono ancora endpoint OAuth, calendario o SMTP.

**Decisioni confermate da Andrea (24/10/2026)**
1. Ogni operatore collega il proprio account Google o Microsoft; appuntamenti e call stanno sul suo calendario.
2. La condivisione è solo con utenti Closer della stessa azienda, con tre livelli: `libero_occupato`,
   `dettagli`, `modifica`. Il default è `dettagli` in sola lettura; `modifica` si concede solo esplicitamente.
3. Il proprietario crea e revoca la condivisione; il destinatario non può ri-condividere; la revoca è immediata.
4. `libero_occupato` nasconde titolo, cliente, note e luogo; `dettagli` mostra data/ora, titolo, cliente e luogo
   ma non le note private; `modifica` consente la modifica con traccia dell'autore.
5. L'evento e il link Meet/Teams sono intestati al proprietario del calendario; se un collega crea un evento su
   un calendario condiviso, l'organizzatore resta il proprietario.
6. L'app OAuth Closer, unica e verificata, è il default per tutti. L'azienda può scegliere un'app OAuth propria
   in `Impostazioni → Integrazioni`, con procedura guidata e test di connessione.
7. Google: app Closer esterna con verifica per l'uso multi-azienda; app propria di tipo Internal per le aziende
   con Google Workspace. Microsoft: app Closer multi-tenant; app propria con tenant, client e secret dell'azienda.
8. SMTP aziendale: una sola configurazione per azienda, usata per tutti i promemoria.
9. I segreti stanno solo lato Worker (KV/secret); in Firestore solo stato e metadati; mai token o client secret.
10. Tutte le configurazioni aziendali stanno nel pannello admin dell'azienda. FCM, VAPID e APNs restano
    configurazione di piattaforma del superadmin perché legati all'app installata.

**User story**
- Come operatore voglio collegare il mio account Google o Microsoft e vedere i miei appuntamenti e le mie call
  sul mio calendario, così non duplico gli impegni a mano.
- Come proprietario del calendario voglio condividerlo con un collega scegliendo quanto mostrare, così resta
  coordinato senza esporre note private o dati del cliente.
- Come collega con livello `dettagli` voglio vedere quando un collega è occupato e con chi, senza poter
  modificare nulla.
- Come collega con livello `modifica` voglio poter spostare o correggere un appuntamento sul calendario del
  collega, sapendo che resta traccia di chi ha modificato.
- Come amministratore dell'azienda voglio configurare l'app OAuth e l'SMTP aziendale in un solo pannello, con
  un test che mi dica subito se i dati sono corretti, senza vedere i segreti in chiaro.

### Criteri di accettazione

1. **Connessione account**
   Si vede: in `Impostazioni → Integrazioni` le voci Google e Microsoft con stato "Non collegato" e il pulsante
   "Collega account". Si può: completare il flusso OAuth del provider scelto; a fine flusso lo stato diventa
   "Collegato" e mostra indirizzo dell'account e data di collegamento. Non deve succedere: se l'utente annulla
   o il provider risponde con errore, lo stato resta "Non collegato" e nessun appuntamento viene modificato.

2. **Scollegamento**
   Si può: scollegare l'account con una conferma esplicita. Dopo lo scollegamento lo stato torna "Non
   collegato" e il Worker invalida i token dell'utente. Non deve succedere: nessun appuntamento Closer viene
   eliminato o modificato e nessun evento già creato sul calendario esterno viene cancellato.

3. **Stato e identità visibili**
   Si vede: per ogni operatore il provider, l'indirizzo dell'account collegato, lo stato, la data dell'ultimo
   collegamento e l'ultimo errore in italiano. Si può: l'amministratore dell'azienda consultare lo stato dei
   colleghi. Non deve succedere: l'amministratore o un collega non vedono token, refresh token o client secret.

4. **Condivisione e livelli**
   Si può: il proprietario apre "Condividi calendario", sceglie uno o più utenti attivi della stessa azienda e
   un livello. Il livello proposto è `dettagli`; `modifica` richiede una scelta esplicita e una conferma. La
   lista mostra nome, livello e data della condivisione. Non deve succedere: non si può condividere con utenti
   di altre aziende o con utenti disattivati; non esiste un livello diverso dai tre indicati.

5. **Revoca immediata**
   Si può: il proprietario revoca una condivisione in qualsiasi momento. Il destinatario perde l'accesso al
   primo caricamento o aggiornamento successivo, senza attendere la scadenza di un token. Non deve succedere:
   dopo la revoca il destinatario non vede più l'evento, non lo apre e non lo modifica; eventuali dati già
   caricati nella schermata spariscono al refresh.

6. **Nessuna ri-condivisione**
   Si vede: il pulsante "Condividi" solo al proprietario. Si può: il destinatario usa l'evento secondo il
   livello ricevuto. Non deve succedere: il destinatario non può creare, modificare o revocare condivisioni,
   non può cambiare il proprio livello e non può girarne i dettagli a un altro utente tramite la funzione di
   condivisione.

7. **Isolamento per azienda**
   Si vede: solo calendari e condivisioni dell'azienda attiva. Si può: aprire un evento condiviso solo se la
   condivisione esiste nella propria azienda. Non deve succedere: con due aziende di prova, un utente
   dell'azienda A non vede nomi, eventi o condivisioni dell'azienda B e un tentativo diretto produce un errore
   di permesso, non un dato.

8. **Mascheramento `libero_occupato`**
   Si vede: solo "Occupato" con data e orario di inizio e fine. Non si vede: titolo, cliente, note, luogo,
   link call e allegati. Non deve succedere: i campi nascosti non arrivano al dispositivo del destinatario,
   nemmeno nella risposta di rete; la ricerca e il dettaglio non li mostrano.

9. **`dettagli` in sola lettura**
   Si vede: data, ora, titolo, cliente e luogo. Non si vede: note private e link della call. Non deve
   succedere: il destinatario non trova pulsanti di modifica o eliminazione e un tentativo di salvataggio
   viene rifiutato con un messaggio comprensibile.

10. **`modifica` con traccia autore**
    Si può: il destinatario autorizzato modifica i campi dell'evento sul calendario del proprietario. Ogni
    salvataggio registra chi ha modificato e quando; il proprietario vede "Modificato da <nome> il <data/ora>".
    Non deve succedere: il delegato non può cambiare proprietario, condivisione o livello, e l'evento non si
    sposta sul calendario del delegato.

11. **Organizzatore e call sul calendario corretto**
    Si può: creare un evento e una call Meet o Teams su un calendario condiviso con `modifica`. L'evento nasce
    sul calendario del proprietario, con il proprietario come organizzatore e con il link della call salvato
    nell'appuntamento. Non deve succedere: l'evento non nasce sul calendario del delegato e l'organizzatore non
    cambia; chi ha creato materialmente l'evento resta registrato nella traccia autore.

12. **Cliente invitato**
    Si può: invitare il cliente solo dall'evento del proprietario o da un delegato con `modifica`. L'invito
    parte dall'account del proprietario e il cliente vede il proprietario come organizzatore. Non deve
    succedere: l'invito non parte da un livello `libero_occupato` o `dettagli`; il messaggio al cliente non
    contiene note private, altri clienti o dati interni.

13. **App OAuth Closer predefinita**
    Si vede: in `Impostazioni → Integrazioni` l'app Closer indicata come predefinita e già pronta, senza campi
    da compilare. Si può: collegare Google o Microsoft senza configurare nulla. Non deve succedere: una nuova
    azienda non è obbligata a creare un'app propria e non vede campi tecnici vuoti o obbligatori.

14. **App OAuth propria: procedura guidata, test e rotazione**
    Si può: scegliere "Usa un'app propria", seguire la procedura guidata con i campi del provider, copiare
    l'URL di reindirizzamento mostrato e usare "Prova connessione". Il salvataggio è consentito solo se il test
    riesce; se fallisce, il messaggio dice cosa correggere. Sostituendo client secret o tenant, il test
    conferma la nuova configurazione e le connessioni esistenti continuano o mostrano "Ricollega l'account".
    Non deve succedere: la rotazione non richiede di ricreare utenti o appuntamenti e il vecchio secret non
    funziona più.

15. **Nessun segreto esposto**
    Si vede: dopo il salvataggio i campi segreti sono mascherati e non più leggibili in chiaro. In Firestore
    restano solo stato e metadati (provider, tenant, client id, date, esito test). Non deve succedere: token,
    refresh token, client secret e password SMTP non compaiono in Firestore, nel browser, nei log, nei messaggi
    di errore o nei link condivisi; stanno solo nei secret/KV del Worker.

16. **SMTP aziendale unico**
    Si può: l'amministratore configura un solo SMTP per azienda, invia un messaggio di prova e attiva il canale
    email. Tutti i promemoria dell'azienda usano quella configurazione. Non deve succedere: non esistono
    configurazioni SMTP per singolo utente nell'MVP; senza SMTP valido il canale email è disattivato con
    spiegazione e gli altri canali restano attivi.

17. **Nessuna migrazione e nessun impatto sugli appuntamenti esistenti**
    Si vede: gli appuntamenti già presenti restano visibili al loro operatore con gli stessi dati. Si può:
    attivare o disattivare la funzione senza toccare i documenti esistenti. Non deve succedere: nessuna
    migrazione, nessuna riscrittura di `appuntamenti`, `giro_visite`, `impostazioni_agenda` o `integrazioni`,
    nessun utente costretto a ricollegare l'account e nessun dato cancellato disattivando la funzione.

18. **Errori comprensibili**
    Si vede: per token revocato "Ricollega l'account"; per secret o configurazione non valida "Configurazione
    non valida: controlla i dati e riprova"; per licenza Teams mancante "L'account Microsoft non ha una licenza
    per Teams"; per rete assente "Connessione non disponibile, riprova". Non deve succedere: l'utente non vede
    stack trace, codici HTTP da soli o nomi tecnici interni, e l'app resta utilizzabile.

19. **Confini del pannello**
    Si vede: nel pannello admin dell'azienda solo le configurazioni aziendali (OAuth propria, SMTP, livelli di
    condivisione, fuso orario). Non si vede: FCM, VAPID e APNs, che restano nel pannello di piattaforma del
    superadmin. Non deve succedere: un admin d'azienda non può modificare le chiavi push della piattaforma.

### Cosa non deve succedere (riepilogo)

- Nessun token, refresh token, client secret o password SMTP in Firestore, nel codice, nei log o nei link.
- Nessun dato di un'altra azienda, nemmeno per errore di query o di ricerca.
- Nessun campo nascosto di `libero_occupato` inviato al dispositivo del destinatario.
- Nessuna ri-condivisione o autopromozione di livello da parte del destinatario.
- Nessuna revoca "dopo un po'": la perdita di accesso è immediata al refresh.
- Nessuna modifica o cancellazione dei dati esistenti e nessuna migrazione.
- Nessun evento creato sul calendario sbagliato e nessun organizzatore diverso dal proprietario.
- Nessun invito al cliente da un livello che non mostra i dettagli.
- Nessuna sovrascrittura silenziosa in caso di modifica concorrente.
- Nessun promemoria inviato con un SMTP diverso da quello dell'azienda.
- Nessuna configurazione push (FCM/VAPID/APNs) spostata nel pannello azienda.

### Casi limite

- **Token revocato o scaduto**: lo stato passa a "Da ricollegare", l'app avvisa e i dati Closer restano intatti;
  nessun errore tecnico mostrato.
- **Client secret scaduto o ruotato dal provider**: il test di connessione fallisce con messaggio chiaro; le
  connessioni esistenti mostrano "Ricollega l'account" e non vengono cancellate.
- **Account Microsoft senza licenza Teams**: gli appuntamenti e il calendario funzionano; la creazione della call
  è disabilitata con spiegazione e resta possibile incollare un link manuale.
- **Utente rimosso dall'azienda**: le sue condivisioni verso colleghi e le condivisioni ricevute diventano
  inattive; i suoi appuntamenti restano al proprietario e non vengono riassegnati automaticamente.
- **Condivisione verso utente disattivato**: la condivisione non si crea; se l'utente viene disattivato dopo, non
  vede più nulla al refresh e il proprietario vede lo stato "Non attivo".
- **Fuso orario**: l'ora mostrata è quella aziendale; un evento creato da un dispositivo in un altro fuso resta
  corretto e non slitta. Il passaggio ora legale/solare non duplica né sposta gli eventi.
- **Evento esterno ricorrente**: in MVP è visibile in sola lettura come gli altri eventi esterni; non si modifica
  la serie e non si creano copie degli eventi ricorrenti.
- **Modifica concorrente**: se proprietario e delegato salvano quasi insieme, vince l'ultimo salvataggio ma
  l'app avvisa del conflitto e mostra chi ha modificato; nessuna sovrascrittura silenziosa.
- **Proprietario disattivato**: il calendario condiviso resta consultabile secondo il livello, ma non si creano
  nuovi eventi né call finché il proprietario non è di nuovo attivo.
- **Stesso account collegato due volte**: la seconda connessione riusa lo stato esistente senza duplicare
  eventi o token.

### Rischi

- **Verifica Google**: l'app Closer esterna richiede verifica e tempi non prevedibili; l'app Internal funziona
  solo con Google Workspace e non per account Gmail generici.
- **Consenso Microsoft**: l'app multi-tenant può richiedere consenso dell'amministratore del tenant; senza
  consenso il collegamento fallisce.
- **Identità dell'organizzatore**: creare un evento sul calendario di un altro utente richiede l'autorizzazione
  del proprietario; va verificato che il provider intesti davvero l'evento e la call al proprietario.
- **Segreti e rotazione**: un errore di rotazione può interrompere tutti i collegamenti; serve una procedura
  provata e un test prima di sostituire il secret attivo.
- **Mascheramento**: nascondere i campi solo nell'interfaccia non basta; il dato non deve arrivare al client.
- **Revoca**: se il client conserva una cache locale, la revoca deve invalidarla al refresh.
- **Fuso orario e ora legale**: errori di conversione possono spostare appuntamenti e promemoria.
- **Privacy/GDPR**: la condivisione espone dati di clienti e colleghi; servono livelli chiari, revoca semplice e
  conservazione delle tracce di modifica.
- **Complessità delle regole Firestore**: la condivisione introduce controlli per documento; regole sbagliate
  possono aprire dati o bloccare utenti legittimi.
- **Assenza di suite automatica**: la verifica resta manuale su staging, con costo e rischio di regressioni.

### Assunzioni

- Si lavora **solo su staging**; produzione e ramo `main` non esistono e non vengono toccati.
- Si usano le collezioni esistenti. L'eventuale nuova collezione per le condivisioni e per la configurazione
  OAuth aziendale è **solo una proposta** dell'architetto/dba e richiede l'approvazione di Andrea; nessuna
  migrazione e nessuna modifica a `firestore.rules` senza approvazione.
- "Operatore" significa utente Closer attivo con login e membership nell'azienda. I clienti finali non hanno
  account e non vedono il calendario.
- Il calendario è personale: ogni evento appartiene all'operatore a cui è assegnato; non esiste un calendario
  unico aziendale in questa versione.
- `dettagli` non mostra il link della call: il link resta visibile al proprietario e a chi ha `modifica`, finché
  Andrea non indica diversamente.
- `modifica` riguarda i campi dell'evento, non la condivisione, il proprietario o il livello.
- La condivisione riguarda gli appuntamenti; `giro_visite` resta visibile e gestita come oggi.
- L'ora di riferimento è quella aziendale, già prevista in `impostazioni_agenda`.
- L'SMTP è uno per azienda; l'eventuale override per utente non è previsto nell'MVP.
- FCM, VAPID e APNs restano configurazione di piattaforma del superadmin.

### Fuori ambito (MVP)

- Condivisione nativa Google/Outlook tramite ACL esterna: la condivisione è solo dentro Closer.
- Utenti esterni a Closer, ospiti, clienti con account o calendari di altre aziende.
- App mobile negli store (App Store, Google Play) e relativa distribuzione.
- Notifiche push iOS (APNs) e ottimizzazioni specifiche per iOS.
- Sincronizzazione bidirezionale automatica: in MVP gli eventi esterni sono in sola lettura e non si sovrascrive
  nulla in silenzio.
- Migrazione o riscrittura di appuntamenti, visite o impostazioni esistenti.
- Calendari di risorse, sale riunioni, ferie e presenze.
- Sostituzione di Google Calendar o Outlook e copia delle loro funzioni avanzate.
- Configurazione FCM/VAPID/APNs nel pannello azienda.

### Domande aperte

Nessuna domanda bloccante: le assunzioni sopra valgono fino a diversa indicazione di Andrea. Restano due punti
che Andrea può cambiare senza toccare i dati: (1) se il link Meet/Teams debba essere visibile anche a chi ha
`dettagli`; (2) se la condivisione debba valere anche per le visite in `giro_visite` o solo per `appuntamenti`.
