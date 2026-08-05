-- ============================================================
-- MULTI-AZIENDA — Tappa 4: RLS (isolamento a livello database)
-- Esegui UNA VOLTA nel Supabase SQL Editor, DOPO le Tappe 1-3 e dopo
-- aver messo online la versione dell'app con azienda attiva (Tappa 2/3).
-- ============================================================
-- Ogni utente vede/modifica solo i dati delle aziende di cui è membro.
-- In caso di problemi: esegui supabase-schema-multitenant-4-rollback.sql
-- ============================================================

-- 1) Funzioni sicure (SECURITY DEFINER) per non entrare in ricorsione con RLS
CREATE OR REPLACE FUNCTION azienda_ids_correnti()
RETURNS SETOF uuid
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT m.azienda_id
  FROM membri m
  JOIN utenti u ON u.id = m.utente_id
  WHERE lower(u.email) = lower(auth.jwt() ->> 'email');
$$;

CREATE OR REPLACE FUNCTION utente_id_corrente()
RETURNS bigint
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT id FROM utenti
  WHERE lower(email) = lower(auth.jwt() ->> 'email')
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION azienda_ids_correnti() TO authenticated;
GRANT EXECUTE ON FUNCTION utente_id_corrente()  TO authenticated;

-- 2) Tabelle dati per-azienda: sostituisce ogni policy esistente con l'isolamento
DO $$
DECLARE t text; r record;
BEGIN
  FOREACH t IN ARRAY ARRAY['prodotti','clienti','preventivi','categorie','ruoli'] LOOP
    FOR r IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename=t LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, t);
    END LOOP;
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY "isolamento_azienda" ON public.%I FOR ALL TO authenticated '
      || 'USING (azienda_id IN (SELECT azienda_ids_correnti())) '
      || 'WITH CHECK (azienda_id IN (SELECT azienda_ids_correnti()))', t);
  END LOOP;
END $$;

-- 3) Aziende: vedi le tue, creane di nuove (self-service), modifica/elimina le tue
ALTER TABLE aziende ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "aziende_select" ON aziende;
DROP POLICY IF EXISTS "aziende_insert" ON aziende;
DROP POLICY IF EXISTS "aziende_update" ON aziende;
DROP POLICY IF EXISTS "aziende_delete" ON aziende;
CREATE POLICY "aziende_select" ON aziende FOR SELECT TO authenticated
  USING (id IN (SELECT azienda_ids_correnti()));
CREATE POLICY "aziende_insert" ON aziende FOR INSERT TO authenticated
  WITH CHECK (true);
CREATE POLICY "aziende_update" ON aziende FOR UPDATE TO authenticated
  USING (id IN (SELECT azienda_ids_correnti()))
  WITH CHECK (id IN (SELECT azienda_ids_correnti()));
CREATE POLICY "aziende_delete" ON aziende FOR DELETE TO authenticated
  USING (id IN (SELECT azienda_ids_correnti()));

-- 4) Membri: vedi i membri delle tue aziende; puoi aggiungere te stesso
--    (onboarding) o membri alle tue aziende; modifica/elimina nelle tue aziende
ALTER TABLE membri ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "membri_select" ON membri;
DROP POLICY IF EXISTS "membri_insert" ON membri;
DROP POLICY IF EXISTS "membri_update" ON membri;
DROP POLICY IF EXISTS "membri_delete" ON membri;
CREATE POLICY "membri_select" ON membri FOR SELECT TO authenticated
  USING (azienda_id IN (SELECT azienda_ids_correnti()) OR utente_id = utente_id_corrente());
CREATE POLICY "membri_insert" ON membri FOR INSERT TO authenticated
  WITH CHECK (utente_id = utente_id_corrente() OR azienda_id IN (SELECT azienda_ids_correnti()));
CREATE POLICY "membri_update" ON membri FOR UPDATE TO authenticated
  USING (azienda_id IN (SELECT azienda_ids_correnti()))
  WITH CHECK (azienda_id IN (SELECT azienda_ids_correnti()));
CREATE POLICY "membri_delete" ON membri FOR DELETE TO authenticated
  USING (azienda_id IN (SELECT azienda_ids_correnti()));

-- NOTE:
-- - utenti: resta con le policy attuali (autenticati) — le anagrafiche non
--   contengono password e l'app mostra solo i membri dell'azienda attiva.
-- - impostazioni: RLS non attivata in questa tappa (rifinitura successiva).
-- - bandi_*: dati pubblici condivisi, invariati.

-- Verifica: elenca le policy attive sulle tabelle per-azienda
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname='public'
  AND tablename IN ('prodotti','clienti','preventivi','categorie','ruoli','aziende','membri')
ORDER BY tablename, policyname;
