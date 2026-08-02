-- ============================================================
-- Migrazione: immagine dell'articolo (prodotto)
-- Esegui UNA VOLTA nel Supabase SQL Editor.
-- ============================================================
-- Aggiunge la colonna per l'immagine del prodotto (salvata come
-- data URL base64). Usata nel catalogo e, se abilitato, nei preventivi.
-- ============================================================

ALTER TABLE prodotti ADD COLUMN IF NOT EXISTS immagine text;

-- Verifica
SELECT id, nome, (immagine IS NOT NULL) AS ha_immagine FROM prodotti ORDER BY id;
