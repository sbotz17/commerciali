-- ============================================================
-- ROLLBACK Tappa 5 (SUPER ADMIN) — riporta le policy allo stato Tappa 4.
-- Esegui SOLO se dopo la Tappa 5 qualcosa non funziona.
-- ============================================================
-- Rimuove il "super potere" dalle policy e la colonna super_admin.
-- L'isolamento per-azienda (Tappa 4) resta intatto e attivo.
-- ============================================================

-- 1) Tabelle dati per-azienda: torna all'isolamento semplice (senza super admin)
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

-- 2) Aziende: policy Tappa 4 (senza super admin)
DROP POLICY IF EXISTS "aziende_select" ON aziende;
CREATE POLICY "aziende_select" ON aziende FOR SELECT TO authenticated
  USING (id IN (SELECT azienda_ids_correnti()));
DROP POLICY IF EXISTS "aziende_update" ON aziende;
CREATE POLICY "aziende_update" ON aziende FOR UPDATE TO authenticated
  USING (id IN (SELECT azienda_ids_correnti()))
  WITH CHECK (id IN (SELECT azienda_ids_correnti()));
DROP POLICY IF EXISTS "aziende_delete" ON aziende;
CREATE POLICY "aziende_delete" ON aziende FOR DELETE TO authenticated
  USING (id IN (SELECT azienda_ids_correnti()));

-- 3) Membri: policy Tappa 4 (senza super admin)
DROP POLICY IF EXISTS "membri_select" ON membri;
CREATE POLICY "membri_select" ON membri FOR SELECT TO authenticated
  USING (azienda_id IN (SELECT azienda_ids_correnti()) OR utente_id = utente_id_corrente());
DROP POLICY IF EXISTS "membri_insert" ON membri;
CREATE POLICY "membri_insert" ON membri FOR INSERT TO authenticated
  WITH CHECK (utente_id = utente_id_corrente() OR azienda_id IN (SELECT azienda_ids_correnti()));
DROP POLICY IF EXISTS "membri_update" ON membri;
CREATE POLICY "membri_update" ON membri FOR UPDATE TO authenticated
  USING (azienda_id IN (SELECT azienda_ids_correnti()))
  WITH CHECK (azienda_id IN (SELECT azienda_ids_correnti()));
DROP POLICY IF EXISTS "membri_delete" ON membri;
CREATE POLICY "membri_delete" ON membri FOR DELETE TO authenticated
  USING (azienda_id IN (SELECT azienda_ids_correnti()));

-- 4) Rimuove la funzione e la colonna super_admin
DROP FUNCTION IF EXISTS sono_super_admin();
ALTER TABLE utenti DROP COLUMN IF EXISTS super_admin;

-- Verifica: policy attive sulle tabelle
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname='public'
  AND tablename IN ('prodotti','clienti','preventivi','categorie','ruoli','aziende','membri')
ORDER BY tablename, policyname;
