# Design — Commerciali

- UI in italiano, tono semplice.
- Tailwind CSS; componenti e classi riusati da `index.html`.
- Modali per azioni secondarie; per i flussi principali usare pagine intere quando possibile.
- Stati obbligatori: caricamento, vuoto, errore, senza permessi.
- Formati data e valuta italiani.
- Mobile first: la maggior parte degli utenti usa il telefono.

## 2026-10-22 — Design Flutter

Vale per `flutter_app/` (web, Android, iOS). Nessun restyling: stessa informazione, stessa gerarchia,
stessi testi. Fonte dei flussi: nodi `memoria/ui/*` e `architettura.md` §Architettura Flutter.

### 1. Mappa schermate → rotte e widget

| Oggi (`pagina`) | Rotta go_router | Screen Flutter |
|---|---|---|
| login / recupero | `/login`, `/reset-password` | `LoginScreen`, `ResetPasswordScreen` |
| onboarding | `/onboarding` | `OnboardingScreen` |
| dashboard | `/` | `DashboardScreen` |
| clienti (+ modale VIES) | `/clienti` | `ClientiScreen` + `ClienteFormSheet` |
| catalogo | `/catalogo` | `CatalogoScreen` |
| categorie | `/catalogo/categorie` | `CategorieScreen` |
| preventivi | `/preventivi` | `PreventiviScreen` |
| nuova richiesta | `/preventivi/nuovo` | `PreventivoEditScreen` |
| giro visite | `/visite` | `VisiteScreen` |
| bandi (pubblica) | `/bandi` | `BandiScreen` |
| import bandi | `/bandi/import` | `ImportBandiScreen` |
| impostazioni | `/impostazioni` | `ImpostazioniScreen` |
| utenti / ruoli | `/impostazioni/utenti`, `/impostazioni/ruoli` | `UtentiScreen`, `RuoliScreen` |
| superadmin | `/superadmin` | `SuperAdminScreen` |

### 2. Shell responsive (un solo albero, `LayoutBuilder`)
- **<600 telefono**: `Scaffold` + `NavigationBar` (Operativo: Dashboard, Clienti, Preventivi, Visite, Altro);
  "Altro" apre `Drawer` con Catalogo, Bandi, Amministrazione, utente/logout. Top bar corta, FAB per
  "Nuova richiesta" se il permesso `preventivi_propri` è presente.
- **600–1024 tablet**: `NavigationRail` compatta a icone + `Drawer` per le voci secondarie; contenuti in
  1–2 colonne.
- **>1024 desktop**: `Row` con `NavigationRail` estesa (o drawer permanente) — sezioni Operativo,
  Amministrazione, Super Admin come oggi; area principale con griglie multi-colonna.
- **Dashboard**: telefono = 4 card in 2×2, poi "Ultimi preventivi" a tutta larghezza, azioni rapide in
  lista; tablet = card 2×2 + due colonne; desktop = 4 card in riga, ultimi preventivi 2/3 + azioni 1/3.
- `AppBar` mostra il titolo pagina come oggi; "Nuova richiesta" solo nelle pagine operative e con permesso.

### 3. Componenti condivisi (`core/ui`)
Riuso prima, creazione solo se assente: `AppScaffold` (AppBar + azioni), `SezioneCard`, `StatCard`,
`CampoTesto`/`CampoSelect`/`CampoData` (validazione inline), `ModaleConferma`, `SheetForm`,
`TabellaResponsive` (DataTable ≥600, card in lista <600), `StatoVuoto`, `Caricamento`, `BannerErrore`,
`SenzaPermesso`, `BadgeStato` (bozza/inviato/accettato/rifiutato, visite `da_fare`/`fatto`),
`SelettoreAzienda`, `AvatarUtente`, `ImportoEuro`, `DataItaliana`. I modali restano per azioni
secondarie (VIES, conferme); i flussi principali (nuovo preventivo) sono pagine intere.
Ogni nuovo widget va registrato in `catalogo.md`.

### 4. Token Material 3 (`ColorScheme.fromSeed`)
- Primario blu `#1D4ED8`, superficie bianca, sfondo `#F8FAFC`, bordi `#E2E8F0`.
- Semantici: attesa ambra `#D97706`, accettato verde `#16A34A`, errore rosso `#DC2626`, super admin viola `#7E22CE`.
- Tipografia `TextTheme` M3: titolo schermata `titleLarge` bold, titoli card `titleSmall` semibold,
  corpo `bodyMedium`, etichette maiuscole `labelSmall` con tracking.
