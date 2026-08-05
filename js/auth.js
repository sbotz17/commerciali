// ============================================================
// auth.js — Autenticazione tramite Supabase Auth (email + password)
//           + profilo utente (ruolo, menu, permessi) dalla tabella "utenti"
// ============================================================
// Il login NON usa più l'hash SHA-256 in tabella: le password sono
// gestite in modo sicuro (bcrypt + salt) da Supabase Auth e non sono
// mai esposte. La tabella "utenti" conserva solo il profilo, collegato
// all'account di login tramite l'email.
// ============================================================

const AUTH_KEY = "configuratore_utente";

// ------------------------------------------------------------
// Cache locale del profilo (per un rendering immediato)
// ------------------------------------------------------------
function getUtenteSessione() {
  try {
    const raw = sessionStorage.getItem(AUTH_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
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
  }));
}

function cancellaSessione() {
  sessionStorage.removeItem(AUTH_KEY);
}

// Hash SHA-256 — mantenuto solo per compatibilità con vecchi record.
// NON è più usato per il login (lo gestisce Supabase Auth).
async function hashPassword(password) {
  const data   = new TextEncoder().encode(password);
  const buffer = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(buffer))
    .map(b => b.toString(16).padStart(2, "0"))
    .join("");
}

// ------------------------------------------------------------
// Profilo utente (ruolo, menu, ecc.) letto dalla tabella "utenti"
// in base all'email dell'account autenticato.
// ------------------------------------------------------------
async function caricaProfilo(email) {
  const em = (email || "").trim().toLowerCase();
  if (!em) return null;
  const { data, error } = await _sb
    .from("utenti")
    .select("id, username, nome, ruolo, attivo, avatar, menu_utente, email")
    .eq("email", em)
    .maybeSingle();
  if (error) { console.error("caricaProfilo:", error.message); return null; }
  return data;
}

// ------------------------------------------------------------
// Login con email + password (Supabase Auth)
// ------------------------------------------------------------
async function login(email, password) {
  const em = (email || "").trim().toLowerCase();
  const { data, error } = await _sb.auth.signInWithPassword({ email: em, password });
  if (error || !data?.session) return { ok: false };

  const prof = await caricaProfilo(em);
  if (prof && prof.attivo === false) {
    // Profilo disabilitato → nega
    await _sb.auth.signOut();
    return { ok: false, disabilitato: true };
  }
  if (prof) salvaSessione(prof);
  // Se non c'è profilo/azienda, l'utente andrà all'onboarding (gestito dallo store)
  return { ok: true, email: em, profilo: prof || null };
}

// Registrazione self-service: crea l'account di autenticazione
async function registrati(email, password) {
  const em = (email || "").trim().toLowerCase();
  const { data, error } = await _sb.auth.signUp({ email: em, password });
  if (error) { console.error("registrati:", error.message); return { ok: false, error: error.message }; }
  return { ok: true, email: em, sessione: !!data?.session };
}

// ------------------------------------------------------------
// Ripristino sessione all'avvio (se già autenticato in precedenza)
// ------------------------------------------------------------
async function ripristinaSessione() {
  const { data } = await _sb.auth.getSession();
  const session = data?.session;
  if (!session?.user?.email) { cancellaSessione(); return { authed: false }; }

  const em = session.user.email;
  const prof = await caricaProfilo(em);
  if (prof && prof.attivo === false) {
    await _sb.auth.signOut();
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
  try { await _sb.auth.signOut(); } catch (_) {}
  cancellaSessione();
}

// ------------------------------------------------------------
// Recupero password: invia l'email con il link per reimpostarla
// ------------------------------------------------------------
async function richiediRecuperoPassword(email) {
  const em = (email || "").trim().toLowerCase();
  const redirectTo = window.location.origin + window.location.pathname;
  const { error } = await _sb.auth.resetPasswordForEmail(em, { redirectTo });
  if (error) console.error("richiediRecuperoPassword:", error.message);
  // Ritorna comunque true: non riveliamo se l'email è registrata (anti-enumerazione).
  return true;
}

// ------------------------------------------------------------
// Imposta una nuova password per l'utente attualmente autenticato.
// Usato sia dopo il link di recupero, sia dal cambio password.
// ------------------------------------------------------------
async function impostaNuovaPassword(nuovaPassword) {
  const { error } = await _sb.auth.updateUser({ password: nuovaPassword });
  if (error) { console.error("impostaNuovaPassword:", error.message); return false; }
  return true;
}

// True se la pagina è stata aperta dal link di recupero password.
// Usa il flag catturato in modo sincrono all'avvio (vedi supabase.js),
// perché la libreria Supabase ripulisce l'hash dall'URL subito dopo l'init.
function inRecuperoPassword() {
  return (typeof _RECOVERY_FLAG !== "undefined" && _RECOVERY_FLAG)
    || (window.location.hash || "").includes("type=recovery");
}

// ------------------------------------------------------------
// Crea un account di login (Supabase Auth) SENZA sloggare l'admin,
// usando un client secondario. Best-effort: se i signup sono
// disabilitati o serve conferma email, ritorna il messaggio.
// ------------------------------------------------------------
async function creaAccountLogin(email, password) {
  const em = (email || "").trim().toLowerCase();
  if (!em || !password) return { ok: false, msg: "Email e password obbligatorie" };
  try {
    const tmp = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    });
    const { error } = await tmp.auth.signUp({ email: em, password });
    if (error) { console.error("creaAccountLogin:", error.message); return { ok: false, msg: error.message }; }
    return { ok: true };
  } catch (e) {
    console.error("creaAccountLogin:", e);
    return { ok: false, msg: String(e) };
  }
}

// ------------------------------------------------------------
// Permessi per ruolo (fallback legacy usato in altre parti) — invariato
// ------------------------------------------------------------
const PERMESSI = {
  admin: ["dashboard", "catalogo", "preventivi", "nuovo-preventivo", "clienti", "bandi",
          "gestione-prodotti", "categorie", "utenti", "ruoli"],
  commerciale: ["dashboard", "catalogo", "preventivi", "nuovo-preventivo", "clienti", "bandi"],
};

function puoAccedere(ruolo, pagina) {
  return (PERMESSI[ruolo] || []).includes(pagina);
}
