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
