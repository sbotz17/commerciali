// Funzioni pure per gli avvisi programmati all'operatore.
//
// Stanno fuori da `index.js` per poterle provare con Node senza avviare il
// Worker né Cloudflare. Le chiavi includono il progetto Firebase perché
// staging e produzione condividono lo stesso spazio KV.

/** Prefisso comune a tutti gli avvisi nella coda KV. */
export const PREFISSO_AVVISO = "avviso:";

/** Quanti giorni nel futuro un avviso può essere registrato. */
export const GIORNI_MASSIMI_AVVISO = 120;

/** Chiave di un singolo avviso nella coda. */
export function avvisoCoda(progetto, aziendaId, chiave) {
  return `${PREFISSO_AVVISO}${progetto}:${aziendaId}:${chiave}`;
}

/** Prefisso per annullare tutti gli avvisi di un elemento. */
export function avvisoPrefisso(progetto, aziendaId, tipo, targetId) {
  return `${PREFISSO_AVVISO}${progetto}:${aziendaId}:${tipo}:${targetId}:`;
}

/**
 * Valida una voce ricevuta dal client.
 *
 * Ritorna i campi normalizzati oppure `null` se la voce non è utilizzabile.
 * Non legge Firestore: consenso e numero si controllano in `index.js`.
 */
export function validaAvviso(voce, adesso = Date.now()) {
  if (!voce || typeof voce !== "object") return null;
  const chiave = String(voce.chiave || "").trim();
  const uid = String(voce.utenteUid || "").trim();
  const due = Date.parse(voce.dueAt || "");
  const testo = String(voce.testo || "").trim().slice(0, 500);
  const titolo = String(voce.titolo || "").trim().slice(0, 120);
  const tipo = String(voce.tipo || "").trim();
  const targetId = String(voce.targetId || "").trim();
  if (!/^[A-Za-z0-9_:.-]{1,180}$/.test(chiave)) return null;
  if (!uid || !/^[A-Za-z0-9]{1,128}$/.test(uid)) return null;
  if (!Number.isFinite(due) || !testo) return null;
  if (!/^[a-z]{1,20}$/.test(tipo)) return null;
  if (due > adesso + GIORNI_MASSIMI_AVVISO * 24 * 60 * 60 * 1000) {
    return null;
  }
  return { chiave, uid, due, testo, titolo, tipo, targetId };
}
