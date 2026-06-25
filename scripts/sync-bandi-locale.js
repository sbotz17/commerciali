// ============================================================
// sync-bandi-locale.js
// Script Node.js da pianificare con Windows Task Scheduler
// Scarica i bandi da incentivi.gov.it e li importa in Supabase
//
// Esecuzione manuale:
//   node scripts/sync-bandi-locale.js
//
// Pianificazione automatica (Windows Task Scheduler):
//   Vedi istruzioni in fondo al file
// ============================================================

// ── Configurazione ──────────────────────────────────────────
// Legge dalle variabili d'ambiente (GitHub Actions) o usa i valori hardcoded (locale)
const SUPABASE_URL  = process.env.SUPABASE_URL  || "https://segbfdfoqxrnitboeyof.supabase.co";
const SUPABASE_ANON = process.env.SUPABASE_ANON || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlZ2JmZGZvcXhybml0Ym9leW9mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxMzIxNzksImV4cCI6MjA5NzcwODE3OX0.v5ZGCkqTduegxFaa6GOYUIIHrQ5cQe0JFB7PGO93XNo";

// URL Solr di incentivi.gov.it — aggiorna rows se vuoi più/meno record
const INCENTIVI_URL = "https://www.incentivi.gov.it/solr/coredrupal/select?q.op=OR&wt=json&rows=8000&fl=ID_Incentivo%3Azs_nid%2CTitolo%3Azs_title%2CDescrizione%3Azs_body%2CObiettivo_Finalita%3Azm_field_scopes_value%2CData_apertura%3Azs_field_open_date%2CData_chiusura%3Azs_field_close_date%2CNote_di_apertura_chiusura%3Azs_field_close_date_descriptor%2CDimensioni%3Azm_field_dimensions_value%2CTipologia_Soggetto%3Azm_field_subject_type_value%2CForma_agevolazione%3Azm_field_support_form_value%2CCosti_Ammessi%3Azm_field_granted_costs_value%2CSpesa_Ammessa_min%3Azs_field_cost_min%2CSpesa_Ammessa_max%3Azs_field_cost_max%2CAgevolazione_Concedibile_min%3Azs_field_support_grant_type_min%2CAgevolazione_Concedibile_max%3Azs_field_support_grant_type_max%2CSettore_Attivita%3Azm_field_activity_sector_value%2CCodici_ATECO%3Azs_field_ateco%2CRegioni%3Azm_field_regions_value%2CComuni%3Azs_field_comuni%2CAmbito_territoriale%3Azm_field_special_territory_value%2CSoggetto_Concedente%3Azs_field_subject_grant%2CBase_normativa_primaria%3Azs_field_primary_ruleset%2CBase_normativa_secondaria%3Azs_field_secondary_ruleset%2CProvvedimento_attuativo%3Azs_field_implementation_ruleset%2CGazzetta_ufficiale%3Azs_field_official_references%2CStanziamento_incentivo%3Azs_field_budget_allocation%2CLink_istituzionale%3Azs_field_link%2CAltre_caratteristiche%3Azs_field_other_characteristic%2CData_ultimo_aggiornamento%3Ads_last_update%2C&q=index_id%3Aincentivi+";

const BATCH_SIZE    = 100;
const FONTE_ID      = "incentivi_gov";
const FONTE_NOME    = "incentivi.gov.it";

// ── Utilità ─────────────────────────────────────────────────
function log(msg) {
  const ora = new Date().toLocaleString("it-IT");
  console.log(`[${ora}] ${msg}`);
}

function calcolaStato(dataChiusura) {
  if (!dataChiusura) return "permanente";
  const fine = new Date(dataChiusura);
  if (isNaN(fine.getTime())) return "attivo";
  const oggi = new Date();
  if (fine < oggi) return "scaduto";
  const giorni = Math.round((fine - oggi) / 86_400_000);
  return giorni <= 30 ? "in_scadenza" : "attivo";
}

function normalizza(d) {
  const ateco = d.Codici_ATECO || "";
  const low   = ateco.toLowerCase();
  const tuttiAteco = !ateco || low.includes("tutti") || low.includes("qualsiasi") || low.includes("indifferente");
  const codiciAteco = tuttiAteco
    ? []
    : ateco.split(";").map(c => c.trim()).filter(c => c && /^\d/.test(c));
  const regioni = Array.isArray(d.Regioni) ? d.Regioni : [];

  return {
    id:                   String(d.ID_Incentivo),
    titolo:               (d.Titolo || "").trim(),
    descrizione:          (d.Descrizione || "").substring(0, 2000),
    data_apertura:        d.Data_apertura  || null,
    data_chiusura:        d.Data_chiusura  || null,
    stato:                calcolaStato(d.Data_chiusura),
    codici_ateco:         codiciAteco,
    tutti_ateco:          tuttiAteco,
    regioni,
    tutte_regioni:        regioni.length === 0,
    forma_agevolazione:   Array.isArray(d.Forma_agevolazione)  ? d.Forma_agevolazione  : [],
    dimensioni:           Array.isArray(d.Dimensioni)           ? d.Dimensioni           : [],
    settore_attivita:     Array.isArray(d.Settore_Attivita)    ? d.Settore_Attivita    : [],
    obiettivi:            Array.isArray(d.Obiettivo_Finalita)  ? d.Obiettivo_Finalita  : [],
    soggetto_concedente:  (d.Soggetto_Concedente || "").trim(),
    agevolazione_min:     parseFloat(d.Agevolazione_Concedibile_min) || 0,
    agevolazione_max:     parseFloat(d.Agevolazione_Concedibile_max) || 0,
    stanziamento:         parseFloat(d.Stanziamento_incentivo)       || 0,
    link_ufficiale:       (d.Link_istituzionale || "").trim(),
    fonte:                FONTE_NOME,
    ultimo_aggiornamento: d.Data_ultimo_aggiornamento || null,
    data_importazione:    new Date().toISOString(),
  };
}

