# Blocchi funzionali — Closer

**Regola**: si lavora in più sessioni solo su blocchi **diversi**. Due richieste sullo stesso blocco non
partono insieme: la seconda si blocca e va in coda, con il motivo comunicato ad Andrea.

Il controllo si fa con `scripts/blocco-squadra.py` (registro condiviso fra tutte le worktree del repository):

```sh
python3 scripts/blocco-squadra.py stato
python3 scripts/blocco-squadra.py occupa calendario --richiesta "..." --sessione "..."
python3 scripts/blocco-squadra.py coda calendario --richiesta "..." --sessione "..."
python3 scripts/blocco-squadra.py rilascia calendario --motivo "..."
```

## Mappa

| Blocco | Cosa comprende | File e servizi tipici |
|---|---|---|
| `accesso` | Login email, Google, Face ID/passkey, reset password, onboarding, sessione, utente disattivato | `features/auth/**`, `accesso_face_id_card.dart`, `passkey_service.dart`, `functions/webauthn.js` |
| `dashboard` | Conteggi, valore aperto, ultimi preventivi, azioni rapide | `features/dashboard/**` |
| `intro` | Pagina introduttiva e installazione dell'app, primo avvio | `features/intro/**`, `web/aggiornamento.js` |
| `clienti` | Elenco, form, ricerca, duplicati, VIES, isolamento azienda | `features/clienti/**`, `models/cliente.dart`, parti clienti di `sp_service.dart` |
| `catalogo` | Prodotti, categorie, immagini, codici, panieri | `features/catalogo/**`, `models/prodotto.dart`, `models/categoria.dart` |
| `preventivi` | Elenco, editor, righe, sconti, IVA, totali, numero `PRV-`, revisioni, PDF | `features/preventivi/**`, `models/preventivo.dart`, `services/preventivo_pdf.dart` |
| `visite` | Giro visite, elenco per giorno, riordino, stati, promemoria visita | `features/visite/**`, `models/visita.dart` |
| `calendario` | Calendario e appuntamenti: giorno/settimana/mese, creazione, ricorrenza, tutto il giorno, privato, partecipanti, call, Maps, allegati, condivisione, promemoria cliente | `features/calendario/**`, `models/appuntamento.dart`, `worker/src/promemoria.mjs` |
| `task` | Elenco, filtri, form, scadenze, priorità, completamento | `features/task/**`, `models/task_item.dart` |
| `notifiche` | Centro notifiche, badge, lette/non lette, preferenze, push web, WhatsApp personale, silenzio, anteprima | `features/notifiche/**`, `features/impostazioni/notifiche_preferenze_screen.dart`, `services/web_push_service.dart`, `worker/src/whatsapp.mjs` |
| `chat` | Chat dirette, gruppi, messaggi, immagini, letture, badge, notifiche | `features/chat/**`, `models/messaggio_chat.dart`, `models/stanza_chat.dart` |
| `bandi` | Lista, ricerca, filtri, dettaglio, import superadmin, sincronizzazione | `features/bandi/**`, `js/bandi-data.js`, `scripts/import-bandi.js`, workflow `sync-bandi.yml` |
| `impostazioni-azienda` | Profilo, azienda, utenti, ruoli, licenze, agenda, condivisione calendario | `features/impostazioni/**` (tranne notifiche), `models/ruolo.dart`, `models/licenza.dart` |
| `superadmin` | Aziende, licenze, server WhatsApp, server email | `features/superadmin/**`, parti superadmin di `functions/` |
| `integrazioni` | WhatsApp, email/Resend, push VAPID/FCM, VIES, R2, errori e retry | `worker/**`, `functions/**`, `services/vies*`, configurazioni |
| `infrastruttura` | Routing, shell, tema condiviso, regole Firestore, `pubspec`, CI, script di build/deploy | `routing/**`, `features/shell/**`, `core/theme/**`, `firestore.rules`, `firestore.indexes.json`, `.github/workflows/**`, `pubspec.yaml`, `scripts/build-web.sh` |
| `rilascio` | Deploy hosting, regole e funzioni; un solo rilascio alla volta | `firebase.json`, `.firebaserc`, comandi `firebase deploy` |
| `produzione` | Progetto `commerciali-prod`, Auth, database, hosting, backup, ripristino | configurazioni e credenziali di produzione |
| `processi-squadra` | Regole, agenti, comandi, skill, registro blocchi, documentazione condivisa | `AGENTS.md`, `.claude/**`, `.opencode/**`, `docs/progetto/**` |

## File condivisi

Anche due blocchi diversi non possono essere lavorati insieme se toccano gli stessi file condivisi:
`routing/app_router.dart`, `features/shell/app_shell.dart`, `core/theme/**`, `firestore.rules`,
`firestore.indexes.json`, `pubspec.yaml`, `.github/workflows/**`, `firebase.json`, `scripts/build-web.sh`,
`worker/src/whatsapp.mjs` (calendario/notifiche/integrazioni), `web/index.html`, `web/aggiornamento.js`,
`functions/webauthn.js`, `docs/progetto/**` (processi/manuale).
In quel caso si occupa anche `infrastruttura` (stesso giro, ordine alfabetico per evitare attese incrociate)
e si serializza.

## Coda e priorità

- La coda è FIFO. Solo Andrea può cambiare priorità o autorizzare un'urgenza che salta la coda.
- Una richiesta in coda non ha ramo, non ha codice e non ha deploy.
- Alla chiusura si libera il blocco con un motivo; il primo della coda parte solo dopo.
- Un blocco fermo da più di 24 ore si verifica e si libera solo con prova che non c'è lavoro in corso.

## Esempio

Richiesta A: «sposta luogo e note nel form appuntamento» → occupa `calendario`.
Richiesta B: «aggiungi la ricorrenza mensile» → stesso blocco: **non parte**, va in coda.
Risposta ad Andrea: «Non posso partire con la ricorrenza: sul blocco calendario (appuntamenti) è già in corso “sposta
luogo e note” (sessione X, iniziata alle 14:20). L'ho messa in coda al posto 1. Posso lavorare su un altro
blocco, se vuoi.»