- Spazi su scala 4/8: padding pagina 16 (telefono) / 24–32 (desktop), gap card 16, interno card 20.
- Raggi: card 16, campi e pulsanti 12, chip 8, avatar circolare.
- Tema unico, `useMaterial3: true`; nessun colore fuori tema.

### 5. Stati obbligatori per ogni schermata
1. **Caricamento**: skeleton o `CircularProgressIndicator` centrato, senza layout che salta.
2. **Vuoto**: messaggio semplice + azione primaria ("Nessun cliente trovato — Aggiungi cliente").
3. **Errore**: `BannerErrore` in italiano con "Riprova" (errori rete/Firestore/VIES distinti e comprensibili).
4. **Senza permesso**: `SenzaPermesso` con spiegazione breve, raggiungibile solo se la rotta è bloccata dal
   `redirect`; nessun dato caricato. Vale per utenti, ruoli, import bandi, superadmin, valori economici.
   Bandi: il "senza login" è uno stato normale, non un errore.

### 6. Adattamenti necessari (e solo questi)
- Tabelle clienti/preventivi/categorie/utenti → card su telefono, `DataTable` ≥600.
- Sidebar → `NavigationBar` + `Drawer` su telefono, `NavigationRail` da tablet.
- Griglie dashboard e catalogo → 1 colonna su telefono.
- Form lunghi → sezioni espandibili su telefono, colonne su desktop.
- Modali VIES e conferme → `Dialog` su desktop, `showModalBottomSheet` su telefono.
- Tabelle orizzontali in preventivo (righe) → card riga modificabile su telefono.

### 7. Cosa non cambia
Testi e tono in italiano; nomi voci di menu; formati data `dd/MM/yyyy` e valuta `1.234,56 €` (`intl`, locale
`it_IT`); numerazione `PRV-0001` e revisioni `-R1`; permessi, ruoli e visibilità per `azienda_id`; flussi
login/onboarding/reset, CRUD e PDF. Nessuna nuova funzione, campo o schermata.

## 2026-10-23 — Calendario, task, notifiche e chat

Linee guida per le nuove schermate, da usare in fase di implementazione.

### Navigazione
- **Desktop/tablet**: barra laterale con tutte le pagine — Dashboard, Clienti, Catalogo, Preventivi, Visite,
  Calendario, Task, Chat, Bandi, Notifiche — e **rotella Impostazioni** in fondo. Niente voce “Altro” né
  secondi tre puntini.
- **Telefono**: barra inferiore con Dashboard, Clienti, Preventivi, Bandi e “Altro”; il drawer “Altro”
  contiene Catalogo, Calendario, Visite, Task, Chat, Notifiche e Impostazioni.
- Badge non letti su Chat e campanella notifiche.

### Calendario
- Telefono: vista **giorno** a lista cronologica; settimana a colonne compressa.
- Desktop: griglia settimanale con ore; elementi colorati per tipo.
- Elementi: orario, titolo, cliente/operatore, stato, icona call/allegati.
- Tocco su spazio vuoto → nuovo appuntamento con data/ora già compilate.
- “Senza orario” in fondo, sempre visibile.

**Aggiornamento 2026-10-24 — viste classiche e card**
- Il calendario è la vista predefinita, aperta sul **mese**.
- Periodo: **Giorno**, **Settimana**, **Mese**; stile: **Calendario** o **Card**.
- Giorno e settimana usano una griglia con righello delle ore; gli eventi sovrapposti si affiancano.
- Mese: griglia lunedì–domenica con voci compatte (su telefono solo indicatori); tocco sul giorno → vista giorno.
- La vista card esistente resta disponibile per giorno, settimana e mese.
- Tocco su uno spazio vuoto della griglia → nuovo appuntamento con data e ora proposte.

**Aggiornamento 2026-10-24 — nuovo cliente e inviti**
- Nel form appuntamento il cliente ha un pulsante **+** che apre la creazione e seleziona il nuovo cliente.
- Sezione **Condivisione**: dialogo con gruppi della chat e singole persone; chip degli invitati.
- Gli invitati ricevono una notifica In-App e confermano o rifiutano dal dettaglio dell'appuntamento.
- Finché nessuno conferma lo stato è **In attesa di conferma**; poi diventa **Confermato** o **Non disponibile**.

