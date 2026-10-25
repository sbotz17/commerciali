# Integrazioni esterne — guida di configurazione

**Stato: bozza tecnica.** Le credenziali vanno inserite in secret/variabili d'ambiente, mai nel codice o in chat.

## Chi configura cosa

| Voce | Chi la configura | Dove |
|---|---|---|
| Client ID/secret Google | Superadmin / responsabile tecnico, una volta per l'app | Google Cloud + secret del Worker |
| Connessione a Google Calendar | Ogni utente, con il proprio account | Impostazioni utente → Integrazioni |
| App registration Azure/Microsoft | Superadmin / responsabile tecnico, una volta per l'app | Azure Portal + secret del Worker |
| Connessione a Microsoft 365/Teams | Ogni utente, con il proprio account aziendale | Impostazioni utente → Integrazioni |
| SMTP | Azienda, con eventuale override per utente | Impostazioni → Email |
| WhatsApp Volty | Superadmin | Impostazioni → WhatsApp |
| Bucket R2 | Superadmin | Impostazioni → Storage |
| VAPID/FCM | Superadmin / responsabile tecnico | Firebase Console + secret del Worker |
| Apple Developer/APNs | Superadmin / responsabile tecnico | Apple Developer + Firebase Console |

Le **password e i token** non vanno mai incollati in chat, in Firestore o nel codice: si inseriscono in un pannello superadmin che li invia al Worker e li salva come secret.

## 1. Google Calendar e Google Meet

### Cosa serve

- progetto Google Cloud;
- API **Google Calendar** abilitata;
- OAuth consent screen configurato;
- client OAuth di tipo Web;
- redirect autorizzato: dominio Closer + percorso di callback;
- scope minimi per leggere/scrivere eventi e creare la conferenza Meet.

### Configurazione

1. Crea il client OAuth.
2. Inserisci client ID e secret nei secret del Worker.
3. Collega l'account da **Impostazioni → Integrazioni → Google**.
4. Concedi i permessi.
5. Verifica lo stato “Collegato”.

### Comportamento

- gli appuntamenti Closer possono essere creati/aggiornati su Google Calendar;
- gli eventi esterni del periodo compaiono in Closer;
- il link Meet viene salvato nell'appuntamento;
- token scaduto → “Ricollega l'account”.

### Limiti

- servono scope sensibili e verifica Google per l'uso pubblico;
- la creazione di Meet dipende dall'account Google;
- gli eventi esterni ricorrenti sono importati in sola lettura.

## 2. Microsoft 365, Outlook e Teams

### Cosa serve

- registrazione app su Azure/Entra ID;
- tenant ID, client ID e client secret;
- permessi Microsoft Graph per calendario e online meeting;
- licenza Microsoft 365 adeguata per creare riunioni Teams;
- redirect autorizzato.

### Configurazione

1. Registra l'app su Azure.
2. Aggiungi i permessi Graph necessari.
3. Inserisci tenant/client/secret nei secret del Worker.
4. Collega l'account da **Impostazioni → Integrazioni → Microsoft**.
5. Verifica lo stato.

### Comportamento

- gli appuntamenti possono essere sincronizzati con Outlook;
- il link Teams viene creato e salvato;
- eventi esterni importati in sola lettura;
- conflitti segnalati, senza sovrascrittura silenziosa.

### Limiti

- la creazione di riunioni Teams richiede licenza Microsoft 365;
- alcuni permessi richiedono consenso amministratore del tenant;
- costi e disponibilità dipendono dal piano Microsoft.

## 2bis. Email clienti (Resend)

Per l'MVP l'email ai clienti usa un unico mittente di piattaforma tramite **Resend**.

1. Apri **Super Admin → Server email**.
2. Inserisci l'**email mittente** (dominio verificato su Resend), il **nome mittente** e la **API key**.
3. Salva e usa **Invia email di prova** verso un indirizzo tuo.
4. La chiave resta nel KV `EMAIL_CONFIG` del Worker e non viene salvata in Firestore.

