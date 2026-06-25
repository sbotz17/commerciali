# Setup Bandi — Guida Completa

Questa guida configura l'import automatico dei bandi da **incentivi.gov.it**.  
Tempo stimato: ~20 minuti (una tantum).

---

## PASSO 1 — Crea la tabella su Supabase

1. Vai su [supabase.com](https://supabase.com) → il tuo progetto
2. **SQL Editor** → **New Query**
3. Incolla il contenuto di `supabase-schema-bandi.sql`
4. Clicca **Run**

Vedrai la nuova tabella `bandi_incentivi` in **Table Editor**.

---

## PASSO 2 — Import iniziale (dati già scaricati)

Hai già il file `opendata-export.json`. Usalo per popolare subito il database.

### Prerequisiti
- Node.js 18 o superiore (verifica: `node --version`)

### Ottieni la Service Role Key
1. Supabase → **Settings** → **API**
2. Copia la chiave **service_role** (è diversa dalla anon key — non condividerla mai)

### Esegui lo script

```bash
# Apri il terminale nella cartella del progetto

# Windows (PowerShell):
$env:SUPABASE_SERVICE_KEY="eyJ...la-tua-service-role-key..."
node scripts/import-bandi.js opendata-export.json

# Mac/Linux:
SUPABASE_SERVICE_KEY="eyJ...la-tua-service-role-key..." node scripts/import-bandi.js opendata-export.json
```

Lo script importerà ~774 bandi attivi in pochi secondi.  
Potrai verificare subito nella sezione Bandi dell'app.

---

## PASSO 3 — Configura l'aggiornamento automatico notturno (Edge Function)

### 3a — Installa Supabase CLI (se non l'hai)

```bash
npm install -g supabase
supabase login
```

### 3b — Trova l'URL del file open data

1. Vai su **https://www.incentivi.gov.it/it/open-data**
2. Cerca il pulsante di download del file JSON (catalogo incentivi)
3. Copia il link diretto al file `.json`  
   (es. `https://www.incentivi.gov.it/.../catalogo-incentivi.json`)

### 3c — Imposta il Secret su Supabase

```bash
supabase secrets set INCENTIVI_OPEN_DATA_URL="https://...url-del-file-json..."
```

### 3d — Deploy dell'Edge Function

```bash
# Dalla cartella del progetto:
supabase link --project-ref segbfdfoqxrnitboeyof
supabase functions deploy sync-bandi --no-verify-jwt
```

### 3e — Testa manualmente

```bash
curl -X POST \
  https://segbfdfoqxrnitboeyof.supabase.co/functions/v1/sync-bandi \
  -H "Authorization: Bearer <la-tua-anon-key>"
```

Risposta attesa:
```json
{
  "ok": true,
  "totale": 5507,
  "attivi": 774,
  "importati": 774,
  "elapsed_ms": 8432
}
```

---

## PASSO 4 — Scheduling notturno con cron-job.org (gratuito)

> Alternativa: usa **pg_cron** su Supabase (disponibile nei piani Pro).

1. Vai su [cron-job.org](https://cron-job.org) e crea un account gratuito
2. **Create cronjob**:
   - **URL**: `https://segbfdfoqxrnitboeyof.supabase.co/functions/v1/sync-bandi`
   - **Method**: POST
   - **Header**: `Authorization: Bearer <anon-key>`
   - **Schedule**: `0 3 * * *` (ogni notte alle 03:00)
3. Salva e attiva

Da quel momento i bandi si aggiornano automaticamente ogni notte.

---

## Struttura dei file creati

```
CONFIGURATORE COMMERCIALI/
├── supabase-schema-bandi.sql          ← schema tabella (Passo 1)
├── scripts/
│   └── import-bandi.js               ← import iniziale (Passo 2)
├── supabase/
│   └── functions/
│       └── sync-bandi/
│           └── index.ts              ← Edge Function (Passo 3)
└── SETUP-BANDI.md                    ← questa guida
```

---

## Risoluzione problemi

**"tabella bandi_incentivi non trovata"**  
→ Esegui il PASSO 1 (schema SQL).

**"SUPABASE_SERVICE_KEY non impostata"**  
→ Imposta la variabile d'ambiente come mostrato nel PASSO 2.

**La Edge Function risponde `INCENTIVI_OPEN_DATA_URL non configurata`**  
→ Esegui il PASSO 3c con l'URL corretto.

**I bandi non si aggiornano automaticamente**  
→ Verifica che il cronjob su cron-job.org sia attivo e che l'URL sia corretto.

---

## Fonte dati

I bandi provengono da **incentivi.gov.it** (Ministero delle Imprese e del Made in Italy),  
rilasciati con licenza **Italian Open Data License v2.0**.  
Ogni record include il link al bando ufficiale per la verifica.
