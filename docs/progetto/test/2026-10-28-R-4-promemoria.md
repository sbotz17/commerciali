# R-4 — Promemoria: quota `KV list()` esaurita

**Data**: 28/10/2026
**Ramo**: `fix/R-4-promemoria-kv`
**Commit testato**: `2463479`
**Ambiente**: worktree `/Users/andreabotti/Documents/commerciali-promemoria`; nessun deploy eseguito dal tester.

## Segnalazione

Durante l'audit della UI (calendario) il Worker ha risposto:

```
POST https://commerciali-vies.bottiandrea83.workers.dev/promemoria/annulla
500 {"error":"KV list() limit exceeded for the day."}
```

Causa: il cron girava ogni minuto e `annullaPromemoria()` faceva `list()` sul KV a ogni
salvataggio/cancellazione. La quota giornaliera `KV list()` del piano Cloudflare si esaurisce, quindi i
promemoria non vengono programmati né cancellati e l'app riceve 500.

## Correzione

- Indice per appuntamento `promemoria-indice:{id}`: la cancellazione usa `get` + `delete`, mai `list`.
- Dati vecchi senza indice: una sola `list`, poi marcatore `[]`; se la quota è esaurita l'errore viene
  registrato e **non** blocca il salvataggio.
- Cron da ogni minuto a ogni 5 minuti (`*/5 * * * *`): 288 `list`/giorno invece di 1440.
- CI aggiornata con il nuovo file di test.

## Prove eseguite dal tester (indipendente)

| Prova | Esito |
|---|---|
| `node --check` su `index.js`, `promemoria.mjs`, `whatsapp.mjs` | OK |
| `node --test test/promemoria.test.mjs test/promemoria-kv.test.mjs test/whatsapp.test.mjs` | 18 test passati, 0 falliti |
| KV finto: indice presente → 0 chiamate `list()`, chiavi cancellate, marcatore `[]` | OK |
| KV finto: indice già `[]` → 0 `list`, nessuna cancellazione | OK |
| KV finto: dati vecchi senza indice → 1 sola `list`, chiavi rimosse, marcatore `[]` | OK |
| KV finto: `list()` lancia “quota esaurita” → `annullaPromemoria` non lancia, chiave vecchia resta | OK (residuo dichiarato) |
| KV finto: indice corrotto o voci non stringa → non lancia, 0 `list` | OK |
| KV finto: senza binding KV → non lancia | OK |
| La chiave `promemoria-indice:` non ricade nel prefisso `promemoria:` del cron | OK |
| Handler reale con Firebase simulato: POST `/promemoria` → 200, `creati=1`, indice scritto | OK |
| POST `/promemoria/annulla` con quota list esaurita → 200 `{ok:true}`, nessuna `list` aggiuntiva | OK |
| Azienda non propria → 403; senza token → 401 | OK |
| `wrangler.toml`: `crons = ["*/5 * * * *"]` | OK |
| `.github/workflows/test.yml`: YAML valido e include `promemoria-kv.test.mjs` | OK |
| `flutter analyze` / `flutter test` nella worktree | 0 problemi / 898 test verdi |

## Cosa NON è stato provato

- Deploy reale del Worker e risposta 200 dell'endpoint pubblicato: il tester non poteva pubblicare.
- Quota KV reale su Cloudflare (la prova è con KV finto e handler simulato).
- Chiamata reale dal client Flutter al Worker (solo simulazione lato Node).

## Residui noti

- Per gli appuntamenti creati **prima** di questa correzione, se la quota `list()` è già esaurita, le
  chiavi vecchie non vengono rimosse (il salvataggio non si blocca). I nuovi promemoria funzionano;
  le chiavi vecchie possono restare e generare un invio doppio. Da valutare una pulizia quando la quota
  torna disponibile.

## Verdetto del tester

**SUPERATO** sui criteri verificabili. Restano da verificare in fase di rilascio: deploy del Worker e
smoke test reale di `/promemoria/annulla` con risposta 200.

## Validazione indipendente

**Esito: APPROVATO.** Il validatore ha letto il diff e il report e ha rieseguito:

- `node --check` su `index.js`, `promemoria.mjs`, `whatsapp.mjs`: OK.
- `node --test test/promemoria.test.mjs test/promemoria-kv.test.mjs test/whatsapp.test.mjs`: 18 passati, 0 falliti.
- Controllo puntuale: con indice presente nessuna `list`; fallback una sola `list` e nessuna eccezione;
  indice per appuntamento; cron `*/5`; 401/403 invariati.

Residui confermati: appuntamenti storici con quota già esaurita possono mantenere chiavi vecchie (possibile
invio doppio); indice corrotto non ripulito; primo accesso agli storici fa una `list` una-tantum.
Non verificati dal validatore: deploy reale, quota KV reale, `flutter analyze`/`flutter test` (diff solo
Worker/config/CI; il client Flutter non è toccato).
