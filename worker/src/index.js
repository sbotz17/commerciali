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

import {
  canaliCliente,
  componiPromemoriaCliente,
  emailValida,
  normalizzaNumeroWhatsapp,
} from "./promemoria.mjs";
import {
  inviaWhatsapp,
  normalizzaStatoServerWhatsapp,
} from "./whatsapp.mjs";

const VIES_BASE = "https://ec.europa.eu/taxation_customs/vies/rest-api/ms/IT/vat";
const CONFIG_KEY = "server";
const EMAIL_KEY = "server";
const EMAIL_DEFAULT_URL = "https://api.resend.com/emails";
const FIRESTORE_BASE = "https://firestore.googleapis.com/v1/projects";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,DELETE,OPTIONS",
  "Access-Control-Allow-Headers":
    "Content-Type, Authorization, x-azienda-id, x-elemento-id, x-elemento-tipo, x-nome, x-mime",
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
  // Prima il KV (modificabile dal super admin); se il KV è vuoto usa i valori
  // di ambiente, così la configurazione resta disponibile anche dopo un reset
  // o una rotazione del namespace.
  if (env.WHATSAPP_CONFIG) {
    const raw = await env.WHATSAPP_CONFIG.get(CONFIG_KEY);
    if (raw) {
      try {
        return JSON.parse(raw);
      } catch (_) {
        // passa al fallback
      }
    }
  }
  if (env.WHATSAPP_URL && env.WHATSAPP_API_KEY) {
    return { url: env.WHATSAPP_URL, apiKey: env.WHATSAPP_API_KEY };
  }
  return null;
}

async function scriviConfig(env, config) {
  if (!env.WHATSAPP_CONFIG) throw new Error("KV WhatsApp non configurato");
  await env.WHATSAPP_CONFIG.put(CONFIG_KEY, JSON.stringify(config));
}

async function leggiConfigEmail(env) {
  if (env.EMAIL_CONFIG) {
    const raw = await env.EMAIL_CONFIG.get(EMAIL_KEY);
    if (raw) {
      try {
        return JSON.parse(raw);
      } catch (_) {
        // passa al fallback
      }
    }
  }
  if (env.EMAIL_API_KEY && env.EMAIL_FROM) {
    return {
      apiKey: env.EMAIL_API_KEY,
      from: env.EMAIL_FROM,
      nome: env.EMAIL_FROM_NAME || "",
    };
  }
  return null;
}

async function scriviConfigEmail(env, config) {
  if (!env.EMAIL_CONFIG) throw new Error("KV email non configurato");
  await env.EMAIL_CONFIG.put(EMAIL_KEY, JSON.stringify(config));
}

function mittenteEmail(config) {
  const email = String(config?.from || "").trim();
  const nome = String(config?.nome || "").trim();
  return nome ? `${nome} <${email}>` : email;
}

async function inviaEmail(config, { to, subject, text }) {
  if (!config) throw new Error("Email non configurata");
  const destinatario = String(to || "").trim();
  if (!emailValida(destinatario)) throw new Error("Email destinatario non valida");
  const url = normalizzaUrl(config.url) || EMAIL_DEFAULT_URL;
  const risposta = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${String(config.apiKey || "")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: mittenteEmail(config),
      to: [destinatario],
      subject,
      text,
    }),
    signal: AbortSignal.timeout(20000),
  });
  const testo = await risposta.text();
  let corpo = {};
  try {
    corpo = testo ? JSON.parse(testo) : {};
  } catch (_) {
    corpo = { raw: testo };
  }
  if (!risposta.ok) {
    throw new Error(
      corpo?.message || corpo?.error || `Email HTTP ${risposta.status}`,
    );
  }
  return corpo;
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

