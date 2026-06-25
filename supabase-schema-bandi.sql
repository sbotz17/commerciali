-- ============================================================
-- SCHEMA BANDI — Tabella bandi_incentivi
-- ============================================================
-- Fonte dati: incentivi.gov.it open data (JSON)
-- Import iniziale: node scripts/import-bandi.js
-- Aggiornamento automatico: Supabase Edge Function sync-bandi
--
-- Eseguire nell'SQL Editor di Supabase → Run
-- ============================================================

-- Rimuovi tabella precedente se esisteva (statica)
-- DROP TABLE IF EXISTS bandi_incentivi;

CREATE TABLE IF NOT EXISTS bandi_incentivi (
  id                  TEXT PRIMARY KEY,                    -- ID_Incentivo da incentivi.gov.it
  titolo              TEXT NOT NULL,
  descrizione         TEXT,
  data_apertura       TIMESTAMPTZ,
  data_chiusura       TIMESTAMPTZ,
  stato               TEXT DEFAULT 'attivo',               -- attivo | in_scadenza | permanente | scaduto
  codici_ateco        TEXT[]  DEFAULT '{}',                -- codici ATECO compatibili (es. {"56.10","56.20"})
  tutti_ateco         BOOLEAN DEFAULT FALSE,               -- TRUE = "Tutti i settori economici"
  regioni             TEXT[]  DEFAULT '{}',                -- regioni ammissibili (nomi completi)
  tutte_regioni       BOOLEAN DEFAULT FALSE,               -- TRUE = nazionale
  forma_agevolazione  TEXT[]  DEFAULT '{}',                -- es. {"Contributo/Fondo perduto"}
  dimensioni          TEXT[]  DEFAULT '{}',                -- es. {"Microimpresa","Piccola Impresa"}
  settore_attivita    TEXT[]  DEFAULT '{}',
  obiettivi           TEXT[]  DEFAULT '{}',
  soggetto_concedente TEXT,
  agevolazione_min    NUMERIC DEFAULT 0,
  agevolazione_max    NUMERIC DEFAULT 0,
  stanziamento        NUMERIC DEFAULT 0,
  link_ufficiale      TEXT,
  fonte               TEXT    DEFAULT 'incentivi.gov.it',
  ultimo_aggiornamento TIMESTAMPTZ,
  data_importazione   TIMESTAMPTZ DEFAULT NOW()
);

-- Disabilita RLS (come le altre tabelle del progetto)
ALTER TABLE bandi_incentivi DISABLE ROW LEVEL SECURITY;

-- Indici per ricerca efficiente
CREATE INDEX IF NOT EXISTS idx_bandi_ateco   ON bandi_incentivi USING GIN(codici_ateco);
CREATE INDEX IF NOT EXISTS idx_bandi_regioni ON bandi_incentivi USING GIN(regioni);
CREATE INDEX IF NOT EXISTS idx_bandi_stato   ON bandi_incentivi(stato);
CREATE INDEX IF NOT EXISTS idx_bandi_chiusura ON bandi_incentivi(data_chiusura);
