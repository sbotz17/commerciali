# App Flutter

**Quando leggerlo**: qualsiasi lavoro su `flutter_app/`.
**Riferimento**: `docs/progetto/architettura.md` §Architettura Flutter, `docs/progetto/design.md` §Design Flutter.

## Struttura

```
flutter_app/lib/
├── main.dart / app.dart        # ProviderScope, Firebase, MaterialApp.router
├── core/theme/                 # Material 3
├── core/ui/                    # widget condivisi
├── data/models/                # UserProfile, Azienda, ...
├── data/services/              # AuthService, SpService
├── state/                      # provider Riverpod
├── routing/                    # go_router
└── features/                   # shell, auth, dashboard, clienti, ...
```

## Stato (2026-10-22)

- F01 scaffold + dipendenze: fatto.
- F02 Firebase (web/Android/iOS) + avvio: fatto.
- F03 tema, router, shell responsive: fatto.
- F04a auth email/password + profilo: fatto.
- F04b `SpService` base (aziende, membri, seed): fatto.
- F05 login email/password: fatto.
- F06a login Google web: fatto.
- F06a/F06b/F06c login Google e prova reale: fatti.
- F07a recupero password: fatto.
- F07b onboarding: fatto.
- F07c redirect: rinviato dopo F08 (vedi registro decisioni).
- F20 pagina introduttiva installazione: fatto.
- F21 intro interattiva con scelta dispositivo e mockup animati: fatto.
- Agenda, task, notifiche, chat: base fatta (vedi `memoria/ui/` e report).
- Calendario: vista classica giorno/settimana/mese e stile card; apertura predefinita sul calendario mensile
  (`calendario_logica.dart` + `viste_calendario.dart`).
- Integrazioni aziendali e condivisione calendario: O01–O04 fatti; O10 parziale; call manuale O11.
- Menu desktop: `NavigationRail` con tutte le pagine e rotella Impostazioni in fondo; telefono con `NavigationBar` + drawer “Altro”.
- Form appuntamento: sezione Partecipanti per invitare colleghi/gruppi; etichette visibili “Utente/Utenti” (campo dati `operatore_id` invariato).
- Pulizia dati test: `scripts/pulisci-dati-test.py`.
- Prossimo: Worker OAuth (O06/O07), connessioni utente (O08), vista calendario condiviso (O09), call automatica (O11), E2E browser (O12).

## Punti fermi

- Stesso progetto Firebase e stesse collezioni della vecchia app.
- Nessuna modifica a `firestore.rules`, contatori o Worker VIES.
- La vecchia app resta in uso finché non c'è parità.
- `flutter analyze` e `flutter test` devono restare verdi a ogni task.

**Ultima revisione**: 2026-10-24
