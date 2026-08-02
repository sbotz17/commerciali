-- ============================================================
-- Migrazione: proprietario del preventivo (commerciale che lo emette)
-- Esegui UNA VOLTA nel Supabase SQL Editor.
-- ============================================================
-- Serve per far vedere a ciascun commerciale SOLO i propri preventivi,
-- mentre l'amministratore (permesso "preventivi_tutti") li vede tutti.
-- ============================================================

-- 1) Colonna proprietario
ALTER TABLE preventivi ADD COLUMN IF NOT EXISTS utente_id uuid;

-- 2) Collega alla tabella utenti; se l'utente viene eliminato, azzera il campo
ALTER TABLE preventivi
  DROP CONSTRAINT IF EXISTS preventivi_utente_id_fkey;
ALTER TABLE preventivi
  ADD CONSTRAINT preventivi_utente_id_fkey
  FOREIGN KEY (utente_id) REFERENCES utenti(id) ON DELETE SET NULL;

-- 3) Indice per filtrare velocemente per proprietario
CREATE INDEX IF NOT EXISTS idx_preventivi_utente ON preventivi (utente_id);

-- NOTA sui preventivi già esistenti:
-- restano con utente_id = NULL, quindi visibili solo all'amministratore.
-- Se vuoi assegnarli a un commerciale specifico, trova il suo id con:
--   SELECT id, username, email FROM utenti;
-- e poi (esempio) assegna TUTTI i preventivi senza proprietario a quell'utente:
--   UPDATE preventivi SET utente_id = '<id-del-commerciale>' WHERE utente_id IS NULL;

-- Verifica
SELECT id, numero, cliente_nome, utente_id, stato FROM preventivi ORDER BY id;
