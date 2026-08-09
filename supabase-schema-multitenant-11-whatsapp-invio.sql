-- ============================================================
-- MULTI-AZIENDA — Tappa 11: invii WhatsApp (lettura config per gli utenti)
-- Esegui UNA VOLTA nel Supabase SQL Editor, DOPO la Tappa 9.
-- ============================================================
-- Perché gli utenti delle aziende possano INVIARE messaggi dal proprio
-- browser al server WhatsApp, devono poter leggere URL + API key della
-- configurazione. La SCRITTURA resta riservata al super admin.
--
-- NOTA di sicurezza: così l'API key è leggibile da tutti gli utenti
-- autenticati (nel loro browser). È accettabile per questo scenario; per
-- irrigidire in futuro si può instradare gli invii tramite una Edge
-- Function che tiene la chiave lato server.
-- In caso di problemi: esegui supabase-schema-multitenant-11-rollback.sql
-- ============================================================

-- Sostituisce la policy "tutto solo super admin" con:
--   - lettura per tutti gli autenticati
--   - scrittura solo super admin
DROP POLICY IF EXISTS "whatsapp_config_all"    ON whatsapp_config;
DROP POLICY IF EXISTS "whatsapp_config_select" ON whatsapp_config;
DROP POLICY IF EXISTS "whatsapp_config_write"  ON whatsapp_config;

CREATE POLICY "whatsapp_config_select" ON whatsapp_config FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "whatsapp_config_write" ON whatsapp_config FOR ALL TO authenticated
  USING (sono_super_admin()) WITH CHECK (sono_super_admin());

-- Verifica
SELECT policyname, cmd FROM pg_policies
WHERE schemaname='public' AND tablename='whatsapp_config' ORDER BY policyname;
