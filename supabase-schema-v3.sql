-- ============================================================
-- SCHEMA V3 — Ruoli & Permessi configurabili
-- ============================================================
-- Incolla nell'SQL Editor di Supabase ed esegui con Run
-- Da eseguire DOPO v1 e v2
-- ============================================================

CREATE TABLE IF NOT EXISTS ruoli (
  id           BIGSERIAL PRIMARY KEY,
  nome         TEXT NOT NULL,
  chiave       TEXT UNIQUE NOT NULL,           -- corrisponde a utenti.ruolo
  descrizione  TEXT DEFAULT '',
  sconto_max   INTEGER DEFAULT 0,              -- sconto massimo % consentito
  permessi     JSONB DEFAULT '{}',             -- { "permId": "lettura"|"scrittura"|"entrambi" }
  sistema      BOOLEAN DEFAULT FALSE,          -- i ruoli di sistema non si eliminano
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE ruoli DISABLE ROW LEVEL SECURITY;

-- ============================================================
-- Ruoli di default
-- ============================================================
INSERT INTO ruoli (nome, chiave, descrizione, sconto_max, permessi, sistema) VALUES
(
  'Amministratore', 'admin', 'Accesso completo a tutte le funzionalità', 100,
  '{
    "dashboard":          "entrambi",
    "listino":            "entrambi",
    "gestione_prodotti":  "entrambi",
    "preventivi_propri":  "entrambi",
    "preventivi_tutti":   "entrambi",
    "approva_preventivi": "entrambi",
    "clienti":            "entrambi",
    "bandi":              "entrambi",
    "gestione_categorie": "entrambi",
    "gestione_utenti":    "entrambi",
    "gestione_ruoli":     "entrambi"
  }',
  true
),
(
  'Commerciale', 'commerciale', 'Può creare e gestire i propri preventivi con sconto fino al 20%', 20,
  '{
    "dashboard":         "lettura",
    "listino":           "lettura",
    "preventivi_propri": "entrambi",
    "clienti":           "entrambi",
    "bandi":             "lettura"
  }',
  false
)
ON CONFLICT (chiave) DO UPDATE SET
  nome        = EXCLUDED.nome,
  descrizione = EXCLUDED.descrizione,
  sconto_max  = EXCLUDED.sconto_max,
  permessi    = EXCLUDED.permessi;
