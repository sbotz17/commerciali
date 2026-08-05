-- ============================================================
-- ROLLBACK Tappa 7 (anagrafica azienda) — rimuove i campi aggiunti.
-- Esegui SOLO se vuoi tornare indietro. Non tocca "nome" (ragione sociale).
-- ============================================================

ALTER TABLE aziende DROP COLUMN IF EXISTS partita_iva;
ALTER TABLE aziende DROP COLUMN IF EXISTS codice_fiscale;
ALTER TABLE aziende DROP COLUMN IF EXISTS indirizzo;
ALTER TABLE aziende DROP COLUMN IF EXISTS comune;
ALTER TABLE aziende DROP COLUMN IF EXISTS provincia;
ALTER TABLE aziende DROP COLUMN IF EXISTS cap;
ALTER TABLE aziende DROP COLUMN IF EXISTS telefono;
ALTER TABLE aziende DROP COLUMN IF EXISTS email;
ALTER TABLE aziende DROP COLUMN IF EXISTS pec;

SELECT column_name FROM information_schema.columns
WHERE table_schema='public' AND table_name='aziende' ORDER BY ordinal_position;
