-- ============================================================
-- MULTI-AZIENDA — Tappa 8: configurazione dei piani (Configuratore)
-- Esegui UNA VOLTA nel Supabase SQL Editor, DOPO la Tappa 7.
-- ============================================================
-- Definisce, per ogni piano (trial/starter/professional/enterprise):
--   - quali pagine sono attive (jsonb: { "clienti": true, ... })
--   - il numero massimo di utenti e di preventivi (-1 o NULL = illimitato)
-- Le aziende ereditano queste impostazioni in base al loro piano.
-- Solo il super admin può modificarle; tutti gli autenticati le leggono
-- (servono per applicare pagine/limiti dentro ogni azienda).
-- In caso di problemi: esegui supabase-schema-multitenant-8-rollback.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS piani_config (
  piano          text PRIMARY KEY,          -- trial | starter | professional | enterprise
  pagine         jsonb NOT NULL DEFAULT '{}'::jsonb,
  max_utenti     integer,                    -- NULL o -1 = illimitato
  max_preventivi integer,                    -- NULL o -1 = illimitato
  updated_at     timestamptz DEFAULT now()
);

ALTER TABLE piani_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "piani_config_select" ON piani_config;
CREATE POLICY "piani_config_select" ON piani_config FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "piani_config_insert" ON piani_config;
CREATE POLICY "piani_config_insert" ON piani_config FOR INSERT TO authenticated
  WITH CHECK (sono_super_admin());

DROP POLICY IF EXISTS "piani_config_update" ON piani_config;
CREATE POLICY "piani_config_update" ON piani_config FOR UPDATE TO authenticated
  USING (sono_super_admin()) WITH CHECK (sono_super_admin());

DROP POLICY IF EXISTS "piani_config_delete" ON piani_config;
CREATE POLICY "piani_config_delete" ON piani_config FOR DELETE TO authenticated
  USING (sono_super_admin());

-- Valori iniziali: tutte le pagine attive, limiti utenti/preventivi predefiniti.
INSERT INTO piani_config (piano, pagine, max_utenti, max_preventivi) VALUES
  ('trial',        '{"dashboard":true,"catalogo":true,"preventivi":true,"clienti":true,"bandi":true,"categorie":true,"utenti":true,"ruoli":true,"impostazioni":true}'::jsonb, 2,   20),
  ('starter',      '{"dashboard":true,"catalogo":true,"preventivi":true,"clienti":true,"bandi":true,"categorie":true,"utenti":true,"ruoli":true,"impostazioni":true}'::jsonb, 3,   100),
  ('professional', '{"dashboard":true,"catalogo":true,"preventivi":true,"clienti":true,"bandi":true,"categorie":true,"utenti":true,"ruoli":true,"impostazioni":true}'::jsonb, 10,  1000),
  ('enterprise',   '{"dashboard":true,"catalogo":true,"preventivi":true,"clienti":true,"bandi":true,"categorie":true,"utenti":true,"ruoli":true,"impostazioni":true}'::jsonb, -1,  -1)
ON CONFLICT (piano) DO NOTHING;

-- Verifica
SELECT piano, max_utenti, max_preventivi FROM piani_config ORDER BY piano;
