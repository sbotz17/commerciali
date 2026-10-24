// ============================================================
// Cloudflare Worker: proxy VIES per la verifica P.IVA
// più proxy autenticato per il server WhatsApp di piattaforma.
//
// VIES:
//   POST /  { "piva": "00159560366" }
//   GET  /?piva=00159560366
//
// WhatsApp (richiede il token Firebase dell'utente):
//   GET  /whatsapp/config   (solo super admin) → { url, apiKey }
//   POST /whatsapp/config   (solo super admin) { url, apiKey }
//   GET  /whatsapp/status   (solo super admin)
//   GET  /whatsapp/qr       (solo super admin)
//   POST /whatsapp/send     { aziendaId, utenteUid, message }
//
// L'API key del server WhatsApp vive nel KV del Worker e non viene mai
// inviata ai client che non siano il super admin.
// ============================================================

const VIES_BASE = "https://ec.europa.eu/taxation_customs/vies/rest-api/ms/IT/vat";
const CONFIG_KEY = "server";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,DELETE,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

async function corpoJson(request) {
  try {
    return await request.json();
  } catch (_) {
    return {};
  }
}

function normalizzaUrl(valore) {
  const url = String(valore || "").trim().replace(/\/+$/, "");
  if (!url) return null;
  try {
    const u = new URL(url);
    if (u.protocol !== "https:" && u.protocol !== "http:") return null;
    return url;
  } catch (_) {
    return null;
  }
}

async function leggiConfig(env) {
  if (!env.WHATSAPP_CONFIG) return null;
  const raw = await env.WHATSAPP_CONFIG.get(CONFIG_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch (_) {
    return null;
  }
}

async function scriviConfig(env, config) {
  if (!env.WHATSAPP_CONFIG) throw new Error("KV WhatsApp non configurato");
  await env.WHATSAPP_CONFIG.put(CONFIG_KEY, JSON.stringify(config));
}

async function utenteFirebase(request, env) {
  const intestazione = request.headers.get("Authorization") || "";
  const token = intestazione.replace(/^Bearer\s+/i, "").trim();
  if (!token || !env.FIREBASE_API_KEY) return null;
  const risposta = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${env.FIREBASE_API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idToken: token }),
      signal: AbortSignal.timeout(10000),
    },
  );
  if (!risposta.ok) return null;
  const dati = await risposta.json();
  const uid = dati?.users?.[0]?.localId;
  return uid ? { uid, token } : null;
}

