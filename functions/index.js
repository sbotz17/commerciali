// ============================================================
// Cloud Function: vies
// Proxy verso l'API VIES della Commissione europea.
// Serve perché il browser non può chiamare VIES direttamente
// (CORS) e perché così la risposta viene normalizzata.
// ============================================================

const { onRequest } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");

setGlobalOptions({ region: "europe-west8", maxInstances: 10 });

const VIES_BASE = "https://ec.europa.eu/taxation_customs/vies/rest-api/ms/IT/vat";

exports.vies = onRequest({ cors: true, timeoutSeconds: 25 }, async (req, res) => {
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  const raw = (req.body && req.body.piva) || req.query.piva || "";
  const piva = String(raw).replace(/^IT/i, "").replace(/\D/g, "");

  if (piva.length !== 11) {
    res.status(400).json({ ok: false, error: "Partita IVA italiana non valida: servono 11 cifre" });
    return;
  }

  try {
    const r = await fetch(`${VIES_BASE}/${piva}`, {
      headers: { "Accept": "application/json" },
      signal: AbortSignal.timeout(20000),
    });

    if (!r.ok) {
      res.status(502).json({ ok: false, error: `VIES ha risposto HTTP ${r.status}` });
      return;
    }

    const j = await r.json();
    const name = j.name && j.name !== "---" ? j.name : "";
    const address = j.address && j.address !== "---" ? j.address : "";

    res.json({
      ok: true,
      valido: !!j.isValid,
      piva,
      name,
      address,
      requestDate: j.requestDate || null,
      fonte: "VIES",
    });
  } catch (e) {
    res.status(502).json({ ok: false, error: "VIES non raggiungibile: " + e.message });
  }
});
