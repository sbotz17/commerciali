// ============================================================
// app.js — Store Alpine.js + logica componenti + utilities
// ============================================================

// ==========================================================
// PERMESSI_DEF — definizione centralizzata di tutti i permessi
// ==========================================================
// Voci del menu operativo (sidebar) — usate anche per la personalizzazione per utente
const VOCI_MENU_OP = [
  { pagina: "dashboard",  label: "Dashboard",         emoji: "🏠", permesso: null },
  { pagina: "preventivi", label: "Configura richiesta", emoji: "📋", permesso: "preventivi_propri" },
  { pagina: "clienti",    label: "Clienti",           emoji: "👤", permesso: "clienti" },
  { pagina: "catalogo",   label: "Catalogo prodotti", emoji: "📦", permesso: "listino" },
  { pagina: "bandi",      label: "Bandi & Agevolaz.", emoji: "💰", permesso: "bandi" },
];

const PERMESSI_DEF = [
  { id: "dashboard",          label: "Dashboard",           emoji: "🏠", pagine: ["dashboard"] },
  { id: "listino",            label: "Visualizza listino",  emoji: "📦", pagine: ["catalogo"] },
  { id: "gestione_prodotti",  label: "Gestione prodotti",   emoji: "📝", pagine: ["catalogo"] },
  { id: "preventivi_propri",  label: "Vedi propri prev.",   emoji: "📋", pagine: ["preventivi", "nuovo-preventivo"] },
  { id: "preventivi_tutti",   label: "Vedi tutti i prev.",  emoji: "🔴", pagine: ["preventivi"] },
  { id: "approva_preventivi", label: "Approva preventivi",  emoji: "🔐", pagine: [] },
  { id: "clienti",            label: "Gestione clienti",    emoji: "👤", pagine: ["clienti"] },
  { id: "bandi",              label: "Bandi & Agevolaz.",   emoji: "💰", pagine: ["bandi"] },
  { id: "gestione_categorie", label: "Gestione categorie",  emoji: "🏷️",  pagine: ["categorie"] },
  { id: "gestione_utenti",    label: "Gestione utenti",     emoji: "👥", pagine: ["utenti"] },
  { id: "gestione_ruoli",     label: "Gestione ruoli",      emoji: "🔑", pagine: ["ruoli", "importBandi"] },
  { id: "impostazioni",       label: "Impostazioni",         emoji: "⚙️",  pagine: ["impostazioni"] },
];

// Fallback permessi quando la tabella ruoli non è ancora stata creata (schema v3)
const PERMESSI_FALLBACK = {
  admin:       { dashboard:"entrambi", listino:"entrambi", gestione_prodotti:"entrambi", preventivi_propri:"entrambi", preventivi_tutti:"entrambi", approva_preventivi:"entrambi", clienti:"entrambi", bandi:"entrambi", gestione_categorie:"entrambi", gestione_utenti:"entrambi", gestione_ruoli:"entrambi", impostazioni:"entrambi" },
  commerciale: { dashboard:"lettura",  listino:"lettura",  preventivi_propri:"entrambi", clienti:"entrambi", bandi:"lettura" },
};

document.addEventListener("alpine:init", () => {

  // ==========================================================
  // STORE: sessione — utente loggato
  // ==========================================================
  Alpine.store("sessione", {
    utente: null,

    init() {
      this.utente = getUtenteSessione();
    },

    get loggato()    { return !!this.utente; },
    get nomeUtente() { return this.utente?.nome || this.utente?.username || ""; },
    get ruolo()      { return this.utente?.ruolo || ""; },

    // Recupera il ruolo corrente dall'elenco DB
    _mioRuolo() {
      const ruoliDB = Alpine.store("db").ruoli;
      if (ruoliDB && ruoliDB.length) {
        return ruoliDB.find(r => r.chiave === this.utente?.ruolo) || null;
      }
      // Fallback se ruoli DB non ancora caricati
      return { permessi: PERMESSI_FALLBACK[this.utente?.ruolo] || {} };
    },

    // Verifica se l'utente ha un permesso con il livello richiesto
    haPermesso(permId, livelloRichiesto = "lettura") {
      if (!this.utente) return false;
      const mioRuolo = this._mioRuolo();
      if (!mioRuolo) return false;
      const mioLivello = mioRuolo.permessi?.[permId];
      if (!mioLivello) return false;
      // "lettura" → qualsiasi livello va bene
      // "scrittura" → deve essere "scrittura" o "entrambi"
      if (livelloRichiesto === "lettura") return true;
      return mioLivello === "scrittura" || mioLivello === "entrambi";
    },

    // Può accedere a una pagina (almeno lettura)
    puo(pagina) {
      if (!this.loggato) return false;
      if (pagina === "dashboard") return true;
      return PERMESSI_DEF.some(def =>
        def.pagine.includes(pagina) && this.haPermesso(def.id)
      );
    },

    // Shortcut: ha accesso alle sezioni di amministrazione
    get isAdmin() { return this.haPermesso("gestione_ruoli"); },

    async eseguiLogin(username, password) {
      const u = await login(username, password);
      if (u) { this.utente = u; return true; }
      return false;
    },

    logout() {
      cancellaSessione();
      this.utente = null;
      Alpine.store("ui").vai("dashboard");
    },
  });

  // ==========================================================
  // STORE: db — dati dell'app
  // ==========================================================
  Alpine.store("db", {
    prodotti:      [],
    clienti:       [],
    preventivi:    [],
    categorie:     [],
    utenti:        [],
    ruoli:         [],
    impostazioni:  {},
    caricamento:   true,

    // Getter impostazioni — leggono dalla store reattiva (aggiornata al save)
    get logo()        { return this.impostazioni.logo || null; },
    get nomeAzienda() { return this.impostazioni.nome_azienda || "Configuratore"; },

    async init() {
      // Carica impostazioni da localStorage (sincrono, sempre disponibile)
      try {
        const logo = JSON.parse(localStorage.getItem("cfg_logo") || "null");
        const nome = localStorage.getItem("cfg_nome_azienda") || "";
        this.impostazioni = { logo, nome_azienda: nome };
      } catch (_) {}

      if (!Alpine.store("sessione").loggato) {
        this.caricamento = false;
        return;
      }
      try {
        // Carica sempre i ruoli per primo (necessari per i permessi)
        try { this.ruoli = await SP.getRuoli(); } catch (_) { /* schema v3 non ancora eseguito */ }

        const sess = Alpine.store("sessione");
        const fetches = [
          SP.getProdotti(), SP.getClienti(), SP.getPreventivi(), SP.getCategorie(),
        ];
        if (sess.haPermesso("gestione_utenti")) fetches.push(SP.getUtenti());
        else fetches.push(Promise.resolve([]));

        const [prodotti, clienti, preventivi, categorie, utenti] = await Promise.all(fetches);
        this.prodotti   = prodotti;
        this.clienti    = clienti;
        this.preventivi = preventivi;
        this.categorie  = categorie;
        this.utenti     = utenti || [];
      } catch (e) {
        console.error("Errore caricamento dati:", e);
        Alpine.store("ui").mostraToast("Errore connessione al database", "error");
      } finally {
        this.caricamento = false;
      }
    },

    async ricarica() {
      this.caricamento = true;
      await this.init();
    },

    // --- Prodotti ---
    async aggiungiProdotto(dati) {
      const p = await SP.inserisciProdotto(dati);
      if (p) this.prodotti.push(p);
      return p;
    },
    async modificaProdotto(id, dati) {
      const p = await SP.aggiornaProdotto(id, dati);
      if (p) { const i = this.prodotti.findIndex(x => x.id === id); if (i !== -1) this.prodotti[i] = p; }
      return p;
    },
    async eliminaProdotto(id) {
      const ok = await SP.eliminaProdotto(id);
      if (ok) this.prodotti = this.prodotti.filter(p => p.id !== id);
      return ok;
    },

    // --- Clienti ---
    async aggiungiCliente(dati) {
      const c = await SP.inserisciCliente(dati);
      if (c) this.clienti.push(c);
      return c;
    },
    async modificaCliente(id, dati) {
      const c = await SP.aggiornaCliente(id, dati);
      if (c) { const i = this.clienti.findIndex(x => x.id === id); if (i !== -1) this.clienti[i] = c; }
      return c;
    },
    async eliminaCliente(id) {
      const ok = await SP.eliminaCliente(id);
      if (ok) this.clienti = this.clienti.filter(c => c.id !== id);
      return ok;
    },

    // --- Preventivi ---
    async salvaPreventivo(dati) {
      const p = await SP.inserisciPreventivo(dati);
      if (p) this.preventivi.unshift(p);
      return p;
    },
    async aggiornaStato(id, stato) {
      const ok = await SP.aggiornaStato(id, stato);
      if (ok) { const i = this.preventivi.findIndex(p => p.id === id); if (i !== -1) this.preventivi[i].stato = stato; }
      return ok;
    },
    async modificaPreventivo(id, dati) {
      const p = await SP.aggiornaPreventivo(id, dati);
      if (p) { const i = this.preventivi.findIndex(x => x.id === id); if (i !== -1) this.preventivi[i] = p; }
      return p;
    },
    async eliminaPreventivo(id) {
      const ok = await SP.eliminaPreventivo(id);
      if (ok) this.preventivi = this.preventivi.filter(p => p.id !== id);
      return ok;
    },

    // --- Categorie ---
    async aggiungiCategoria(dati) {
      const c = await SP.inserisciCategoria(dati);
      if (c) this.categorie.push(c);
      return c;
    },
    async modificaCategoria(id, dati) {
      const c = await SP.aggiornaCategoria(id, dati);
      if (c) { const i = this.categorie.findIndex(x => x.id === id); if (i !== -1) this.categorie[i] = c; }
      return c;
    },
    async eliminaCategoria(id) {
      const ok = await SP.eliminaCategoria(id);
      if (ok) this.categorie = this.categorie.filter(c => c.id !== id);
      return ok;
    },

    // --- Utenti ---
    async aggiungiUtente(dati, passwordHash) {
      const u = await SP.inserisciUtente(dati, passwordHash);
      if (u) this.utenti.push(u);
      return u;
    },
    async modificaUtente(id, dati) {
      const u = await SP.aggiornaUtente(id, dati);
      if (u) { const i = this.utenti.findIndex(x => x.id === id); if (i !== -1) this.utenti[i] = u; }
      return u;
    },
    async eliminaUtente(id) {
      const ok = await SP.eliminaUtente(id);
      if (ok) this.utenti = this.utenti.filter(u => u.id !== id);
      return ok;
    },

    // --- Ruoli ---
    async aggiungiRuolo(dati) {
      const r = await SP.inserisciRuolo(dati);
      if (r) this.ruoli.push(r);
      return r;
    },
    async modificaRuolo(id, dati) {
      const r = await SP.aggiornaRuolo(id, dati);
      if (r) { const i = this.ruoli.findIndex(x => x.id === id); if (i !== -1) this.ruoli[i] = r; }
      return r;
    },
    async eliminaRuolo(id) {
      const ok = await SP.eliminaRuolo(id);
      if (ok) this.ruoli = this.ruoli.filter(r => r.id !== id);
      return ok;
    },
  });

  // ==========================================================
  // STORE: ui — stato interfaccia
  // ==========================================================
  Alpine.store("ui", {
    pagina:      "dashboard",
    toast:       null,
    _toastTimer: null,

    vai(pagina) {
      const sess = Alpine.store("sessione");
      if (!sess.loggato) { this.pagina = "login"; return; }
      if (!sess.puo(pagina)) { this.mostraToast("Accesso non autorizzato", "error"); return; }
      this.pagina = pagina;
      window.scrollTo(0, 0);
    },

    mostraToast(msg, tipo = "success") {
      if (this._toastTimer) clearTimeout(this._toastTimer);
      this.toast = { msg, tipo };
      this._toastTimer = setTimeout(() => { this.toast = null; }, 3000);
    },
  });

}); // fine alpine:init

