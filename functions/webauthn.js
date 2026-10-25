// Accesso con Face ID / Touch ID (passkey WebAuthn) per Closer.
//
// La chiave privata resta sul dispositivo; qui si conserva solo la chiave
// pubblica. Il flusso:
//   1. il client chiede le opzioni (sfida) a una Cloud Function;
//   2. il sistema mostra Face ID e firma la sfida;
//   3. la funzione verifica la firma e, per l'accesso, restituisce un custom
//      token Firebase che apre la sessione.
//
// Collezioni (solo Admin SDK, negate nelle regole Firestore):
//   _passkey_sfide/{id}        sfide monouso, scadenza 5 minuti
//   _passkey_credenziali/{id}  chiave pubblica e contatore per dispositivo
//   _passkey_limiti/{id}       limite tentativi per IP
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse,
} = require("@simplewebauthn/server");

const REGIONE = "europe-west1";
const SFIDE = "_passkey_sfide";
const CREDENZIALI = "_passkey_credenziali";
const LIMITI = "_passkey_limiti";
const DURATA_SFIDA_MS = 5 * 60 * 1000;
const FINESTRA_LIMITE_MS = 10 * 60 * 1000;
const MAX_TENTATIVI = 40;

const PROGETTO =
  process.env.GCLOUD_PROJECT ||
  (() => {
    try {
      return JSON.parse(process.env.FIREBASE_CONFIG || "{}").projectId || "";
    } catch (_) {
      return "";
    }
  })();

// Un solo indirizzo ufficiale per ambiente: la passkey è legata al dominio.
const AMBIENTI = {
  "commerciali-app": {
    rpId: "commerciali-app.web.app",
    origine: "https://commerciali-app.web.app",
  },
  "commerciali-prod": {
    rpId: "commerciali-prod.web.app",
    origine: "https://commerciali-prod.web.app",
  },
};
const AMBIENTE = AMBIENTI[PROGETTO] || AMBIENTI["commerciali-app"];
const RP_ID = AMBIENTE.rpId;
const ORIGINI = [AMBIENTE.origine];
if (process.env.FUNCTIONS_EMULATOR === "true") {
  ORIGINI.push("http://localhost:5000", "http://127.0.0.1:5000");
}

const db = () => admin.firestore();

function b64(buffer) {
  return Buffer.from(buffer).toString("base64url");
}

function daB64(testo) {
  return new Uint8Array(Buffer.from(testo, "base64url"));
}

function verificaOrigine(request) {
  if (process.env.FUNCTIONS_EMULATOR === "true") return;
  const origine = request.rawRequest && request.rawRequest.headers
    ? request.rawRequest.headers.origin
    : undefined;
  if (origine && !ORIGINI.includes(origine)) {
    throw new HttpsError("permission-denied", "Origine non ammessa.");
  }
}

function ipRichiesta(request) {
  const raw = request.rawRequest || {};
  const avanti = raw.headers && raw.headers["x-forwarded-for"];
  const ip = (Array.isArray(avanti) ? avanti[0] : avanti || "").split(",")[0].trim();
  return ip || raw.ip || "sconosciuto";
}

/** Limite semplice per IP, in Firestore: evita tentativi a raffica. */
async function limita(request, azione) {
  const ip = ipRichiesta(request).replace(/[^a-zA-Z0-9:._-]/g, "_");
  const ref = db().collection(LIMITI).doc(`${azione}_${ip}`);
  const ora = Date.now();
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const dati = snap.exists ? snap.data() : { conteggio: 0, creata: ora };
    if (!dati.creata || ora - dati.creata > FINESTRA_LIMITE_MS) {
      tx.set(ref, { conteggio: 1, creata: ora });
      return;
    }
    if (dati.conteggio >= MAX_TENTATIVI) {
      throw new HttpsError(
        "resource-exhausted",
        "Troppi tentativi con Face ID: attendi qualche minuto e riprova."
      );
    }
    tx.set(ref, { conteggio: dati.conteggio + 1, creata: dati.creata });
  });
}

async function salvaSfida(tipo, challenge, uid) {
  const ref = db().collection(SFIDE).doc();
  await ref.set({
    tipo,
    challenge,
    uid: uid || null,
    creata: Date.now(),
    scade: Date.now() + DURATA_SFIDA_MS,
  });
  return ref.id;
}

