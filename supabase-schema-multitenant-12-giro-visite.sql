-- ============================================================
-- MULTI-AZIENDA — Tappa 12: GIRO VISITE (pianificazione visite giornaliere)
-- Esegui UNA VOLTA nel Supabase SQL Editor, DOPO la Tappa 4 (RLS), che
-- crea la funzione azienda_ids_correnti() usata qui sotto.
-- ============================================================
-- Tabella per il "giro visite" della rete vendita: ogni riga è una visita
-- pianificata a un cliente in una certa giornata, con stato ed esito.
-- Isolamento per azienda tramite RLS (come prodotti/clienti/preventivi).
-- In caso di problemi: esegui supabase-schema-multitenant-12-rollback.sql
-- ============================================================

-- 1) Tabella
CREATE TABLE IF NOT EXISTS giro_visite (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  azienda_id   uuid   NOT NULL REFERENCES aziende(id) ON DELETE CASCADE,
  utente_id    bigint REFERENCES utenti(id) ON DELETE SET NULL,   -- venditore assegnato
  cliente_id   bigint,                                            -- allineato al tipo di clienti.id dal blocco 2
  cliente_nome text   NOT NULL DEFAULT '',                        -- snapshot per la visualizzazione
  telefono     text,                                              -- snapshot contatto
  indirizzo    text,                                              -- snapshot per la navigazione mappe
  data         date   NOT NULL DEFAULT current_date,              -- giornata del giro
  ora          time,                                              -- orario previsto (opzionale)
  ordine       int    NOT NULL DEFAULT 0,                         -- ordine nella giornata
  stato        text   NOT NULL DEFAULT 'da_fare',                 -- da_fare|completata|annullata|rinviata
  esito        text,                                              -- note dopo la visita
  note         text,                                              -- note di pianificazione
  created_at   timestamptz DEFAULT now(),
  updated_at   timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_visite_azienda_data ON giro_visite (azienda_id, data);
CREATE INDEX IF NOT EXISTS idx_visite_utente_data  ON giro_visite (utente_id, data);

-- 2) Allinea cliente_id al tipo REALE di clienti.id (uuid, bigint, ecc.) e
--    crea la FK. Questo blocco è idempotente: puoi ri-eseguire il file per
--    correggere un'installazione precedente con il tipo sbagliato.
DO $$
DECLARE
  tipo text;
  attuale text;
BEGIN
  SELECT format_type(a.atttypid, a.atttypmod) INTO tipo
  FROM pg_attribute a
  WHERE a.attrelid = 'public.clienti'::regclass
    AND a.attname = 'id' AND a.attnum > 0 AND NOT a.attisdropped;

  IF tipo IS NULL THEN
    RAISE NOTICE 'Tabella clienti non trovata: cliente_id lasciato invariato.';
    RETURN;
  END IF;

  SELECT format_type(a.atttypid, a.atttypmod) INTO attuale
  FROM pg_attribute a
  WHERE a.attrelid = 'public.giro_visite'::regclass
    AND a.attname = 'cliente_id' AND a.attnum > 0 AND NOT a.attisdropped;

  -- La FK va rimossa prima di poter cambiare il tipo della colonna
  ALTER TABLE giro_visite DROP CONSTRAINT IF EXISTS giro_visite_cliente_fk;

  IF attuale IS DISTINCT FROM tipo THEN
    EXECUTE format(
      'ALTER TABLE giro_visite ALTER COLUMN cliente_id TYPE %s USING NULLIF(cliente_id::text, %L)::%s',
      tipo, '', tipo);
    RAISE NOTICE 'cliente_id convertito da % a % (come clienti.id)', attuale, tipo;
  END IF;

  BEGIN
    ALTER TABLE giro_visite
      ADD CONSTRAINT giro_visite_cliente_fk
      FOREIGN KEY (cliente_id) REFERENCES clienti(id) ON DELETE SET NULL;
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'FK cliente non creata (%). Il modulo funziona comunque grazie a cliente_nome.', SQLERRM;
  END;
END $$;

-- 3) RLS: isolamento per azienda (ogni azienda vede solo le proprie visite)
ALTER TABLE giro_visite ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "isolamento_azienda" ON giro_visite;
CREATE POLICY "isolamento_azienda" ON giro_visite FOR ALL TO authenticated
  USING      (azienda_id IN (SELECT azienda_ids_correnti()))
  WITH CHECK (azienda_id IN (SELECT azienda_ids_correnti()));

-- Verifica: policy attive + tipo di cliente_id (deve combaciare con clienti.id)
SELECT policyname, cmd FROM pg_policies
WHERE schemaname='public' AND tablename='giro_visite';

SELECT 'giro_visite.cliente_id' AS colonna,
       format_type(a.atttypid, a.atttypmod) AS tipo
FROM pg_attribute a
WHERE a.attrelid='public.giro_visite'::regclass AND a.attname='cliente_id'
UNION ALL
SELECT 'clienti.id',
       format_type(a.atttypid, a.atttypmod)
FROM pg_attribute a
WHERE a.attrelid='public.clienti'::regclass AND a.attname='id';
