-- ============================================================
-- SCHEMA V2 — Login, Utenti, Ruoli, Categorie dinamiche
-- ============================================================
-- Incolla nell'SQL Editor di Supabase ed esegui con Run
-- ============================================================


-- ============================================================
-- TABELLA: utenti (autenticazione custom)
-- ============================================================
CREATE TABLE IF NOT EXISTS utenti (
  id           BIGSERIAL PRIMARY KEY,
  username     TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  nome         TEXT DEFAULT '',
  ruolo        TEXT DEFAULT 'commerciale', -- 'admin' | 'commerciale'
  attivo       BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE utenti DISABLE ROW LEVEL SECURITY;

-- Utente admin di default (password: admin123)
INSERT INTO utenti (username, password_hash, nome, ruolo) VALUES
  ('admin', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'Amministratore', 'admin')
ON CONFLICT (username) DO NOTHING;


-- ============================================================
-- TABELLA: categorie (prodotti — dinamiche)
-- ============================================================
CREATE TABLE IF NOT EXISTS categorie (
  id         BIGSERIAL PRIMARY KEY,
  nome       TEXT NOT NULL,
  icona      TEXT DEFAULT '📦',
  ordine     INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE categorie DISABLE ROW LEVEL SECURITY;

-- Categorie di default
INSERT INTO categorie (nome, icona, ordine) VALUES
  ('Software', '💻', 1),
  ('Moduli',   '🔧', 2),
  ('Servizi',  '🛠️', 3)
ON CONFLICT DO NOTHING;


-- ============================================================
-- Aggiunge colonna utente_id ai preventivi (opzionale)
-- Per tracciare quale commerciale ha creato il preventivo
-- ============================================================
ALTER TABLE preventivi
  ADD COLUMN IF NOT EXISTS utente_id BIGINT REFERENCES utenti(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS utente_nome TEXT DEFAULT '';
