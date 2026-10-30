// Invio messaggi al server WhatsApp, con supporto a due contratti:
// - VOLTY: POST /invia { numero, testo }
// - vecchio server: POST /send { to, message }
// Le funzioni sono separate da index.js per poterle provare con fetch finto.

export function normalizzaStatoServerWhatsapp(dati) {
  return {
    connected: dati?.connected === true || dati?.connesso === true,
    number: dati?.number || dati?.numero || null,
    state: dati?.stato || dati?.state || null,
  };
}

export async function inviaWhatsapp(
  config,
  numero,
  testo,
  fetchImpl = fetch,
) {
  const url = String(config?.url || "").trim().replace(/\/+$/, "");
  if (!url) throw new Error("Server WhatsApp non configurato");
  const intestazioni = {
    "x-api-key": String(config.apiKey || ""),
    "Content-Type": "application/json",
  };

  async function invia(percorso, corpo) {
    const risposta = await fetchImpl(`${url}${percorso}`, {
      method: "POST",
      headers: intestazioni,
      body: JSON.stringify(corpo),
      signal: AbortSignal.timeout(20000),
    });
    const raw = await risposta.text();
    let dati = {};
    try {
      dati = raw ? JSON.parse(raw) : {};
    } catch (_) {
      dati = { raw };
    }
    return { risposta, dati };
  }

  let esito = await invia("/invia", { numero, testo });
  if (esito.risposta.status === 404) {
    esito = await invia("/send", { to: numero, message: testo });
  }
  if (!esito.risposta.ok) {
    throw new Error(
      esito.dati?.errore ||
        esito.dati?.error ||
        `WhatsApp HTTP ${esito.risposta.status}`,
    );
  }
  return { ...esito.dati, id: esito.dati?.id || esito.dati?.messageId || null };
}
