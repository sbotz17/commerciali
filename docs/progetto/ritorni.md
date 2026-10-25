# Registro dei ritorni

| Numero | Data | Segnalazione | Esito | Note |
|---|---|---|---|---|
| R-1 | 25/10/2026 | Riaprendo un preventivo dalla lista si apre un editor vuoto "Nuovo preventivo" | CORRETTO — prova UI in sospeso | Riprodotto in UI su staging (PRV-0001). Causa: `preventivi_screen.dart:160` naviga sempre a `/preventivi/nuovo` ignorando il preventivo. Gravità alta: impedisce modifica e revisione. Trovato durante l'audit ondata 2. Correzione: la lista naviga a `/preventivi/<id>`; test di regressione aggiunto (fallisce senza correzione). `flutter analyze` 0, `flutter test` 882 verdi. Manca la prova UI sulla build pubblicata: richiede un deploy su staging, bloccato dal gate audit. |
