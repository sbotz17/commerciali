-- ============================================================
-- Schema: tabella utenti (login applicazione)
-- Esegui nel Supabase SQL Editor
-- ============================================================
-- Colonne allineate al codice: js/auth.js e js/supabase.js
-- ============================================================

CREATE TABLE IF NOT EXISTS utenti (
  id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  username      text NOT NULL UNIQUE,
  password_hash text NOT NULL,          -- SHA-256 (hex) della password
  nome          text DEFAULT '',
  ruolo         text DEFAULT 'commerciale',
  avatar        text,
  menu_utente   jsonb,
  attivo        boolean DEFAULT true,
  created_at    timestamptz DEFAULT now()
);

-- RLS (come per la tabella ruoli): necessaria al login con la anon key.
-- NOTA: con queste policy la tabella utenti è leggibile/scrivibile da chiunque
-- possieda la anon key. Per un login realmente sicuro conviene una funzione
-- RPC (SECURITY DEFINER) che non esponga gli hash. Vedi note nel README.
ALTER TABLE utenti ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Leggi utenti"    ON utenti FOR SELECT USING (true);
CREATE POLICY "Modifica utenti" ON utenti FOR ALL    USING (true);

-- Utente amministratore predefinito — password: admin123
-- (240be5...c720a9 = SHA-256 di "admin123")
INSERT INTO utenti (username, password_hash, nome, ruolo, attivo)
VALUES (
  'admin',
  '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9',
  'Amministratore', 'admin', true
)
ON CONFLICT (username) DO UPDATE
SET password_hash = EXCLUDED.password_hash,
    ruolo  = 'admin',
    attivo = true;