async function upsertBatch(records) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/bandi_incentivi`, {
    method:  "POST",
    headers: {
      "apikey":        SUPABASE_ANON,
      "Authorization": "Bearer " + SUPABASE_ANON,
      "Content-Type":  "application/json",
      "Prefer":        "resolution=merge-duplicates",
    },
    body: JSON.stringify(records),
  });
  if (!res.ok) {
    const testo = await res.text();
    throw new Error(`Upsert fallito (${res.status}): ${testo.substring(0, 300)}`);
  }
}

async function aggiornaStatoFonte(stato, importati, errore) {
  await fetch(`${SUPABASE_URL}/rest/v1/bandi_fonti?id=eq.${FONTE_ID}`, {
    method:  "PATCH",
    headers: {
      "apikey":        SUPABASE_ANON,
      "Authorization": "Bearer " + SUPABASE_ANON,
      "Content-Type":  "application/json",
    },
    body: JSON.stringify({
      sync_stato:     stato,
      ultimo_sync:    new Date().toISOString(),
      sync_importati: importati,
      sync_errore:    errore || null,
    }),
  });
}

async function scriviLog(stato, importati, totale, errore) {
  await fetch(`${SUPABASE_URL}/rest/v1/bandi_sync_log`, {
    method:  "POST",
    headers: {
      "apikey":        SUPABASE_ANON,
      "Authorization": "Bearer " + SUPABASE_ANON,
      "Content-Type":  "application/json",
    },
    body: JSON.stringify({
      fonte_id:     FONTE_ID,
      stato,
      importati,
      totale_fonte: totale,
      errore:       errore || null,
      completato_il: new Date().toISOString(),
    }),
  });
}

// ── Main ────────────────────────────────────────────────────
async function main() {
  log("=== SYNC BANDI AVVIATO ===");

  // 1. Download
  log(`Download da ${INCENTIVI_URL.substring(0, 60)}…`);
  let raw;
  try {
    const res = await fetch(INCENTIVI_URL);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const parsed = await res.json();
    raw = Array.isArray(parsed) ? parsed : (parsed?.response?.docs ?? []);
    log(`Ricevuti ${raw.length} record totali`);
  } catch (e) {
    log(`ERRORE download: ${e.message}`);
    await aggiornaStatoFonte("errore", 0, `Fetch fallita: ${e.message}`);
    await scriviLog("errore", 0, 0, `Fetch fallita: ${e.message}`);
    process.exit(1);
  }

  if (!raw.length) {
    log("Nessun record ricevuto — sync terminata");
    await aggiornaStatoFonte("errore", 0, "Nessun record ricevuto");
    process.exit(1);
  }

  // 2. Filtra attivi e normalizza
  const oggi   = new Date();
  const attivi = raw.filter(d => !d.Data_chiusura || new Date(d.Data_chiusura) >= oggi);
  log(`Bandi attivi: ${attivi.length} (scaduti esclusi: ${raw.length - attivi.length})`);

  const records = attivi.map(normalizza);

  // 3. Upsert a batch
  let importati = 0;
  try {
    for (let i = 0; i < records.length; i += BATCH_SIZE) {
      const batch = records.slice(i, i + BATCH_SIZE);
      await upsertBatch(batch);
      importati += batch.length;
      process.stdout.write(`\r  Importati: ${importati}/${records.length}`);
    }
    console.log(); // newline dopo il progress
  } catch (e) {
    log(`ERRORE upsert: ${e.message}`);
    await aggiornaStatoFonte("errore", importati, e.message);
    await scriviLog("errore", importati, raw.length, e.message);
    process.exit(1);
  }

  // 4. Aggiorna stato fonti e log
  await aggiornaStatoFonte("ok", importati, null);
  await scriviLog("ok", importati, raw.length, null);

  log(`=== COMPLETATO: ${importati} bandi importati ===`);
}

main().catch(e => {
  console.error("Errore fatale:", e);
  process.exit(1);
});

// ============================================================
// PIANIFICAZIONE AUTOMATICA — Windows Task Scheduler
// ============================================================
//
// 1. Apri "Utilità di pianificazione" (Task Scheduler) da Start
// 2. Clic su "Crea attività di base…"
// 3. Nome: "Sync Bandi Incentivi"
// 4. Trigger: Giornaliero → ore 03:00
// 5. Azione: "Avvia un programma"
//    - Programma: node
//    - Argomenti: "C:\Users\andrea.botti.GAB\Claude\Projects\CONFIGURATORE COMMERCIALI\scripts\sync-bandi-locale.js"
//    - Avvia in:  C:\Users\andrea.botti.GAB\Claude\Projects\CONFIGURATORE COMMERCIALI
// 6. Fine — salva
//
// Test manuale da terminale:
//   node scripts/sync-bandi-locale.js
// ============================================================