// ==========================================================
// SVG ICONS (riutilizzati in più componenti)
// ==========================================================
const _ICONS = {
  home:    '<svg fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"/></svg>',
  doc:     '<svg fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15c1.012 0 1.867.668 2.15 1.586"/></svg>',
  users:   '<svg fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"/></svg>',
  catalog: '<svg fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z"/></svg>',
  money:   '<svg fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>',
  tag:     '<svg fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.648.43 2.583-1.298 4.944-3.263 6.742-5.862.597-.847.373-2.006-.52-2.689L7.527 3.659A2.25 2.25 0 005.936 3z"/><path stroke-linecap="round" stroke-linejoin="round" d="M6 6h.008v.008H6z"/></svg>',
  shield:  '<svg fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"/></svg>',
  upload:   '<svg fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/></svg>',
  settings: '<svg fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z"/><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>',
};

// ==========================================================
// COMPONENTE: appShell
// ==========================================================
function appShell() {
  return {
    sidebarAperta: false,

    get pagina()      { return Alpine.store("ui").pagina; },
    get caricamento() { return Alpine.store("db").caricamento; },
    get loggato()     { return Alpine.store("sessione").loggato; },
    get isAdmin()     { return Alpine.store("sessione").isAdmin; },

    vai(p) {
      Alpine.store("ui").vai(p);
      this.sidebarAperta = false;
    },

    // Verifica permesso per templates
    puoPagina(p)             { return Alpine.store("sessione").puo(p); },
    puoLeggere(permId)       { return Alpine.store("sessione").haPermesso(permId, "lettura"); },
    puoScrivere(permId)      { return Alpine.store("sessione").haPermesso(permId, "scrittura"); },

    // Nav operativo: filtrato per permessi ruolo + eventuale menu personalizzato per utente
    get navOperativo() {
      const s = Alpine.store("sessione");
      const icone = { dashboard: _ICONS.home, preventivi: _ICONS.doc, clienti: _ICONS.users, catalogo: _ICONS.catalog, bandi: _ICONS.money };
      // Partenza: tutte le voci permesse dal ruolo
      const permesse = VOCI_MENU_OP
        .filter(v => !v.permesso || s.haPermesso(v.permesso))
        .map(v => ({ ...v, icon: icone[v.pagina] }));
      // Se l'utente ha un menu personalizzato non vuoto, filtra ulteriormente
      const menuUtente = s.utente?.menu_utente;
      if (Array.isArray(menuUtente) && menuUtente.length > 0) {
        return permesse.filter(v => menuUtente.includes(v.pagina));
      }
      return permesse;
    },

    salvaImpostazione(chiave, valore) {
      // Salvataggio primario in localStorage (immediato, sempre funzionante)
      try {
        if (chiave === "logo") {
          if (valore) localStorage.setItem("cfg_logo", JSON.stringify(valore));
          else localStorage.removeItem("cfg_logo");
        } else {
          if (valore) localStorage.setItem("cfg_" + chiave, valore);
          else localStorage.removeItem("cfg_" + chiave);
        }
        // Forza aggiornamento reattivo anche delle impostazioni in store
        this.impostazioni = { ...this.impostazioni, [chiave]: valore };
        // Tenta anche salvataggio DB (best-effort, non blocca)
        SP.salvaImpostazione(chiave, valore).catch(() => {});
        return true;
      } catch (e) {
        console.error("salvaImpostazione localStorage:", e);
        return false;
      }
    },

    // Nav amministrazione: mostrato se l'utente ha almeno un permesso admin
    get navAdmin() {
      const s = Alpine.store("sessione");
      return [
        { pagina: "categorie",     label: "Categorie",        icon: _ICONS.tag,      permesso: "gestione_categorie" },
        { pagina: "utenti",        label: "Utenti",           icon: _ICONS.users,    permesso: "gestione_utenti" },
        { pagina: "ruoli",         label: "Ruoli & Permessi", icon: _ICONS.shield,   permesso: "gestione_ruoli" },
        { pagina: "importBandi",   label: "Import Bandi",     icon: _ICONS.upload,   permesso: "gestione_ruoli" },
        { pagina: "impostazioni",  label: "Impostazioni",     icon: _ICONS.settings, permesso: "impostazioni" },
      ].filter(i => s.haPermesso(i.permesso));
    },

    get hasAdminNav() { return this.navAdmin.length > 0; },
  };
}

// ==========================================================
// COMPONENTE: loginPage
// ==========================================================
function loginPage() {
  return {
    username:  "",
    password:  "",
    errore:    "",
    caricando: false,

    async esegui() {
      if (!this.username || !this.password) { this.errore = "Inserisci username e password"; return; }
      this.caricando = true;
      this.errore    = "";
      const ok = await Alpine.store("sessione").eseguiLogin(this.username, this.password);
      if (ok) {
        await Alpine.store("db").ricarica();
        Alpine.store("ui").pagina = "dashboard";
      } else {
        this.errore = "Credenziali non valide o utente disabilitato";
      }
      this.caricando = false;
    },
  };
}