/** Ritorna la sfida e la consuma subito (monouso). */
async function prendiSfida(id, tipo) {
  if (!id || typeof id !== "string") {
    throw new HttpsError("invalid-argument", "Richiesta non valida.");
  }
  const ref = db().collection(SFIDE).doc(id);
  return db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Richiesta scaduta o non valida: riprova.");
    }
    const dati = snap.data() || {};
    if (dati.tipo !== tipo || !dati.scade || Date.now() > dati.scade) {
      tx.delete(ref);
      throw new HttpsError("not-found", "Richiesta scaduta: riprova.");
    }
    tx.delete(ref);
    return dati;
  });
}

async function utenteAttivo(uid) {
  const utente = await admin.auth().getUser(uid);
  if (utente.disabled) {
    throw new HttpsError("permission-denied", "Utente disattivato. Contatta l'amministratore.");
  }
  const profilo = await db().collection("utenti").doc(uid).get();
  if (profilo.exists && profilo.data().attivo === false) {
    throw new HttpsError("permission-denied", "Utente disattivato. Contatta l'amministratore.");
  }
  return utente;
}

function nomeDispositivo(request) {
  const agente = (request.rawRequest && request.rawRequest.headers
    ? request.rawRequest.headers["user-agent"]
    : "") || "";
  if (/iPhone/i.test(agente)) return "iPhone";
  if (/iPad/i.test(agente)) return "iPad";
  if (/Android/i.test(agente)) return "Android";
  if (/Macintosh/i.test(agente)) return "Mac";
  if (/Windows/i.test(agente)) return "Windows";
  return "Dispositivo";
}

exports.passkeyRegistrazioneOpzioni = onCall(
  { region: REGIONE, cors: ORIGINI },
  async (request) => {
    verificaOrigine(request);
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Accedi prima di attivare Face ID.");
    }
    await limita(request, "registrazione");
    const utente = await utenteAttivo(uid);
    const esistenti = await db()
      .collection(CREDENZIALI)
      .where("uid", "==", uid)
      .get();

    const opzioni = await generateRegistrationOptions({
      rpName: "Closer",
      rpID: RP_ID,
      userID: Buffer.from(uid),
      userName: utente.email || uid,
      userDisplayName: utente.displayName || utente.email || uid,
      attestationType: "none",
      excludeCredentials: esistenti.docs.map((doc) => ({
        id: doc.id,
        transports: doc.data().trasporti || [],
      })),
      authenticatorSelection: {
        residentKey: "required",
        userVerification: "required",
      },
    });
    const challengeId = await salvaSfida("registrazione", opzioni.challenge, uid);
    return { challengeId, options: opzioni };
  }
);

exports.passkeyRegistrazioneVerifica = onCall(
  { region: REGIONE, cors: ORIGINI },
  async (request) => {
    verificaOrigine(request);
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sessione scaduta: accedi di nuovo.");
    }
    const dati = request.data || {};
    const sfida = await prendiSfida(dati.challengeId, "registrazione");
    if (sfida.uid !== uid) {
      throw new HttpsError("permission-denied", "Richiesta non valida.");
    }
    let verifica;
    try {
      verifica = await verifyRegistrationResponse({
        response: dati.credential,
        expectedChallenge: sfida.challenge,
        expectedOrigin: ORIGINI,
        expectedRPID: RP_ID,
        requireUserVerification: true,
      });
    } catch (errore) {
      console.error("Verifica registrazione passkey fallita", uid, errore.message);
      throw new HttpsError("invalid-argument", "Face ID non verificato. Riprova.");
    }
    if (!verifica.verified || !verifica.registrationInfo) {
      throw new HttpsError("invalid-argument", "Face ID non verificato. Riprova.");
    }
    const credenziale = verifica.registrationInfo.credential;
    await db().collection(CREDENZIALI).doc(credenziale.id).set({
      uid,
      chiavePubblica: b64(credenziale.publicKey),
      contatore: credenziale.counter || 0,
      trasporti: credenziale.transports || [],
      nome: nomeDispositivo(request),
      creato: Date.now(),
      ultimoUso: null,
      rpId: RP_ID,
    });
    return { id: credenziale.id, nome: nomeDispositivo(request) };
  }
);

exports.passkeyAccessoOpzioni = onCall(
  { region: REGIONE, cors: ORIGINI },
  async (request) => {
    verificaOrigine(request);
    await limita(request, "accesso");
    const opzioni = await generateAuthenticationOptions({
      rpID: RP_ID,
      userVerification: "required",
    });
    const challengeId = await salvaSfida("accesso", opzioni.challenge, null);
    return { challengeId, options: opzioni };
  }
);

