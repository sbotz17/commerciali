-- ============================================================
-- Schema: impostazioni aziendali + avatar utente
-- Esegui nel SQL Editor di Supabase
-- ============================================================

-- Tabella impostazioni chiave/valore
CREATE TABLE IF NOT EXISTS impostazioni (
  chiave TEXT PRIMARY KEY,
  valore TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE impostazioni DISABLE ROW LEVEL SECURITY;

-- Riga iniziale per il logo
INSERT INTO impostazioni (chiave, valore) VALUES ('logo', NULL)
  ON CONFLICT (chiave) DO NOTHING;

-- Colonna avatar nella tabella utenti (base64 o URL)
ALTER TABLE utenti ADD COLUMN IF NOT EXISTS avatar TEXT;

-- Colonna menu_utente: array di pagine visibili (NULL = usa i permessi del ruolo)
ALTER TABLE utenti ADD COLUMN IF NOT EXISTS menu_utente TEXT[];
