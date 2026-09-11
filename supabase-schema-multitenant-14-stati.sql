-- ============================================================
-- MULTI-AZIENDA — Tappa 14: STATI VISITA ORIENTATI AL FLUSSO COMMERCIALE
-- Esegui UNA VOLTA nel Supabase SQL Editor, DOPO la Tappa 13.
-- ============================================================
-- 1) Lo stato "completata" diventa "fare_preventivo": dopo il sopralluogo
--    ciò che conta è l'azione successiva (produrre il preventivo).
-- 2) Nuovo stato "prossimo_appuntamento" per i sopralluoghi che richiedono
--    un ulteriore incontro: la visita successiva resta AGGANCIATA a quella
--    precedente tramite visita_padre_id, così la catena dei sopralluoghi
--    dello stesso cliente è ricostruibile.
-- In caso di problemi: esegui supabase-schema-multitenant-14-rollback.sql
-- ============================================================

-- 1) Migrazione degli stati già salvati
UPDATE giro_visite SET stato = 'fare_preventivo' WHERE stato = 'completata';

-- 2) Collegamento tra sopralluoghi successivi dello stesso cliente
ALTER TABLE giro_visite
  ADD COLUMN IF NOT EXISTS visita_padre_id uuid REFERENCES giro_visite(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_visite_padre   ON giro_visite (visita_padre_id);
CREATE INDEX IF NOT EXISTS idx_visite_cliente ON giro_visite (azienda_id, cliente_id, data);

-- Verifica: conteggio per stato + presenza della nuova colonna
SELECT stato, count(*) AS visite
FROM giro_visite
GROUP BY stato
ORDER BY stato;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='public' AND table_name='giro_visite'
  AND column_name = 'visita_padre_id';
