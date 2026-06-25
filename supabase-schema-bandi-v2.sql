-- ============================================================
-- Schema Bandi v2 — gestione multi-fonte automatica
-- Esegui nel SQL Editor di Supabase (in ordine)
-- ============================================================

-- ── 1. Tabella fonti ────────────────────────────────────────
-- Ogni riga è una fonte di bandi (JSON, RSS, ecc.)
CREATE TABLE IF NOT EXISTS bandi_fonti (
  id           TEXT        PRIMARY KEY,           -- slug univoco, es. "incentivi_gov"
  nome         TEXT        NOT NULL,              -- nome visualizzato
  url          TEXT        NOT NULL DEFAULT '',   -- URL endpoint / feed
  tipo         TEXT        NOT NULL DEFAULT 'rss', -- 'json_incentivi' | 'rss'
  attiva       BOOLEAN     NOT NULL DEFAULT TRUE,
  note         TEXT        DEFAULT '',
  creata_il    TIMESTAMPTZ DEFAULT NOW(),
  -- Stato ultimo sync (aggiornato dalla Edge Function)
  ultimo_sync  TIMESTAMPTZ,
  sync_stato   TEXT        DEFAULT 'mai',         -- 'mai' | 'ok' | 'errore' | 'in_corso'
  sync_importati INTEGER   DEFAULT 0,
  sync_errore  TEXT
);

ALTER TABLE bandi_fonti DISABLE ROW LEVEL SECURITY;

-- ── 2. Storico sincronizzazioni ─────────────────────────────
CREATE TABLE IF NOT EXISTS bandi_sync_log (
  id           SERIAL      PRIMARY KEY,
  fonte_id     TEXT        REFERENCES bandi_fonti(id) ON DELETE CASCADE,
  stato        TEXT        NOT NULL,              -- 'ok' | 'errore'
  importati    INTEGER     DEFAULT 0,
  totale_fonte INTEGER     DEFAULT 0,
  errore       TEXT,
  avviato_il   TIMESTAMPTZ DEFAULT NOW(),
  completato_il TIMESTAMPTZ
);

ALTER TABLE bandi_sync_log DISABLE ROW LEVEL SECURITY;

-- ── 3. Fonti pre-configurate ────────────────────────────────
INSERT INTO bandi_fonti (id, nome, url, tipo, attiva, note) VALUES
  (
    'incentivi_gov',
    'incentivi.gov.it',
    '',   -- URL configurato via Supabase Secret: INCENTIVI_OPEN_DATA_URL
    'json_incentivi',
    TRUE,
    'Catalogo nazionale incentivi. URL configurato come Secret nella Edge Function.'
  ),
  (
    'invitalia',
    'Invitalia',
    'https://www.invitalia.it/rss/bandi-e-contratti.rss',
    'rss',
    FALSE,  -- disattiva finché non verifichi l''URL con il tuo browser
    'Agenzia nazionale per l''attrazione degli investimenti. Verifica URL RSS sul sito invitalia.it'
  ),
  (
    'mimit',
    'MIMIT (ex MISE)',
    'https://www.mimit.gov.it/it/rss/bandi.rss',
    'rss',
    FALSE,
    'Ministero delle Imprese e del Made in Italy. Verifica URL RSS sul sito mimit.gov.it'
  ),
  (
    'eu_funding',
    'EU Funding Portal',
    'https://ec.europa.eu/info/funding-tenders/opportunities/portal/screen/opportunities/topic-search;rss=true&status=31094501&programmePeriod=2021-2027&isOpenForApplication=true',
    'rss',
    FALSE,
    'Bandi europei per PMI. Feed RSS ufficiale della Commissione Europea.'
  )
ON CONFLICT (id) DO NOTHING;

-- ── 4. Scheduling automatico via pg_cron ───────────────────
-- Richiede estensioni pg_cron e pg_net attive (Supabase le include)
-- ISTRUZIONI:
--   1. In Supabase → Database → Extensions → abilita pg_cron e pg_net
--   2. Sostituisci <REF> con il Project Reference ID del tuo progetto
--   3. Sostituisci <ANON_KEY> con la tua anon public key
--   4. Esegui il blocco sottostante

-- SELECT cron.schedule(
--   'sync-bandi-nightly',
--   '0 3 * * *',   -- ogni notte alle 03:00
--   $$
--     SELECT net.http_post(
--       url     := 'https://<REF>.supabase.co/functions/v1/sync-bandi',
--       headers := '{"Authorization":"Bearer <ANON_KEY>","Content-Type":"application/json"}'::jsonb,
--       body    := '{}'::jsonb
--     );
--   $$
-- );

-- Per verificare che il job sia attivo:
-- SELECT * FROM cron.job WHERE jobname = 'sync-bandi-nightly';

-- Per rimuoverlo:
-- SELECT cron.unschedule('sync-bandi-nightly');

-- ── 5. Indice per performance ───────────────────────────────
CREATE INDEX IF NOT EXISTS idx_sync_log_fonte ON bandi_sync_log(fonte_id, avviato_il DESC);