exports.passkeyAccessoVerifica = onCall(
  { region: REGIONE, cors: ORIGINI },
  async (request) => {
    verificaOrigine(request);
    const dati = request.data || {};
    const challengeId = dati.challengeId;
    const credenziale = dati.credential;
    if (!credenziale || !credenziale.id) {
      throw new HttpsError("invalid-argument", "Risposta di Face ID non valida.");
    }
    const sfida = await prendiSfida(challengeId, "accesso");
    const refCredenziale = db().collection(CREDENZIALI).doc(credenziale.id);
    const snapCredenziale = await refCredenziale.get();
    if (!snapCredenziale.exists) {
      throw new HttpsError("not-found", "Accesso con Face ID non riconosciuto. Usa email e password.");
    }
    const salvata = snapCredenziale.data() || {};
    let verifica;
    try {
      verifica = await verifyAuthenticationResponse({
        response: credenziale,
        expectedChallenge: sfida.challenge,
        expectedOrigin: ORIGINI,
        expectedRPID: RP_ID,
        credential: {
          id: credenziale.id,
          publicKey: daB64(salvata.chiavePubblica),
          counter: salvata.contatore || 0,
          transports: salvata.trasporti || [],
        },
        requireUserVerification: true,
      });
    } catch (errore) {
      console.error("Verifica accesso passkey fallita", errore.message);
      throw new HttpsError("invalid-argument", "Face ID non verificato. Riprova o usa email e password.");
    }
    if (!verifica.verified) {
      throw new HttpsError("invalid-argument", "Face ID non verificato. Riprova o usa email e password.");
    }
    // Il userHandle è l'uid codificato: se presente deve coincidere.
    const handle = credenziale.response && credenziale.response.userHandle;
    if (handle) {
      const uidHandle = Buffer.from(handle, "base64url").toString("utf8");
      if (uidHandle !== salvata.uid) {
        throw new HttpsError("permission-denied", "Accesso con Face ID non valido.");
      }
    }
    await utenteAttivo(salvata.uid);
    await refCredenziale.set(
      {
        contatore: verifica.authenticationInfo.newCounter || 0,
        ultimoUso: Date.now(),
      },
      { merge: true }
    );
    const customToken = await admin.auth().createCustomToken(salvata.uid);
    return { customToken };
  }
);

exports.passkeyElenco = onCall(
  { region: REGIONE, cors: ORIGINI },
  async (request) => {
    verificaOrigine(request);
    const uid = request.auth && request.auth.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sessione scaduta: accedi di nuovo.");
    const credenziali = await db()
      .collection(CREDENZIALI)
      .where("uid", "==", uid)
      .get();
    return {
      passkeys: credenziali.docs.map((doc) => {
        const d = doc.data();
        return {
          id: doc.id,
          nome: d.nome || "Dispositivo",
          creato: d.creato || null,
          ultimoUso: d.ultimoUso || null,
        };
      }),
    };
  }
);

exports.passkeyRimuovi = onCall(
  { region: REGIONE, cors: ORIGINI },
  async (request) => {
    verificaOrigine(request);
    const uid = request.auth && request.auth.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sessione scaduta: accedi di nuovo.");
    const id = request.data && request.data.id;
    if (!id || typeof id !== "string") {
      throw new HttpsError("invalid-argument", "Dispositivo non indicato.");
    }
    const ref = db().collection(CREDENZIALI).doc(id);
    const snap = await ref.get();
    if (!snap.exists || (snap.data() || {}).uid !== uid) {
      throw new HttpsError("permission-denied", "Questo accesso non è tuo.");
    }
    await ref.delete();
    return { ok: true };
  }
);

/** Pulizia giornaliera di sfide e contatori vecchi. */
exports.pulisciPasskey = onSchedule(
  {
    region: REGIONE,
    schedule: "every day 03:00",
    timeZone: "Europe/Rome",
  },
  async () => {
    const taglio = Date.now() - 24 * 60 * 60 * 1000;
    for (const collezione of [SFIDE, LIMITI]) {
      const vecchi = await db()
        .collection(collezione)
        .where("creata", "<", taglio)
        .limit(400)
        .get();
      if (vecchi.empty) continue;
      const lotto = db().batch();
      vecchi.docs.forEach((doc) => lotto.delete(doc.ref));
      await lotto.commit();
    }
  }
);