async function leggiDocumento(env, percorso, token) {
  const risposta = await fetch(
    `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT}/databases/(default)/documents/${percorso}`,
    {
      headers: { Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(10000),
    },
  );
  if (!risposta.ok) return null;
  return risposta.json();
}

async function isSuperAdmin(utente, env) {
  const doc = await leggiDocumento(env, `utenti/${utente.uid}`, utente.token);
  return doc?.fields?.super_admin?.booleanValue === true;
}

function valoreCampo(doc, nome) {
  return doc?.fields?.[nome] || null;
}

async function inoltraAlServer(config, percorso, opzioni = {}) {
  const url = normalizzaUrl(config?.url);
  if (!url) throw new Error("Server WhatsApp non configurato");
  const risposta = await fetch(`${url}${percorso}`, {
    method: opzioni.method || "GET",
    headers: {
      "x-api-key": String(config.apiKey || ""),
      "Content-Type": "application/json",
    },
    body: opzioni.body ? JSON.stringify(opzioni.body) : undefined,
    signal: AbortSignal.timeout(15000),
  });
  const testo = await risposta.text();
  let corpo = {};
  try {
    corpo = testo ? JSON.parse(testo) : {};
  } catch (_) {
    corpo = { raw: testo };
  }
  if (!risposta.ok) {
    throw new Error(corpo?.error || `Server WhatsApp HTTP ${risposta.status}`);
  }
  return corpo;
}

async function gestisciWhatsapp(request, env, url) {
  const utente = await utenteFirebase(request, env);
  if (!utente) return json({ error: "Non autenticato" }, 401);

  const superAdmin = await isSuperAdmin(utente, env);
  const percorso = url.pathname;

  if (percorso === "/whatsapp/config") {
    if (!superAdmin) return json({ error: "Riservato al super admin" }, 403);
    if (request.method === "GET") {
      const config = await leggiConfig(env);
      return json({
        url: config?.url || "",
        apiKey: config?.apiKey || "",
      });
    }
    if (request.method === "POST") {
      const body = await corpoJson(request);
      const indirizzo = normalizzaUrl(body.url);
      if (!indirizzo) return json({ error: "URL del server non valido" }, 400);
      const apiKey = String(body.apiKey || "").trim();
      if (!apiKey) return json({ error: "API key mancante" }, 400);
      await scriviConfig(env, { url: indirizzo, apiKey });
      return json({ ok: true });
    }
    if (request.method === "DELETE") {
      await env.WHATSAPP_CONFIG.delete(CONFIG_KEY);
      return json({ ok: true });
    }
  }

  if (percorso === "/whatsapp/status" && request.method === "GET") {
    if (!superAdmin) return json({ error: "Riservato al super admin" }, 403);
    const config = await leggiConfig(env);
    if (!config) return json({ connected: false, number: null });
    try {
      return json(await inoltraAlServer(config, "/status"));
    } catch (e) {
      return json({ error: String(e.message || e) }, 502);
    }
  }

  if (percorso === "/whatsapp/qr" && request.method === "GET") {
    if (!superAdmin) return json({ error: "Riservato al super admin" }, 403);
    const config = await leggiConfig(env);
    if (!config) return json({ error: "Server WhatsApp non configurato" }, 400);
    try {
      return json(await inoltraAlServer(config, "/qr"));
    } catch (e) {
      return json({ error: String(e.message || e) }, 502);
    }
  }

  if (percorso === "/whatsapp/send" && request.method === "POST") {
    const body = await corpoJson(request);
    const aziendaId = String(body.aziendaId || "").trim();
    const utenteUid = String(body.utenteUid || "").trim();
    const messaggio = String(body.message || "").trim();
    if (!aziendaId || !utenteUid || !messaggio) {
      return json({ error: "aziendaId, utenteUid e message sono obbligatori" }, 400);
    }

    // Il numero non arriva dal client: si legge la rubrica aziendale con il
    // token del chiamante, che può leggere solo i contatti della sua azienda.
    const documento = await leggiDocumento(
      env,
      `contatti_notifiche/${encodeURIComponent(`${aziendaId}_${utenteUid}`)}`,
      utente.token,
    );
    if (!documento) return json({ ok: false, error: "Contatto non trovato" }, 404);
    if (valoreCampo(documento, "consenso_whatsapp")?.booleanValue !== true) {
      return json({ ok: false, error: "Consenso WhatsApp assente" }, 403);
    }
    const numero = valoreCampo(documento, "numero_whatsapp")?.stringValue || "";
    if (!numero) return json({ ok: false, error: "Numero WhatsApp assente" }, 404);

    const config = await leggiConfig(env);
    if (!config) return json({ error: "Server WhatsApp non configurato" }, 400);
    try {
      const esito = await inoltraAlServer(config, "/send", {
        method: "POST",
        body: { to: numero, message: messaggio },
      });
      return json({ ok: true, id: esito?.id || null });
    } catch (e) {
      return json({ ok: false, error: String(e.message || e) }, 502);
    }
  }

  return json({ error: "Endpoint non trovato" }, 404);
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS });
    }

    const url = new URL(request.url);
    if (url.pathname.startsWith("/whatsapp/")) {
      try {
        return await gestisciWhatsapp(request, env, url);
      } catch (e) {
        return json({ error: String(e.message || e) }, 500);
      }
    }

    let piva = url.searchParams.get("piva") || "";
    if (request.method === "POST") {
      const body = await corpoJson(request);
      piva = body.piva || piva;
    }

    const p = String(piva).replace(/^IT/i, "").replace(/\D/g, "");
    if (p.length !== 11) {
      return json(
        { ok: false, error: "Partita IVA italiana non valida: servono 11 cifre" },
        400,
      );
    }

    try {
      const res = await fetch(`${VIES_BASE}/${p}`, {
        headers: { Accept: "application/json" },
        signal: AbortSignal.timeout(20000),
      });
      if (!res.ok) {
        return json({ ok: false, error: `VIES ha risposto HTTP ${res.status}` }, 502);
      }

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