// ==========================================================
// COMPONENTE: dashboardPage
// ==========================================================
function dashboardPage() {
  return {
    get totali() {
      const pp = Alpine.store("db").preventivi;
      return {
        tutti:     pp.length,
        bozze:     pp.filter(p => p.stato === "bozza").length,
        inviati:   pp.filter(p => p.stato === "inviato").length,
        accettati: pp.filter(p => p.stato === "accettato").length,
        rifiutati: pp.filter(p => p.stato === "rifiutato").length,
      };
    },
    get valoreAperto() {
      return Alpine.store("db").preventivi
        .filter(p => p.stato === "inviato" || p.stato === "bozza")
        .reduce((s, p) => s + (p.totale_iva || 0), 0);
    },
    get ultimi()       { return Alpine.store("db").preventivi.slice(0, 5); },
    get utentiAttivi() { return Alpine.store("db").utenti.filter(u => u.attivo); },
    vai(p) { Alpine.store("ui").vai(p); },

    azioniRapide: [
      { pagina: "nuovo-preventivo", label: "Nuovo preventivo", bg: "bg-blue-100",   icon: '<svg class="text-blue-700 w-4 h-4" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>' },
      { pagina: "clienti",          label: "Nuovo cliente",    bg: "bg-green-100",  icon: '<svg class="text-green-700 w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z"/></svg>' },
      { pagina: "bandi",            label: "Cerca bandi",      bg: "bg-purple-100", icon: '<svg class="text-purple-700 w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>' },
      { pagina: "catalogo",         label: "Catalogo",         bg: "bg-orange-100", icon: '<svg class="text-orange-700 w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z"/></svg>' },
    ],
  };
}

// ==========================================================
// COMPONENTE: catalogoPage
// ==========================================================
function catalogoPage() {
  return {
    filtro:       "tutti",
    ricerca:      "",
    modaleAperto: false,
    corrente:     null,
    form:         {},
    salvando:     false,

    get canWrite()  { return Alpine.store("sessione").haPermesso("gestione_prodotti", "scrittura"); },
    get categorie() { return [{ id: "tutti", nome: "Tutti" }, ...Alpine.store("db").categorie]; },

    get prodottiFiltrati() {
      return Alpine.store("db").prodotti.filter(p => {
        const okCat = this.filtro === "tutti" || p.categoria === this.filtro;
        const okRic = p.nome.toLowerCase().includes(this.ricerca.toLowerCase());
        return okCat && okRic;
      });
    },

    apriNuovo() {
      if (!this.canWrite) return;
      this.corrente = null;
      this.form = { nome: "", categoria: Alpine.store("db").categorie[0]?.nome || "", prezzo: "", descrizione: "" };
      this.modaleAperto = true;
    },
    apriModifica(p) {
      if (!this.canWrite) return;
      this.corrente = p;
      this.form = { ...p };
      this.modaleAperto = true;
    },
    async salva() {
      if (!this.form.nome || !this.form.prezzo || this.salvando) return;
      this.salvando = true;
      try {
        if (this.corrente) {
          await Alpine.store("db").modificaProdotto(this.corrente.id, this.form);
          Alpine.store("ui").mostraToast("Prodotto aggiornato");
        } else {
          await Alpine.store("db").aggiungiProdotto(this.form);
          Alpine.store("ui").mostraToast("Prodotto aggiunto");
        }
        this.modaleAperto = false;
      } finally { this.salvando = false; }
    },
    async elimina(id) {
      if (!this.canWrite || !confirm("Eliminare questo prodotto?")) return;
      await Alpine.store("db").eliminaProdotto(id);
      Alpine.store("ui").mostraToast("Prodotto eliminato", "error");
    },
  };
}

// ==========================================================
// COMPONENTE: clientiPage
// ==========================================================
function clientiPage() {
  return {
    ricerca:      "",
    modaleAperto: false,
    corrente:     null,
    form:         {},
    salvando:     false,

    // ── Creditsafe ───────────────────────────────────────────
    csModale:    false,
    csCaricando: false,
    csDati:      null,
    csErrore:    "",

    async verificaPIVA(cliente) {
      const piva = (cliente.piva || cliente.partita_iva || "").trim();
      if (!piva) {
        Alpine.store("ui").mostraToast("Nessuna Partita IVA per questo cliente", "error");
        return;
      }
      this.csDati = null; this.csErrore = ""; this.csCaricando = true; this.csModale = true;
      try {
        const ris = await SP.verificaPIVA(piva);
        if (ris.ok) {
          this.csDati = ris;
        } else {
          this.csErrore = ris.error || "Errore sconosciuto";
        }
      } catch (e) {
        this.csErrore = e.message;
      } finally {
        this.csCaricando = false;
      }
    },

    csScoreColore(score) {
      const map = { "AAA": "text-emerald-700 bg-emerald-50", "AA": "text-emerald-700 bg-emerald-50", "A": "text-green-700 bg-green-50", "BB": "text-amber-700 bg-amber-50", "B": "text-orange-700 bg-orange-50", "C": "text-red-600 bg-red-50", "D": "text-red-800 bg-red-100" };
      return map[score] || "text-slate-600 bg-slate-100";
    },

    fmt(val, valuta = "EUR") {
      if (val == null) return "—";
      return new Intl.NumberFormat("it-IT", { style: "currency", currency: valuta, maximumFractionDigits: 0 }).format(val);
    },

    get canWrite() { return Alpine.store("sessione").haPermesso("clienti", "scrittura"); },

    get clientiFiltrati() {
      const q = this.ricerca.toLowerCase();
      return Alpine.store("db").clienti.filter(c =>
        c.nome.toLowerCase().includes(q) ||
        (c.referente || "").toLowerCase().includes(q) ||
        (c.citta     || "").toLowerCase().includes(q)
      );
    },

    countPreventivi(clienteId) {
      return Alpine.store("db").preventivi.filter(p => p.cliente_id === clienteId).length;
    },

    apriNuovo() {
      this.corrente = null;
      this.form = { tipo_cliente: "azienda", nome: "", referente: "", email: "", telefono: "", piva: "", codice_fiscale: "", indirizzo: "", civico: "", cap: "", citta: "", provincia: "", regione: "lombardia", ateco: "", settore: "ristorazione", note: "" };
      this.modaleAperto = true;
    },
    apriModifica(c) { this.corrente = c; this.form = { ...c }; this.modaleAperto = true; },
    async salva() {
      if (!this.form.nome || this.salvando) return;
      this.salvando = true;
      try {
        if (this.corrente) {
          await Alpine.store("db").modificaCliente(this.corrente.id, this.form);
          Alpine.store("ui").mostraToast("Cliente aggiornato");
        } else {
          await Alpine.store("db").aggiungiCliente(this.form);
          Alpine.store("ui").mostraToast("Cliente aggiunto");
        }
        this.modaleAperto = false;
      } finally { this.salvando = false; }
    },
    async elimina(id) {
      if (!this.canWrite || !confirm("Eliminare questo cliente?")) return;
      await Alpine.store("db").eliminaCliente(id);
      Alpine.store("ui").mostraToast("Cliente eliminato", "error");
    },
    nuovoPreventivoPer(cliente) {
      Alpine.store("ui").vai("nuovo-preventivo");
      setTimeout(() => window.dispatchEvent(new CustomEvent("preseleziona-cliente", { detail: cliente })), 80);
    },
    vaBandi(cliente) {
      Alpine.store("ui").vai("bandi");
      setTimeout(() => window.dispatchEvent(new CustomEvent("precompila-bandi", { detail: cliente })), 80);
    },
  };
}

