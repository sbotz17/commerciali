-- ============================================================
-- ROLLBACK — Tappa 12: GIRO VISITE
-- Rimuove la tabella giro_visite e le sue policy.
-- ATTENZIONE: elimina tutte le visite pianificate salvate.
-- ============================================================
DROP TABLE IF EXISTS giro_visite CASCADE;
