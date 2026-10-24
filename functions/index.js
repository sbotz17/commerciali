// Invio Web Push quando viene creata una notifica in `notifiche/{id}`.
//
// Le sottoscrizioni stanno in `dispositivi` (endpoint + chiavi p256dh/auth).
// Le chiavi VAPID sono in variabili d'ambiente, mai nel repository.
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const webpush = require("web-push");

admin.initializeApp();

const VAPID_PUBLIC_KEY = process.env.VAPID_PUBLIC_KEY || "";
const VAPID_PRIVATE_KEY = process.env.VAPID_PRIVATE_KEY || "";
const VAPID_SUBJECT =
  process.env.VAPID_SUBJECT || "mailto:bottiandrea83@gmail.com";

if (VAPID_PUBLIC_KEY && VAPID_PRIVATE_KEY) {
  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);
}

/** Percorso dell'app da aprire al tocco della notifica. */
function urlNotifica(notifica) {
  switch (notifica.target_tipo) {
    case "chat":
      return "/chat";
    case "task":
      return "/task";
    case "appuntamento":
    case "calendario":
      return "/calendario";
    default:
      return "/notifiche";
  }
}

/** Payload generico quando l'utente ha disattivato l'anteprima. */
function payloadNotifica(notifica, anteprima) {
  if (anteprima === false) {
    return {
      title: "Closer",
      body: "Hai una nuova notifica.",
      url: urlNotifica(notifica),
      tag: notifica.idempotenza_key || "closer",
    };
  }
  return {
    title: notifica.titolo || "Closer",
    body: notifica.testo || "Hai una nuova notifica.",
    url: urlNotifica(notifica),
    tag: notifica.idempotenza_key || "closer",
  };
}

exports.inviaPushNotifica = onDocumentCreated(
  {
    document: "notifiche/{id}",
    region: "europe-west1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const notifica = snap.data() || {};
    if (notifica.stato && notifica.stato !== "programmata") return;
    if (!VAPID_PUBLIC_KEY || !VAPID_PRIVATE_KEY) {
      console.error("VAPID non configurate: push non inviata");
      return;
    }

    const db = admin.firestore();
    const uid = notifica.utente_uid;
    if (!uid) return;

    // Preferenze: push disattivato oppure anteprima disattivata.
    let anteprima = true;
    if (notifica.azienda_id) {
      const pref = await db
        .collection("impostazioni_notifiche")
        .doc(`${notifica.azienda_id}_${uid}`)
        .get();
      const dati = pref.exists ? pref.data() : {};
      if (dati.canale_push === false) return;
      anteprima = dati.anteprima_push !== false;
    }

    const dispositivi = await db
      .collection("dispositivi")
      .where("utente_uid", "==", uid)
      .where("attivo", "==", true)
      .get();

    if (dispositivi.empty) return;

    const payload = JSON.stringify(payloadNotifica(notifica, anteprima));
    let inviati = 0;
    let errori = 0;

    await Promise.all(
      dispositivi.docs.map(async (doc) => {
        const d = doc.data();
        if (!d.endpoint || !d.p256dh || !d.auth) return;
        try {
          await webpush.sendNotification(
            {
              endpoint: d.endpoint,
              keys: { p256dh: d.p256dh, auth: d.auth },
            },
            payload,
            { TTL: 3600 }
          );
          inviati += 1;
          await doc.ref.set(
            { ultimo_uso_at: admin.firestore.FieldValue.serverTimestamp() },
            { merge: true }
          );
        } catch (errore) {
          errori += 1;
          const codice = errore && errore.statusCode;
          if (codice === 404 || codice === 410) {
            await doc.ref.set({ attivo: false }, { merge: true });
          } else {
            console.error("Push fallita", doc.id, codice, errore.message);
          }
        }
      })
    );

    await snap.ref.set(
      {
        stato: inviati > 0 ? "inviata" : "fallita",
        inviata_at: inviati > 0 ? admin.firestore.FieldValue.serverTimestamp() : null,
        tentativi: admin.firestore.FieldValue.increment(1),
        errore: inviati > 0 ? null : `push: ${errori} errori`,
      },
      { merge: true }
    );
  }
);
