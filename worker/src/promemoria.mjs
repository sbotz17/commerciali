// Funzioni pure per i promemoria al cliente.
//
// Stanno fuori da `index.js` per poterle provare con Node senza avviare il
// Worker. Non usano API di Cloudflare né di Node.

/** Formatta una data ISO `YYYY-MM-DD` come `GG/MM/AAAA`. */
export function formattaDataItaliana(iso) {
  const testo = String(iso || "").trim();
  const trovata = /^(\d{4})-(\d{2})-(\d{2})$/.exec(testo);
  if (!trovata) return testo;
  return `${trovata[3]}/${trovata[2]}/${trovata[1]}`;
}

/**
 * Normalizza un numero per il server WhatsApp.
 *
 * - toglie spazi, punti, trattini e parentesi;
 * - `00` iniziale diventa prefisso internazionale senza zeri;
 * - un numero italiano che inizia con `0` (fisso) o ha 10 cifre e inizia con
 *   `3` (cellulare) riceve il prefisso `39`.
 *
 * I numeri esteri vanno inseriti con il prefisso internazionale (es. `+33...`).
 */
export function normalizzaNumeroWhatsapp(numero) {
  let cifre = String(numero || "").replace(/\D/g, "");
  if (!cifre) return "";
  if (cifre.startsWith("00")) cifre = cifre.slice(2);
  if (cifre.startsWith("0")) return `39${cifre}`;
  if (cifre.length === 10 && cifre.startsWith("3")) return `39${cifre}`;
  return cifre;
}

/** Controllo volutamente semplice: il provider fa la validazione finale. */
export function emailValida(email) {
  const testo = String(email || "").trim();
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(testo);
}

/** Canali ammessi per l'avviso al cliente. */
export const CANALI_CLIENTE = ["whatsapp", "email"];

/** Tiene solo i canali noti, senza duplicati, nell'ordine whatsapp/email. */
export function canaliCliente(valori) {
  const scelti = new Set(
    (Array.isArray(valori) ? valori : [])
      .map((valore) => String(valore || "").trim().toLowerCase())
      .filter((valore) => CANALI_CLIENTE.includes(valore)),
  );
  return CANALI_CLIENTE.filter((canale) => scelti.has(canale));
}

/**
 * Testo e oggetto del promemoria al cliente.
 *
 * Per gli appuntamenti privati il titolo non esce mai dall'azienda: il cliente
 * riceve comunque data, ora e luogo.
 */
export function componiPromemoriaCliente(dati = {}) {
  const titolo = String(dati.titolo || "").trim();
  const privato = dati.privato === true;
  const data = formattaDataItaliana(dati.data);
  const dataFine = formattaDataItaliana(dati.dataFine);
  const ora = String(dati.ora || "").trim();
  const oraFine = String(dati.oraFine || "").trim();
  const tuttoIlGiorno = dati.tuttoIlGiorno === true;
  const modifica = dati.modifica === true;

  let quando = dataFine && dataFine !== data ? `dal ${data} al ${dataFine}` : `il ${data}`;
  if (tuttoIlGiorno) {
    quando += " (tutto il giorno)";
  } else if (ora && oraFine && oraFine !== ora) {
    quando += ` dalle ${ora} alle ${oraFine}`;
  } else if (ora) {
    quando += ` alle ${ora}`;
  }

  const luogo = String(dati.luogo || "").trim();
  const indirizzo = String(dati.indirizzo || "").trim();
  const posto = luogo || indirizzo;
  const dove = posto ? ` presso ${posto}` : "";

  const titoloVisibile = privato ? "" : titolo;
  const oggetto = titoloVisibile
    ? `l'appuntamento "${titoloVisibile}"`
    : "il suo appuntamento";
  const oggettoDi = titoloVisibile
    ? `dell'appuntamento "${titoloVisibile}"`
    : "del suo appuntamento";

  const testa = modifica
    ? `Le confermiamo la nuova data ${oggettoDi}: ${quando}${dove}.`
    : `Le confermiamo ${oggetto} ${quando}${dove}.`;

  const testo = [
    "Gentile cliente,",
    testa,
    "",
    "Per eventuali modifiche contatti il suo referente.",
    "",
    "Closer",
  ].join("\n");

  const materia = modifica ? "Appuntamento spostato" : "Appuntamento confermato";
  const oggettoEmail = titoloVisibile ? `${materia} - ${titoloVisibile}` : materia;

  return { testo, oggetto: oggettoEmail };
}
