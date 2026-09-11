// ============================================================
// Server WhatsApp — unico per tutta la piattaforma
// ============================================================
// Espone una piccola API HTTP per:
//   GET  /status      -> { connected, number }
//   GET  /qr          -> { qr }  (data URL PNG da scansionare, se non connesso)
//   POST /send        -> invia un messaggio (testo o media) a un numero
//   POST /disconnect  -> scollega il numero
// Tutte le richieste richiedono l'header  x-api-key: <API_KEY>  (se impostata).
//
// Basato su Baileys (WhatsApp Web multi-device). NB: usa un numero WhatsApp
// reale; per volumi elevati/produzione valutare la WhatsApp Business Cloud API
// ufficiale di Meta. Vedi README.md.
// ============================================================

const express = require("express");
const cors = require("cors");
const QRCode = require("qrcode");
const pino = require("pino");
const {
  default: makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion,
  Browsers,
} = require("@whiskeysockets/baileys");

const PORT           = process.env.PORT || 3000;
const API_KEY        = process.env.API_KEY || "";
const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || "*";
const AUTH_DIR       = process.env.AUTH_DIR || "./auth";

let sock = null;
let currentQR = null;   // data URL PNG del QR corrente
let connected = false;
let numero = null;

async function startSock() {
  const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
  const { version } = await fetchLatestBaileysVersion();
  sock = makeWASocket({
    version,
    auth: state,
    printQRInTerminal: false,
    logger: pino({ level: "silent" }),
    browser: Browsers.appropriate("Chrome"),
  });

  sock.ev.on("creds.update", saveCreds);

  sock.ev.on("connection.update", async (u) => {
    const { connection, lastDisconnect, qr } = u;
    if (qr) {
      try { currentQR = await QRCode.toDataURL(qr); } catch (_) { currentQR = null; }
    }
    if (connection === "open") {
      connected = true;
      currentQR = null;
      numero = (sock.user?.id || "").split(":")[0].split("@")[0] || null;
      console.log("WhatsApp connesso:", numero);
    }
    if (connection === "close") {
      connected = false;
      const code = lastDisconnect?.error?.output?.statusCode;
      if (code !== DisconnectReason.loggedOut) {
        console.log("Connessione chiusa, riprovo…");
        setTimeout(startSock, 3000);
      } else {
        numero = null;
        console.log("Disconnesso (logout).");
      }
    }
  });
}
startSock().catch((e) => console.error("startSock:", e));

const app = express();
app.use(express.json({ limit: "15mb" }));
app.use(cors({ origin: ALLOWED_ORIGIN }));

// Autenticazione via API key (se impostata)
app.use((req, res, next) => {
  if (!API_KEY) return next();
  const key = req.headers["x-api-key"] || req.query.api_key;
  if (key !== API_KEY) return res.status(401).json({ error: "unauthorized" });
  next();
});

app.get("/status", (req, res) => res.json({ connected, number: numero }));

app.get("/qr", (req, res) => res.json({ qr: connected ? null : currentQR }));

function toJid(to) {
  const s = String(to || "");
  if (s.includes("@")) return s;
  const digits = s.replace(/\D/g, "");
  return `${digits}@s.whatsapp.net`;
}

// POST /send  { to, message, mediaUrl?, filename?, mimetype? }
app.post("/send", async (req, res) => {
  try {
    if (!connected || !sock) return res.status(503).json({ error: "not_connected" });
    const { to, message, mediaUrl, filename, mimetype } = req.body || {};
    if (!to) return res.status(400).json({ error: "missing_to" });

    const jid = toJid(to);
    let content;
    if (mediaUrl) {
      if (/\.(jpe?g|png|webp)$/i.test(mediaUrl)) {
        content = { image: { url: mediaUrl }, caption: message || "" };
      } else {
        content = {
          document: { url: mediaUrl },
          fileName: filename || "documento",
          mimetype: mimetype || "application/pdf",
          caption: message || "",
        };
      }
    } else {
      content = { text: message || "" };
    }

    const r = await sock.sendMessage(jid, content);
    res.json({ ok: true, id: r?.key?.id });
  } catch (e) {
    console.error("send:", e);
    res.status(500).json({ error: String(e?.message || e) });
  }
});

