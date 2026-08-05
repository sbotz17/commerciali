-- ============================================================
-- ROLLBACK Tappa 9 (WhatsApp) — rimuove la configurazione WhatsApp.
-- ============================================================

DROP TABLE IF EXISTS whatsapp_config CASCADE;
ALTER TABLE aziende DROP COLUMN IF EXISTS whatsapp_attivo;

SELECT to_regclass('public.whatsapp_config') AS config_esiste; -- atteso: NULL
