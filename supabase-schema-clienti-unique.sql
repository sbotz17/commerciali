-- ============================================================
-- Vincoli di unicità per la tabella clienti
-- Esegui nel Supabase SQL Editor
-- ============================================================

-- Unicità P.IVA: solo dove piva è valorizzata (esclude privati senza P.IVA)
-- Normalizza rimuovendo prefisso IT per evitare duplicati IT123/123
CREATE UNIQUE INDEX IF NOT EXISTS idx_clienti_piva_unique
  ON clienti (UPPER(REPLACE(piva, 'IT', '')))
  WHERE piva IS NOT NULL AND piva != '';

-- Unicità codice fiscale: solo dove valorizzato
CREATE UNIQUE INDEX IF NOT EXISTS idx_clienti_cf_unique
  ON clienti (UPPER(codice_fiscale))
  WHERE codice_fiscale IS NOT NULL AND codice_fiscale != '';