// ==========================================================
// COMPONENTE: preventiviPage
// ==========================================================
function preventiviPage() {
  return {
    filtroStato: "tutti",
    get preventiviFiltrati() {
      const sess = Alpine.store("sessione");
      const tutti = Alpine.store("db").preventivi;
      // Se ha "preventivi_tutti" → vede tutti; altrimenti solo i suoi
      const base = sess.haPermesso("preventivi_tutti")
        ? tutti
        : tutti.filter(p => !p.utente_id || p.utente_id === sess.utente?.id);
      return base.filter(p => this.filtroStato === "tutti" || p.stato === this.filtroStato);
    },
    get canApprova() { return Alpine.store("sessione").haPermesso("approva_preventivi", "scrittura"); },
    async cambiaStato(id, stato) {
      await Alpine.store("db").aggiornaStato(id, stato);
      Alpine.store("ui").mostraToast("Stato aggiornato");
    },
    riprendi(p) {
      Alpine.store("ui").vai("nuovo-preventivo");
      // Piccolo delay per dare tempo ad Alpine di montare il componente
      setTimeout(() => window.dispatchEvent(new CustomEvent("riprendi-bozza", { detail: p })), 50);
    },
    async elimina(id) {
      if (!confirm("Eliminare il preventivo?")) return;
      await Alpine.store("db").eliminaPreventivo(id);
      Alpine.store("ui").mostraToast("Preventivo eliminato", "error");
    },
    esportaPDF(p) { generaPDF(p); },
  };
}

// ==========================================================
// COMPONENTE: nuovoPreventivo
// ==========================================================
function nuovoPreventivo() {
  return {
    // Testata
    titolo: "", validita: 30, note: "",

    // ID preventivo in modifica (null = nuovo)
    preventivoId: null,

    // Cliente
    clienteId:        null,
    ricercaCliente:   "",
    dropdownCliente:  false,
    modoNuovoCliente: false,
    formCliente:      { nome: "", azienda: "", email: "", indirizzo: "" },

    // Righe e sconti
    righe:             [],
    scontoGlobaleEuro: 0,
    ivaInclusa:        false,

    // Modal prodotti
    modaleAperto:    false,
    ricercaProdotto: "",
    salvando:        false,

    init() {
      window.addEventListener("preseleziona-cliente", (e) => {
        this.clienteId = e.detail.id;
        const c = Alpine.store("db").clienti.find(x => x.id == e.detail.id);
        if (c) this.ricercaCliente = c.nome;
      });
      window.addEventListener("riprendi-bozza", (e) => {
        this.carica(e.detail);
      });
    },

    carica(p) {
      this._reset();
      this.preventivoId     = p.id;
      this.note             = p.note || "";
      this.scontoGlobaleEuro = p.imp_sconto || 0;
      this.righe            = (p.righe || []).map(r => ({ ...r }));
      // Cliente
      if (p.cliente_id) {
        this.clienteId      = p.cliente_id;
        const c = Alpine.store("db").clienti.find(x => x.id == p.cliente_id);
        this.ricercaCliente = c ? c.nome : (p.cliente_nome || "");
      } else if (p.cliente_nome) {
        this.modoNuovoCliente = true;
        this.formCliente.nome = p.cliente_nome;
      }
    },

    // ── Permessi ─────────────────────────────────────────────
    get scontoMax() {
      const r = Alpine.store("db").ruoli?.find(r => r.chiave === Alpine.store("sessione").utente?.ruolo);
      return r?.sconto_max ?? 100;
    },

    // ── Clienti ──────────────────────────────────────────────
    get cliente() { return Alpine.store("db").clienti.find(c => c.id == this.clienteId); },
    get clientiFiltrati() {
      const q = this.ricercaCliente.toLowerCase();
      return Alpine.store("db").clienti.filter(c =>
        !q || c.nome.toLowerCase().includes(q) || (c.referente||"").toLowerCase().includes(q)
      ).slice(0, 8);
    },
    selezionaCliente(c) {
      this.clienteId       = c.id;
      this.ricercaCliente  = c.nome;
      this.dropdownCliente = false;
      this.modoNuovoCliente = false;
    },
    attivaModalNuovoCliente() {
      this.clienteId = null; this.ricercaCliente = "";
      this.modoNuovoCliente = true; this.dropdownCliente = false;
      this.formCliente = { nome: "", azienda: "", email: "", indirizzo: "" };
    },
    get clienteValido() {
      return this.clienteId || (this.modoNuovoCliente && this.formCliente.nome.trim());
    },

    // ── Prodotti ─────────────────────────────────────────────
    get prodottiFiltrati() {
      const q = this.ricercaProdotto.toLowerCase();
      return Alpine.store("db").prodotti.filter(p =>
        p.attivo && (!q || p.nome.toLowerCase().includes(q) || (p.categoria||"").toLowerCase().includes(q))
      );
    },
    _codiceProdotto(p) {
      const map = { software:"SW", hardware:"HW", servizi:"SRV", licenze:"LIC", abbonamenti:"ABB" };
      const pref = map[(p.categoria||"").toLowerCase()] || "PRD";
      const stessi = Alpine.store("db").prodotti.filter(x => (x.categoria||"").toLowerCase() === (p.categoria||"").toLowerCase());
      const idx = stessi.indexOf(p) + 1;
      return `${pref}-${String(idx).padStart(3,"0")}`;
    },
    aggiungiProdotto(p) {
      const ex = this.righe.find(r => r.prodottoId === p.id);
      if (ex) {
        ex.qty++;
        ex.scontoVal = +(ex.prezzo * ex.qty * ex.scontoPerc / 100).toFixed(2);
      } else {
        this.righe.push({
          prodottoId: p.id, codice: this._codiceProdotto(p),
          nome: p.nome, prezzo: p.prezzo,
          qty: 1, um: "pz",
          scontoPerc: 0, scontoVal: 0, ivaPerc: 22,
        });
      }
    },
    rimuoviRiga(i) { this.righe.splice(i, 1); },

    // ── Sconto riga (bidirezionale) ───────────────────────────
    aggiornaScontoPerc(i) {
      const r = this.righe[i];
      r.scontoPerc = Math.min(Math.max(parseFloat(r.scontoPerc)||0, 0), this.scontoMax);
      r.scontoVal  = +(r.prezzo * r.qty * r.scontoPerc / 100).toFixed(2);
    },
    aggiornaScontoVal(i) {
      const r    = this.righe[i];
      const base = r.prezzo * r.qty;
      r.scontoVal  = Math.min(Math.max(parseFloat(r.scontoVal)||0, 0), base);
      r.scontoPerc = base > 0 ? +((r.scontoVal / base) * 100).toFixed(2) : 0;
    },

    // ── Calcoli ───────────────────────────────────────────────
    totaleRiga(r) {
      return r.prezzo * r.qty - (parseFloat(r.scontoVal)||0);
    },
    get subtotale()  { return this.righe.reduce((s, r) => s + this.totaleRiga(r), 0); },
    get scontoGlobaleValido() {
      return Math.min(Math.max(parseFloat(this.scontoGlobaleEuro)||0, 0), this.subtotale);
    },
    get baseImponibile() { return this.subtotale - this.scontoGlobaleValido; },
    get imponibile() { return this.ivaInclusa ? this.baseImponibile / 1.22 : this.baseImponibile; },
    get iva()        { return this.baseImponibile - this.imponibile; },
    get totaleIva()  { return this.baseImponibile; },

    // ── Salva ─────────────────────────────────────────────────
    async salva(stato = "bozza") {
      if (!this.clienteValido || this.righe.length === 0 || this.salvando) return;
      this.salvando = true;
      try {
        let cId = this.clienteId;
        // Crea nuovo cliente se necessario
        if (this.modoNuovoCliente && this.formCliente.nome.trim()) {
          const nc = await SP.inserisciCliente({
            nome:      this.formCliente.nome.trim(),
            referente: this.formCliente.nome.trim(),
            email:     this.formCliente.email   || "",
            citta:     this.formCliente.indirizzo || "",
            settore: "ristorazione", regione: "lombardia",
          });
          if (nc) { await Alpine.store("db").caricaClienti(); cId = nc.id; }
        }
        const nomeCliente = this.cliente?.nome || this.formCliente.nome;
        const payload = {
          clienteId:   cId,
          clienteNome: nomeCliente,
          righe:       this.righe.map(r => ({...r})),
          note:        this.note,
          subtotale:   this.subtotale,
          impSconto:   this.scontoGlobaleValido,
          imponibile:  this.imponibile,
          iva:         this.iva,
          totaleIva:   this.totaleIva,
          stato,
        };

        let saved;
        if (this.preventivoId) {
          // Aggiorna preventivo esistente
          saved = await Alpine.store("db").modificaPreventivo(this.preventivoId, payload);
          if (saved) Alpine.store("ui").mostraToast(`Preventivo aggiornato!`);
        } else {
          // Crea nuovo preventivo
          payload.utenteId   = Alpine.store("sessione").utente?.id;
          payload.utenteNome = Alpine.store("sessione").nomeUtente;
          saved = await Alpine.store("db").salvaPreventivo(payload);
          if (saved) Alpine.store("ui").mostraToast(`Preventivo ${saved.numero} salvato!`);
        }

        if (saved) {
          Alpine.store("ui").vai("preventivi");
          this._reset();
        }
      } finally { this.salvando = false; }
    },

    _reset() {
      Object.assign(this, {
        titolo:"", validita:30, note:"",
        preventivoId: null,
        clienteId:null, ricercaCliente:"", dropdownCliente:false,
        modoNuovoCliente:false, formCliente:{nome:"",azienda:"",email:"",indirizzo:""},
        righe:[], scontoGlobaleEuro:0, ivaInclusa:false,
        modaleAperto:false, ricercaProdotto:"", salvando:false,
      });
    },
  };
}

