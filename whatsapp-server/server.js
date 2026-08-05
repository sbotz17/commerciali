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

app.listen(PORT, () => console.log("Server WhatsApp in ascolto sulla porta " + PORT));
