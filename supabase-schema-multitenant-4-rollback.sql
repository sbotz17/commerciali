-- ============================================================
-- ROLLBACK RLS (EMERGENZA) — riapre l'accesso disattivando le policy
-- della Tappa 4. Esegui SOLO se dopo la Tappa 4 l'app non carica i dati
-- o non riesci ad accedere.
-- ============================================================
-- Dopo il rollback l'isolamento torna a essere solo lato app (come Tappa 3).
-- ============================================================

DO $$
DECLARE t text; r record;
BEGIN
  FOREACH t IN ARRAY ARRAY['prodotti','clienti','preventivi','categorie','ruoli','aziende','membri'] LOOP
    FOR r IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename=t LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, t);
    END LOOP;
    EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

-- Verifica: nessuna policy e RLS disattivata su queste tabelle
SELECT tablename, rowsecurity AS rls_attiva
FROM pg_tables
WHERE schemaname='public'
  AND tablename IN ('prodotti','clienti','preventivi','categorie','ruoli','aziende','membri')
ORDER BY tablename;