// ==========================================================
// COMPONENTE: categoriePage (solo chi ha gestione_categorie)
// ==========================================================
function categoriePage() {
  return {
    modaleAperto: false,
    corrente:     null,
    form:         {},
    salvando:     false,

    get elenco() { return Alpine.store("db").categorie; },

    apriNuovo()     { this.corrente = null; this.form = { nome: "", icona: "📦", ordine: 0 }; this.modaleAperto = true; },
    apriModifica(c) { this.corrente = c; this.form = { ...c }; this.modaleAperto = true; },

    async salva() {
      if (!this.form.nome || this.salvando) return;
      this.salvando = true;
      try {
        if (this.corrente) {
          await Alpine.store("db").modificaCategoria(this.corrente.id, this.form);
          Alpine.store("ui").mostraToast("Categoria aggiornata");
        } else {
          await Alpine.store("db").aggiungiCategoria(this.form);
          Alpine.store("ui").mostraToast("Categoria aggiunta");
        }
        this.modaleAperto = false;
      } finally { this.salvando = false; }
    },
    async elimina(id) {
      if (!confirm("Eliminare questa categoria?")) return;
      await Alpine.store("db").eliminaCategoria(id);
      Alpine.store("ui").mostraToast("Categoria eliminata", "error");
    },
  };
}

// ==========================================================
// COMPONENTE: utentiPage (solo chi ha gestione_utenti)
// ==========================================================
function utentiPage() {
  return {
    modaleAperto:  false,
    corrente:      null,
    form:          {},
    nuovaPassword: "",
    salvando:      false,
    avatarPreview: null,
    menuVoci:      [],   // pagine selezionate per menu personalizzato ([] = tutto)

    get elenco()      { return Alpine.store("db").utenti; },
    get ruoliList()   { return Alpine.store("db").ruoli; },
    get voceMenuOp()  { return VOCI_MENU_OP; },

    // Restituisce le voci che il ruolo selezionato nel form permetterebbe
    voceAbilitata(voce) {
      if (!voce.permesso) return true; // dashboard sempre
      const ruolo = Alpine.store("db").ruoli.find(r => r.chiave === this.form.ruolo);
      if (!ruolo) return true;
      return !!ruolo.permessi?.[voce.permesso];
    },

    apriNuovo() {
      this.corrente      = null;
      this.form          = { username: "", nome: "", ruolo: "commerciale", attivo: true, avatar: null };
      this.nuovaPassword = "";
      this.avatarPreview = null;
      this.menuVoci      = [];
      this.modaleAperto  = true;
    },
    apriModifica(u) {
      this.corrente      = u;
      this.form          = { ...u };
      this.nuovaPassword = "";
      this.avatarPreview = u.avatar || null;
      this.menuVoci      = Array.isArray(u.menu_utente) ? [...u.menu_utente] : [];
      this.modaleAperto  = true;
    },

    // Carica foto profilo → converte in base64
    caricaAvatar(event) {
      const file = event.target.files[0];
      if (!file) return;
      if (file.size > 500 * 1024) {
        Alpine.store("ui").mostraToast("Immagine troppo grande (max 500KB)", "error");
        return;
      }
      const reader = new FileReader();
      reader.onload = (e) => {
        this.form.avatar   = e.target.result;
        this.avatarPreview = e.target.result;
      };
      reader.readAsDataURL(file);
    },
    rimuoviAvatar() {
      this.form.avatar   = null;
      this.avatarPreview = null;
    },

    async salva() {
      if (!this.form.nome || this.salvando) return;
      if (!this.corrente && !this.nuovaPassword) { Alpine.store("ui").mostraToast("Inserisci una password", "error"); return; }
      this.salvando = true;
      try {
        const db = Alpine.store("db");
        // menu_utente: null se nessuna selezione (= tutti), altrimenti array
        const menu_utente = this.menuVoci.length > 0 ? [...this.menuVoci] : null;
        if (this.corrente) {
          const dati = { ...this.form, menu_utente };
          if (this.nuovaPassword) dati._nuovaPasswordHash = await hashPassword(this.nuovaPassword);
          const aggiornato = await db.modificaUtente(this.corrente.id, dati);
          if (aggiornato) {
            const sess = Alpine.store("sessione");
            if (sess.utente?.id === this.corrente.id) {
              sess.utente.avatar = aggiornato.avatar;
              sess.utente.menu_utente = aggiornato.menu_utente;
            }
          }
          Alpine.store("ui").mostraToast("Utente aggiornato");
        } else {
          const hash = await hashPassword(this.nuovaPassword);
          await db.aggiungiUtente({ ...this.form, menu_utente }, hash);
          Alpine.store("ui").mostraToast("Utente creato");
        }
        this.modaleAperto = false;
      } finally { this.salvando = false; }
    },

    async elimina(id) {
      const sess = Alpine.store("sessione");
      if (sess.utente?.id === id) { Alpine.store("ui").mostraToast("Non puoi eliminare te stesso", "error"); return; }
      if (!confirm("Eliminare questo utente?")) return;
      await Alpine.store("db").eliminaUtente(id);
      Alpine.store("ui").mostraToast("Utente eliminato", "error");
    },
  };
}

// ==========================================================
// COMPONENTE: impostazioniPage
// ==========================================================
function impostazioniPage() {
  return {
    logoPreview: null,
    nomeAzienda: "",

    init() {
      // Lettura diretta da localStorage — sincrono, zero dipendenze
      try { this.logoPreview = JSON.parse(localStorage.getItem("cfg_logo") || "null"); } catch (_) {}
      this.nomeAzienda = localStorage.getItem("cfg_nome_azienda") || "";
    },

    caricaLogo(event) {
      const file = event.target.files[0];
      if (!file) return;
      if (file.size > 500 * 1024) {
        alert("Immagine troppo grande. Usa un file sotto i 500 KB.");
        event.target.value = "";
        return;
      }
      const reader = new FileReader();
      reader.onload = (e) => { this.logoPreview = e.target.result; };
      reader.readAsDataURL(file);
    },

    salvaLogo() {
      if (!this.logoPreview) {
        Alpine.store("ui").mostraToast("Seleziona prima un'immagine", "error");
        return;
      }
      // 1. localStorage
      localStorage.setItem("cfg_logo", JSON.stringify(this.logoPreview));
      // 2. aggiorna store → sidebar reattiva
      const _db = Alpine.store("db");
      _db.impostazioni = { ..._db.impostazioni, logo: this.logoPreview };
      Alpine.store("ui").mostraToast("Logo salvato!");
    },

    rimuoviLogo() {
      localStorage.removeItem("cfg_logo");
      this.logoPreview = null;
      Alpine.store("db").impostazioni = {
        ...Alpine.store("db").impostazioni,
        logo: null,
      };
      Alpine.store("ui").mostraToast("Logo rimosso");
    },

    salvaNomeAzienda() {
      const nome = (this.nomeAzienda || "").trim() || "Configuratore";
      // 1. localStorage
      localStorage.setItem("cfg_nome_azienda", nome);
      // 2. aggiorna store → sidebar reattiva
      const _db = Alpine.store("db");
      _db.impostazioni = { ..._db.impostazioni, nome_azienda: nome };
      Alpine.store("ui").mostraToast("Nome azienda aggiornato!");
    },
  };
}

