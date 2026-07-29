-- ============================================================
-- Migrazione: passaggio a Supabase Auth (login con email + recupero password)
-- Esegui UNA VOLTA nel Supabase SQL Editor.
-- ============================================================
-- Cosa fa:
--  1) aggiunge la colonna "email" alla tabella utenti (collega profilo <-> login)
--  2) imposta l'email dell'utente admin
--  3) blinda la tabella utenti: niente più lettura pubblica con la anon key
--  4) le vecchie password SHA-256 non servono più (le gestisce Supabase Auth)
-- ============================================================

-- 1) Colonna email + unicità (case-insensitive)
ALTER TABLE utenti ADD COLUMN IF NOT EXISTS email text;
CREATE UNIQUE INDEX IF NOT EXISTS idx_utenti_email_unique
  ON utenti (lower(email))
  WHERE email IS NOT NULL AND email <> '';

-- 2) Email dell'amministratore (DEVE combaciare con l'account creato in Authentication → Users)
UPDATE utenti SET email = 'bottiandrea83@gmail.com' WHERE username = 'admin';

-- 3) Blinda la tabella utenti: solo gli utenti AUTENTICATI possono leggere/scrivere i profili.
--    (La anon key non potrà più leggere la tabella: gli hash non sono più esposti.)
ALTER TABLE utenti ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Leggi utenti"    ON utenti;
DROP POLICY IF EXISTS "Modifica utenti" ON utenti;
DROP POLICY IF EXISTS "Utenti autenticati leggono profili"    ON utenti;
DROP POLICY IF EXISTS "Utenti autenticati modificano profili" ON utenti;
CREATE POLICY "Utenti autenticati leggono profili"
  ON utenti FOR SELECT TO authenticated USING (true);
CREATE POLICY "Utenti autenticati modificano profili"
  ON utenti FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 4) La colonna password_hash non è più usata per il login: rendila opzionale
--    e svuota i vecchi valori (le password reali vivono in Supabase Auth, cifrate).
ALTER TABLE utenti ALTER COLUMN password_hash DROP NOT NULL;
UPDATE utenti SET password_hash = NULL;

-- Verifica finale
SELECT username, email, ruolo, attivo FROM utenti ORDER BY username;
