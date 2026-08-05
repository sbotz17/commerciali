-- ============================================================
-- MULTI-AZIENDA — Tappa 1: fondamenta (tabelle + colonne + assegnazione dati)
-- Esegui UNA VOLTA nel Supabase SQL Editor.
-- ============================================================
-- SICURA: aggiunge tabelle/colonne e assegna i dati esistenti a
-- un'azienda predefinita. Non attiva ancora l'isolamento (RLS): quello
-- arriva in una tappa successiva, insieme alle modifiche dell'app.
-- ============================================================

-- 1) Aziende (i "tenant")
CREATE TABLE IF NOT EXISTS aziende (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nome       text NOT NULL,
  logo       text,
  created_at timestamptz DEFAULT now()
);

-- 2) Membri: collega un utente a un'azienda, con il ruolo PER azienda
-- (drop di sicurezza in caso di tentativo precedente con tipo errato — la tabella è nuova)
DROP TABLE IF EXISTS membri CASCADE;
CREATE TABLE IF NOT EXISTS membri (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  azienda_id uuid   NOT NULL REFERENCES aziende(id) ON DELETE CASCADE,
  utente_id  bigint NOT NULL REFERENCES utenti(id) ON DELETE CASCADE,  -- utenti.id è bigint
  ruolo      text   NOT NULL DEFAULT 'commerciale',
  created_at timestamptz DEFAULT now(),
  UNIQUE (azienda_id, utente_id)
);
CREATE INDEX IF NOT EXISTS idx_membri_utente  ON membri (utente_id);
CREATE INDEX IF NOT EXISTS idx_membri_azienda ON membri (azienda_id);

-- 3) Colonna azienda_id sulle tabelle dati (per-azienda)
ALTER TABLE prodotti     ADD COLUMN IF NOT EXISTS azienda_id uuid REFERENCES aziende(id) ON DELETE CASCADE;
ALTER TABLE clienti      ADD COLUMN IF NOT EXISTS azienda_id uuid REFERENCES aziende(id) ON DELETE CASCADE;
ALTER TABLE preventivi   ADD COLUMN IF NOT EXISTS azienda_id uuid REFERENCES aziende(id) ON DELETE CASCADE;
ALTER TABLE categorie    ADD COLUMN IF NOT EXISTS azienda_id uuid REFERENCES aziende(id) ON DELETE CASCADE;
ALTER TABLE ruoli        ADD COLUMN IF NOT EXISTS azienda_id uuid REFERENCES aziende(id) ON DELETE CASCADE;
ALTER TABLE impostazioni ADD COLUMN IF NOT EXISTS azienda_id uuid REFERENCES aziende(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_prodotti_azienda     ON prodotti     (azienda_id);
CREATE INDEX IF NOT EXISTS idx_clienti_azienda      ON clienti      (azienda_id);
CREATE INDEX IF NOT EXISTS idx_preventivi_azienda   ON preventivi   (azienda_id);
CREATE INDEX IF NOT EXISTS idx_categorie_azienda    ON categorie    (azienda_id);
CREATE INDEX IF NOT EXISTS idx_ruoli_azienda        ON ruoli        (azienda_id);
CREATE INDEX IF NOT EXISTS idx_impostazioni_azienda ON impostazioni (azienda_id);

-- 4) Azienda predefinita + assegnazione di TUTTI i dati e utenti esistenti
DO $$
DECLARE az uuid;
BEGIN
  SELECT id INTO az FROM aziende WHERE nome = 'La mia azienda' LIMIT 1;
  IF az IS NULL THEN
    INSERT INTO aziende (nome) VALUES ('La mia azienda') RETURNING id INTO az;
  END IF;

  UPDATE prodotti     SET azienda_id = az WHERE azienda_id IS NULL;
  UPDATE clienti      SET azienda_id = az WHERE azienda_id IS NULL;
  UPDATE preventivi   SET azienda_id = az WHERE azienda_id IS NULL;
  UPDATE categorie    SET azienda_id = az WHERE azienda_id IS NULL;
  UPDATE ruoli        SET azienda_id = az WHERE azienda_id IS NULL;
  UPDATE impostazioni SET azienda_id = az WHERE azienda_id IS NULL;

  -- Iscrive tutti gli utenti esistenti come membri, col ruolo attuale
  INSERT INTO membri (azienda_id, utente_id, ruolo)
    SELECT az, u.id, COALESCE(u.ruolo, 'commerciale')
    FROM utenti u
  ON CONFLICT (azienda_id, utente_id) DO NOTHING;
END $$;

-- (La conversione delle "impostazioni" a per-azienda arriva nella Tappa 2,
--  insieme al codice dell'app che la utilizza, per non cambiare nulla ora.)

-- Verifica
SELECT 'aziende' AS tabella, count(*) FROM aziende
UNION ALL SELECT 'membri', count(*) FROM membri
UNION ALL SELECT 'prodotti con azienda', count(*) FROM prodotti WHERE azienda_id IS NOT NULL
UNION ALL SELECT 'preventivi con azienda', count(*) FROM preventivi WHERE azienda_id IS NOT NULL;