// ==========================================================
// COMPONENTE: ruoliPage — CRUD completo (solo chi ha gestione_ruoli)
// ==========================================================
function ruoliPage() {
  return {
    vista:    "lista",   // "lista" | "form"
    corrente: null,
    form:     {},
    salvando: false,

    get elenco() { return Alpine.store("db").ruoli; },
    get permessiDef() { return PERMESSI_DEF; },

    // Conta gli utenti per ogni ruolo
    utentiPerRuolo(chiave) {
      return Alpine.store("db").utenti.filter(u => u.ruolo === chiave).length;
    },

    // Badge dei permessi attivi nel listino
    permessiBadge(permessi) {
      if (!permessi) return [];
      return PERMESSI_DEF
        .filter(d => permessi[d.id])
        .map(d => ({
          emoji: d.emoji,
          label: d.label,
          livello: permessi[d.id],
          colore: permessi[d.id] === "entrambi" ? "bg-blue-100 text-blue-700"
                : permessi[d.id] === "scrittura" ? "bg-green-100 text-green-700"
                : "bg-slate-100 text-slate-600",
        }));
    },

    apriNuovo() {
      this.corrente = null;
      this.form = {
        nome:        "",
        chiave:      "",
        descrizione: "",
        sconto_max:  0,
        permessi:    {},
      };
      this.vista = "form";
    },

    apriModifica(r) {
      this.corrente = r;
      this.form = {
        nome:        r.nome,
        chiave:      r.chiave,
        descrizione: r.descrizione || "",
        sconto_max:  r.sconto_max  || 0,
        permessi:    { ...(r.permessi || {}) },
      };
      this.vista = "form";
    },

    annulla() { this.vista = "lista"; this.corrente = null; },

    // Toggle permesso (spunta → lettura; già attivo → rimuovi)
    togglePermesso(permId) {
      if (this.form.permessi[permId]) {
        delete this.form.permessi[permId];
        this.form.permessi = { ...this.form.permessi }; // trigger reactivity
      } else {
        this.form.permessi = { ...this.form.permessi, [permId]: "lettura" };
      }
    },

    // Aggiorna livello di un permesso
    setLivello(permId, livello) {
      this.form.permessi = { ...this.form.permessi, [permId]: livello };
    },

    // Label/badge livello
    livelloLabel(l) { return { lettura: "Lettura", scrittura: "Scrittura", entrambi: "Entrambi" }[l] || l; },
    livelloClasse(l) {
      return { lettura: "bg-slate-100 text-slate-600", scrittura: "bg-green-100 text-green-700", entrambi: "bg-blue-100 text-blue-700" }[l] || "";
    },

    async salva() {
      if (!this.form.nome || this.salvando) return;
      this.salvando = true;
      try {
        if (this.corrente) {
          await Alpine.store("db").modificaRuolo(this.corrente.id, this.form);
          Alpine.store("ui").mostraToast("Ruolo aggiornato");
        } else {
          await Alpine.store("db").aggiungiRuolo(this.form);
          Alpine.store("ui").mostraToast("Ruolo creato");
        }
        this.vista = "lista";
        this.corrente = null;
      } finally { this.salvando = false; }
    },

    async elimina(r) {
      if (r.sistema) { Alpine.store("ui").mostraToast("I ruoli di sistema non si eliminano", "error"); return; }
      if (!confirm(`Eliminare il ruolo "${r.nome}"?`)) return;
      await Alpine.store("db").eliminaRuolo(r.id);
      Alpine.store("ui").mostraToast("Ruolo eliminato", "error");
    },
  };
}

// ==========================================================
// COMPONENTE: bandiPage
// ==========================================================
function bandiPage() {
  return {
    ateco: "", provincia: "tutte", regione: "tutte",
    tuttiBandi: [],   // caricati da Supabase all'init
    risultati:  [],
    cercato:    false,
    caricamento: true,
    erroreDB:   null,

    get aggiornamento() {
      if (!this.tuttiBandi.length) return "—";
      const dates = this.tuttiBandi
        .map(b => b.data_importazione).filter(Boolean).sort();
      if (!dates.length) return "—";
      return new Date(dates[dates.length - 1])
        .toLocaleDateString("it-IT", { month: "long", year: "numeric" });
    },
    get oggiFormattato() { return new Date().toLocaleDateString("it-IT"); },
    get settoreInfo() {
      if (!this.ateco || this.ateco.length < 2) return null;
      return ATECO_SETTORI[this.ateco.substring(0, 2)] || null;
    },
    get province() { return PROVINCE_ITALIA; },
    get provinciaSelezionata() {
      return PROVINCE_ITALIA.find(p => p.id === this.provincia) || null;
    },
    get regioni() {
      const tutte = [{ id: "tutte", nome: "Tutte le regioni" }];
      const set = new Set(PROVINCE_ITALIA.filter(p => p.regione).map(p => p.regione));
      return [...tutte, ...Array.from(set).sort().map(r => ({ id: r, nome: r }))];
    },
    get provinceFiltered() {
      const tutte = PROVINCE_ITALIA[0]; // "Tutta Italia"
      if (this.regione === "tutte") return PROVINCE_ITALIA;
      return [tutte, ...PROVINCE_ITALIA.filter(p => p.regione === this.regione)];
    },
    onRegioneChange() {
      // Resetta provincia se non appartiene alla nuova regione
      if (this.regione !== "tutte") {
        const prov = PROVINCE_ITALIA.find(p => p.id === this.provincia);
        if (!prov || prov.regione !== this.regione) this.provincia = "tutte";
      }
    },
    onProvinciaChange() {
      if (this.provincia !== "tutte") this.regione = "tutte";
    },
    aggiornaSettore() { /* getter auto-calcola */ },

    async init() {
      this.caricamento = true;
      try {
        this.tuttiBandi = await SP.getBandi();
      } catch (e) {
        this.erroreDB = "Impossibile caricare i bandi: " + e.message;
      }
      this.caricamento = false;
      window.addEventListener("precompila-bandi", (e) => {
        this.ateco    = e.detail.ateco    || "";
        this.regione  = e.detail.regione  || "tutte";
        this.provincia = e.detail.provincia || "tutte";
        if (this.ateco) this.cerca();
      });
    },

    // ── Matching ──────────────────────────────────────────────
    _matchAteco(b) {
      if (b.tutti_ateco) return true;
      if (!b.codici_ateco?.length) return true;
      const prefix2 = this.ateco.trim().substring(0, 2);
      return b.codici_ateco.some(c => c.trim().substring(0, 2) === prefix2);
    },
    _matchRegione(b) {
      if (b.tutte_regioni || !b.regioni?.length) return true;
      // Priorità: regione diretta → poi provincia (deriva la regione)
      if (this.regione !== "tutte") {
        return b.regioni.some(r => r.toLowerCase() === this.regione.toLowerCase());
      }
      if (this.provincia !== "tutte") {
        const prov = PROVINCE_ITALIA.find(p => p.id === this.provincia);
        if (prov?.regione) return b.regioni.some(r => r.toLowerCase() === prov.regione.toLowerCase());
      }
      return true;
    },

    // ── Mappa DB record → formato usato dall'HTML ─────────────
    _mapBando(b) {
      const oggi    = new Date();
      const chiusura = b.data_chiusura ? new Date(b.data_chiusura) : null;
      const giorni  = chiusura ? Math.round((chiusura - oggi) / 86_400_000) : null;

      let _statoScadenza;
      if (!chiusura || b.stato === "permanente") {
        _statoScadenza = { label: "Sempre attivo",       classe: "bg-green-100 text-green-700",  icon: "♾️" };
      } else if (giorni !== null && giorni <= 30) {
        _statoScadenza = { label: `Scade tra ${giorni} gg`, classe: "bg-orange-100 text-orange-700", icon: "⚠️" };
      } else if (giorni !== null && giorni <= 90) {
        _statoScadenza = { label: `Scade tra ${giorni} gg`, classe: "bg-amber-100 text-amber-700",  icon: "⏳" };
      } else {
        _statoScadenza = { label: "Attivo",               classe: "bg-green-100 text-green-700",  icon: "✅" };
      }

      // Tipo agevolazione
      const forma = (b.forma_agevolazione || [])[0]?.toLowerCase() || "";
      let tipo = "contributo";
      if (forma.includes("fiscale"))    tipo = "credito_imposta";
      else if (forma.includes("garanzia"))  tipo = "garanzia";
      else if (forma.includes("prestito"))  tipo = "finanziamento_agevolato";
      else if (forma.includes("capitale")) tipo = "contributo";

      // Testo aliquota
      let aliquota = "Varia";
      if (b.agevolazione_max > 0) {
        aliquota = `Fino a ${new Intl.NumberFormat("it-IT", { style: "currency", currency: "EUR", maximumFractionDigits: 0 }).format(b.agevolazione_max)}`;
      }
      if (b.forma_agevolazione?.length) {
        aliquota += ` — ${b.forma_agevolazione[0]}`;
      }

      // Requisiti da dimensioni
      const requisiti = (b.dimensioni || [])
        .filter(d => d !== "Non classificabile/classificato")
        .map(d => d);

      return {
        ...b,
        nome:       b.titolo,
        ente:       b.soggetto_concedente || "—",
        link:       b.link_ufficiale      || "#",
        fonte:      "incentivi.gov.it",
        aliquota,
        importoMax: b.agevolazione_max || 0,
        scadenza:   b.data_chiusura    || "Permanente",
        descrizione: (b.descrizione || "").substring(0, 500) +
                     ((b.descrizione || "").length > 500 ? "…" : ""),
        requisiti,
        note:       null,
        tipo,
        _statoScadenza,
      };
    },

    cerca() {
      if (!this.ateco) return;
      this.risultati = this.tuttiBandi
        .filter(b => this._matchAteco(b) && this._matchRegione(b))
        .map(b => this._mapBando(b))
        .slice(0, 50); // max 50 risultati per UX
      this.cercato = true;
    },
  };
}

