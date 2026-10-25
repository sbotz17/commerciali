# Registro dei ritorni

| Numero | Data | Segnalazione | Esito | Note |
|---|---|---|---|---|
| R-1 | 25/10/2026 | Riaprendo un preventivo dalla lista si apre un editor vuoto "Nuovo preventivo" | CONFERMATO | Riprodotto in UI su staging (PRV-0001). Causa: `preventivi_screen.dart:160` naviga sempre a `/preventivi/nuovo` ignorando il preventivo. Gravità alta: impedisce modifica e revisione. Trovato durante l'audit ondata 2. |
