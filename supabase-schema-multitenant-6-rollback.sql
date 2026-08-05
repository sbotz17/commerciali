-- ============================================================
-- ROLLBACK Tappa 6 (LICENZE) — rimuove la gestione licenze.
-- Esegui SOLO se dopo la Tappa 6 qualcosa non funziona.
-- ============================================================
-- Elimina la tabella licenze e le sue policy. L'app, non trovando la
-- tabella, smette di applicare blocchi/limiti (torna come alla Tappa 5).
-- ============================================================

DROP TABLE IF EXISTS licenze CASCADE;

-- Verifica: la tabella non esiste più
SELECT to_regclass('public.licenze') AS licenze_esiste; -- atteso: NULL