// ==========================================================
// COMPONENTE: importBandiPage
// ==========================================================
function _normalizzaBando(d, fonteName = "incentivi.gov.it") {
  const s = d.Codici_ATECO || "";
  const low = s.toLowerCase();
  const tuttiAteco = !s || low.includes("tutti") || low.includes("qualsiasi");
  const codiciAteco = tuttiAteco ? [] : s.split(";").map(c => c.trim()).filter(c => c && /^\d/.test(c));
  const regioni = Array.isArray(d.Regioni) ? d.Regioni : [];
  const oggi    = new Date();
  const chiusura = d.Data_chiusura ? new Date(d.Data_chiusura) : null;
  let stato = "permanente";
  if (chiusura) {
    if (chiusura < oggi) stato = "scaduto";
    else {
      const gg = Math.round((chiusura - oggi) / 86_400_000);
      stato = gg <= 30 ? "in_scadenza" : "attivo";
    }
  }
  return {
    id:                   String(d.ID_Incentivo),
    titolo:               (d.Titolo || "").trim(),
    descrizione:          (d.Descrizione || "").substring(0, 2000),
    data_apertura:        d.Data_apertura  || null,
    data_chiusura:        d.Data_chiusura  || null,
    stato,
    codici_ateco:         codiciAteco,
    tutti_ateco:          tuttiAteco,
    regioni,
    tutte_regioni:        regioni.length === 0,
    forma_agevolazione:   Array.isArray(d.Forma_agevolazione) ? d.Forma_agevolazione : [],
    dimensioni:           Array.isArray(d.Dimensioni)         ? d.Dimensioni         : [],
    settore_attivita:     Array.isArray(d.Settore_Attivita)   ? d.Settore_Attivita   : [],
    obiettivi:            Array.isArray(d.Obiettivo_Finalita) ? d.Obiettivo_Finalita : [],
    soggetto_concedente:  (d.Soggetto_Concedente || "").trim(),
    agevolazione_min:     parseFloat(d.Agevolazione_Concedibile_min) || 0,
    agevolazione_max:     parseFloat(d.Agevolazione_Concedibile_max) || 0,
    stanziamento:         parseFloat(d.Stanziamento_incentivo)       || 0,
    link_ufficiale:       (d.Link_istituzionale || "").trim(),
    fonte:                fonteName,
    ultimo_aggiornamento: d.Data_ultimo_aggiornamento || null,
    data_importazione:    new Date().toISOString(),
  };
}

function importBandiPage() {
  return {
    // ── Stato generale ──────────────────────────────────────
    fonti:      [],
    syncLog:    [],
    caricando:  false,

    // ── Sync in corso ───────────────────────────────────────
    syncingFonte: null,   // id fonte in sync, o "tutte"
    syncRis:      null,   // risultato ultimo sync

    // ── Form nuova fonte ────────────────────────────────────
    formAperto:  false,
    formFonte:   { id: "", nome: "", url: "", tipo: "rss", note: "" },
    formSalvando: false,

    // ── Upload manuale (fallback) ───────────────────────────
    uploadFase:     "idle",
    uploadProgresso: 0,
    uploadStats:    null,
    uploadErrMsg:   "",

    async init() {
      await this.ricarica();
    },

    async ricarica() {
      this.caricando = true;
      try {
        this.fonti   = await SP.getFontiBandi();
        this.syncLog = await SP.getSyncLog(null, 15);
      } finally {
        this.caricando = false;
      }
    },

    // ── Sync ────────────────────────────────────────────────
    async avviaSync(fonteId = null) {
      if (this.syncingFonte) return;
      this.syncingFonte = fonteId || "tutte";
      this.syncRis = null;

      // Segna in_corso nella UI localmente
      if (fonteId) {
        const f = this.fonti.find(f => f.id === fonteId);
        if (f) f.sync_stato = "in_corso";
      } else {
        this.fonti.filter(f => f.attiva).forEach(f => f.sync_stato = "in_corso");
      }

      try {
        const ris = await SP.avviaSyncBandi(fonteId);
        this.syncRis = ris;
        if (ris.ok) {
          Alpine.store("ui").mostraToast("Sincronizzazione completata!");
        } else {
          const dettaglio = ris.error || ris.message || ris.code || JSON.stringify(ris);
          Alpine.store("ui").mostraToast("Errore nella sync: " + dettaglio, "error");
        }
      } catch (e) {
        Alpine.store("ui").mostraToast("Errore: " + e.message, "error");
      } finally {
        this.syncingFonte = null;
        await this.ricarica();
      }
    },

    // ── Toggle attiva/disattiva fonte ───────────────────────
    async toggleFonte(fonte) {
      fonte.attiva = !fonte.attiva;
      await SP.toggleFonteBandi(fonte.id, fonte.attiva);
    },

    // ── Elimina fonte ───────────────────────────────────────
    async eliminaFonte(fonte) {
      if (!confirm(`Eliminare la fonte "${fonte.nome}"?`)) return;
      await SP.eliminaFonteBandi(fonte.id);
      this.fonti = this.fonti.filter(f => f.id !== fonte.id);
      Alpine.store("ui").mostraToast("Fonte eliminata");
    },

    // ── Aggiungi / modifica fonte ───────────────────────────
    apriFormFonte(fonte = null) {
      this.formFonte = fonte
        ? { ...fonte }
        : { id: "", nome: "", url: "", tipo: "rss", note: "" };
      this.formAperto = true;
    },

    async salvaFonte() {
      if (!this.formFonte.nome || !this.formFonte.url) {
        Alpine.store("ui").mostraToast("Nome e URL sono obbligatori", "error");
        return;
      }
      this.formSalvando = true;
      try {
        const salvata = await SP.salvaFonteBandi(this.formFonte);
        if (salvata) {
          this.formAperto = false;
          await this.ricarica();
          Alpine.store("ui").mostraToast("Fonte salvata!");
        }
      } finally {
        this.formSalvando = false;
      }
    },

    // ── Helpers UI ──────────────────────────────────────────
    statoFonteBadge(fonte) {
      const map = {
        ok:       "bg-green-50 text-green-700",
        errore:   "bg-red-50 text-red-600",
        in_corso: "bg-amber-50 text-amber-700",
        mai:      "bg-slate-100 text-slate-500",
      };
      return map[fonte.sync_stato] || map.mai;
    },
    statoFonteLabel(fonte) {
      if (fonte.sync_stato === "ok")       return `✓ ${fonte.sync_importati} importati`;
      if (fonte.sync_stato === "errore")   return "✗ Errore";
      if (fonte.sync_stato === "in_corso") return "↻ In corso…";
      return "Mai sincronizzata";
    },
    fmtSync(ts) {
      if (!ts) return "—";
      return new Date(ts).toLocaleString("it-IT", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });
    },

    // ── Import diretto da browser (bypassa Edge Function) ──
    async importaDaFonte(fonte) {
      if (!fonte.url) {
        Alpine.store("ui").mostraToast("URL non configurato nella fonte", "error");
        return;
      }
      this.uploadFase = "fetch"; this.uploadProgresso = 0; this.uploadErrMsg = "";
      try {
        Alpine.store("ui").mostraToast("Download in corso dal browser…");
        const res = await fetch(fonte.url);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const parsed = await res.json();
        // Supporta array diretto e Solr { response: { docs: [...] } }
        const raw = Array.isArray(parsed)
          ? parsed
          : (parsed?.response?.docs ?? parsed?.docs ?? []);
        if (!raw.length) throw new Error("Nessun record ricevuto — verifica l'URL");
        await this._importaRecords(raw, fonte.nome || "browser");
      } catch (e) {
        this.uploadErrMsg = e.message.includes("Failed to fetch") || e.message.includes("CORS")
          ? "Il sito blocca le richieste dal browser (CORS). Scarica il file manualmente e usa il caricamento sotto."
          : e.message;
        this.uploadFase = "errore";
      }
    },

    // ── Upload manuale (fallback) ───────────────────────────
    async caricaFile(event) {
      const file = event.target.files[0];
      if (!file) return;
      this.uploadFase = "lettura"; this.uploadProgresso = 0; this.uploadErrMsg = "";
      try {
        const parsed = JSON.parse(await file.text());
        // Supporta array diretto e Solr { response: { docs: [...] } }
        const raw = Array.isArray(parsed)
          ? parsed
          : (parsed?.response?.docs ?? parsed?.docs ?? []);
        if (!raw.length) throw new Error("Nessun record trovato nel file");
        await this._importaRecords(raw, "file");
      } catch (e) {
        this.uploadErrMsg = e.message;
        this.uploadFase   = "errore";
      }
    },

    async _importaRecords(raw, fonte) {
      const records = raw.map(d => _normalizzaBando(d, fonte));
      this.uploadFase = "importazione";
      const BATCH = 100;
      let importati = 0;
      for (let i = 0; i < records.length; i += BATCH) {
        await SP.upsertBandi(records.slice(i, i + BATCH));
        importati += Math.min(BATCH, records.length - i);
        this.uploadProgresso = Math.round((importati / records.length) * 100);
      }
      const attivi = records.filter(r => r.stato !== "scaduto").length;
      this.uploadStats = { totale: raw.length, attivi, importati };
      this.uploadFase  = "completato";
      Alpine.store("ui").mostraToast(`${importati} bandi importati!`);
      await SP.scriviLogManuale(importati, raw.length);
      await this.ricarica();
    },

    resetUpload() { this.uploadFase = "idle"; this.uploadProgresso = 0; this.uploadStats = null; this.uploadErrMsg = ""; },
  };
}

