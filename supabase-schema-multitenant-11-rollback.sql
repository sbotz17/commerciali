-- ============================================================
-- ROLLBACK Tappa 11 — riporta la config WhatsApp a "solo super admin".
-- ============================================================

DROP POLICY IF EXISTS "whatsapp_config_select" ON whatsapp_config;
DROP POLICY IF EXISTS "whatsapp_config_write"  ON whatsapp_config;
DROP POLICY IF EXISTS "whatsapp_config_all"    ON whatsapp_config;

CREATE POLICY "whatsapp_config_all" ON whatsapp_config FOR ALL TO authenticated
  USING (sono_super_admin()) WITH CHECK (sono_super_admin());

SELECT policyname, cmd FROM pg_policies
WHERE schemaname='public' AND tablename='whatsapp_config' ORDER BY policyname;
