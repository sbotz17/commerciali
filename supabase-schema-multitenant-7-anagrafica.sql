-- ============================================================
-- MULTI-AZIENDA — Tappa 7: anagrafica azienda (dati completi)
-- Esegui UNA VOLTA nel Supabase SQL Editor, DOPO la Tappa 6.
-- ============================================================
-- Aggiunge i campi anagrafici all'azienda, così la console Super Admin
-- può creare un'azienda con ragione sociale, P.IVA, indirizzo, ecc.
-- (Il campo "nome" già esistente resta la Ragione sociale.)
-- In caso di problemi: esegui supabase-schema-multitenant-7-rollback.sql
-- ============================================================

ALTER TABLE aziende ADD COLUMN IF NOT EXISTS partita_iva    text;
ALTER TABLE aziende ADD COLUMN IF NOT EXISTS codice_fiscale text;
ALTER TABLE aziende ADD COLUMN IF NOT EXISTS indirizzo      text;
ALTER TABLE aziende ADD COLUMN IF NOT EXISTS comune         text;
ALTER TABLE aziende ADD COLUMN IF NOT EXISTS provincia      text;
ALTER TABLE aziende ADD COLUMN IF NOT EXISTS cap            text;
ALTER TABLE aziende ADD COLUMN IF NOT EXISTS telefono       text;
ALTER TABLE aziende ADD COLUMN IF NOT EXISTS email          text;
ALTER TABLE aziende ADD COLUMN IF NOT EXISTS pec            text;

-- Verifica: struttura della tabella aziende
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'aziende'
ORDER BY ordinal_position;
