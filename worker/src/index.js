// ============================================================
// Cloudflare Worker: proxy VIES per la verifica P.IVA
// Gratuito, senza carta di credito.
// Endpoint: POST /  { "piva": "00159560366" }
//           GET  /?piva=00159560366
// ============================================================

const VIES_BASE = "https://ec.europa.eu/taxation_customs/vies/rest-api/ms/IT/vat";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

export default {
  async fetch(request) {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });

    let piva = new URL(request.url).searchParams.get("piva") || "";
    if (request.method === "POST") {
      try {
        const body = await request.json();
        piva = body.piva || piva;
      } catch (_) { /* body non JSON: resta il query param */ }
    }

    const p = String(piva).replace(/^IT/i, "").replace(/\D/g, "");
    if (p.length !== 11) {
      return json({ ok: false, error: "Partita IVA italiana non valida: servono 11 cifre" }, 400);
    }

    try {
      const res = await fetch(`${VIES_BASE}/${p}`, {
        headers: { "Accept": "application/json" },
        signal: AbortSignal.timeout(20000),
      });
      if (!res.ok) return json({ ok: false, error: `VIES ha risposto HTTP ${res.status}` }, 502);

      const j = await res.json();
      return json({
        ok: true,
        valido: !!j.isValid,
        piva: p,
        name: j.name && j.name !== "---" ? j.name : "",
        address: j.address && j.address !== "---" ? j.address : "",
        requestDate: j.requestDate || null,
        fonte: "VIES",
      });
    } catch (e) {
      return json({ ok: false, error: "VIES non raggiungibile: " + e.message }, 502);
    }
  },
};
