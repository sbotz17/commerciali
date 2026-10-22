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
- Prossimo: F16b bandi UI, F17b utenti/ruoli, F18 super admin.

## Punti fermi

- Stesso progetto Firebase e stesse collezioni della vecchia app.
- Nessuna modifica a `firestore.rules`, contatori o Worker VIES.
- La vecchia app resta in uso finché non c'è parità.
- `flutter analyze` e `flutter test` devono restare verdi a ogni task.

**Ultima revisione**: 2026-10-22
