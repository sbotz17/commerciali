# Audit ondata 3 — Accesso, dati economici e agenda (staging)

**Data**: 28/10/2026
**Build provata**: `v1.0.0+1 · 2026.10.26-0028` (live `https://commerciali-app.web.app`)
**Utente di prova**: creato dall'app con registrazione autonoma (`audit-…@commerciali.test`), azienda
`Audit Azienda 28-10`.
**Metodo**: Chrome reale automatizzato (Playwright) sulla UI pubblicata, con login, onboarding e creazione
dei dati di prova; nessun dato preesistente modificato.
**Nota**: il numero di build non riporta il commit; la versione visibile è quella del 26/10 00:28. Le
modifiche locali di accesso/password presenti nel repository non sono su questa build.

## Esiti

| Area | Prova | Esito | Evidenza |
|---|---|---|---|
| AU01 | Registrazione nuovo account dall'app | OK | account creato, email di prova |
| AU01 | Onboarding “Configura la tua azienda” | OK | azienda `Audit Azienda 28-10`, dashboard raggiunta |
| AU01 | Login email + sessione + intro primo avvio | OK | login, “Ho capito, inizia”, dashboard |
| AU02 | Dashboard con azienda nuova | OK | 0 preventivi, 0 clienti, azioni rapide visibili |
| AU03 | Creazione cliente | OK | `Audit Cliente 28-10`, P.IVA `00159560366` |
| AU03 | Persistenza dopo reload | OK | cliente ancora in elenco |
| AU04 | Creazione prodotto | OK | `Audit Prodotto 28-10`, 125,50 € |
| AU05 | Creazione preventivo con cliente e riga | OK | `PRV-0001`, 100,00 € |
| AU05 | Riapertura preventivo | OK | “Modifica preventivo”, numero e cliente |
| AU05 | PDF | OK | download `PRV-0001.pdf` |
| AU06 | Creazione visita | OK | visita del 28/10 con cliente |
| AU07 | Creazione appuntamento | OK (lenta) | appuntamento visibile in calendario; ~15-20 s per il refresh |
| AU07/AU09 | Promemoria: cancellazione | **FALLITA → corretta R-4** | `POST /promemoria/annulla` 500 `KV list() limit exceeded`; dopo deploy **200 `{ok:true}`** |
| AU08 | Creazione task | OK | task conteggiato in “Senza scadenza 1” |
| AU08 | Accessibilità card task | **FALLITA (R-3)** | titolo non presente nell'albero semantico; solo “Senza scadenza · 1 · Azioni” |
| AU09 | Preferenze notifiche | OK | nessun “Non hai i permessi”; R-2 confermato |
| AU11 | Elenco e ricerca bandi | OK | lista reale, ricerca “software” |
| AU12 | Apertura impostazioni | OK | schermata caricata |
| AU15 | Produzione | BLOCCATA | progetto di produzione non ancora creato |

## Bug

### R-4 — Promemoria: quota `KV list()` esaurita (P1) — CHIUSO

- Riproduzione: creazione appuntamento → `POST https://commerciali-vies.bottiandrea83.workers.dev/promemoria/annulla`
  → **500** `{"error":"KV list() limit exceeded for the day."}`.
- Causa: cron ogni minuto + `list()` sul KV a ogni salvataggio/cancellazione; la quota giornaliera si esaurisce.
- Correzione: indice `promemoria-indice:{id}` (get/delete, niente list), fallback una-tantum per i dati
  vecchi che non blocca il salvataggio, cron ogni 5 minuti.
- Tester `SUPERATO`, validatore `APPROVATO`, CI verde, deploy Worker `eae06f48`.
- Smoke reale: `POST /promemoria/annulla` → **200 `{ok:true}`**; UI calendario senza errore console.
- Report: `test/2026-10-28-R-4-promemoria.md`.

### R-3 — Task: titolo non leggibile dall'albero di accessibilità (P2) — APERTO

- La card è visibile a schermo ma il testo semantico contiene solo “Senza scadenza · 1 · Azioni”.
- Effetto: screen reader e test UI non leggono il titolo.
- Da correggere con `Semantics`/`MergeSemantics` e un test di regressione.

### R-2 — Preferenze notifiche (P1) — CHIUSO

- Confermato di nuovo il 28/10: la schermata si apre senza “Non hai i permessi”. Regola già corretta e
  pubblicata; resta da provare il salvataggio dal pulsante.

## Osservazioni

- **Calendario lento**: dopo “Crea appuntamento” la vista resta con lo spinner per circa 15-20 secondi. Non
  è un errore, ma è un'attesa percepita; da misurare e ridurre.
- **Doppioni da prove ripetute**: le prove hanno creato più appuntamenti con lo stesso titolo; sono dati di
  test, non un difetto dell'app.
- **Build senza commit**: la versione mostra data/ora ma non il commit. Per l'audit serve il commit nel
  numero di build.

## Cosa resta da provare (non dichiarato “funzionante”)

- AU01: Google, Face ID/passkey, recupero password, utente disattivato.
- AU05: modifica, eliminazione, revisioni, invio.
- AU06: modifica, eliminazione, riordino, stati, promemoria visita.
- AU07: ricorrenza, tutto il giorno, privato, partecipanti, call, Maps, allegati, condivisione.
- AU08: modifica, eliminazione, completamento, filtri; R-3.
- AU09: salvataggio preferenze, push reale, WhatsApp personale, silenzio.
- AU10: chat (serve un secondo utente in azienda).
- AU11: dettaglio e import.
- AU12: utenti, ruoli, licenze, superadmin, integrazioni reali.
- AU13: invio WhatsApp/email/push reali.
- AU15: produzione.

## Dati di prova

Creati su staging con l'account di audit: 1 cliente, 1 prodotto, 1 preventivo, 1 visita, 4 appuntamenti
(da prove ripetute), 1 task. Nessun dato reale toccato.
