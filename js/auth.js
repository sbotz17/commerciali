// ============================================================
// auth.js — Autenticazione Firebase (email/password + Google)
//           + profilo utente nella collezione "utenti"
// ============================================================
// Le password sono gestite da Firebase Auth e non sono mai esposte.
// Il profilo (ruolo, menu, permessi) vive in Firestore.
// ============================================================

const AUTH_KEY = "configuratore_utente";

function getUtenteSessione() {
  try {
    const raw = sessionStorage.getItem(AUTH_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch (_) { return null; }
}

function salvaSessione(utente) {
  sessionStorage.setItem(AUTH_KEY, JSON.stringify({
    id:          utente.id,
    username:    utente.username,
    nome:        utente.nome,
    ruolo:       utente.ruolo,
    email:       utente.email       || null,
    avatar:      utente.avatar      || null,
    menu_utente: utente.menu_utente || null,
    super_admin: !!utente.super_admin,
  }));
}

function cancellaSessione() {
  sessionStorage.removeItem(AUTH_KEY);
}

// Mantenuto per compatibilità con vecchi record; non usato dal login.
async function hashPassword(password) {
  const data = new TextEncoder().encode(password);
  const buffer = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(buffer)).map(b => b.toString(16).padStart(2, "0")).join("");
}

// ------------------------------------------------------------
// Profilo utente (collezione "utenti", collegato all'email)
// ------------------------------------------------------------
async function caricaProfilo(email) {
  const em = (email || "").trim().toLowerCase();
  if (!em) return null;
  try {
    const q = await fbDb.collection("utenti").where("email", "==", em).limit(1).get();
    if (q.empty) return null;
    const d = q.docs[0];
    const data = d.data();
    return { id: d.id, ...data, super_admin: !!data.super_admin };
  } catch (e) {
    console.error("caricaProfilo:", e.message);
    return null;
  }
}

function messaggioAuth(e) {
  const code = (e && e.code) || "";
  if (code.includes("wrong-password") || code.includes("invalid-credential")) return "Email o password non validi";
  if (code.includes("user-not-found")) return "Email o password non validi";
  if (code.includes("email-already-in-use")) return "Esiste già un account con questa email";
  if (code.includes("weak-password")) return "La password deve avere almeno 6 caratteri";
  if (code.includes("invalid-email")) return "Email non valida";
  if (code.includes("popup-closed-by-user")) return "Accesso Google annullato";
  if (code.includes("too-many-requests")) return "Troppi tentativi: riprova tra qualche minuto";
  return (e && e.message) || "Errore di autenticazione";
}

function authPronta() {
  return new Promise(resolve => {
    const unsub = fbAuth.onAuthStateChanged(u => { unsub(); resolve(u); });
  });
}

// ------------------------------------------------------------
// Login email + password
// ------------------------------------------------------------
async function login(email, password) {
  const em = (email || "").trim().toLowerCase();
  try {
    await fbAuth.signInWithEmailAndPassword(em, password);
  } catch (e) {
    console.error("login:", e.message);
    return { ok: false, error: messaggioAuth(e) };
  }
  const prof = await caricaProfilo(em);
  if (prof && prof.attivo === false) {
    await fbAuth.signOut();
    return { ok: false, disabilitato: true };
  }
  if (prof) salvaSessione(prof);
  return { ok: true, email: em, profilo: prof || null };
}

// ------------------------------------------------------------
// Login Google
// ------------------------------------------------------------
async function loginConGoogle() {
  try {
    const provider = new firebase.auth.GoogleAuthProvider();
    provider.setCustomParameters({ prompt: "select_account" });
    const cred = await fbAuth.signInWithPopup(provider);
    const em = (cred.user.email || "").trim().toLowerCase();
    const prof = await caricaProfilo(em);
    if (prof && prof.attivo === false) {
      await fbAuth.signOut();
      return { ok: false, disabilitato: true };
    }
    if (prof) salvaSessione(prof);
    return { ok: true, email: em, profilo: prof || null };
  } catch (e) {
    console.error("loginConGoogle:", e.message);
    return { ok: false, error: messaggioAuth(e) };
  }
}

// ------------------------------------------------------------
// Registrazione self-service
// ------------------------------------------------------------
async function registrati(email, password) {
  const em = (email || "").trim().toLowerCase();
  try {
    await fbAuth.createUserWithEmailAndPassword(em, password);
    return { ok: true, email: em, sessione: true };
  } catch (e) {
    console.error("registrati:", e.message);
    return { ok: false, error: messaggioAuth(e) };
  }
}

// ------------------------------------------------------------
// Ripristino sessione all'avvio
// ------------------------------------------------------------
async function ripristinaSessione() {
  const u = await authPronta();
  if (!u || !u.email) { cancellaSessione(); return { authed: false }; }
  const em = u.email;
  const prof = await caricaProfilo(em);
  if (prof && prof.attivo === false) {
    await fbAuth.signOut();
    cancellaSessione();
    return { authed: false };
  }
  if (prof) salvaSessione(prof); else cancellaSessione();
  return { authed: true, email: em, profilo: prof || null };
}

// ------------------------------------------------------------
// Logout
// ------------------------------------------------------------
async function authLogout() {
  try { await fbAuth.signOut(); } catch (_) {}
  cancellaSessione();
}

// ------------------------------------------------------------
// Recupero password
// ------------------------------------------------------------
async function richiediRecuperoPassword(email) {
  const em = (email || "").trim().toLowerCase();
  try {
    await fbAuth.sendPasswordResetEmail(em, {
      url: window.location.origin + window.location.pathname,
    });
  } catch (e) {
    // Non riveliamo se l'email esiste (anti-enumerazione).
    console.error("richiediRecuperoPassword:", e.message);
  }
  return true;
}

// Imposta la nuova password: con oobCode (link email) o da utente autenticato.
async function impostaNuovaPassword(nuovaPassword) {
  try {
    const params = new URLSearchParams(window.location.search);
    const oob = params.get("oobCode");
    if (oob) {
      await fbAuth.verifyPasswordResetCode(oob);
      await fbAuth.confirmPasswordReset(oob, nuovaPassword);
    } else if (fbAuth.currentUser) {
      await fbAuth.currentUser.updatePassword(nuovaPassword);
    } else {
      return false;
    }
    return true;
  } catch (e) {
    console.error("impostaNuovaPassword:", e.message);
    return false;
  }
}

// True se la pagina è stata aperta dal link di recupero Firebase.
function inRecuperoPassword() {
  const params = new URLSearchParams(window.location.search);
  return params.get("mode") === "resetPassword" || !!params.get("oobCode");
}

function onRecuperoPassword(cb) {
  if (inRecuperoPassword()) { try { cb(); } catch (_) {} }
}

// ------------------------------------------------------------
// Crea un account di login SENZA sloggare l'admin (app secondaria)
// ------------------------------------------------------------
async function creaAccountLogin(email, password) {
  const em = (email || "").trim().toLowerCase();
  if (!em || !password) return { ok: false, msg: "Email e password obbligatorie" };
  const nome = "crea-utente-" + Date.now();
  let app2 = null;
  try {
    app2 = firebase.initializeApp(FIREBASE_CONFIG, nome);
    const auth2 = firebase.auth(app2);
    await auth2.createUserWithEmailAndPassword(em, password);
    await auth2.signOut();
    return { ok: true };
  } catch (e) {
    console.error("creaAccountLogin:", e.message);
    return { ok: false, msg: messaggioAuth(e) };
  } finally {
    if (app2) { try { await app2.delete(); } catch (_) {} }
  }
}

// ------------------------------------------------------------
// Permessi legacy (invariati)
// ------------------------------------------------------------
const PERMESSI = {
  admin: ["dashboard", "catalogo", "preventivi", "nuovo-preventivo", "clienti", "bandi",
          "gestione-prodotti", "categorie", "utenti", "ruoli"],
  commerciale: ["dashboard", "catalogo", "preventivi", "nuovo-preventivo", "clienti", "bandi"],
};

function puoAccedere(ruolo, pagina) {
  return (PERMESSI[ruolo] || []).includes(pagina);
}
