// ============================================================
// sync-bandi — Edge Function multi-fonte
// ============================================================
// Scarica bandi da tutte le fonti attive configurate nella
// tabella bandi_fonti (Supabase), normalizza e fa upsert
// in bandi_incentivi.
//
// Fonti supportate:
//   tipo = "json_incentivi"  → JSON array da incentivi.gov.it
//   tipo = "rss"             → RSS/Atom feed generico
//
// Deploy:
//   supabase functions deploy sync-bandi --no-verify-jwt
//
// Secrets richiesti:
//   SUPABASE_URL              (auto-iniettato)
//   SUPABASE_SERVICE_ROLE_KEY (auto-iniettato)
//   INCENTIVI_OPEN_DATA_URL   → URL JSON open data incentivi.gov.it
//
// Scheduling automatico (pg_cron + pg_net):
//   Vedi supabase-schema-bandi-v2.sql per le istruzioni
// ============================================================

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ─────────────────────────────────────────────────────────────
// TIPI
// ─────────────────────────────────────────────────────────────
interface Fonte {
  id:    string;
  nome:  string;
  url:   string;
  tipo:  "json_incentivi" | "rss" | string;
  attiva: boolean;
}

interface BandoRecord {
  id:                   string;
  titolo:               string;
  descrizione:          string;
  data_apertura:        string | null;
  data_chiusura:        string | null;
  stato:                string;
  codici_ateco:         string[];
  tutti_ateco:          boolean;
  regioni:              string[];
  tutte_regioni:        boolean;
  forma_agevolazione:   string[];
  dimensioni:           string[];
  settore_attivita:     string[];
  obiettivi:            string[];
  soggetto_concedente:  string;
  agevolazione_min:     number;
  agevolazione_max:     number;
  stanziamento:         number;
  link_ufficiale:       string;
  fonte:                string;
  ultimo_aggiornamento: string | null;
  data_importazione:    string;
}

// ─────────────────────────────────────────────────────────────
// UTILITÀ
// ─────────────────────────────────────────────────────────────

function calcolaStato(chiusura: string | null): string {
  if (!chiusura) return "permanente";
  const fine = new Date(chiusura);
  if (isNaN(fine.getTime())) return "attivo";
  const oggi = new Date();
  if (fine < oggi) return "scaduto";
  const giorni = Math.round((fine.getTime() - oggi.getTime()) / 86_400_000);
  return giorni <= 30 ? "in_scadenza" : "attivo";
}

/** Hash numerico stabile di una stringa — usato per generare ID da URL RSS */
function hashStr(s: string): string {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = Math.imul(31, h) + s.charCodeAt(i) | 0;
  }
  return Math.abs(h).toString(36);
}

/** Estrae testo da un tag XML (gestisce CDATA) */
function xmlTag(xml: string, tag: string): string {
  const re = new RegExp(`<${tag}[^>]*>(?:<!\\[CDATA\\[)?([\\s\\S]*?)(?:\\]\\]>)?<\\/${tag}>`, "i");
  const m = re.exec(xml);
  return m ? m[1].trim() : "";
}

/** Parsing RSS/Atom minimal — nessuna dipendenza esterna */
function parseRSSItems(xml: string): { title: string; description: string; link: string; pubDate: string; category: string }[] {
  const items: { title: string; description: string; link: string; pubDate: string; category: string }[] = [];
  // Supporta sia <item> (RSS 2.0) sia <entry> (Atom)
  const tagName = xml.includes("<entry>") ? "entry" : "item";
  const re = new RegExp(`<${tagName}>([\\s\\S]*?)<\\/${tagName}>`, "gi");
  let m;
  while ((m = re.exec(xml)) !== null) {
    const chunk = m[1];
    // Atom usa <id> come link e <summary>/<content> come description
    const link = xmlTag(chunk, "link") || xmlTag(chunk, "id");
    const description = xmlTag(chunk, "description") ||
                        xmlTag(chunk, "summary") ||
                        xmlTag(chunk, "content");
    const pubDate = xmlTag(chunk, "pubDate") ||
                    xmlTag(chunk, "published") ||
                    xmlTag(chunk, "updated");
    items.push({
      title:       xmlTag(chunk, "title"),
      description: description.replace(/<[^>]+>/g, "").substring(0, 1000),
      link:        link.replace(/^<!\[CDATA\[|\]\]>$/g, "").trim(),
      pubDate,
      category:    xmlTag(chunk, "category"),
    });
  }
  return items;
}

// ─────────────────────────────────────────────────────────────
// ADATTATORI PER FONTE
// ─────────────────────────────────────────────────────────────

