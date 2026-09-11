-- ============================================================
-- ROLLBACK — Tappa 13: PROMEMORIA GIRO VISITE
-- Rimuove i campi del promemoria. Le visite restano intatte.
-- ============================================================
DROP INDEX IF EXISTS idx_visite_promemoria;

ALTER TABLE giro_visite
  DROP COLUMN IF EXISTS promemoria_min,
  DROP COLUMN IF EXISTS promemoria_at,
  DROP COLUMN IF EXISTS promemoria_numero,
  DROP COLUMN IF EXISTS promemoria_inviato_at;