Senza questa configurazione il canale email risulta **non configurato** e WhatsApp resta l'unico canale
esterno disponibile. La configurazione SMTP per singola azienda resta un'evoluzione separata.

## 3. Email SMTP per azienda

### Cosa serve

- server SMTP: host, porta, sicurezza (SSL/TLS);
- utente e password;
- indirizzo mittente verificato;
- eventuale limite giornaliero.

### Configurazione

1. Apri **Impostazioni → Calendario e notifiche → Email**.
2. Inserisci i dati SMTP.
3. Salva: i segreti vengono conservati lato server, non mostrati in chiaro.
4. Invia un messaggio di prova.
5. Attiva il canale email per i promemoria.

### Comportamento

- ogni azienda usa il proprio SMTP;
- template con segnaposto;
- invio immediato e programmato;
- retry ed esito visibile.

### Limiti

- il browser non può inviare SMTP direttamente: serve il Worker/server;
- provider gratuiti hanno limiti giornalieri;
- senza SMTP configurato il canale email è disattivato, WhatsApp e in-app restano attivi.

## 4. WhatsApp — server Volty

### Cosa serve

- URL del server Volty;
- API key;
- numero mittente;
- endpoint `/send` raggiungibile;
- consenso del destinatario.

### Configurazione

1. **Super Admin → Server WhatsApp** (nella nuova app Closer).
2. Inserisci URL e API key del server: vengono salvati nel KV del Worker
   Cloudflare, non in Firestore e non sul dispositivo degli utenti.
3. Premi **Verifica connessione**; se il numero non è collegato, usa
   **Mostra QR** e scansiona il QR da WhatsApp → Dispositivi collegati.
4. Ogni utente imposta il proprio numero e il consenso in
   **Impostazioni → Notifiche → WhatsApp**.
5. Gli inviti e le conferme degli appuntamenti partono in automatico.

### Comportamento

- promemoria al cliente e notifiche all'operatore;
- esito inviato/fallito;
- retry;
- opt-out dell'operatore.

### Limiti

- il server è esterno: disponibilità e costi dipendono dal servizio Volty;
- la API key non deve essere leggibile dal client;
- messaggi fuori orario secondo le preferenze.

## 5. Cloudflare R2 — immagini

### Cosa serve

- account Cloudflare R2;
- bucket dedicato;
- access key e secret;
- URL pubblico o firmato;
- regole di scadenza.

### Configurazione

1. Crea il bucket.
2. Inserisci le credenziali nei secret del Worker.
3. Imposta dimensione massima e formati.
4. Verifica upload e cancellazione.

### Comportamento

- upload firmato dal Worker;
- immagini visibili solo agli utenti dell'azienda;
- rimozione su eliminazione del messaggio/allegato;
- scansione periodica degli orfani.

## 6. Push — FCM, VAPID, APNs

### Web/PWA

- chiave VAPID generata in Firebase;
- service worker `firebase-messaging-sw.js`;
- permesso browser.

### Android

- `google-services.json`;
- Firebase Cloud Messaging;
- token dispositivo.

### iOS

- account Apple Developer;
- chiave APNs caricata su Firebase;
- `GoogleService-Info.plist`;
- permesso notifiche.

**Senza Apple Developer le push iOS non sono disponibili.**

## Sicurezza

- nessuna credenziale nel repository;
- nessun secret in Firestore leggibile dal client;
- token OAuth e SMTP solo lato server;
- redirect OAuth limitati ai domini Closer;
- log senza password, token o contenuto sensibile.

## Server WhatsApp di piattaforma

Il server è una VM Google Cloud (`whatsapp-server`) con reverse proxy HTTPS Caddy su
`https://35.188.136.131.sslip.io`. È collegato al numero `393516722792`.

- La API key è nel KV Cloudflare `WHATSAPP_CONFIG` e nel `.env` della VM, non nel repository.
- Staging usa il Worker `commerciali-vies`; produzione usa `commerciali-vies-prod`.
- Il QR e lo stato si gestiscono da Super Admin → WhatsApp.
- Il server usa Baileys (WhatsApp Web non ufficiale): per uso intensivo valutare la WhatsApp Business Cloud API.
