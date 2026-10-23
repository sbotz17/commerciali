# Notifiche e promemoria — guida funzionale

**Stato: bozza funzionale.** Le schermate definitive saranno aggiunte dopo l'implementazione.

## Tre canali

| Canale | A cosa serve | Configurazione |
|---|---|---|
| **In-app** | Centro notifiche, badge e avvisi dentro Closer | automatico |
| **Push** | Avviso sul dispositivo, anche con app chiusa | permesso + FCM/VAPID |
| **WhatsApp** | Promemoria operativo o comunicazione all'operatore | server Volty, numero e consenso |

Le notifiche push **non sostituiscono** il centro notifiche: ogni avviso resta sempre nell'elenco in-app.

## Centro notifiche

- icona campanella con badge delle non lette;
- elenco per data, con tipo e anteprima;
- tocco sulla notifica → apre appuntamento, task o chat;
- “Segna letta” e “Segna tutte come lette”;
- notifiche lette restano consultabili.

## Cosa genera una notifica

- nuovo appuntamento assegnato;
- modifica di data/ora di un appuntamento;
- task assegnato o in scadenza;
- promemoria di appuntamento o task;
- nuovo messaggio in chat;
- comunicazione inviata da un collega;
- esito di un invio al cliente (inviato/fallito).

Non arrivano notifiche per elementi annullati o completati, salvo comunicazioni esplicite.

## Preferenze per utente

Ogni operatore configura:

- canali attivi: in-app, push, WhatsApp;
- tipi attivi: appuntamenti, task, promemoria, chat, comunicazioni;
- numero WhatsApp e consenso;
- orari di silenzio;
- fuso orario;
- anteprima del testo nelle push.

Le preferenze sono personali. Un amministratore può vedere lo stato delle configurazioni, ma non i messaggi privati.

## Orari di silenzio

- Sono configurabili nelle impostazioni.
- Di default: **22:00–08:00**.
- Le notifiche normali vengono trattenute e consegnate dopo la fine del silenzio.
- Le notifiche **urgenti** possono essere configurate per passare comunque.
- Il fuso orario usato è quello aziendale, salvo diversa impostazione dell'operatore.

## Push: prerequisiti

### Web / PWA

- sito HTTPS;
- permesso notifiche concesso dal browser;
- chiave VAPID e service worker configurati;
- su iPhone funziona solo con PWA installata e iOS aggiornato.

### Android

- configurazione Firebase/Google Services;
- permesso notifiche del sistema;
- token del dispositivo registrato.

### iOS

- account Apple Developer attivo;
- chiave APNs caricata su Firebase;
- permesso notifiche dell'utente.

**Nota**: senza account Apple Developer le push iOS non possono essere attivate.

## WhatsApp operatore

- Ogni operatore inserisce il proprio numero e conferma il consenso.
- Il numero deve avere il prefisso internazionale.
- L'invio usa il server Volty configurato dall'amministratore.
- Se il server non è configurato o il numero non è valido, la notifica WhatsApp risulta “non inviata” e resta disponibile in-app.
- L'operatore può disattivare WhatsApp senza perdere le altre notifiche.

## Promemoria al cliente

- Canale: email o WhatsApp, secondo le impostazioni.
- Momento: subito dopo la creazione (solo se attivo) e all'orario configurato.
- Template modificabile con data, ora, luogo, azienda e riferimento.
- Ogni invio è registrato con esito; un errore non blocca l'appuntamento.

## Se non arrivano notifiche

1. Controlla di aver concesso il permesso nelle impostazioni del dispositivo.
2. Verifica che il canale sia attivo nelle preferenze.
3. Controlla gli orari di silenzio.
4. Per WhatsApp, verifica numero, consenso e server Volty.
5. Per iOS, verifica APNs e account Apple Developer.
6. Esci e rientra nell'app per rinnovare il token del dispositivo.
