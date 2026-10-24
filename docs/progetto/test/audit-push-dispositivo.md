# Audit push e notifiche sul dispositivo

**Data**: 25/10/2026
**Stato**: **BLOCCATO**
**Area**: AU09 — Notifiche

## Cosa funziona

- service worker `/push/push-sw.js` pubblicato e registrabile;
- scope `/push/` separato dal service worker Flutter;
- `CloserPush.supportato = true` nel browser di prova;
- client che chiede il permesso, registra la sottoscrizione e restituisce
  endpoint/p256dh/auth;
- salvataggio della sottoscrizione in `dispositivi`;
- Cloud Function `inviaPushNotifica` pubblicata in produzione, trigger su `notifiche/{id}`;
- gestione endpoint scaduti 404/410;
- trigger provato con sottoscrizione finta: funzione eseguita, notifica passata a `fallita` con errore atteso;
- in staging il push è volutamente disattivato perché non esiste la funzione server.

## Perché è bloccato

La consegna reale non è stata provata con un dispositivo che concede il permesso notifiche:

- il browser di prova ha `Notification.permission = denied`;
- il test headless non ha completato il flusso UI in modo affidabile;
- su iPhone serve la PWA installata dalla schermata Home, non una scheda Safari normale.

Quindi non si può dichiarare “notifiche push funzionanti ad app chiusa”: manca la prova sul dispositivo.

## Cosa manca

1. Chrome desktop o Android con permesso notifiche concesso;
2. attivazione dalla schermata `Impostazioni → Notifiche → Notifiche sul dispositivo`;
3. verifica della sottoscrizione in `dispositivi`;
4. invio di una notifica di prova;
5. verifica che la notifica compaia ad app chiusa;
6. prova iPhone con Closer aggiunta alla Home;
7. tester + validatore.

## Cosa non è stato fatto

- non è stato dichiarato SUPERATO;
- non è stato usato un permesso forzato o un test finto come prova di consegna;
- non è stato inviato un messaggio a un numero reale senza consenso.

Fino a questa prova l’audit push è **BLOCCATO**.
