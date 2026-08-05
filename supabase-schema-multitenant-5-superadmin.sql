-- ============================================================
-- MULTI-AZIENDA — Tappa 5: SUPER ADMIN globale
-- Esegui UNA VOLTA nel Supabase SQL Editor, DOPO la Tappa 4 (RLS).
-- ============================================================
-- Crea un ruolo "super admin" che sta SOPRA tutte le aziende: puo' vedere
-- ed entrare in qualsiasi azienda registrata. Tutti gli altri utenti
-- restano isolati alla propria azienda (invariato rispetto alla Tappa 4).
-- In caso di problemi: esegui supabase-schema-multitenant-5-rollback.sql
-- ============================================================

-- 1) Colonna super_admin sull'anagrafica utenti (default: false)
ALTER TABLE utenti ADD COLUMN IF NOT EXISTS super_admin BOOLEAN NOT NULL DEFAULT false;

-- 2) Funzione sicura (SECURITY DEFINER): l'utente autenticato è super admin?
CREATE OR REPLACE FUNCTION sono_super_admin()
RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT COALESCE(bool_or(u.super_admin), false)
  FROM utenti u
  WHERE lower(u.email) = lower(auth.jwt() ->> 'email');
$$;

GRANT EXECUTE ON FUNCTION sono_super_admin() TO authenticated;

-- 3) Nomina il super admin (cambia l'email se necessario)
UPDATE utenti SET super_admin = true
WHERE lower(email) = lower('bottiandrea83@gmail.com');

-- 4) Tabelle dati per-azienda: l'isolamento vale per tutti, TRANNE il super admin
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
      || 'USING (azienda_id IN (SELECT azienda_ids_correnti()) OR sono_super_admin()) '
      || 'WITH CHECK (azienda_id IN (SELECT azienda_ids_correnti()) OR sono_super_admin())', t);
  END LOOP;
END $$;

-- 5) Aziende: il super admin le vede/gestisce tutte
DROP POLICY IF EXISTS "aziende_select" ON aziende;
CREATE POLICY "aziende_select" ON aziende FOR SELECT TO authenticated
  USING (id IN (SELECT azienda_ids_correnti()) OR sono_super_admin());
DROP POLICY IF EXISTS "aziende_update" ON aziende;
CREATE POLICY "aziende_update" ON aziende FOR UPDATE TO authenticated
  USING (id IN (SELECT azienda_ids_correnti()) OR sono_super_admin())
  WITH CHECK (id IN (SELECT azienda_ids_correnti()) OR sono_super_admin());
DROP POLICY IF EXISTS "aziende_delete" ON aziende;
CREATE POLICY "aziende_delete" ON aziende FOR DELETE TO authenticated
  USING (id IN (SELECT azienda_ids_correnti()) OR sono_super_admin());
-- (aziende_insert resta invariata: chiunque autenticato può creare la propria)

-- 6) Membri: il super admin vede/gestisce i membri di tutte le aziende
DROP POLICY IF EXISTS "membri_select" ON membri;
CREATE POLICY "membri_select" ON membri FOR SELECT TO authenticated
  USING (azienda_id IN (SELECT azienda_ids_correnti()) OR utente_id = utente_id_corrente() OR sono_super_admin());
DROP POLICY IF EXISTS "membri_insert" ON membri;
CREATE POLICY "membri_insert" ON membri FOR INSERT TO authenticated
  WITH CHECK (utente_id = utente_id_corrente() OR azienda_id IN (SELECT azienda_ids_correnti()) OR sono_super_admin());
DROP POLICY IF EXISTS "membri_update" ON membri;
CREATE POLICY "membri_update" ON membri FOR UPDATE TO authenticated
  USING (azienda_id IN (SELECT azienda_ids_correnti()) OR sono_super_admin())
  WITH CHECK (azienda_id IN (SELECT azienda_ids_correnti()) OR sono_super_admin());
DROP POLICY IF EXISTS "membri_delete" ON membri;
CREATE POLICY "membri_delete" ON membri FOR DELETE TO authenticated
  USING (azienda_id IN (SELECT azienda_ids_correnti()) OR sono_super_admin());

-- Verifica: chi è super admin
SELECT email, super_admin FROM utenti WHERE super_admin = true;
