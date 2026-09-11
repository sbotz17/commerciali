-- ============================================================
-- MULTI-AZIENDA — Tappa 13: PROMEMORIA GIRO VISITE
-- Esegui UNA VOLTA nel Supabase SQL Editor, DOPO la Tappa 12.
-- ============================================================
-- Aggiunge alla tabella giro_visite i campi per il promemoria automatico
-- su WhatsApp. L'app calcola "promemoria_at" (istante esatto in cui va
-- inviato l'avviso) partendo da data + ora della visita meno i minuti di
-- anticipo scelti: così il server non deve fare conti sui fusi orari.
-- Il server WhatsApp interroga periodicamente questa tabella e invia i
-- promemoria scaduti, marcandoli in promemoria_inviato_at.
-- In caso di problemi: esegui supabase-schema-multitenant-13-rollback.sql
-- ============================================================

ALTER TABLE giro_visite
  ADD COLUMN IF NOT EXISTS promemoria_min        int,          -- minuti di anticipo (NULL = nessun promemoria)
  ADD COLUMN IF NOT EXISTS promemoria_at         timestamptz,  -- quando inviare (calcolato dall'app)
  ADD COLUMN IF NOT EXISTS promemoria_numero     text,         -- numero WhatsApp destinatario
  ADD COLUMN IF NOT EXISTS promemoria_inviato_at timestamptz;  -- marcato dal server dopo l'invio

-- Indice parziale: il server cerca solo i promemoria ancora da inviare
CREATE INDEX IF NOT EXISTS idx_visite_promemoria
  ON giro_visite (promemoria_at)
  WHERE promemoria_at IS NOT NULL AND promemoria_inviato_at IS NULL;

-- Verifica
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='public' AND table_name='giro_visite'
  AND column_name LIKE 'promemoria%'
ORDER BY column_name;
