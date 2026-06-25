-- ============================================================
-- SCHEMA SUPABASE — Configuratore Commerciali
-- ============================================================
-- Incolla questo script nell'editor SQL di Supabase:
-- Dashboard → SQL Editor → New query → incolla → Run
-- ============================================================


-- ============================================================
-- TABELLA: prodotti
-- ============================================================
CREATE TABLE IF NOT EXISTS prodotti (
  id          BIGSERIAL PRIMARY KEY,
  nome        TEXT          NOT NULL,
  categoria   TEXT          NOT NULL DEFAULT 'software',
  prezzo      NUMERIC(10,2) NOT NULL DEFAULT 0,
  descrizione TEXT                   DEFAULT '',
  attivo      BOOLEAN                DEFAULT TRUE,
  created_at  TIMESTAMPTZ            DEFAULT NOW()
);

-- ============================================================
-- TABELLA: clienti
-- ============================================================
CREATE TABLE IF NOT EXISTS clienti (
  id         BIGSERIAL PRIMARY KEY,
  nome       TEXT NOT NULL,
  referente  TEXT DEFAULT '',
  email      TEXT DEFAULT '',
  telefono   TEXT DEFAULT '',
  citta      TEXT DEFAULT '',
  ateco      TEXT DEFAULT '',
  settore    TEXT DEFAULT 'ristorazione',
  regione    TEXT DEFAULT 'lombardia',
  note       TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABELLA: preventivi
-- ============================================================
CREATE TABLE IF NOT EXISTS preventivi (
  id          BIGSERIAL PRIMARY KEY,
  numero      TEXT UNIQUE,
  cliente_id  BIGINT REFERENCES clienti(id) ON DELETE SET NULL,
  cliente_nome TEXT          DEFAULT '',
  righe       JSONB         DEFAULT '[]',
  sconto      NUMERIC(5,2)  DEFAULT 0,
  note        TEXT          DEFAULT '',
  subtotale   NUMERIC(10,2) DEFAULT 0,
  imp_sconto  NUMERIC(10,2) DEFAULT 0,
  imponibile  NUMERIC(10,2) DEFAULT 0,
  iva         NUMERIC(10,2) DEFAULT 0,
  totale_iva  NUMERIC(10,2) DEFAULT 0,
  stato       TEXT          DEFAULT 'bozza',
  created_at  TIMESTAMPTZ   DEFAULT NOW()
);


-- ============================================================
-- DISABILITA RLS (app single-user, senza autenticazione)
-- Se in futuro aggiungi il login, riabilita e configura le policy
-- ============================================================
ALTER TABLE prodotti   DISABLE ROW LEVEL SECURITY;
ALTER TABLE clienti    DISABLE ROW LEVEL SECURITY;
ALTER TABLE preventivi DISABLE ROW LEVEL SECURITY;


-- ============================================================
-- DATI DI ESEMPIO — prodotti
-- ============================================================
INSERT INTO prodotti (nome, categoria, prezzo, descrizione) VALUES
  ('Software Gestionale Base',       'software', 499,  'Gestione ordini, magazzino e cassa'),
  ('Software Gestionale Pro',        'software', 899,  'Base + analisi vendite e fidelity card'),
  ('Modulo E-commerce',              'modulo',   299,  'Vetrina online + ordini digitali'),
  ('App Mobile Cliente',             'modulo',   199,  'App branded per ordinare e prenotare'),
  ('Supporto Annuale',               'servizio', 199,  'Assistenza telefonica + aggiornamenti 12 mesi'),
  ('Formazione On-site',             'servizio', 150,  'Mezza giornata di formazione presso il cliente'),
  ('Installazione e Configurazione', 'servizio', 120,  'Setup completo sistema + import dati');

-- ============================================================
-- DATI DI ESEMPIO — clienti
-- ============================================================
INSERT INTO clienti (nome, referente, email, telefono, citta, ateco, settore, regione) VALUES
  ('Ristorante La Pergola', 'Marco Rossi',   'info@lapergola.it', '02 1234567', 'Milano', '56.10', 'ristorazione', 'lombardia'),
  ('Boutique Elena',        'Elena Bianchi', 'elena@boutique.it', '011 987654', 'Torino', '47.71', 'retail',        'piemonte');
