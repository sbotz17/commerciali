-- ============================================================
-- MULTI-AZIENDA — Tappa 6: LICENZE (piani + scadenze + limiti)
-- Esegui UNA VOLTA nel Supabase SQL Editor, DOPO la Tappa 5 (super admin).
-- ============================================================
-- Aggiunge la gestione delle licenze del software: ogni azienda ha una
-- licenza con un piano (trial/starter/professional/enterprise), una data
-- di scadenza e dei limiti (max utenti, max preventivi). Solo il super
-- admin può creare/assegnare/modificare le licenze; le aziende vedono
-- solo la propria (in sola lettura).
-- In caso di problemi: esegui supabase-schema-multitenant-6-rollback.sql
-- ============================================================

-- 1) Tabella licenze (una licenza per azienda)
CREATE TABLE IF NOT EXISTS licenze (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  azienda_id     uuid NOT NULL REFERENCES aziende(id) ON DELETE CASCADE,
  piano          text NOT NULL DEFAULT 'trial',       -- trial | starter | professional | enterprise
  stato          text NOT NULL DEFAULT 'attiva',      -- attiva | sospesa
  data_inizio    date NOT NULL DEFAULT current_date,
  data_fine      date,                                -- NULL = senza scadenza
  max_utenti     integer,                             -- NULL = illimitato
  max_preventivi integer,                             -- NULL = illimitato
  note           text,
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now(),
  UNIQUE (azienda_id)
);

CREATE INDEX IF NOT EXISTS idx_licenze_azienda ON licenze(azienda_id);

-- 2) RLS: l'azienda vede solo la propria licenza (lettura); il super admin gestisce tutto
ALTER TABLE licenze ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "licenze_select" ON licenze;
CREATE POLICY "licenze_select" ON licenze FOR SELECT TO authenticated
  USING (azienda_id IN (SELECT azienda_ids_correnti()) OR sono_super_admin());

DROP POLICY IF EXISTS "licenze_insert" ON licenze;
CREATE POLICY "licenze_insert" ON licenze FOR INSERT TO authenticated
  WITH CHECK (sono_super_admin());

DROP POLICY IF EXISTS "licenze_update" ON licenze;
CREATE POLICY "licenze_update" ON licenze FOR UPDATE TO authenticated
  USING (sono_super_admin()) WITH CHECK (sono_super_admin());

DROP POLICY IF EXISTS "licenze_delete" ON licenze;
CREATE POLICY "licenze_delete" ON licenze FOR DELETE TO authenticated
  USING (sono_super_admin());

-- 3) Le aziende già esistenti ricevono una licenza Enterprise senza scadenza,
--    così nessun utente viene bloccato al momento dell'attivazione.
INSERT INTO licenze (azienda_id, piano, stato, data_inizio, data_fine, max_utenti, max_preventivi)
SELECT a.id, 'enterprise', 'attiva', current_date, NULL, NULL, NULL
FROM aziende a
WHERE NOT EXISTS (SELECT 1 FROM licenze l WHERE l.azienda_id = a.id);

-- Verifica: elenco licenze
SELECT a.nome AS azienda, l.piano, l.stato, l.data_fine, l.max_utenti, l.max_preventivi
FROM licenze l JOIN aziende a ON a.id = l.azienda_id
ORDER BY a.nome;
