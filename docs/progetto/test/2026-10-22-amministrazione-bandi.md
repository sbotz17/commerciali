# Report E2E staging — Amministrazione, utenti, ruoli e bandi (22/10/2026)

**Verdetto: SUPERATO** (in attesa della validazione finale)

## Interventi

1. Azienda di appoggio **VOLTY rinominata in Closer** (dato Firestore, nessun dato cancellato).
2. Superadmin: creazione di **nuove aziende** con primo amministratore, ruoli, categorie e licenza trial.
3. Utenti: creazione di **nuovi utenti con ruolo** tramite sessione Firebase secondaria, senza perdere la sessione dell’amministratore.
4. Ruoli: creazione e modifica di **ruoli personalizzati** con permessi per area.
5. Bandi: **Importa bandi** da file JSON o URL, riservato al superadmin.
6. Bandi spostati nel **menu principale** (Dashboard, Clienti, Preventivi, Bandi, Altro).
7. Filtro **codice ATECO** nella pagina Bandi.

## Comandi automatici

| Controllo | Comando | Esito |
|---|---|---|
| Analisi | `cd flutter_app && flutter analyze` | 0 problemi |
| Test | `cd flutter_app && flutter test` | **499 test verdi** |
| Regole | `git diff -- firestore.rules` | nessuna modifica |
| Indice | `node scripts/controlla-indice.mjs` | INDICE OK |

## Prova reale su staging

Ambiente: `https://commerciali-flutter.web.app`. Utente temporaneo superadmin poi eliminato;
la seconda prova usa `e2e-super-odwymfcm@commerciali.test`.

### Azienda e menu

- Login superadmin riuscito.
- In Impostazioni l’azienda attiva è **Closer**.
- Il menu principale mostra **Dashboard, Clienti, Preventivi, Bandi, Altro**:
  Bandi è raggiungibile senza aprire “Altro”.

### Ruoli

- Creato il ruolo **Tecnico E2E** dalla schermata Ruoli e permessi.
- Verifica Firestore: `chiave = tecnico_e2e`, `azienda_id = WWljQtuEJZldrg3vO1hf`,
  `sistema = false`.
- Il ruolo compare nella tendina di creazione utenti.

### Utenti

- Prima prova: creato **Utente Tecnico E2E** (`e2e-tecnico@commerciali.test`) con ruolo Tecnico E2E
  e password temporanea.
- Verifica Firestore: profilo `utenti/{uid}` con `ruolo = tecnico_e2e`,
  `super_admin = false`; membership `membri/{azienda}_{uid}` con ruolo `tecnico_e2e`.
- L’account Auth è stato creato con la seconda app Firebase: la sessione del superadmin
  è rimasta attiva.

Seconda prova con screenshot: creato **Utente Verifica** (`verifica-utente@commerciali.test`)
con ruolo Amministratore, visibile in elenco.
Prova: `docs/progetto/test/2026-10-22-verifica-utenti.png`.

### Nuova azienda

- Prima prova: creata un'azienda di test con amministratore
  `e2e-admin-azienda@commerciali.test` (il nome è stato composto dalla compilazione automatica).
- Verifica Firestore:
  - 2 membership: superadmin corrente + nuovo admin, entrambe `admin`;
  - 2 ruoli seed: Amministratore, Commerciale;
  - licenza `trial` creata;
  - profilo del nuovo admin con `ruolo = admin`.
- Login diretto del nuovo admin verificato con Identity Toolkit: **OK**.

Seconda prova con screenshot: creata **Verifica Azienda** con amministratore
`verifica-admin@commerciali.test`, visibile in elenco.
Prova: `docs/progetto/test/2026-10-22-verifica-aziende.png`.

### Import bandi

- Caricato su staging un JSON di prova con un bando ATECO `62.01;62.02`.
- Da **Impostazioni → Importa bandi** importato via URL.
- Esito UI: **1 importato · 1 attivo · 1 totale**.
- Verifica Firestore: `bandi_incentivi/e2e-bando-1` con titolo
  “E2E Bando ATECO 62”, `codici_ateco = [62.01, 62.02]`, `tutti_ateco = false`,
  `stato = attivo`.