app.post("/disconnect", async (req, res) => {
  try { await sock?.logout(); } catch (_) {}
  connected = false;
  numero = null;
  currentQR = null;
  setTimeout(startSock, 1000);
  res.json({ ok: true });
});

// ============================================================
// PROMEMORIA GIRO VISITE (scheduler)
// ------------------------------------------------------------
// Interroga periodicamente Supabase per le visite con un promemoria
// scaduto e non ancora inviato, manda il messaggio WhatsApp e marca la
// riga come inviata. Richiede la Tappa 13 dello schema e le variabili
// SUPABASE_URL + SUPABASE_SERVICE_KEY (service role: bypassa le RLS).
// Se non sono impostate, lo scheduler resta semplicemente spento.
// ============================================================
const SUPABASE_URL     = process.env.SUPABASE_URL || "";
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || "";
const POLL_MS          = Number(process.env.PROMEMORIA_POLL_MS || 60000);

let sb = null;
let ultimoGiro = { at: null, inviati: 0, errori: 0 };

function messaggioPromemoria(v) {
  const ora = (v.ora || "").slice(0, 5);
  const righe = [
    "🔔 *Promemoria visita*",
    "",
    "👤 " + (v.cliente_nome || "Cliente"),
    ora ? "🕑 Oggi alle " + ora : "",
    v.indirizzo ? "📍 " + v.indirizzo : "",
    v.telefono ? "📞 " + v.telefono : "",
  ];
  return righe.filter(Boolean).join("\n");
}

async function giroPromemoria() {
  if (!sb || !connected || !sock) return;
  try {
    const ora = new Date().toISOString();
    const { data, error } = await sb
      .from("giro_visite")
      .select("id, cliente_nome, telefono, indirizzo, ora, promemoria_numero")
      .not("promemoria_at", "is", null)
      .is("promemoria_inviato_at", null)
      .lte("promemoria_at", ora)
      .in("stato", ["da_fare", "rinviata"])
      .limit(50);
    if (error) { console.error("promemoria/select:", error.message); return; }
    if (!data || !data.length) return;

    let inviati = 0, errori = 0;
    for (const v of data) {
      if (!v.promemoria_numero) {
        // niente destinatario: marca come gestita per non riprovare all'infinito
        await sb.from("giro_visite").update({ promemoria_inviato_at: new Date().toISOString() }).eq("id", v.id);
        continue;
      }
      try {
        await sock.sendMessage(toJid(v.promemoria_numero), { text: messaggioPromemoria(v) });
        await sb.from("giro_visite")
          .update({ promemoria_inviato_at: new Date().toISOString() })
          .eq("id", v.id);
        inviati++;
      } catch (e) {
        errori++;
        console.error("promemoria/send", v.id, e?.message || e);
      }
    }
    ultimoGiro = { at: new Date().toISOString(), inviati, errori };
    if (inviati || errori) console.log(`Promemoria: ${inviati} inviati, ${errori} errori`);
  } catch (e) {
    console.error("promemoria:", e?.message || e);
  }
}

if (SUPABASE_URL && SUPABASE_SERVICE_KEY) {
  const { createClient } = require("@supabase/supabase-js");
  sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, { auth: { persistSession: false } });
  setInterval(giroPromemoria, POLL_MS);
  console.log("Scheduler promemoria attivo (ogni " + Math.round(POLL_MS / 1000) + "s)");
} else {
  console.log("Scheduler promemoria NON attivo: imposta SUPABASE_URL e SUPABASE_SERVICE_KEY");
}

// Diagnostica dello scheduler
app.get("/promemoria/stato", (req, res) => res.json({
  attivo: !!sb, pollMs: POLL_MS, ultimoGiro,
}));

app.listen(PORT, () => console.log("Server WhatsApp in ascolto sulla porta " + PORT));
