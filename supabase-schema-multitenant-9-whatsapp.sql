-- ============================================================
-- MULTI-AZIENDA — Tappa 9: configurazione WhatsApp (piattaforma)
-- Esegui UNA VOLTA nel Supabase SQL Editor, DOPO la Tappa 8.
-- ============================================================
-- Un unico server WhatsApp per tutta la piattaforma (URL + API key),
-- gestito solo dal super admin. Ogni azienda può avere il modulo
-- WhatsApp attivo o meno (interruttore per-azienda).
-- NB: le credenziali (API key) sono leggibili SOLO dal super admin.
-- In caso di problemi: esegui supabase-schema-multitenant-9-rollback.sql
-- ============================================================

-- 1) Configurazione server (riga unica id = 1)
CREATE TABLE IF NOT EXISTS whatsapp_config (
  id         int PRIMARY KEY DEFAULT 1,
  url        text,
  api_key    text,
  numero     text,           -- numero collegato (informativo)
  stato      text,           -- connesso | disconnesso | sconosciuto
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT whatsapp_config_riga_unica CHECK (id = 1)
);

ALTER TABLE whatsapp_config ENABLE ROW LEVEL SECURITY;

-- Solo il super admin può leggere/scrivere (contiene l'API key)
DROP POLICY IF EXISTS "whatsapp_config_all" ON whatsapp_config;
CREATE POLICY "whatsapp_config_all" ON whatsapp_config FOR ALL TO authenticated
  USING (sono_super_admin()) WITH CHECK (sono_super_admin());

-- 2) Interruttore modulo WhatsApp per azienda
ALTER TABLE aziende ADD COLUMN IF NOT EXISTS whatsapp_attivo boolean NOT NULL DEFAULT false;

-- Verifica
SELECT to_regclass('public.whatsapp_config') AS tabella_config,
       (SELECT count(*) FROM information_schema.columns
        WHERE table_name='aziende' AND column_name='whatsapp_attivo') AS colonna_azienda;
