// ============================================================
// auth.js — Login, sessione utente, hash password
// ============================================================

const AUTH_KEY = "configuratore_utente";

// Hash SHA-256 della password (browser crypto API)
async function hashPassword(password) {
  const data    = new TextEncoder().encode(password);
  const buffer  = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(buffer))
    .map(b => b.toString(16).padStart(2, "0"))
    .join("");
}

// Legge l'utente dalla sessione (sessionStorage — dura finché il tab è aperto)
function getUtenteSessione() {
  try {
    const raw = sessionStorage.getItem(AUTH_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

// Salva l'utente in sessione
function salvaSessione(utente) {
  sessionStorage.setItem(AUTH_KEY, JSON.stringify({
    id:          utente.id,
    username:    utente.username,
    nome:        utente.nome,
    ruolo:       utente.ruolo,
    avatar:      utente.avatar      || null,
    menu_utente: utente.menu_utente || null,
  }));
}

// Cancella sessione (logout)
function cancellaSessione() {
  sessionStorage.removeItem(AUTH_KEY);
}

// Login: verifica username + password contro tabella utenti Supabase
async function login(username, password) {
  const hash = await hashPassword(password);
  const { data, error } = await _sb
    .from("utenti")
    .select("id, username, nome, ruolo, attivo, avatar, menu_utente")
    .eq("username", username.trim().toLowerCase())
    .eq("password_hash", hash)
    .eq("attivo", true)
    .single();

  if (error || !data) return null;
  salvaSessione(data);
  return data;
}

// Cambio password (aggiorna hash nel DB)
async function cambiaPassword(utenteId, nuovaPassword) {
  const hash = await hashPassword(nuovaPassword);
  const { error } = await _sb
    .from("utenti")
    .update({ password_hash: hash })
    .eq("id", utenteId);
  return !error;
}

// Permessi per ruolo
const PERMESSI = {
  admin: ["dashboard", "catalogo", "preventivi", "nuovo-preventivo", "clienti", "bandi",
          "gestione-prodotti", "categorie", "utenti", "ruoli"],
  commerciale: ["dashboard", "catalogo", "preventivi", "nuovo-preventivo", "clienti", "bandi"],
};

function puoAccedere(ruolo, pagina) {
  return (PERMESSI[ruolo] || []).includes(pagina);
}
