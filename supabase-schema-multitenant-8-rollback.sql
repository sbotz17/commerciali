-- ============================================================
-- ROLLBACK Tappa 8 (configurazione piani) — rimuove la tabella piani_config.
-- Esegui SOLO se vuoi tornare indietro. L'app, non trovando la tabella,
-- smette di applicare le regole per-piano (pagine sempre visibili, limiti
-- dalla licenza come alla Tappa 6/7).
-- ============================================================

DROP TABLE IF EXISTS piani_config CASCADE;

SELECT to_regclass('public.piani_config') AS piani_config_esiste; -- atteso: NULL
