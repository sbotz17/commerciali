# Handoff sessione — 1 novembre 2026

Stato per chi riprende il lavoro. Nessuna area nuova è stata dichiarata `PROVATA` in questa sessione.

## Cosa è stato chiuso

| Oggetto | Stato | Dove |
|---|---|---|
| Regole della squadra in nucleo breve + 10 skill | fatto, sincronizzato su 6 progetti | `squadraalphalab`, `AGENTS.md` |
| Sincronizzazione automatica delle regole (SYNC_TOKEN) | attiva | workflow `sync-squad-rules.yml` |
| Regola “staging è ambiente di rilascio” + validatore con prove | attiva | `AGENTS.md`, `skills/squadra-audit` |
| R-1 riapertura preventivo | CHIUSO (corretto + prova UI su canale di anteprima) | `docs/progetto/ritorni.md` |
| AU03 Clienti | `PROVATA` (altra sessione, PR #75) | `docs/progetto/test/2026-10-29-AU03-clienti.md` |
| AU04 Catalogo | `DA RIFARE` | `docs/progetto/test/2026-10-30-AU04-catalogo.md` |

## Cosa manca su AU04

Build di riferimento: commit `e69ae43`, build locale (`flutter build web --release`), nessun deploy.

1. **Immagine prodotto da URL**: non si carica con URL esterni, la console riporta
   `blocked by CORS policy`. Il campo si salva, l'immagine non compare.
   Da decidere: hosting interno (Firebase Storage) oppure gestione esplicita di URL con CORS.
2. **Filtro categoria senza prodotti**: creare una categoria vuota dedicata e verificare lo stato vuoto.
3. **Eliminazione con asserzione corretta**: lo script deve verificare il nome letto dal dialogo, non un
   prodotto fisso.

Prove già solide: creazione categoria e prodotti, validazione senza nome, paniere con due figli + badge +
persistenza, ricerca con e senza risultati, isolamento tra aziende, test rosso del badge
(3 rossi rompendo `etichettaFigli`, 6 verdi dopo il ripristino).

## Stato del repository (importante)

Ci sono **31 file non committati** che non appartengono a questa sessione (auth, login, reset password,
shell, `functions/webauthn.js`, `versione_app.dart`, `aggiornamento.js`, più script di audit). Non sono
stati toccati e non risultano modificati nelle ultime ore: sembrano lavoro fermo di un'altra sessione.

Contaminano qualsiasi build: per l'audit ho usato un worktree pulito
(`/private/var/folders/.../opencode/commerciali-au04`) sul commit `e69ae43`.
Vanno commit, spostati su un ramo o scartati da chi li ha prodotti: finché restano lì, ogni prova va fatta
da un worktree.

## Prossimi passi

1. Chiudere i tre punti di AU04, poi tester e validatore in sessioni distinte.
2. Proseguire l'ordine dell'audit: AU05 Preventivi, AU02 Dashboard, AU06–AU08, AU11–AU14.
3. AU01 (Google, Face ID, reset) e AU09 (push) restano `BLOCCATA`: servono prove su dispositivi o servizi
   non disponibili in questa sessione.
4. Non pubblicare su staging finché un'area non è `PROVATA`.

## Comandi utili

```bash
python3 scripts/blocco-squadra.py stato
python3 scripts/e2e-ui-dati.py setup            # stampa email, azienda e file di stato
E2E_STATO=<file> python3 scripts/e2e-ui-dati.py cleanup
cd scripts/audit-ui && AUDIT_BASE=... AUDIT_EMAIL=... AUDIT_PASS=... node au04-prova.js
```