### Appuntamento / Task
- Form a sezioni: Dettagli, Cliente e operatore, Luogo, Promemoria, Allegati.
- Solo titolo e data obbligatori; il resto facoltativo.
- Icona auto accanto all'indirizzo; pulsante grande “Apri in Maps”.
- Call: pulsante “Crea link” con stato chiaro; se non configurato, campo per incollare il link.
- Allegati: griglia miniature, aggiunta da fotocamera/galleria, anteprima, eliminazione con conferma.
- Esito di ogni invio (email/WhatsApp/push) sempre visibile con “Riprova”.

### Task
- Lista per scadenza con sezioni Oggi, Questa settimana, Più avanti.
- Filtri stato/operatore/cliente; ricerca per titolo.
- Completamento con un tocco e possibilità di riaprire.
- Priorità urgente evidenziata, non solo con colore.

### Notifiche
- Centro notifiche a lista, raggruppato per giorno.
- Non lette in grassetto, puntino colorato; “Segna tutte come lette”.
- Tocco → deep link all'elemento.
- Preferenze per canale e tipo in Impostazioni, con interruttori grandi e testo semplice.

### Chat
- Lista conversazioni con avatar/nome, ultimo messaggio, ora, badge non letti.
- Thread con bolle proprie/altrui, stato inviato/letto, immagini con anteprima.
- Composer fisso in basso, pulsante invio grande, allegato con icona.
- Creazione gruppo: nome + selezione partecipanti con ricerca.
- Messaggio eliminato: segnaposto grigio “Messaggio eliminato”.

### Impostazioni
- Sezione “Calendario e notifiche” con card separate: Agenda, Promemoria cliente, Email SMTP, WhatsApp, Google, Microsoft, Push, Chat, Allegati.
- Campi segreti mai mostrati in chiaro dopo il salvataggio.
- Pulsante “Invia prova” per SMTP e WhatsApp.
- Stato integrazione con pallino verde/rosso e “Ricollega”.

## 2026-10-24 — Impostazioni integrazioni e calendario condiviso

Solo UI: nessuna nuova regola dati. Testi in italiano semplice, mobile first. Riuso prima di creare.

### Componenti riusati

| Componente | Da dove | Uso |
|---|---|---|
| Card impostazioni | `index.html` (`bg-white rounded-2xl border border-slate-200 shadow-sm p-6`) | ogni integrazione e ogni connessione |
| Intestazione card | `h2 text-base font-bold` + `p text-xs text-slate-400` | titolo e descrizione breve |
| Pulsante primario / secondario / pericolo | classi `btn-tap` blu, bordo, rosso | Configura, Test, Disconnetti |
| Pallino stato | `w-2 h-2 rounded-full` verde/grigio/rosso/ambra | stato integrazione |
| Passi numerati | cerchi `w-6 h-6 rounded-full bg-blue-700` di Import Bandi | procedura guidata |
| Box esito | verde `bg-green-50 border-green-200`, rosso `bg-red-50 border-red-200` | test riuscito/fallito |
| Spinner | SVG `animate-spin` | caricamento e test in corso |
| Modale / foglio | `fixed inset-0 bg-black/40`, su telefono `items-end sm:items-center` | conferme e scelta modalità |
| Toast | `Alpine.store("ui").mostraToast(...)` | salvataggi e revoche |

Nuovi, da registrare in `catalogo.md`: `PallinoStato`, `BadgeLivello`, `PassoGuida`, `CampoSegreto`, `CardIntegrazione`.
Token da `design.md` §4: blu `#1D4ED8`, sfondo `#F8FAFC`, bordi `#E2E8F0`, verde `#16A34A`, rosso `#DC2626`, ambra `#D97706`.

### 1. Impostazioni → Integrazioni (solo admin azienda)

**Gerarchia.** Titolo pagina "Integrazioni", una riga di aiuto: "Collega i servizi che Closer usa per email, calendario, messaggi e allegati." Poi 6 card, in quest'ordine: Google, Microsoft, Email SMTP, WhatsApp, Storage R2, Push.

