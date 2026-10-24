# Sviluppi in attesa della validazione di Andrea

_Quando uno sviluppo è APPROVATO dal validatore, il coordinatore aggiunge qui una voce con: cosa fa, come
provarlo, rischi e come tornare indietro._


## 2026-10-24 — Calendario classico giorno/settimana/mese

**Cosa fa**: apre l'agenda sulla vista calendario mensile; in alto si scelgono periodo (Giorno, Settimana,
Mese) e stile (Calendario, Card). Giorno e settimana hanno la griglia delle ore, gli eventi sovrapposti
affiancati, “Senza orario” e la creazione di un appuntamento toccando uno spazio vuoto. La vista a card
esistente resta disponibile per tutti i periodi.

**Come provarlo**: aprire Calendario; verificare l'apertura sul mese; passare tra i tre periodi e i due
stili; creare un appuntamento da uno spazio vuoto; aprire il dettaglio di una voce; controllare un evento
senza orario.

**Rischi**: nessuna modifica a dati, regole o collezioni; sono cambiati solo widget e funzioni pure del
calendario. Il periodo scelto non viene memorizzato tra sessioni (si riparte dal mese).

**Come tornare indietro**: ripristinare `calendario_screen.dart` e `appuntamento_form_screen.dart` dal
commit precedente; i nuovi file `calendario_logica.dart` e `viste_calendario.dart` possono restare senza
effetto.

## 2026-10-24 — Nuovo cliente e condivisione appuntamento

**Cosa fa**: nel form appuntamento il **+** accanto al cliente apre la creazione cliente e lo seleziona
subito. La sezione **Condivisione** permette di invitare una o più persone e uno o più gruppi della chat:
gli invitati ricevono una notifica, aprono l'appuntamento dal centro notifiche e confermano o rifiutano la
disponibilità. L'appuntamento resta **In attesa di conferma** finché il primo invitato non conferma; il
dettaglio mostra lo stato di ciascuno.

**Come provarlo**: creare un appuntamento con almeno un invitato; controllare la notifica sul suo account;
confermare; verificare il badge “Confermato” e il dettaglio con le risposte; provare anche “Non disponibile”.

**Rischi**: campi nuovi su `appuntamenti` (nessuna migrazione, i documenti vecchi restano validi); nessuna
modifica a regole, indici o collezioni. Se un invito non parte, l'appuntamento viene comunque salvato e
resta visibile nel calendario.

**Come tornare indietro**: rimuovere i campi dal payload e ripristinare il form; i campi già scritti non
impediscono il funzionamento della versione precedente.

### Aggiornamento — notifica di conferma e WhatsApp

- La conferma di un invitato ora genera una notifica In-App per chi ha creato l'appuntamento e per
  l'operatore assegnato; è stata recuperata anche la conferma già presente di Simone.
- L'invio WhatsApp è implementato con rubrica aziendale e consenso, ma **non è attivo** finché non vengono
  configurati URL/API key nel Worker e il numero/consenso dell'utente.
- I test sono della squadra: analyze, 849 test, E2E regole reali e Worker. Andrea deve solo validare l'esperienza.

### Aggiornamento — configurazione WhatsApp dal pannello Super Admin

- Nuova schermata **Super Admin → Server WhatsApp**: URL, API key, verifica connessione, QR.
- La API key è nel KV del Worker Cloudflare, non in Firestore e non sul dispositivo degli utenti.
- Per usarla: aprire la schermata e inserire i dati del server; poi ogni utente imposta numero e consenso in
  Impostazioni → Notifiche. Non servono test tecnici da parte di Andrea.

### Aggiornamento — form appuntamento completo

- Data/ora di inizio e fine, flag **Tutto il giorno**.
- **Ripeti** (giorno, settimana, due settimane, mese, anno, personalizzato con giorni e intervallo).
- **Notifica** (all'ora, 5/10/15/30 minuti prima, personalizzata).
- **Appuntamento privato** con mascheramento di titolo/luogo/dettagli per chi non è creatore o operatore.
- **Allegati**: non ancora disponibili perché Cloudflare R2 non è attivo; nessun pulsante finto.
