# Definition of Done — nessun rilascio senza questi criteri

Un task o un milestone **non è "fatto"** e non si rilascia se manca anche uno solo di questi punti.

## Codice

1. `flutter analyze` → 0 problemi.
2. `flutter test` → tutti verdi; ogni correzione ha un test che fallisce senza la correzione.
3. Nessuna modifica a `firestore.rules`, vecchia app o configurazioni di produzione senza approvazione.

## Test eseguiti dalla squadra

I test sono un compito della squadra, **non di Andrea**:

- il tester esegue i comandi (`flutter analyze`, `flutter test`, script E2E) e la prova su staging;
- ogni comportamento nuovo o corretto ha un test automatico che lo copre;
- se manca un test, il task non è `FATTO` e torna allo sviluppo;
- ad Andrea si chiede solo la validazione funzionale/UX, dopo il report del tester.

## Prova reale su staging (obbligatoria)

Il tester deve eseguire l'app pubblicata su `https://commerciali-app.web.app` con un utente di test e:

1. fare login (email/password o Google);
2. verificare che l'**azienda attiva** sia impostata automaticamente;
3. creare, modificare ed eliminare un **cliente**;
4. creare un **preventivo**, verificare il numero `PRV-` e i totali;
5. verificare che i dati siano persistiti e visibili dopo il reload;
6. verificare che non compaia **permission-denied**;
7. verificare che **nessuna pagina del perimetro** mostri "Schermata in preparazione".

Il report deve contenere comandi, passi, esito atteso/ottenuto e almeno una prova (screenshot o log).

## Servizi esterni e contratti

Per ogni schermata che usa un servizio esterno (Worker, server WhatsApp, OAuth, SMTP, push):

- il tester deve provare il **flusso completo nella UI**, non solo l'endpoint con `curl`;
- la risposta del servizio deve essere normalizzata in un contratto unico e coperta da un test che usa una
  risposta reale o un fixture identico alla produzione;
- un test unitario con una risposta inventata non sostituisce la prova UI;
- se la UI non è provabile, il task è **BLOCCATO**, non "SUPERATO con residuo": non si dichiara FATTO.

## Validazione

Il validatore **respinge** se:
- manca la prova E2E;
- una pagina del perimetro è ancora un segnaposto;
- il task board dichiara `FATTO` con criteri non soddisfatti;
- il tester ha scritto "SUPERATO con riserva" senza una data certa per la riserva.

## Rilascio

Solo dopo tester + validatore + GO del guardiano. La produzione resta separata e richiede la validazione di Andrea.