**Struttura card (uguale per tutte).**
- Riga 1: icona, nome servizio, a destra `PallinoStato` + etichetta ("Configurato", "Da configurare", "Errore").
- Riga 2: descrizione di una riga (es. Google: "Crea appuntamenti e link call sul calendario Google.").
- Riga 3 azioni: `Configura` (primario), `Test connessione` (secondario, disabilitato se non configurato), `Disconnetti` (pericolo, solo se configurato).
- Push è **sola lettura**: niente `Configura`; testo "I permessi si gestiscono da Impostazioni → Notifiche"; pulsante `Apri preferenze`.

**Google / Microsoft — scelta modalità.** `Configura` apre una schermata intera (telefono) o un pannello laterale (desktop) con due scelte grandi:
- `Usa app Closer` — preselezionata, testo "Consigliata. Non serve configurare nulla."
- `Usa app propria` — testo "Per aziende con un proprio account Google o Microsoft."
Cambiare modalità chiede conferma: "Se cambi modalità, la connessione attuale viene rimossa. Continuare?"

**Form "app propria".**
Campi: Client ID, Client Secret (`CampoSegreto`, con occhio solo durante l'inserimento), Tenant ID (solo Microsoft, aiuto "Lo trovi nel pannello Microsoft Azure"), Redirect URI **in sola lettura** con pulsante `Copia`.
Sotto: `Apri guida` (link esterno), `Test connessione`, riga stato.
Dopo il salvataggio il secret non è mai più mostrato: si vede solo `•••• 1234` con etichetta "Client Secret salvato". Per cambiarlo: `Sostituisci secret`.

**Procedura guidata (6 passi)** con `PassoGuida`, pulsanti `Indietro` / `Avanti`, barra di avanzamento "Passo 2 di 6":
1. Prerequisiti — cosa serve (account amministratore, accesso alla console).
2. Crea progetto/app — link diretto alla console.
3. Abilita API/permessi — elenco permessi minimi (calendario, email).
4. Crea credenziali — spiega dove copiare Client ID e Secret; pulsante `Copia` dove serve.
5. Incolla in Closer — riepilogo dei campi già compilati.
6. Test — `Test connessione` con esito.
Errori mostrati in chiaro, esempi: "Il Redirect URI non corrisponde. Copia quello mostrato qui sopra."; "Manca l'abilitazione dell'API Calendar."; "Client Secret non valido: controlla di aver copiato tutto."

**Email SMTP.** Una sola configurazione per azienda (testo: "Vale per tutta l'azienda"). Campi: host, porta, TLS (interruttore, aiuto "Di solito 587 con TLS attivo"), username, password (`CampoSegreto`), mittente (email), nome mittente.
Azione `Invia email di prova`, destinatario precompilato con l'email dell'utente. Esiti: invio in corso, "Email di prova inviata a …", errore con motivo semplice e `Riprova`.

### 2. Impostazioni utente → Connessioni

Due card, Google e Microsoft. Per ciascuna:
- Account collegato: email o "Nessun account collegato".
- `Calendario scelto`: menu con i calendari disponibili.
- `Ultimo sync`: "Oggi alle 14:32" oppure "Mai".
- Azioni: `Collega` (se assente), `Ricollega` (se presente), `Scollega` (conferma).
Testo di aiuto obbligatorio sotto il titolo: **"Serve per creare appuntamenti e link call sul tuo calendario."**
Nota privacy breve: "Closer vede solo i calendari che scegli. Puoi scollegare quando vuoi."
Stati: caricamento, nessun calendario disponibile ("Nessun calendario trovato. Riprova o controlla le autorizzazioni."), errore con `Riprova`, senza permesso.

### 3. Impostazioni utente → Condivisione calendario

Titolo sezione: **"Condividi il mio calendario con un collega"**.
- Selezione utente della stessa azienda (ricerca per nome, escluso se stesso).
- Livello: `Solo libero/occupato`, `Dettagli` (predefinito, sola lettura), `Modifica`.
- Spiegazione privacy in 1–2 righe per livello: libero/occupato "Vede solo se sei occupato, non titoli o clienti"; dettagli "Vede titoli e dettagli, senza modificare"; modifica "Può modificare i tuoi eventi".
- `Modifica` mostra avviso ambra: "Il collega potrà cambiare i tuoi appuntamenti." e chiede conferma prima di salvare.
- Elenco condivisioni attive: avatar, nome, `BadgeLivello`, `Revoca` con dialogo "Vuoi revocare l'accesso a …?".
- Sezione **"Condivisi con me"**: elenco in sola lettura (proprietario, livello, nota "Sola lettura" se Dettagli).
Stati: vuoto ("Non hai ancora condiviso il tuo calendario"), caricamento, errore, senza permesso.

### 4. Calendario

- Pannello/legenda con due gruppi: **"I miei calendari"** e **"Condivisi con me"**. Colori distinti (proprio: blu; condivisi: tonalità diverse, sempre con etichetta, mai solo colore).
- Ogni calendario condiviso ha `BadgeLivello` accanto al nome.
- Eventi con livello libero/occupato: blocco grigio intitolato **"Occupato"**, senza titolo, cliente o note.
- Dettaglio evento: mostra "Fonte: calendario di …" e il livello. Il link call è visibile solo se il livello è Dettagli o Modifica; con libero/occupato non compare.
- Con `Modifica` compaiono le azioni di modifica; altrimenti sola lettura.
- Telefono: vista giorno a lista; eventi condivisi con bordo colorato e badge. Desktop: griglia settimanale, eventi condivisi in tinta più chiara; tocco/clic apre il dettaglio in pannello.

### 5. Stati obbligatori

| Stato | Comportamento |
|---|---|
| Caricamento | skeleton delle card, altezza stabile, nessun salto |
| Vuoto | frase semplice + azione ("Nessuna condivisione. Condividi il calendario") |
| Errore | box rosso con motivo breve e `Riprova` |
| Senza permesso | schermata `SenzaPermesso` con spiegazione; nessun dato caricato |
| Test in corso | pulsante disabilitato + spinner + "Verifica in corso…" |
| Test riuscito | box verde "Connessione riuscita" |
| Test fallito | box rosso con causa leggibile + `Riprova` |
| Secret configurato | solo `•••• 1234` + "Sostituisci secret" |
| Disconnesso | pallino grigio, "Da configurare", azioni di connessione |

### 6. Chiavi di test consigliate

| Chiave | Verifica |
|---|---|
| `integrazioni-google` | card Google, stato e azioni |
| `integrazioni-google-modalita` | scelta app Closer / app propria |
| `integrazioni-google-test` | esito test riuscito e fallito |
| `condivisione-calendario` | creazione condivisione |
| `condivisione-livello` | default Dettagli e avviso su Modifica |
| `condivisione-revoca` | conferma e revoca |
| `calendario-condivisi` | sezione "Condivisi con me" e mascheramento "Occupato" |

### 7. Telefono e desktop

- **Telefono (<640):** card impilate a una colonna; form e procedura guidata a schermo intero con barra `Salva` fissa in basso; conferme come foglio dal basso; testi a piena larghezza.
- **Tablet (640–1024):** card a due colonne, form a pannello.
- **Desktop (>1024):** due colonne — elenco integrazioni a sinistra (1/3), dettaglio/configurazione a destra (2/3); spazio interno card 20–24.
- I pulsanti restano grandi e distanziati; nessun menu nascosto per le azioni principali.

### 8. Testi e regole di contenuto

- Aiuti brevi, una frase: "Collega il tuo account per creare appuntamenti.", "Una sola configurazione email per tutta l'azienda."
- Niente gergo: dire "account", "codice", "indirizzo", non "OAuth", "endpoint", "scope".
- Se manca una configurazione, dirlo: "Senza Google o Microsoft, il link call va incollato a mano."; "Senza SMTP, le email non partono: i promemoria restano dentro Closer."
- **Mai** mostrare token, Client Secret o password dopo il salvataggio; sempre mascherati.
- Nessun pulsante "Pubblica sugli store" o simile.

**Aggiornamento 2026-10-24 — form appuntamento**
- Campi inizio/fine con data e ora; flag **Tutto il giorno** accanto alla data di inizio.
- **Ripeti**: mai, giornaliero, settimanale, bisettimanale, mensile, annuale, personalizzato con giorni e
  intervallo in settimane.
- **Notifica**: all'ora, 5/10/15/30 minuti prima, personalizzata.
- **Appuntamento privato**: titolo, luogo e dettagli mascherati per chi non è creatore o operatore.
- Gli allegati restano fuori finché R2 non è attivo; nessun pulsante finto nel form.
