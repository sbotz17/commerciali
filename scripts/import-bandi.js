#!/usr/bin/env node
// ============================================================
// import-bandi.js — Import iniziale bandi da incentivi.gov.it
// ============================================================
// Uso: node scripts/import-bandi.js <percorso-file.json>
// Es.: node scripts/import-bandi.js ./opendata-export.json
//
// Requisiti: Node.js 18+ (usa fetch built-in, nessun npm install)
// ============================================================

// ── CONFIGURA QUI le tue credenziali Supabase ─────────────
const SUPABASE_URL      = "https://segbfdfoqxrnitboeyof.supabase.co";
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || "";
// IMPORTANTE: usa la Service Role Key (non la anon key) per i write
// La trovi in Supabase → Settings → API → service_role (secret)
// Passala come variabile d'ambiente:
//   SUPABASE_SERVICE_KEY="eyJ..." node scripts/import-bandi.js opendata-export.json
// ──────────────────────────────────────────────────────────

const fs   = require("fs");
const path = require("path");

if (!SUPABASE_SERVICE_KEY) {
  console.error("❌ SUPABASE_SERVICE_KEY non impostata.");
  console.error("   Esegui: SUPABASE_SERVICE_KEY=\"eyJ...\" node scripts/import-bandi.js opendata-export.json");
  process.exit(1);
}

const filePath = process.argv[2];
if (!filePath) {
  console.error("❌ Percorso file mancante. Uso: node scripts/import-bandi.js <file.json>");
  process.exit(1);
}

const absPath = path.resolve(process.cwd(), filePath);
if (!fs.existsSync(absPath)) {
  console.error(`❌ File non trovato: ${absPath}`);
  process.exit(1);
}

// ── Normalizzazione ATECO ───────────────────────────────────
function parseAteco(s) {
  if (!s) return { tutti_ateco: true, codici_ateco: [] };
  const low = s.toLowerCase();
  if (low.includes("tutti") || low.includes("qualsiasi") || low.includes("indifferente")) {
    return { tutti_ateco: true, codici_ateco: [] };
  }
  const codici = s
    .split(";")
    .map(c => c.trim())
    .filter(c => c && /^\d/.test(c));
  return { tutti_ateco: codici.length === 0, codici_ateco: codici };
}

// ── Calcolo stato bando ─────────────────────────────────────
function calcolaStato(chiusura) {
  if (!chiusura) return "permanente";
  const oggi  = new Date();
  const fine  = new Date(chiusura);
  if (fine < oggi) return "scaduto";
  const giorni = Math.round((fine - oggi) / 86_400_000);
  if (giorni <= 30) return "in_scadenza";
  return "attivo";
}

// ── Normalizzazione record ──────────────────────────────────
function normalizza(d) {
  const { tutti_ateco, codici_ateco } = parseAteco(d.Codici_ATECO);
  const regioni      = Array.isArray(d.Regioni) ? d.Regioni : [];
  const tutte_regioni = regioni.length === 0;
  return {
    id:                   String(d.ID_Incentivo),
    titolo:               (d.Titolo || "").trim(),
    descrizione:          (d.Descrizione || "").substring(0, 2000),
    data_apertura:        d.Data_apertura  || null,
    data_chiusura:        d.Data_chiusura  || null,
    stato:                calcolaStato(d.Data_chiusura),
    codici_ateco,
    tutti_ateco,
    regioni,
    tutte_regioni,
    forma_agevolazione:   Array.isArray(d.Forma_agevolazione)  ? d.Forma_agevolazione  : [],
    dimensioni:           Array.isArray(d.Dimensioni)          ? d.Dimensioni          : [],
    settore_attivita:     Array.isArray(d.Settore_Attivita)    ? d.Settore_Attivita    : [],
    obiettivi:            Array.isArray(d.Obiettivo_Finalita)  ? d.Obiettivo_Finalita  : [],
    soggetto_concedente:  (d.Soggetto_Concedente  || "").trim(),
    agevolazione_min:     parseFloat(d.Agevolazione_Concedibile_min) || 0,
    agevolazione_max:     parseFloat(d.Agevolazione_Concedibile_max) || 0,
    stanziamento:         parseFloat(d.Stanziamento_incentivo)       || 0,
    link_ufficiale:       (d.Link_istituzionale   || "").trim(),
    fonte:                "incentivi.gov.it",
    ultimo_aggiornamento: d.Data_ultimo_aggiornamento || null,
    data_importazione:    new Date().toISOString(),
  };
}

// ── Upsert batch su Supabase ────────────────────────────────
async function upsertBatch(records) {
  const url = `${SUPABASE_URL}/rest/v1/bandi_incentivi`;
  const res = await fetch(url, {
    method:  "POST",
    headers: {
      "Content-Type":  "application/json",
      "apikey":         SUPABASE_SERVICE_KEY,
      "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`,
      "Prefer":        "resolution=merge-duplicates,return=minimal",
    },
    body: JSON.stringify(records),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Supabase error ${res.status}: ${err}`);
  }
}

// ── Main ────────────────────────────────────────────────────
async function main() {
  console.log(`\n📂 Leggo: ${absPath}`);
  const raw  = JSON.parse(fs.readFileSync(absPath, "utf-8"));
  console.log(`📊 Record totali nel file: ${raw.length}`);

  const oggi   = new Date();
  const attivi = raw.filter(d => {
    if (!d.Data_chiusura) return true;
    return new Date(d.Data_chiusura) >= oggi;
  });
  console.log(`✅ Record attivi (chiusura >= oggi o senza data): ${attivi.length}`);

  const normalizzati = attivi.map(normalizza);

  const BATCH = 100;
  let importati = 0;
  for (let i = 0; i < normalizzati.length; i += BATCH) {
    const batch = normalizzati.slice(i, i + BATCH);
    process.stdout.write(`\r⏳ Importazione: ${Math.min(i + BATCH, normalizzati.length)}/${normalizzati.length}`);
    await upsertBatch(batch);
    importati += batch.length;
  }

  console.log(`\n\n🎉 Import completato! ${importati} bandi caricati in Supabase.`);
  console.log("   Vai nell'app → sezione Bandi per verificare.\n");
}

main().catch(err => {
  console.error("\n❌ Errore:", err.message);
  process.exit(1);
});
