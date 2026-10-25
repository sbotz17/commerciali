# Calendario, appuntamenti e task — guida funzionale

**Stato: bozza funzionale.** Le schermate definitive e gli screenshot saranno aggiunti dopo l'implementazione.

## A cosa serve

Il Calendario riunisce in un unico posto:

- visite del giro visite;
- appuntamenti generici o collegati a un cliente;
- task e attività da fare;
- promemoria con data e ora.

L'obiettivo è che un utente non debba cercare in tre schermate diverse.

## Calendario

1. Apri **Calendario** dal menu.
2. Il calendario si apre sulla **vista mensile**. Scegli **Giorno**, **Settimana** o **Mese** per il periodo e **Calendario** o **Card** per lo stile.
3. Usa **Oggi** per tornare alla data corrente e le frecce per spostarti.
4. Filtra per **operatore**.
5. Tocca un elemento per aprire il dettaglio. Su telefono il dettaglio occupa quasi tutto lo schermo:
   in alto trovi titolo, data/ora e stato; al centro le sezioni **Panoramica**, **Cliente**,
   **Condivisione**, **Dettagli** e **Allegati**; in fondo i pulsanti delle azioni, a tutta larghezza.
   La **X** in alto a destra chiude il dettaglio.
6. Tocca uno spazio vuoto nella vista giorno o settimana per creare un appuntamento con data e ora già impostate.
7. Dalla vista mese, tocca un giorno per aprirlo nella vista giornaliera.

Gli elementi senza orario compaiono in **Senza orario**.

## Creare un appuntamento

1. Premi **+** accanto a **Card** nella barra del calendario.
2. Inserisci il **titolo** (obbligatorio).
3. Scegli **data e ora di inizio** e **data e ora di fine**. Il flag **Tutto il giorno** accanto alla data
   disattiva gli orari.
4. Se serve, imposta **Ripeti**: mai, ogni giorno, ogni settimana, ogni due settimane, ogni mese, ogni anno
   o personalizza scegliendo i giorni della settimana e ogni quante settimane.
5. Scegli la **notifica**: all'ora dell'evento, 5/10/15/30 minuti prima oppure personalizzata.
6. Collega un cliente, se serve. Con il **+** accanto al campo Cliente puoi crearne uno nuovo e selezionarlo subito.
7. Assegna un **operatore**.
8. Inserisci luogo e indirizzo.
9. In **Condivisione** scegli una o più persone oppure un gruppo: ricevono una notifica e devono confermare.
10. Attiva **Appuntamento privato** se titolo, luogo e dettagli devono essere visibili solo a te e
    all'utente assegnato.
11. Aggiungi note.
12. In **Allegati** puoi caricare immagini, video, PDF o file email (max 10 MB per file).
13. Salva.

L'appuntamento condiviso resta **in attesa di conferma** finché almeno un invitato non conferma la
disponibilità. Nel dettaglio vedi lo stato di ogni invitato e, se sei tra gli invitati, i pulsanti
**Confermo** e **Non disponibile**.

Nel dettaglio dell'appuntamento trovi anche i **dati del cliente collegato** (nome, referente, contatti,
P.IVA, indirizzo e note). Il pulsante **Modifica cliente** apre la scheda del cliente; dopo il salvataggio
il nome aggiornato viene riportato anche sull'appuntamento.

Quando un invitato risponde, chi ha creato l'appuntamento e l'utente assegnato ricevono una **notifica
In-App**. Se hanno attivato WhatsApp nelle proprie preferenze, ricevono anche un messaggio WhatsApp.
Per attivarlo: **Impostazioni → Notifiche → WhatsApp**, inserisci il numero e attiva il consenso.

La scelta **Notifica** nel form programma un promemoria WhatsApp: il Worker lo invia ogni minuto quando
scade, se il server WhatsApp è configurato. Non è ancora un push/notifica In-App programmata.

Gli **allegati** sono nel KV del Worker (non in Firestore) e si aprono con un link temporaneo di un'ora.
Sono una soluzione temporanea finché R2 non viene attivato.

### Icona auto

Se l'appuntamento ha un indirizzo, accanto compare l'icona **auto**.
Toccandola si apre Google Maps con la destinazione già impostata.

### Call online

Nell'appuntamento puoi scegliere **Google Meet** o **Microsoft Teams**.
Se l'integrazione è configurata, il link viene creato automaticamente e salvato nell'appuntamento.
Il link può essere copiato e incluso nel promemoria al cliente.

## Creare un task

1. Apri **Task** oppure crea il task dall'appuntamento.
2. Inserisci titolo, scadenza, operatore e priorità.
3. Collega cliente o appuntamento, se serve.
4. Aggiungi note, checklist e immagini.
5. Salva.

Il task appare nella pagina **Task** e, se ha una data, anche nel Calendario.
Completandolo viene registrata data, ora e autore.

## Promemoria

- Il promemoria interno arriva nell'app e, se attivo, in push.
- Il promemoria al cliente può partire via WhatsApp o email.
- L'orario si configura in **Impostazioni → Calendario e notifiche**.
- Ogni invio ha uno stato: programmato, inviato, fallito.
- Se sposti l'appuntamento, il promemoria viene ricalcolato.

## Allegati

- Puoi aggiungere una o più immagini a un appuntamento o a un task.
- Le immagini si aprono a schermo intero e si possono eliminare con conferma.
- I limiti di dimensione e numero si configurano nelle impostazioni.

## Condivisione slot

1. Apri l'appuntamento o il calendario.
2. Scegli **Condividi disponibilità**.
3. Seleziona data, durata e numero di slot.
4. Invia il link al cliente via email o WhatsApp.
5. Il cliente sceglie uno slot libero.
6. Lo slot prenotato entra in Closer e l'operatore riceve una notifica.

## Impostazioni collegate

- fuso orario aziendale;
- anticipo promemoria;
- orario di invio al cliente;
- canale email/WhatsApp;
- template messaggi;
- account Google e Microsoft;
- provider call predefinito;
- durata slot e scadenza link;
- limiti allegati;
- notifiche e orari di silenzio.

## Se qualcosa non funziona

- **Nessun promemoria**: controlla canale, orario e integrazione nelle impostazioni.
- **Maps non si apre**: verifica che l'indirizzo sia completo.
- **Call non creata**: controlla che l'account Google o Microsoft sia collegato.
- **Slot già occupato**: ricarica la pagina; il sistema impedisce la doppia prenotazione.
- **Allegato non caricato**: controlla dimensione, formato e connessione.