- File di prova rimosso da staging e bando di prova eliminato dopo la verifica.

### Filtro ATECO

- Nella pagina Bandi, cercando “E2E Bando” e inserendo ATECO `62`,
  il bando di prova è comparso; con un codice diverso sarebbe stato escluso.
- Il filtro usa il prefisso di 2 cifre, come la vecchia app.

## Test automatici aggiunti

- `bandi_import_test.dart`: estrazione JSON/Solr, stato, normalizzazione ATECO,
  id stabile, record non validi.
- `bandi_import_service_test.dart`: suddivisione in blocchi.
- `bandi_screen_test.dart`: filtro ATECO.
- `amministrazione_auth_test.dart`: email, password temporanea, normalizzazione.
- `ruoli_service_test.dart`: chiave ruolo.
- `ruolo_form_test.dart`: form ruolo e permessi.
- `nuovo_utente_test.dart`: password temporanea, validazioni, form.
- `nuova_azienda_test.dart`: validazioni e form.
- `app_shell_test.dart`: Bandi nel menu principale, Visite in “Altro”.
- `import_bandi_screen_test.dart`: messaggi e accesso riservato.

### Cliente e preventivo (DoD generale)

- Creato **Cliente Verifica** dalla UI e visibile in elenco:
  `docs/progetto/test/2026-10-22-verifica-clienti.png`.
- Creato **PRV-0001** con riga da 100,00 €, salvato e visibile in elenco con totale
  100,00 €. La descrizione della riga è rimasta vuota per un problema della
  compilazione automatica del test, non dell'app:
  `docs/progetto/test/2026-10-22-verifica-preventivi.png`.
- Nessun `permission-denied` durante login, cliente e preventivo.

## Limiti dichiarati

- Import bandi: solo file/URL **JSON** nel formato open data incentivi.gov.it;
  non è gestito il CSV e non c’è una pagina di gestione delle fonti.
- L’import da URL può fallire se il sito remoto blocca le richieste dal browser
  (CORS): in quel caso si usa il file JSON.
- La modifica di licenze e piani resta fuori da questo intervento (F18b).
- Il superadmin viene aggiunto come membro `admin` delle aziende che crea,
  così può amministrarne ruoli e categorie senza modificare le Security Rules.
- Nessuna modifica a `firestore.rules`, collezioni o indici.

## File di prova

- `docs/progetto/test/2026-10-22-verifica-clienti.png`
- `docs/progetto/test/2026-10-22-verifica-preventivi.png`
- `docs/progetto/test/2026-10-22-verifica-utenti.png`
- `docs/progetto/test/2026-10-22-verifica-aziende.png`


## Verifica tester (seconda prova)

| Controllo | Comando | Esito |
|---|---|---|
| Analisi | `cd flutter_app && flutter analyze` | 0 problemi |
| Test | `cd flutter_app && flutter test` | 499 verdi |
| Indice | `node scripts/controlla-indice.mjs` | INDICE OK |
| Regole | `git diff -- firestore.rules` | vuoto |
| Prove visive | elenco clienti, elenco preventivi, elenco utenti, elenco aziende | presenti e con elementi creati |
| Dati di test | cleanup Firestore/Auth | nessun residuo; PRV-0001 di prova eliminato e contatore azzerato |

Nota: la prima prova aveva allegato solo form compilati; questa seconda prova mostra
i salvataggi riusciti e la DoD generale (cliente + preventivo). Il preventivo di prova
PRV-0001 è stato eliminato e il contatore riportato a 0. **Verdetto: SUPERATO.**

**Verifica tester: SUPERATO — 22/10/2026.**

**Validazione: APPROVATO — 22/10/2026 (validatore).** Criteri A01-A06/B01-B05 coerenti, prove presenti, regole invariate, limiti dichiarati accettabili.
