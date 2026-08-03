-- ============================================================
-- Migrazione: revisioni dei preventivi
-- Esegui UNA VOLTA nel Supabase SQL Editor.
-- ============================================================
-- Aggiunge il numero di revisione. Revisione 0 = originale;
-- 1, 2, ... = versioni successive. Quando si crea una revisione,
-- il preventivo precedente passa allo stato "revisionato".
-- ============================================================

ALTER TABLE preventivi ADD COLUMN IF NOT EXISTS revisione integer DEFAULT 0;

-- Verifica
SELECT id, numero, revisione, stato FROM preventivi ORDER BY id;
