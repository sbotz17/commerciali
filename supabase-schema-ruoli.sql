-- ============================================================
-- Schema: tabella ruoli
-- Esegui nel Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS ruoli (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nome        text NOT NULL,
  chiave      text NOT NULL UNIQUE,
  descrizione text DEFAULT '',
  sconto_max  integer DEFAULT 0,
  permessi    jsonb DEFAULT '{}',
  sistema     boolean DEFAULT false,
  created_at  timestamptz DEFAULT now()
);

-- Ruoli di sistema predefiniti
INSERT INTO ruoli (nome, chiave, descrizione, sconto_max, permessi, sistema) VALUES
(
  'Amministratore',
  'admin',
  'Accesso completo a tutte le funzionalità',
  100,
  '{
    "dashboard": "entrambi",
    "listino": "entrambi",
    "gestione_prodotti": "entrambi",
    "preventivi_propri": "entrambi",
    "preventivi_tutti": "entrambi",
    "approva_preventivi": "entrambi",
    "clienti": "entrambi",
    "bandi": "entrambi",
    "gestione_categorie": "entrambi",
    "gestione_utenti": "entrambi",
    "gestione_ruoli": "entrambi",
    "impostazioni": "entrambi"
  }'::jsonb,
  true
),
(
  'Commerciale',
  'commerciale',
  'Accesso operativo standard',
  20,
  '{
    "dashboard": "lettura",
    "listino": "lettura",
    "preventivi_propri": "entrambi",
    "clienti": "entrambi",
    "bandi": "lettura"
  }'::jsonb,
  true
)
ON CONFLICT (chiave) DO NOTHING;

-- RLS (opzionale — disabilita se non usi auth Supabase)
ALTER TABLE ruoli ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Tutti possono leggere ruoli" ON ruoli FOR SELECT USING (true);
CREATE POLICY "Solo admin può modificare ruoli" ON ruoli FOR ALL USING (true);