// ==========================================================
// UTILITIES
// ==========================================================
function fmt(val) {
  return new Intl.NumberFormat("it-IT", { style: "currency", currency: "EUR" }).format(val || 0);
}
function fmtData(iso) {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("it-IT");
}
function statoLabel(stato) {
  return { bozza: "Bozza", inviato: "In attesa", accettato: "Accettato", rifiutato: "Rifiutato", annullato: "Annullato" }[stato] || stato;
}
function statoClasse(stato) {
  return {
    bozza:     "bg-slate-100 text-slate-600",
    inviato:   "bg-amber-100 text-amber-700",
    accettato: "bg-green-100 text-green-700",
    rifiutato: "bg-red-100 text-red-600",
    annullato: "bg-red-50 text-red-400",
  }[stato] || "bg-slate-100 text-slate-600";
}
function tipoBandoLabel(tipo) {
  return { credito_imposta: "Credito Imposta", contributo: "Contributo", voucher: "Voucher", garanzia: "Garanzia", finanziamento_agevolato: "Finanziamento Agevolato", contributo_interessi: "Contributo Interessi" }[tipo] || tipo;
}
function tipoBandoClasse(tipo) {
  return { credito_imposta: "bg-purple-100 text-purple-700", contributo: "bg-green-100 text-green-700", voucher: "bg-blue-100 text-blue-700", garanzia: "bg-orange-100 text-orange-700", finanziamento_agevolato: "bg-teal-100 text-teal-700", contributo_interessi: "bg-indigo-100 text-indigo-700" }[tipo] || "bg-slate-100 text-slate-600";
}
function ruoloClasse(ruolo) {
  return ruolo === "admin" ? "bg-purple-100 text-purple-700" : "bg-blue-100 text-blue-700";
}
function ruoloLabel(ruolo) {
  const db = Alpine.store && Alpine.store("db");
  if (db) {
    const r = db.ruoli?.find(x => x.chiave === ruolo);
    if (r) return r.nome;
  }
  return ruolo === "admin" ? "Admin" : "Commerciale";
}

// ==========================================================
// GENERA PDF
// ==========================================================
function generaPDF(preventivo) {
  const { jsPDF } = window.jspdf;
  const doc = new jsPDF();
  const cli = Alpine.store("db").clienti.find(c => c.id === preventivo.cliente_id);
  const db  = Alpine.store("db");
  const logo = db.logo;
  const nomeAzienda = db.nomeAzienda;

  // Header con logo (se disponibile) o nome azienda
  if (logo) {
    try {
      // Determina formato dal data URL
      const fmt_logo = logo.startsWith("data:image/png") ? "PNG"
                     : logo.startsWith("data:image/svg") ? "SVG"
                     : "JPEG";
      doc.addImage(logo, fmt_logo, 14, 10, 0, 18); // altezza 18mm, larghezza auto
    } catch (_) {
      doc.setFontSize(14); doc.setTextColor(30, 64, 175); doc.setFont("helvetica", "bold");
      doc.text(nomeAzienda, 14, 20);
    }
  } else {
    doc.setFontSize(14); doc.setTextColor(30, 64, 175); doc.setFont("helvetica", "bold");
    doc.text(nomeAzienda, 14, 20);
  }

  doc.setFontSize(24); doc.setTextColor(30, 64, 175); doc.setFont("helvetica", "bold");
  doc.text("PREVENTIVO", 196, 22, { align: "right" });
  doc.setFontSize(10); doc.setTextColor(100); doc.setFont("helvetica", "normal");
  doc.text(`N° ${preventivo.numero}   •   Data: ${fmtData(preventivo.data || preventivo.created_at)}`, 196, 30, { align: "right" });
  doc.setDrawColor(200); doc.line(14, 34, 196, 34);

  doc.setFontSize(11); doc.setTextColor(30); doc.setFont("helvetica", "bold");
  doc.text(cli?.nome || preventivo.cliente_nome || "—", 14, 42);
  doc.setFont("helvetica", "normal"); doc.setFontSize(10); doc.setTextColor(80);
  if (cli?.referente) doc.text(`Referente: ${cli.referente}`, 14, 48);
  if (cli?.email)     doc.text(`Email: ${cli.email}`, 14, 54);
  if (cli?.telefono)  doc.text(`Tel: ${cli.telefono}`, 14, 60);

  doc.autoTable({
    head: [["Descrizione", "Qtà", "Prezzo Unit.", "Totale"]],
    body: (preventivo.righe || []).map(r => [r.nome, r.qty, fmt(r.prezzo), fmt(r.prezzo * r.qty)]),
    startY: 68,
    styles: { fontSize: 10, cellPadding: 4 },
    headStyles: { fillColor: [30, 64, 175], fontStyle: "bold" },
    columnStyles: { 1: { halign: "center" }, 2: { halign: "right" }, 3: { halign: "right" } },
  });

  const y = doc.lastAutoTable.finalY + 8;
  let riga = 0;
  const linea = (label, val, grassetto = false) => {
    doc.setFont("helvetica", grassetto ? "bold" : "normal");
    doc.setTextColor(grassetto ? 30 : 60); if (grassetto) doc.setTextColor(30, 64, 175);
    doc.text(label, 130, y + riga * 7); doc.text(val, 196, y + riga * 7, { align: "right" }); riga++;
  };
  linea("Subtotale:", fmt(preventivo.subtotale));
  if (preventivo.sconto > 0) linea(`Sconto ${preventivo.sconto}%:`, `-${fmt(preventivo.imp_sconto)}`);
  linea("Imponibile:", fmt(preventivo.imponibile));
  linea("IVA 22%:", fmt(preventivo.iva));
  linea("TOTALE:", fmt(preventivo.totale_iva), true);

  if (preventivo.note) {
    doc.setFont("helvetica", "normal"); doc.setFontSize(9); doc.setTextColor(100);
    doc.text("Note:", 14, y + 4); doc.text(preventivo.note, 14, y + 10);
  }
  doc.setFontSize(8); doc.setTextColor(160);
  doc.text("Documento generato automaticamente — non ha valore fiscale", 105, 285, { align: "center" });
  doc.save(`${preventivo.numero}.pdf`);
}
