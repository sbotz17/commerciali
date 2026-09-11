-- ============================================================
-- ROLLBACK — Tappa 14: STATI VISITA
-- Riporta "fare_preventivo" a "completata", azzera lo stato
-- "prossimo_appuntamento" (riportato a completata) e rimuove il
-- collegamento tra sopralluoghi.
-- ============================================================
UPDATE giro_visite SET stato = 'completata'
WHERE stato IN ('fare_preventivo', 'prossimo_appuntamento');

DROP INDEX IF EXISTS idx_visite_padre;
DROP INDEX IF EXISTS idx_visite_cliente;

ALTER TABLE giro_visite DROP COLUMN IF EXISTS visita_padre_id;