// deno-lint-ignore no-explicit-any
function normalizzaIncentivi(d: any, fonteName: string): BandoRecord {
  const ateco = d.Codici_ATECO ?? "";
  const low = ateco.toLowerCase();
  const tuttiAteco = !ateco || low.includes("tutti") || low.includes("qualsiasi") || low.includes("indifferente");
  const codiciAteco: string[] = tuttiAteco ? [] : ateco.split(";").map((c: string) => c.trim()).filter((c: string) => c && /^\d/.test(c));
  const regioni: string[] = Array.isArray(d.Regioni) ? d.Regioni : [];

  return {
    id:                   String(d.ID_Incentivo),
    titolo:               (d.Titolo ?? "").trim(),
    descrizione:          (d.Descrizione ?? "").substring(0, 2000),
    data_apertura:        d.Data_apertura  ?? null,
    data_chiusura:        d.Data_chiusura  ?? null,
    stato:                calcolaStato(d.Data_chiusura ?? null),
    codici_ateco:         codiciAteco,
    tutti_ateco:          tuttiAteco,
    regioni,
    tutte_regioni:        regioni.length === 0,
    forma_agevolazione:   Array.isArray(d.Forma_agevolazione)  ? d.Forma_agevolazione  : [],
    dimensioni:           Array.isArray(d.Dimensioni)           ? d.Dimensioni           : [],
    settore_attivita:     Array.isArray(d.Settore_Attivita)    ? d.Settore_Attivita    : [],
    obiettivi:            Array.isArray(d.Obiettivo_Finalita)  ? d.Obiettivo_Finalita  : [],
    soggetto_concedente:  (d.Soggetto_Concedente ?? "").trim(),
    agevolazione_min:     parseFloat(d.Agevolazione_Concedibile_min) || 0,
    agevolazione_max:     parseFloat(d.Agevolazione_Concedibile_max) || 0,
    stanziamento:         parseFloat(d.Stanziamento_incentivo)       || 0,
    link_ufficiale:       (d.Link_istituzionale ?? "").trim(),
    fonte:                fonteName,
    ultimo_aggiornamento: d.Data_ultimo_aggiornamento ?? null,
    data_importazione:    new Date().toISOString(),
  };
}

function normalizzaRSSItem(
  item: { title: string; description: string; link: string; pubDate: string; category: string },
  fonteId: string,
  fonteName: string
): BandoRecord {
  // Tenta parsing data pubblicazione
  let dataApertura: string | null = null;
  if (item.pubDate) {
    try { dataApertura = new Date(item.pubDate).toISOString(); } catch { /* ignore */ }
  }

  return {
    id:                   `${fonteId}_${hashStr(item.link || item.title)}`,
    titolo:               item.title || "(senza titolo)",
    descrizione:          item.description || "",
    data_apertura:        dataApertura,
    data_chiusura:        null,   // RSS raramente include scadenza
    stato:                "attivo",
    codici_ateco:         [],
    tutti_ateco:          true,
    regioni:              [],
    tutte_regioni:        true,
    forma_agevolazione:   [],
    dimensioni:           [],
    settore_attivita:     item.category ? [item.category] : [],
    obiettivi:            [],
    soggetto_concedente:  fonteName,
    agevolazione_min:     0,
    agevolazione_max:     0,
    stanziamento:         0,
    link_ufficiale:       item.link || "",
    fonte:                fonteName,
    ultimo_aggiornamento: null,
    data_importazione:    new Date().toISOString(),
  };
}

// ─────────────────────────────────────────────────────────────
// SYNC DI UNA SINGOLA FONTE
// ─────────────────────────────────────────────────────────────