async function creaDocumento(env, collection, id, fields, token) {
  const risposta = await fetch(
    `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT}/databases/(default)/documents/${collection}?documentId=${encodeURIComponent(id)}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields }),
      signal: AbortSignal.timeout(10000),
    },
  );
  if (!risposta.ok) {
    throw new Error(`Firestore HTTP ${risposta.status}`);
  }
  return risposta.json();
}

async function eliminaDocumento(env, percorso, token) {
  const risposta = await fetch(
    `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT}/databases/(default)/documents/${percorso}`,
    {
      method: "DELETE",
      headers: { Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(10000),
    },
  );
  return risposta.ok;
}

async function aggiornaDocumento(env, percorso, fields, token) {
  const maschera = Object.keys(fields)
    .map((campo) => `updateMask.fieldPaths=${encodeURIComponent(campo)}`)
    .join("&");
  const risposta = await fetch(
    `${FIRESTORE_BASE}/${env.FIREBASE_PROJECT}/databases/(default)/documents/${percorso}?${maschera}`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields }),
      signal: AbortSignal.timeout(10000),
    },
  );
  return risposta.ok;
}

function stringaCampo(doc, nome) {
  return doc?.fields?.[nome]?.stringValue || "";
}

function booleanoCampo(doc, nome) {
  return doc?.fields?.[nome]?.booleanValue === true;
}

async function sha256Hex(testo) {
  const buffer = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(testo),
  );
  return [...new Uint8Array(buffer)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function isMembro(env, aziendaId, utente) {
  const doc = await leggiDocumento(
    env,
    `membri/${aziendaId}_${utente.uid}`,
    utente.token,
  );
  return !!doc;
}

async function firma(env, testo) {
  const chiave = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(env.ALLEGATI_SECRET || ""),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const firma = await crypto.subtle.sign(
    "HMAC",
    chiave,
    new TextEncoder().encode(testo),
  );
  return [...new Uint8Array(firma)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function stringa(v) {
  return { stringValue: v == null ? "" : String(v) };
}

function intero(v) {
  return { integerValue: String(v) };
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
      const dati = await inoltraAlServer(config, "/status");
      return json(normalizzaStatoServerWhatsapp(dati));
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
    const messaggio = String(body.message || "").trim().slice(0, 1000);
    if (!aziendaId || !utenteUid || !messaggio) {
      return json({ error: "aziendaId, utenteUid e message sono obbligatori" }, 400);
    }
    if (!(await isMembro(env, aziendaId, utente))) {
      return json({ error: "Non appartieni all'azienda" }, 403);
    }
    if (env.PROMEMORIA) {
      const chiave = `whatsapp-send:${env.FIREBASE_PROJECT}:${aziendaId}:${utente.uid}:${Math.floor(Date.now() / 60000)}`;
      const usati = Number((await env.PROMEMORIA.get(chiave)) || 0);
      if (usati >= 10) {
        return json({ error: "Troppi messaggi in un minuto. Riprova." }, 429);
      }
      await env.PROMEMORIA.put(chiave, String(usati + 1), {
        expirationTtl: 120,
      });
    }

    // Il numero non arriva dal client: si legge la rubrica aziendale con il
    // token del chiamante, che può leggere solo i contatti della sua azienda.
    const documento = await leggiDocumento(
      env,
      `contatti_notifiche/${encodeURIComponent(`${aziendaId}_${utenteUid}`)}`,
      utente.token,
    );
    if (!documento) return json({ ok: false, error: "Contatto non trovato" }, 404);
    if (stringaCampo(documento, "azienda_id") !== aziendaId) {
      return json({ error: "Contatto di un'altra azienda" }, 403);
    }
    if (valoreCampo(documento, "consenso_whatsapp")?.booleanValue !== true) {
      return json({ ok: false, error: "Consenso WhatsApp assente" }, 403);
    }
    const numero = valoreCampo(documento, "numero_whatsapp")?.stringValue || "";
    if (!numero) return json({ ok: false, error: "Numero WhatsApp assente" }, 404);

    const config = await leggiConfig(env);
    if (!config) return json({ error: "Server WhatsApp non configurato" }, 400);
    try {
      const esito = await inviaWhatsapp(config, numero, messaggio);
      return json({ ok: true, id: esito?.id || null });
    } catch (e) {
      return json({ ok: false, error: String(e.message || e) }, 502);
    }
  }

  return json({ error: "Endpoint non trovato" }, 404);
}

async function gestisciEmail(request, env, url) {
  const utente = await utenteFirebase(request, env);
  if (!utente) return json({ error: "Non autenticato" }, 401);
  if (!(await isSuperAdmin(utente, env))) {
    return json({ error: "Riservato al super admin" }, 403);
  }

  const percorso = url.pathname;

  if (percorso === "/email/config") {
    if (request.method === "GET") {
      const config = await leggiConfigEmail(env);
      return json({
        url: config?.url || "",
        from: config?.from || "",
        nome: config?.nome || "",
        apiKey: config?.apiKey || "",
      });
    }
    if (request.method === "POST") {
      const body = await corpoJson(request);
      const from = String(body.from || "").trim().toLowerCase();
      const apiKey = String(body.apiKey || "").trim();
      const nome = String(body.nome || "")
        .replace(/[\r\n<>]/g, " ")
        .trim()
        .slice(0, 120);
      if (!emailValida(from)) {
        return json({ error: "Inserisci l'email del mittente" }, 400);
      }
      if (!apiKey) {
        return json({ error: "Inserisci la API key del servizio email" }, 400);
      }
      await scriviConfigEmail(env, { apiKey, from, nome });
      return json({ ok: true });
    }
    if (request.method === "DELETE") {
      if (env.EMAIL_CONFIG) await env.EMAIL_CONFIG.delete(EMAIL_KEY);
      return json({ ok: true });
    }
  }

  if (percorso === "/email/test" && request.method === "POST") {
    const body = await corpoJson(request);
    const to = String(body.to || "").trim();
    if (!emailValida(to)) {
      return json({ error: "Inserisci un'email valida per la prova" }, 400);
    }
    if (env.PROMEMORIA) {
      const chiave = `email-test:${utente.uid}:${Math.floor(Date.now() / 60000)}`;
      const usati = Number((await env.PROMEMORIA.get(chiave)) || 0);
      if (usati >= 3) {
        return json({ error: "Troppe prove in un minuto. Riprova." }, 429);
      }
      await env.PROMEMORIA.put(chiave, String(usati + 1), {
        expirationTtl: 120,
      });
    }
    const config = await leggiConfigEmail(env);
    if (!config) return json({ error: "Email non configurata" }, 400);
    try {
      await inviaEmail(config, {
        to,
        subject: "Prova email Closer",
        text: "Questa è una prova di invio email da Closer.",
      });
      return json({ ok: true });
    } catch (e) {
      return json({ error: String(e.message || e) }, 502);
    }
  }

  return json({ error: "Endpoint non trovato" }, 404);
}

async function gestisciPromemoriaCliente(request, env, url) {
  if (url.pathname !== "/promemoria-cliente") {
    return json({ error: "Endpoint non trovato" }, 404);
  }
  if (request.method !== "POST") {
    return json({ error: "Metodo non ammesso" }, 405);
  }
  const utente = await utenteFirebase(request, env);
  if (!utente) return json({ error: "Non autenticato" }, 401);

  const body = await corpoJson(request);
  const aziendaId = String(body.aziendaId || "").trim();
  const appuntamentoId = String(body.appuntamentoId || "").trim();
  if (!aziendaId || !appuntamentoId) {
    return json({ error: "aziendaId e appuntamentoId sono obbligatori" }, 400);
  }
  if (!(await isMembro(env, aziendaId, utente))) {
    return json({ error: "Non appartieni all'azienda" }, 403);
  }
  if (!env.PROMEMORIA) return json({ error: "KV promemoria assente" }, 500);

  // Limite di frequenza: l'invio costa e non deve diventare un modo per
  // spedire molti messaggi in poco tempo.
  const chiaveLimite = `cliente-rate:${env.FIREBASE_PROJECT}:${aziendaId}:${utente.uid}:${Math.floor(Date.now() / 60000)}`;
  const usati = Number((await env.PROMEMORIA.get(chiaveLimite)) || 0);
  if (usati >= 20) {
    return json({ error: "Troppi invii in un minuto. Riprova tra poco." }, 429);
  }
  await env.PROMEMORIA.put(chiaveLimite, String(usati + 1), {
    expirationTtl: 120,
  });

  const documento = await leggiDocumento(
    env,
    `appuntamenti/${encodeURIComponent(appuntamentoId)}`,
    utente.token,
  );
  if (!documento) return json({ error: "Appuntamento non trovato" }, 404);
  if (stringaCampo(documento, "azienda_id") !== aziendaId) {
    return json({ error: "Appuntamento di un'altra azienda" }, 403);
  }
  if (booleanoCampo(documento, "avvisa_cliente") === false) {
    return json({ ok: true, saltato: "disattivato" });
  }

  // Per gli appuntamenti privati il documento principale è redatto: i
  // recapiti del cliente stanno nella sotto-collezione protetta, leggibile
  // dal creatore e dall'operatore con il token dell'utente.
  let dettagli = documento;
  if (booleanoCampo(documento, "privato")) {
    const privato = await leggiDocumento(
      env,
      `appuntamenti/${encodeURIComponent(appuntamentoId)}/privato/dettagli`,
      utente.token,
    );
    if (privato?.fields) {
      dettagli = { fields: { ...documento.fields, ...privato.fields } };
    }
  }

  const data = stringaCampo(documento, "data");
  if (!data) return json({ ok: true, saltato: "senza_data" });
  if (data < new Date().toISOString().slice(0, 10)) {
    return json({ ok: true, saltato: "passato" });
  }

  const consentiti = canaliCliente(
    documento?.fields?.canali_cliente?.arrayValue?.values?.map(
      (valore) => valore.stringValue,
    ),
  );
  const richiesti = canaliCliente(body.canali);
  const canali = consentiti.length
    ? richiesti.filter((canale) => consentiti.includes(canale))
    : richiesti;
  if (!canali.length) return json({ ok: true, saltato: "nessun_canale" });

  const clienteId = stringaCampo(dettagli, "cliente_id");
  let cliente = null;
  if (clienteId) {
    cliente = await leggiDocumento(
      env,
      `clienti/${encodeURIComponent(clienteId)}`,
      utente.token,
    );
    if (cliente && stringaCampo(cliente, "azienda_id") !== aziendaId) {
      cliente = null;
    }
  }
  const numero = normalizzaNumeroWhatsapp(
    stringaCampo(dettagli, "cliente_telefono") ||
      stringaCampo(cliente, "telefono"),
  );
  const email = (
    stringaCampo(dettagli, "cliente_email") ||
    stringaCampo(cliente, "email")
  ).trim();

  const impronta = await sha256Hex(
    [
      data,
      stringaCampo(documento, "ora"),
      stringaCampo(documento, "data_fine"),
      stringaCampo(documento, "ora_fine"),
      booleanoCampo(documento, "tutto_il_giorno") ? "1" : "0",
    ].join("|"),
  );
  const baseKey = `${env.FIREBASE_PROJECT}:cliente:${appuntamentoId}:${impronta}`;
  const fattoKey = `cliente-fatto:${baseKey}`;
  const lockKey = `cliente-lock:${baseKey}`;

  if (!body.forza && (await env.PROMEMORIA.get(fattoKey))) {
    return json({ ok: true, saltato: "gia_inviato" });
  }
  if (await env.PROMEMORIA.get(lockKey)) {
    return json({ ok: true, saltato: "in_corso" });
  }
  await env.PROMEMORIA.put(lockKey, "1", { expirationTtl: 90 });

  const contenuto = componiPromemoriaCliente({
    titolo: stringaCampo(dettagli, "titolo"),
    privato: booleanoCampo(documento, "privato"),
    data,
    ora: stringaCampo(documento, "ora"),
    dataFine: stringaCampo(documento, "data_fine"),
    oraFine: stringaCampo(documento, "ora_fine"),
    tuttoIlGiorno: booleanoCampo(documento, "tutto_il_giorno"),
    luogo: stringaCampo(dettagli, "luogo"),
    indirizzo: stringaCampo(dettagli, "indirizzo"),
    modifica: body.modifica === true,
  });

  const risultati = {};
  let inviato = false;

  if (canali.includes("whatsapp")) {
    if (!numero) {
      risultati.whatsapp = { stato: "senza_recapito" };
    } else {
      try {
        const config = await leggiConfig(env);
        if (!config) throw new Error("Server WhatsApp non configurato");
        await inviaWhatsapp(config, numero, contenuto.testo);
        risultati.whatsapp = { stato: "inviato" };
        inviato = true;
      } catch (e) {
        risultati.whatsapp = {
          stato: "errore",
          errore: String(e.message || e).slice(0, 300),
        };
      }
    }
  } else {
    risultati.whatsapp = { stato: "non_selezionato" };
  }

  if (canali.includes("email")) {
    if (!emailValida(email)) {
      risultati.email = { stato: "senza_recapito" };
    } else {
      try {
        const config = await leggiConfigEmail(env);
        if (!config) throw new Error("Email non configurata");
        await inviaEmail(config, {
          to: email,
          subject: contenuto.oggetto,
          text: contenuto.testo,
        });
        risultati.email = { stato: "inviato" };
        inviato = true;
      } catch (e) {
        const messaggio = String(e.message || e);
        risultati.email = {
          stato: messaggio.toLowerCase().includes("non configurata")
            ? "non_configurata"
            : "errore",
          errore: messaggio.slice(0, 300),
        };
      }
    }
  } else {
    risultati.email = { stato: "non_selezionato" };
  }

  if (inviato) {
    await env.PROMEMORIA.put(fattoKey, "1", {
      expirationTtl: 30 * 24 * 60 * 60,
    });
  }
  await env.PROMEMORIA.delete(lockKey);

  // Registro sull'appuntamento: solo stati, nessun recapito.
  const canaliLog = {};
  for (const [canale, esito] of Object.entries(risultati)) {
    canaliLog[canale] = {
      mapValue: {
        fields: {
          stato: stringa(esito.stato),
          ...(esito.errore ? { errore: stringa(esito.errore) } : {}),
        },
      },
    };
  }
  await aggiornaDocumento(
    env,
    `appuntamenti/${encodeURIComponent(appuntamentoId)}`,
    {
      promemoria_cliente: {
        mapValue: {
          fields: {
            inviato_at: stringa(new Date().toISOString()),
            impronta: stringa(impronta),
            canali: { mapValue: { fields: canaliLog } },
          },
        },
      },
    },
    utente.token,
  ).catch(() => false);

  return json({ ok: inviato, risultati });
}

async function gestisciPromemoria(request, env, url) {
  const utente = await utenteFirebase(request, env);
  if (!utente) return json({ error: "Non autenticato" }, 401);

  if (url.pathname === "/promemoria/annulla" && request.method === "POST") {
    const body = await corpoJson(request);
    const aziendaId = String(body.aziendaId || "").trim();
    const appuntamentoId = String(body.appuntamentoId || "").trim();
    if (!aziendaId || !appuntamentoId) {
      return json({ error: "Parametri mancanti" }, 400);
    }
    if (!(await isMembro(env, aziendaId, utente))) {
      return json({ error: "Non appartieni all'azienda" }, 403);
    }
    await annullaPromemoria(env, appuntamentoId);
    return json({ ok: true });
  }

  if (url.pathname === "/promemoria" && request.method === "POST") {
    const body = await corpoJson(request);
    const aziendaId = String(body.aziendaId || "").trim();
    const appuntamentoId = String(body.appuntamentoId || "").trim();
    const utenti = Array.isArray(body.utenteUids)
      ? body.utenteUids.map((u) => String(u || "").trim()).filter(Boolean)
      : [];
    const occorrenze = Array.isArray(body.occorrenze) ? body.occorrenze : [];
    if (!aziendaId || !appuntamentoId || !utenti.length || !occorrenze.length) {
      return json({ error: "Parametri mancanti" }, 400);
    }
    if (!(await isMembro(env, aziendaId, utente))) {
      return json({ error: "Non appartieni all'azienda" }, 403);
    }
    if (!env.PROMEMORIA) return json({ error: "KV promemoria assente" }, 500);
    await annullaPromemoria(env, appuntamentoId);

    let creati = 0;
    for (const uid of utenti) {
      const contatto = await leggiDocumento(
        env,
        `contatti_notifiche/${aziendaId}_${uid}`,
        utente.token,
      );
      if (!contatto) continue;
      if (contatto.fields?.consenso_whatsapp?.booleanValue !== true) continue;
      const numero = contatto.fields?.numero_whatsapp?.stringValue || "";
      if (!numero) continue;
      for (const occorrenza of occorrenze.slice(0, 30)) {
        const due = Date.parse(occorrenza.dueAt || "");
        const testo = String(occorrenza.testo || "").trim();
        if (!Number.isFinite(due) || !testo) continue;
        const key = `promemoria:${appuntamentoId}:${crypto.randomUUID()}`;
        await env.PROMEMORIA.put(
          key,
          JSON.stringify({
            due,
            numero,
            testo,
            appuntamentoId,
            utenteUid: uid,
          }),
        );
        creati++;
      }
    }
    return json({ ok: true, creati });
  }

  return json({ error: "Endpoint non trovato" }, 404);
}

async function annullaPromemoria(env, appuntamentoId) {
  if (!env.PROMEMORIA) return;
  const prefisso = `promemoria:${appuntamentoId}:`;
  const elenco = await env.PROMEMORIA.list({ prefix: prefisso });
  await Promise.all(elenco.keys.map((voce) => env.PROMEMORIA.delete(voce.name)));
}

async function inviaPromemoriaScaduti(env) {
  if (!env.PROMEMORIA) return;
  const config = await leggiConfig(env);
  if (!config) return;
  const elenco = await env.PROMEMORIA.list({ prefix: "promemoria:" });
  const adesso = Date.now();
  for (const voce of elenco.keys) {
    const raw = await env.PROMEMORIA.get(voce.name);
    if (!raw) continue;
    let dato;
    try {
      dato = JSON.parse(raw);
    } catch (_) {
      await env.PROMEMORIA.delete(voce.name);
      continue;
    }
    if (Number(dato.due) > adesso) continue;
    try {
      await inviaWhatsapp(config, dato.numero, dato.testo);
      await env.PROMEMORIA.delete(voce.name);
    } catch (_) {
      // Se il server è irraggiungibile riprova; dopo 24h scarta.
      if (adesso - Number(dato.due) > 24 * 60 * 60 * 1000) {
        await env.PROMEMORIA.delete(voce.name);
      }
    }
  }
}

async function gestisciAllegati(request, env, url) {
  const percorso = url.pathname;
  if (percorso === "/allegati/object" && request.method === "GET") {
    const key = url.searchParams.get("key") || "";
    const exp = Number(url.searchParams.get("exp") || 0);
    const sig = url.searchParams.get("sig") || "";
    if (!key || !sig || exp < Math.floor(Date.now() / 1000)) {
      return json({ error: "Link scaduto" }, 403);
    }
    const attesa = await firma(env, `${key}|${exp}`);
    if (attesa !== sig) return json({ error: "Firma non valida" }, 403);
    const oggetto = await env.ALLEGATI.getWithMetadata(key, {
      type: "arrayBuffer",
    });
    if (!oggetto || !oggetto.value) return json({ error: "File non trovato" }, 404);
    const mime = oggetto.metadata?.mime || "application/octet-stream";
    const nome = oggetto.metadata?.nome || "allegato";
    return new Response(oggetto.value, {
      headers: {
        ...CORS,
        "Content-Type": mime,
        "Content-Disposition": `inline; filename="${String(nome).replace(/"/g, "")}"`,
      },
    });
  }

  const utente = await utenteFirebase(request, env);
  if (!utente) return json({ error: "Non autenticato" }, 401);

  if (percorso === "/allegati/upload" && request.method === "POST") {
    const aziendaId = String(request.headers.get("x-azienda-id") || "").trim();
    const elementoId = String(request.headers.get("x-elemento-id") || "").trim();
    const elementoTipo = String(request.headers.get("x-elemento-tipo") || "appuntamento").trim();
    const nome = decodeURIComponent(request.headers.get("x-nome") || "allegato");
    const mime = String(request.headers.get("x-mime") || "application/octet-stream");
    if (!aziendaId || !elementoId) return json({ error: "Parametri mancanti" }, 400);
    if (!(await isMembro(env, aziendaId, utente))) {
      return json({ error: "Non appartieni all'azienda" }, 403);
    }
    const bytes = await request.arrayBuffer();
    if (!bytes.byteLength) return json({ error: "File vuoto" }, 400);
    if (bytes.byteLength > 10 * 1024 * 1024) {
      return json({ error: "File troppo grande (max 10 MB)" }, 413);
    }
    const key = `${aziendaId}/${elementoId}/${crypto.randomUUID()}`;
    await env.ALLEGATI.put(key, bytes, { metadata: { mime, nome } });
    const id = crypto.randomUUID();
    const adesso = new Date().toISOString();
    try {
      await creaDocumento(
        env,
        "allegati",
        id,
        {
          azienda_id: stringa(aziendaId),
          elemento_tipo: stringa(elementoTipo),
          elemento_id: stringa(elementoId),
          nome: stringa(nome),
          tipo_mime: stringa(mime),
          dimensione: intero(bytes.byteLength),
          object_key: stringa(key),
          created_by: stringa(utente.uid),
          created_at: stringa(adesso),
        },
        utente.token,
      );
    } catch (e) {
      await env.ALLEGATI.delete(key);
      return json({ error: String(e.message || e) }, 500);
    }
    return json({
      id,
      aziendaId,
      elementoId,
      elementoTipo,
      nome,
      mime,
      dimensione: bytes.byteLength,
      objectKey: key,
      createdAt: adesso,
    });
  }

  if (percorso === "/allegati/link" && request.method === "POST") {
    const body = await corpoJson(request);
    const aziendaId = String(body.aziendaId || "").trim();
    const key = String(body.key || "").trim();
    if (!aziendaId || !key) return json({ error: "Parametri mancanti" }, 400);
    if (!(await isMembro(env, aziendaId, utente))) {
      return json({ error: "Non appartieni all'azienda" }, 403);
    }
    if (!key.startsWith(`${aziendaId}/`)) return json({ error: "Chiave non valida" }, 403);
    const exp = Math.floor(Date.now() / 1000) + 3600;
    const sig = await firma(env, `${key}|${exp}`);
    return json({
      url: `${url.origin}/allegati/object?key=${encodeURIComponent(key)}&exp=${exp}&sig=${sig}`,
    });
  }

  if (percorso === "/allegati" && request.method === "DELETE") {
    const body = await corpoJson(request);
    const aziendaId = String(body.aziendaId || "").trim();
    const id = String(body.id || "").trim();
    const key = String(body.key || "").trim();
    if (!aziendaId || !id || !key) return json({ error: "Parametri mancanti" }, 400);
    if (!(await isMembro(env, aziendaId, utente))) {
      return json({ error: "Non appartieni all'azienda" }, 403);
    }
    if (!key.startsWith(`${aziendaId}/`)) return json({ error: "Chiave non valida" }, 403);
    await env.ALLEGATI.delete(key);
    await eliminaDocumento(env, `allegati/${id}`, utente.token);
    return json({ ok: true });
  }

  return json({ error: "Endpoint non trovato" }, 404);
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS });
    }

    const url = new URL(request.url);
    if (url.pathname === "/promemoria-cliente") {
      try {
        return await gestisciPromemoriaCliente(request, env, url);
      } catch (e) {
        return json({ error: String(e.message || e) }, 500);
      }
    }

    if (url.pathname.startsWith("/email/")) {
      try {
        return await gestisciEmail(request, env, url);
      } catch (e) {
        return json({ error: String(e.message || e) }, 500);
      }
    }

    if (url.pathname === "/promemoria" || url.pathname === "/promemoria/annulla") {
      try {
        return await gestisciPromemoria(request, env, url);
      } catch (e) {
        return json({ error: String(e.message || e) }, 500);
      }
    }

    if (url.pathname.startsWith("/allegati/") || url.pathname === "/allegati") {
      try {
        return await gestisciAllegati(request, env, url);
      } catch (e) {
        return json({ error: String(e.message || e) }, 500);
      }
    }

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

  async scheduled(event, env, ctx) {
    ctx.waitUntil(inviaPromemoriaScaduti(env));
  },
};