// deno-lint-ignore no-explicit-any
async function syncFonte(fonte: Fonte, supabase: any): Promise<{ importati: number; totale: number; errore?: string }> {
  const urlEffettivo = fonte.tipo === "json_incentivi"
    ? (Deno.env.get("INCENTIVI_OPEN_DATA_URL") || fonte.url)
    : fonte.url;

  if (!urlEffettivo) {
    return { importati: 0, totale: 0, errore: "URL non configurato" };
  }

  console.log(`[sync-bandi] → ${fonte.nome} (${fonte.tipo}) — ${urlEffettivo}`);

  // 1. Fetch
  let rawText: string;
  try {
    const res = await fetch(urlEffettivo, {
      headers: { "Accept": "application/json, application/rss+xml, application/atom+xml, text/xml, */*" },
      signal: AbortSignal.timeout(60_000),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    rawText = await res.text();
  } catch (e) {
    return { importati: 0, totale: 0, errore: `Fetch fallita: ${(e as Error).message}` };
  }

  // 2. Parse + normalizza
  let records: BandoRecord[] = [];
  try {
    if (fonte.tipo === "json_incentivi") {
      // deno-lint-ignore no-explicit-any
      const parsed: any = JSON.parse(rawText);
      // Supporta array diretto e risposta Solr { response: { docs: [...] } }
      const raw: any[] = Array.isArray(parsed)
        ? parsed
        : (parsed?.response?.docs ?? parsed?.docs ?? []);
      if (!raw.length) {
        return { importati: 0, totale: 0, errore: "Nessun record nella risposta — verifica URL" };
      }
      const oggi = new Date();
      const attivi = raw.filter(d => !d.Data_chiusura || new Date(d.Data_chiusura) >= oggi);
      records = attivi.map(d => normalizzaIncentivi(d, fonte.nome));
    } else if (fonte.tipo === "rss") {
      const items = parseRSSItems(rawText);
      records = items.map(item => normalizzaRSSItem(item, fonte.id, fonte.nome));
    } else {
      return { importati: 0, totale: 0, errore: `Tipo fonte "${fonte.tipo}" non supportato` };
    }
  } catch (e) {
    return { importati: 0, totale: 0, errore: `Parsing fallito: ${(e as Error).message}` };
  }

  const totale = records.length;
  if (totale === 0) return { importati: 0, totale: 0 };

  // 3. Upsert a batch
  const BATCH = 100;
  let importati = 0;
  let erroreUpsert: string | undefined;

  for (let i = 0; i < records.length; i += BATCH) {
    const { error } = await supabase
      .from("bandi_incentivi")
      .upsert(records.slice(i, i + BATCH), { onConflict: "id" });
    if (error) {
      erroreUpsert = error.message;
      console.error(`[sync-bandi] Upsert errore (${fonte.id}):`, error.message);
      break;
    }
    importati += Math.min(BATCH, records.length - i);
  }

  return { importati, totale, errore: erroreUpsert };
}

// ─────────────────────────────────────────────────────────────
// HANDLER PRINCIPALE
// ─────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();

  // Parametro opzionale: ?fonte=invitalia  → sync solo quella fonte
  const url = new URL(req.url);
  const soloFonte = url.searchParams.get("fonte") || null;

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1. Carica fonti attive dalla DB
    let query = supabase.from("bandi_fonti").select("*").eq("attiva", true);
    if (soloFonte) query = query.eq("id", soloFonte);

    const { data: fonti, error: errFonti } = await query;
    if (errFonti) throw new Error(`Caricamento fonti: ${errFonti.message}`);
    if (!fonti || fonti.length === 0) {
      return new Response(
        JSON.stringify({ ok: true, messaggio: "Nessuna fonte attiva configurata.", fonti: [] }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[sync-bandi] Fonti attive: ${fonti.map((f: Fonte) => f.id).join(", ")}`);

    // 2. Sync ogni fonte
    const risultati: Record<string, { importati: number; totale: number; errore?: string }> = {};

    for (const fonte of fonti as Fonte[]) {
      // Marca come "in_corso"
      await supabase.from("bandi_fonti").update({ sync_stato: "in_corso" }).eq("id", fonte.id);

      const ris = await syncFonte(fonte, supabase);
      risultati[fonte.id] = ris;

      const nuovoStato = ris.errore ? "errore" : "ok";

      // Aggiorna status nella tabella fonti
      await supabase.from("bandi_fonti").update({
        sync_stato:     nuovoStato,
        ultimo_sync:    new Date().toISOString(),
        sync_importati: ris.importati,
        sync_errore:    ris.errore || null,
      }).eq("id", fonte.id);

      // Scrivi nel log
      await supabase.from("bandi_sync_log").insert({
        fonte_id:     fonte.id,
        stato:        nuovoStato,
        importati:    ris.importati,
        totale_fonte: ris.totale,
        errore:       ris.errore || null,
        completato_il: new Date().toISOString(),
      });

      console.log(`[sync-bandi] ${fonte.id}: ${ris.importati}/${ris.totale} importati${ris.errore ? " — ERRORE: " + ris.errore : ""}`);
    }

    // 3. Marca come scaduti i bandi non più validi
    await supabase
      .from("bandi_incentivi")
      .update({ stato: "scaduto" })
      .lt("data_chiusura", new Date().toISOString())
      .not("data_chiusura", "is", null);

    const elapsed = Date.now() - startTime;
    const totImportati = Object.values(risultati).reduce((s, r) => s + r.importati, 0);

    return new Response(
      JSON.stringify({
        ok:          true,
        fonti:       risultati,
        importati:   totImportati,
        elapsed_ms:  elapsed,
        timestamp:   new Date().toISOString(),
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("[sync-bandi] Errore critico:", err);
    return new Response(
      JSON.stringify({ ok: false, error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
