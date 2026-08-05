// ============================================================
// supabase.js — Client Supabase e funzioni CRUD
// ============================================================
// 1. Vai su https://supabase.com → il tuo progetto
// 2. Settings → API
// 3. Copia "Project URL" e "anon public key" qui sotto
// ============================================================

const SUPABASE_URL  = "https://segbfdfoqxrnitboeyof.supabase.co";
const SUPABASE_ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlZ2JmZGZvcXhybml0Ym9leW9mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxMzIxNzksImV4cCI6MjA5NzcwODE3OX0.v5ZGCkqTduegxFaa6GOYUIIHrQ5cQe0JFB7PGO93XNo";

// Cattura SUBITO (in modo sincrono) se stiamo arrivando da un link di recupero
// password: la libreria Supabase ripulisce l'hash dall'URL poco dopo l'init.
const _RECOVERY_FLAG = (window.location.hash || "").includes("type=recovery");

// Inizializza client (CDN carica la libreria come window.supabase)
const _sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON);

// ============================================================
// AZIENDA ATTIVA (multi-tenant): tutte le query filtrano/scrivono
// sull'azienda attualmente selezionata dall'utente.
// ============================================================
let _aziendaAttiva = null;
function _scopeAzienda(query) {
  return _aziendaAttiva ? query.eq("azienda_id", _aziendaAttiva) : query;
}

// ============================================================
// Oggetto SP — tutte le operazioni sul database
// ============================================================
const SP = {

  // ----------------------------------------------------------
  // AZIENDE (multi-tenant)
  // ----------------------------------------------------------
  setAziendaAttiva(id) { _aziendaAttiva = id || null; },
  getAziendaAttiva()   { return _aziendaAttiva; },

  // Aziende di cui l'utente è membro (con il ruolo per azienda)
  async getAziendeUtente(utenteId) {
    const { data, error } = await _sb
      .from("membri")
      .select("azienda_id, ruolo, aziende(nome, logo)")
      .eq("utente_id", utenteId);
    if (error) { console.error("getAziendeUtente:", error.message); return []; }
    return (data || []).map(m => ({
      id:    m.azienda_id,
      nome:  m.aziende?.nome || "Azienda",
      logo:  m.aziende?.logo || null,
      ruolo: m.ruolo || "commerciale",
    }));
  },

  // SUPER ADMIN: elenco di TUTTE le aziende registrate (con i membri).
  // Funziona solo per un utente con super_admin=true (le policy RLS della
  // Tappa 5 lasciano leggere tutto solo a lui; per gli altri torna solo le
  // proprie aziende, quindi è comunque sicuro).
  async getTutteAziende() {
    const { data: az, error } = await _sb
      .from("aziende")
      .select("id, nome, logo, created_at")
      .order("created_at");
    if (error) { console.error("getTutteAziende:", error.message); return []; }
    const { data: membri } = await _sb
      .from("membri")
      .select("azienda_id, ruolo, utenti(nome, email)");
    const perAz = {};
    (membri || []).forEach(m => {
      if (!perAz[m.azienda_id]) perAz[m.azienda_id] = [];
      perAz[m.azienda_id].push({ ruolo: m.ruolo, nome: m.utenti?.nome || "", email: m.utenti?.email || "" });
    });
    // Licenze (tabella Tappa 6: se manca, l'errore viene ignorato)
    const licByAz = {};
    const { data: lic } = await _sb.from("licenze").select("*");
    (lic || []).forEach(l => { licByAz[l.azienda_id] = l; });
    return (az || []).map(a => ({ ...a, membri: perAz[a.id] || [], licenza: licByAz[a.id] || null }));
  },

  // ----------------------------------------------------------
  // LICENZE (Tappa 6) — gestite solo dal super admin
  // ----------------------------------------------------------
  // Licenza della singola azienda. Torna:
  //   - l'oggetto licenza se presente
  //   - null se l'azienda non ha licenza
  //   - undefined se la tabella non esiste ancora / errore (→ non bloccare)
  async getLicenzaAzienda(aziendaId) {
    if (!aziendaId) return null;
    const { data, error } = await _sb
      .from("licenze").select("*").eq("azienda_id", aziendaId).maybeSingle();
    if (error) { console.error("getLicenzaAzienda:", error.message); return undefined; }
    return data || null;
  },

  // Crea o aggiorna la licenza di un'azienda (upsert per azienda_id)
  async salvaLicenza(aziendaId, dati) {
    const payload = {
      azienda_id:     aziendaId,
      piano:          dati.piano || "trial",
      stato:          dati.stato || "attiva",
      data_inizio:    dati.data_inizio || new Date().toISOString().slice(0, 10),
      data_fine:      dati.data_fine || null,
      max_utenti:     (dati.max_utenti === "" || dati.max_utenti == null) ? null : Number(dati.max_utenti),
      max_preventivi: (dati.max_preventivi === "" || dati.max_preventivi == null) ? null : Number(dati.max_preventivi),
      note:           dati.note || null,
      updated_at:     new Date().toISOString(),
    };
    const { data, error } = await _sb
      .from("licenze").upsert([payload], { onConflict: "azienda_id" }).select("*").single();
    if (error) { console.error("salvaLicenza:", error.message); return { __errore: error.message }; }
    return data;
  },

  // Revoca (elimina) la licenza di un'azienda
  async revocaLicenza(aziendaId) {
    const { error } = await _sb.from("licenze").delete().eq("azienda_id", aziendaId);
    if (error) { console.error("revocaLicenza:", error.message); return { __errore: error.message }; }
    return { ok: true };
  },

  // Rinomina un'azienda (super admin)
  async rinominaAzienda(aziendaId, nome) {
    const { data, error } = await _sb
      .from("aziende").update({ nome: (nome || "").trim() }).eq("id", aziendaId).select("id, nome, logo").single();
    if (error) { console.error("rinominaAzienda:", error.message); return { __errore: error.message }; }
    return data;
  },

  // Elimina un'azienda (super admin). Fallisce se contiene ancora dati collegati.
  async eliminaAzienda(aziendaId) {
    const { error } = await _sb.from("aziende").delete().eq("id", aziendaId);
    if (error) { console.error("eliminaAzienda:", error.message); return { __errore: error.message }; }
    return { ok: true };
  },

  // Conta i preventivi dell'azienda attiva (per i limiti di piano)
  async contaPreventivi() {
    const { count, error } = await _scopeAzienda(_sb
      .from("preventivi").select("id", { count: "exact", head: true }));
    if (error) { console.error("contaPreventivi:", error.message); return null; }
    return count;
  },

  // Recupera o crea il profilo utente (globale) in base all'email
  async assicuraProfilo(email, nome) {
    const em = (email || "").trim().toLowerCase();
    const { data: ex } = await _sb.from("utenti")
      .select("id, username, email, nome, attivo, avatar, menu_utente")
      .eq("email", em).maybeSingle();
    if (ex) return ex;
    const username = em.split("@")[0] || em;
    const ins = await _sb.from("utenti")
      .insert([{ username, email: em, nome: (nome || username), ruolo: "admin", attivo: true }])
      .select("id, username, email, nome, attivo, avatar, menu_utente").single();
    if (ins.error) { console.error("assicuraProfilo:", ins.error.message); return { __errore: ins.error.message }; }
    return ins.data;
  },

  // Crea una nuova azienda
  async creaAzienda(nome) {
    const { data, error } = await _sb.from("aziende")
      .insert([{ nome: (nome || "La mia azienda").trim() }])
      .select("id, nome, logo").single();
    if (error) { console.error("creaAzienda:", error.message); return { __errore: error.message }; }
    return data;
  },

  // Iscrive un utente a un'azienda con un ruolo
  async aggiungiMembro(aziendaId, utenteId, ruolo = "commerciale") {
    const { error } = await _sb.from("membri")
      .insert([{ azienda_id: aziendaId, utente_id: utenteId, ruolo }]);
    if (error && error.code !== "23505") { console.error("aggiungiMembro:", error.message); return { __errore: error.message }; }
    return { ok: true };
  },

  // Popola una nuova azienda con ruoli di sistema e categorie di base
  async seedAzienda(aziendaId) {
    await _sb.from("ruoli").insert([
      { azienda_id: aziendaId, nome: "Amministratore", chiave: "admin", descrizione: "Accesso completo", sconto_max: 100, sistema: true,
        permessi: { dashboard:"entrambi", listino:"entrambi", gestione_prodotti:"entrambi", preventivi_propri:"entrambi", preventivi_tutti:"entrambi", approva_preventivi:"entrambi", clienti:"entrambi", bandi:"entrambi", gestione_categorie:"entrambi", gestione_utenti:"entrambi", gestione_ruoli:"entrambi", impostazioni:"entrambi" } },
      { azienda_id: aziendaId, nome: "Commerciale", chiave: "commerciale", descrizione: "Accesso operativo", sconto_max: 20, sistema: true,
        permessi: { dashboard:"lettura", listino:"lettura", preventivi_propri:"entrambi", clienti:"entrambi", bandi:"lettura" } },
    ]);
    await _sb.from("categorie").insert([
      { azienda_id: aziendaId, nome: "software", icona: "💻", ordine: 1 },
      { azienda_id: aziendaId, nome: "servizi",  icona: "🛠️", ordine: 2 },
      { azienda_id: aziendaId, nome: "hardware", icona: "🖥️", ordine: 3 },
    ]);
    // Licenza di prova (14 giorni) per la nuova azienda (Tappa 6; se la
    // tabella non esiste ancora l'errore è ignorato)
    try {
      const oggi = new Date();
      const fine = new Date(oggi.getTime() + 14 * 24 * 60 * 60 * 1000);
      await _sb.from("licenze").insert([{
        azienda_id: aziendaId, piano: "trial", stato: "attiva",
        data_inizio: oggi.toISOString().slice(0, 10),
        data_fine:   fine.toISOString().slice(0, 10),
        max_utenti: 2, max_preventivi: 20,
      }]);
    } catch (_) { /* tabella licenze non presente: ignora */ }
    return true;
  },

  // ----------------------------------------------------------
  // PRODOTTI
  // ----------------------------------------------------------
  async getProdotti() {
    const { data, error } = await _scopeAzienda(_sb
      .from("prodotti")
      .select("*")
      .order("id"));
    if (error) { console.error("getProdotti:", error.message); return []; }
    return data;
  },

  async inserisciProdotto(dati) {
    const { data, error } = await _sb
      .from("prodotti")
      .insert([{
        azienda_id:  _aziendaAttiva,
        nome:        dati.nome,
        categoria:   dati.categoria || "software",
        prezzo:      parseFloat(dati.prezzo) || 0,
        descrizione: dati.descrizione || "",
        immagine:    dati.immagine || null,
        attivo:      true,
      }])
      .select()
      .single();
    if (error) { console.error("inserisciProdotto:", error.message); return { __errore: error.message }; }
    return data;
  },

  async aggiornaProdotto(id, dati) {
    const { data, error } = await _sb
      .from("prodotti")
      .update({
        nome:        dati.nome,
        categoria:   dati.categoria,
        prezzo:      parseFloat(dati.prezzo) || 0,
        descrizione: dati.descrizione || "",
        immagine:    dati.immagine || null,
      })
      .eq("id", id)
      .select()
      .single();
    if (error) { console.error("aggiornaProdotto:", error.message); return { __errore: error.message }; }
    return data;
  },

  async eliminaProdotto(id) {
    const { error } = await _sb.from("prodotti").delete().eq("id", id);
    if (error) { console.error("eliminaProdotto:", error.message); return false; }
    return true;
  },

  // ----------------------------------------------------------
  // CLIENTI
  // ----------------------------------------------------------
  async getClienti() {
    const { data, error } = await _scopeAzienda(_sb
      .from("clienti")
      .select("*")
      .order("nome"));
    if (error) { console.error("getClienti:", error.message); return []; }
    return data;
  },

  // Ritorna il primo cliente trovato che è un duplicato, o null
  async cercaDuplicatoCliente({ piva, nome, cf, escludiId }) {
    // Carica i clienti dell'azienda attiva e filtra in JS
    const { data: tutti } = await _scopeAzienda(_sb
      .from("clienti")
      .select("id, nome, piva, codice_fiscale"));

    if (!tutti) return null;

    const altri = escludiId ? tutti.filter(c => c.id !== escludiId) : tutti;

    if (piva) {
      const p = piva.toUpperCase().replace(/^IT/, "");
      return altri.find(c => {
        const cp = (c.piva || "").toUpperCase().replace(/^IT/, "");
        return cp === p && cp !== "";
      }) ?? null;
    }

    if (nome) {
      const n = nome.trim().toLowerCase();
      const trovato = altri.find(c => (c.nome || "").trim().toLowerCase() === n);
      if (trovato) return trovato;
      if (cf && cf.trim()) {
        const f = cf.trim().toLowerCase();
        return altri.find(c => (c.codice_fiscale || "").trim().toLowerCase() === f) ?? null;
      }
      return null;
    }

    return null;
  },

  async inserisciCliente(dati) {
    const { data, error } = await _sb
      .from("clienti")
      .insert([{
        azienda_id:      _aziendaAttiva,
        tipo_cliente:    dati.tipo_cliente    || "azienda",
        nome:            dati.nome,
        referente:       dati.referente       || "",
        email:           dati.email           || "",
        telefono:        dati.telefono        || "",
        piva:            dati.piva            || "",
        codice_fiscale:  dati.codice_fiscale  || "",
        indirizzo:       dati.indirizzo       || "",
        civico:          dati.civico          || "",
        cap:             dati.cap             || "",
        citta:           dati.citta           || "",
        provincia:       dati.provincia       || "",
        ateco:           dati.ateco           || "",
        settore:         dati.settore         || "ristorazione",
        regione:         dati.regione         || "lombardia",
        note:            dati.note            || "",
      }])
      .select()
      .single();
    if (error) {
      if (error.code === "23505") return { __errDuplicato: true };
      console.error("inserisciCliente:", error.message);
      return null;
    }
    return data;
  },

  async aggiornaCliente(id, dati) {
    const { data, error } = await _sb
      .from("clienti")
      .update({
        tipo_cliente:    dati.tipo_cliente    || "azienda",
        nome:            dati.nome,
        referente:       dati.referente       || "",
        email:           dati.email           || "",
        telefono:        dati.telefono        || "",
        piva:            dati.piva            || "",
        codice_fiscale:  dati.codice_fiscale  || "",
        indirizzo:       dati.indirizzo       || "",
        civico:          dati.civico          || "",
        cap:             dati.cap             || "",
        citta:           dati.citta           || "",
        provincia:       dati.provincia       || "",
        ateco:           dati.ateco           || "",
        settore:         dati.settore         || "ristorazione",
        regione:         dati.regione         || "lombardia",
        note:            dati.note            || "",
      })
      .eq("id", id)
      .select()
      .single();
    if (error) {
      if (error.code === "23505") return { __errDuplicato: true };
      console.error("aggiornaCliente:", error.message);
      return null;
    }
    return data;
  },

  async eliminaCliente(id) {
    const { error } = await _sb.from("clienti").delete().eq("id", id);
    if (error) { console.error("eliminaCliente:", error.message); return false; }
    return true;
  },

  // ----------------------------------------------------------
  // PREVENTIVI
  // ----------------------------------------------------------
  async getPreventivi(soloUtenteId = null) {
    let query = _scopeAzienda(_sb
      .from("preventivi")
      .select("*")
      .order("created_at", { ascending: false }));
    // Se richiesto, scarica solo i preventivi di un dato commerciale
    if (soloUtenteId) query = query.eq("utente_id", soloUtenteId);
    const { data, error } = await query;
    if (error) { console.error("getPreventivi:", error.message); return []; }
    // Normalizza: mappa created_at → data per compatibilità con il resto del codice
    return data.map(p => ({ ...p, data: p.created_at }));
  },

  async inserisciPreventivo(dati) {
    // Prima inserisci senza numero per ottenere l'id
    const { data, error } = await _sb
      .from("preventivi")
      .insert([{
        azienda_id:   _aziendaAttiva,
        cliente_id:   dati.clienteId   || null,
        cliente_nome: dati.clienteNome || "",
        utente_id:    (typeof getUtenteSessione === "function" ? getUtenteSessione()?.id : null) || null,
        righe:        dati.righe       || [],
        sconto:       dati.sconto      || 0,
        note:         dati.note        || "",
        subtotale:    dati.subtotale   || 0,
        imp_sconto:   dati.impSconto   || 0,
        imponibile:   dati.imponibile  || 0,
        iva:          dati.iva         || 0,
        totale_iva:   dati.totaleIva   || 0,
        stato:        dati.stato       || "bozza",
      }])
      .select()
      .single();
    if (error) { console.error("inserisciPreventivo:", error.message); return null; }

    // Genera numero con l'id appena creato e aggiorna
    const numero = `PRV-${String(data.id).padStart(4, "0")}`;
    await _sb.from("preventivi").update({ numero }).eq("id", data.id);

    return { ...data, numero, data: data.created_at };
  },

  async aggiornaPreventivo(id, dati) {
    const { data, error } = await _sb
      .from("preventivi")
      .update({
        cliente_id:   dati.clienteId   || null,
        cliente_nome: dati.clienteNome || "",
        righe:        dati.righe       || [],
        note:         dati.note        || "",
        subtotale:    dati.subtotale   || 0,
        imp_sconto:   dati.impSconto   || 0,
        imponibile:   dati.imponibile  || 0,
        iva:          dati.iva         || 0,
        totale_iva:   dati.totaleIva   || 0,
        stato:        dati.stato       || "bozza",
      })
      .eq("id", id)
      .select()
      .single();
    if (error) { console.error("aggiornaPreventivo:", error.message); return null; }
    return { ...data, data: data.created_at };
  },

  async aggiornaStato(id, stato) {
    const { error } = await _sb
      .from("preventivi")
      .update({ stato })
      .eq("id", id);
    if (error) { console.error("aggiornaStato:", error.message); return false; }
    return true;
  },

  // Crea una nuova revisione di un preventivo:
  // 1) segna il vecchio come "revisionato"
  // 2) inserisce una copia con lo stesso numero base e revisione +1
  async creaRevisione(vecchio) {
    const { error: e1 } = await _sb
      .from("preventivi")
      .update({ stato: "revisionato" })
      .eq("id", vecchio.id);
    if (e1) { console.error("creaRevisione (vecchio):", e1.message); return { __errore: e1.message }; }

    // Numero univoco che mantiene la parentela: base + "-R" + numero revisione
    // (la colonna numero ha un vincolo UNIQUE, quindi non si può riusare lo stesso)
    const baseNum  = (vecchio.numero || "").replace(/-R\d+$/, "");
    const nuovaRev = (vecchio.revisione || 0) + 1;
    const nuovoNumero = baseNum ? `${baseNum}-R${nuovaRev}` : null;

    const { data, error } = await _sb
      .from("preventivi")
      .insert([{
        azienda_id:   _aziendaAttiva || vecchio.azienda_id || null,
        cliente_id:   vecchio.cliente_id   || null,
        cliente_nome: vecchio.cliente_nome || "",
        utente_id:    (typeof getUtenteSessione === "function" ? getUtenteSessione()?.id : null) || vecchio.utente_id || null,
        righe:        vecchio.righe        || [],
        sconto:       vecchio.sconto       || 0,
        note:         vecchio.note         || "",
        subtotale:    vecchio.subtotale    || 0,
        imp_sconto:   vecchio.imp_sconto   || 0,
        imponibile:   vecchio.imponibile   || 0,
        iva:          vecchio.iva          || 0,
        totale_iva:   vecchio.totale_iva   || 0,
        stato:        "inviato",
        numero:       nuovoNumero,
        revisione:    nuovaRev,
      }])
      .select()
      .single();
    if (error) { console.error("creaRevisione (nuovo):", error.message); return { __errore: error.message }; }
    return { ...data, data: data.created_at };
  },

  async eliminaPreventivo(id) {
    const { error } = await _sb.from("preventivi").delete().eq("id", id);
    if (error) { console.error("eliminaPreventivo:", error.message); return false; }
    return true;
  },

  // ----------------------------------------------------------
  // CATEGORIE
  // ----------------------------------------------------------
  async getCategorie() {
    const { data, error } = await _scopeAzienda(_sb
      .from("categorie")
      .select("*")
      .order("ordine"));
    if (error) { console.error("getCategorie:", error.message); return []; }
    return data;
  },

  async inserisciCategoria(dati) {
    const { data, error } = await _sb
      .from("categorie")
      .insert([{ azienda_id: _aziendaAttiva, nome: dati.nome, icona: dati.icona || "📦", ordine: dati.ordine || 0 }])
      .select()
      .single();
    if (error) { console.error("inserisciCategoria:", error.message); return null; }
    return data;
  },

  async aggiornaCategoria(id, dati) {
    const { data, error } = await _sb
      .from("categorie")
      .update({ nome: dati.nome, icona: dati.icona || "📦", ordine: dati.ordine || 0 })
      .eq("id", id)
      .select()
      .single();
    if (error) { console.error("aggiornaCategoria:", error.message); return null; }
    return data;
  },

  async eliminaCategoria(id) {
    const { error } = await _sb.from("categorie").delete().eq("id", id);
    if (error) { console.error("eliminaCategoria:", error.message); return false; }
    return true;
  },

  // ----------------------------------------------------------
  // UTENTI
  // ----------------------------------------------------------
  // Elenco dei MEMBRI dell'azienda attiva (con il ruolo per azienda)
  async getUtenti() {
    if (!_aziendaAttiva) return [];
    const { data, error } = await _sb
      .from("membri")
      .select("ruolo, utenti(id, username, email, nome, attivo, avatar, menu_utente, created_at)")
      .eq("azienda_id", _aziendaAttiva);
    if (error) { console.error("getUtenti:", error.message); return []; }
    return (data || []).filter(m => m.utenti).map(m => ({ ...m.utenti, ruolo: m.ruolo }));
  },

  // Crea l'utente globale (o riusa quello con la stessa email) e lo iscrive
  // come membro dell'azienda attiva con il ruolo scelto.
  async inserisciUtente(dati, passwordHash) {
    const email = (dati.email || "").trim().toLowerCase() || null;
    let utente = null;
    const ins = await _sb
      .from("utenti")
      .insert([{
        username:      dati.username.trim().toLowerCase(),
        email,
        password_hash: passwordHash,
        nome:          dati.nome        || "",
        ruolo:         dati.ruolo       || "commerciale",
        avatar:        dati.avatar      || null,
        menu_utente:   dati.menu_utente || null,
        attivo:        true,
      }])
      .select("id, username, email, nome, attivo, avatar, menu_utente")
      .single();
    if (ins.error) {
      // Se l'utente esiste già (email/username duplicati), lo riusa
      if (ins.error.code === "23505" && email) {
        const { data: ex } = await _sb.from("utenti")
          .select("id, username, email, nome, attivo, avatar, menu_utente")
          .eq("email", email).maybeSingle();
        utente = ex || null;
      }
      if (!utente) { console.error("inserisciUtente:", ins.error.message); return { __errore: ins.error.message }; }
    } else {
      utente = ins.data;
    }
    // Iscrizione come membro dell'azienda attiva
    const { error: eM } = await _sb.from("membri")
      .insert([{ azienda_id: _aziendaAttiva, utente_id: utente.id, ruolo: dati.ruolo || "commerciale" }]);
    if (eM && eM.code !== "23505") { console.error("inserisciUtente/membri:", eM.message); return { __errore: eM.message }; }
    return { ...utente, ruolo: dati.ruolo || "commerciale" };
  },

  async aggiornaUtente(id, dati) {
    const aggiornamenti = { nome: dati.nome || "", attivo: dati.attivo !== false };
    if (dati.avatar      !== undefined) aggiornamenti.avatar      = dati.avatar      || null;
    if (dati.menu_utente !== undefined) aggiornamenti.menu_utente = dati.menu_utente || null;
    if (dati._nuovaPasswordHash)        aggiornamenti.password_hash = dati._nuovaPasswordHash;
    const { data, error } = await _sb
      .from("utenti")
      .update(aggiornamenti)
      .eq("id", id)
      .select("id, username, email, nome, attivo, avatar, menu_utente")
      .single();
    if (error) { console.error("aggiornaUtente:", error.message); return null; }
    // Il ruolo è per-azienda: aggiorna la riga in membri dell'azienda attiva
    const ruolo = dati.ruolo || "commerciale";
    if (_aziendaAttiva) {
      await _sb.from("membri").update({ ruolo }).eq("azienda_id", _aziendaAttiva).eq("utente_id", id);
    }
    return { ...data, ruolo };
  },

  // "Elimina" = rimuove l'utente dall'azienda attiva (non cancella l'account globale)
  async eliminaUtente(id) {
    if (!_aziendaAttiva) return false;
    const { error } = await _sb.from("membri").delete()
      .eq("azienda_id", _aziendaAttiva).eq("utente_id", id);
    if (error) { console.error("eliminaUtente:", error.message); return false; }
    return true;
  },

  // ----------------------------------------------------------
  // RUOLI
  // ----------------------------------------------------------
  async getRuoli() {
    const { data, error } = await _scopeAzienda(_sb
      .from("ruoli")
      .select("*")
      .order("nome"));
    if (error) { console.error("getRuoli:", error.message); return []; }
    return data;
  },

  async inserisciRuolo(dati) {
    const { data, error } = await _sb
      .from("ruoli")
      .insert([{
        azienda_id:  _aziendaAttiva,
        nome:        dati.nome.trim(),
        chiave:      (dati.chiave || dati.nome).trim().toLowerCase().replace(/[\s\W]+/g, "_"),
        descrizione: dati.descrizione || "",
        sconto_max:  parseInt(dati.sconto_max) || 0,
        permessi:    dati.permessi || {},
        sistema:     false,
      }])
      .select()
      .single();
    if (error) { console.error("inserisciRuolo:", error.message); return null; }
    return data;
  },

  async aggiornaRuolo(id, dati) {
    const { data, error } = await _sb
      .from("ruoli")
      .update({
        nome:        dati.nome.trim(),
        descrizione: dati.descrizione || "",
        sconto_max:  parseInt(dati.sconto_max) || 0,
        permessi:    dati.permessi || {},
      })
      .eq("id", id)
      .select()
      .single();
    if (error) { console.error("aggiornaRuolo:", error.message); return null; }
    return data;
  },

  async eliminaRuolo(id) {
    const { error } = await _sb.from("ruoli").delete().eq("id", id);
    if (error) { console.error("eliminaRuolo:", error.message); return false; }
    return true;
  },

  // ----------------------------------------------------------
  // BANDI INCENTIVI
  // ----------------------------------------------------------
  async getBandi() {
    const { data, error } = await _sb
      .from("bandi_incentivi")
      .select("*")
      .neq("stato", "scaduto")
      .order("data_chiusura", { ascending: true, nullsFirst: false });
    if (error) throw new Error(error.message);
    return data || [];
  },

  async upsertBandi(records) {
    const { error } = await _sb
      .from("bandi_incentivi")
      .upsert(records, { onConflict: "id" });
    if (error) throw new Error(error.message);
  },

  // ----------------------------------------------------------
  // BANDI FONTI — gestione multi-fonte
  // ----------------------------------------------------------
  async getFontiBandi() {
    const { data, error } = await _sb
      .from("bandi_fonti")
      .select("*")
      .order("nome");
    if (error) { console.error("getFontiBandi:", error.message); return []; }
    return data || [];
  },

  async salvaFonteBandi(dati) {
    const { data, error } = await _sb
      .from("bandi_fonti")
      .upsert({
        id:     dati.id || dati.nome.toLowerCase().replace(/\W+/g, "_"),
        nome:   dati.nome,
        url:    dati.url   || "",
        tipo:   dati.tipo  || "rss",
        attiva: dati.attiva !== false,
        note:   dati.note  || "",
      }, { onConflict: "id" })
      .select()
      .single();
    if (error) { console.error("salvaFonteBandi:", error.message); return null; }
    return data;
  },

  async toggleFonteBandi(id, attiva) {
    const { error } = await _sb
      .from("bandi_fonti")
      .update({ attiva })
      .eq("id", id);
    if (error) { console.error("toggleFonteBandi:", error.message); return false; }
    return true;
  },

  async eliminaFonteBandi(id) {
    const { error } = await _sb.from("bandi_fonti").delete().eq("id", id);
    if (error) { console.error("eliminaFonteBandi:", error.message); return false; }
    return true;
  },

  async scriviLogManuale(importati, totale) {
    const { error } = await _sb.from("bandi_sync_log").insert({
      fonte_id:      "incentivi_gov",
      stato:         "ok",
      importati,
      totale_fonte:  totale,
      errore:        null,
      avviato_il:    new Date().toISOString(),
      completato_il: new Date().toISOString(),
    });
    if (error) console.warn("scriviLogManuale:", error.message);
    // Aggiorna anche bandi_fonti
    await _sb.from("bandi_fonti").update({
      sync_stato:     "ok",
      ultimo_sync:    new Date().toISOString(),
      sync_importati: importati,
      sync_errore:    null,
    }).eq("id", "incentivi_gov");
  },

  async getSyncLog(fonteId = null, limit = 20) {
    let q = _sb
      .from("bandi_sync_log")
      .select("*, bandi_fonti(nome)")
      .order("avviato_il", { ascending: false })
      .limit(limit);
    if (fonteId) q = q.eq("fonte_id", fonteId);
    const { data, error } = await q;
    if (error) { console.error("getSyncLog:", error.message); return []; }
    return data || [];
  },

  // Chiama la Edge Function per avviare una sync
  // fonteId: null = tutte le fonti, oppure id specifico
  async avviaSyncBandi(fonteId = null) {
    const urlBase = SUPABASE_URL + "/functions/v1/sync-bandi";
    const url = fonteId ? urlBase + "?fonte=" + encodeURIComponent(fonteId) : urlBase;
    try {
      const res = await fetch(url, {
        method:  "POST",
        headers: {
          "Authorization": "Bearer " + SUPABASE_ANON,
          "Content-Type":  "application/json",
        },
        body: "{}",
      });
      // Legge prima il testo grezzo per mostrare errori di parsing
      const testo = await res.text();
      let json;
      try {
        json = JSON.parse(testo);
      } catch (_) {
        // La funzione ha risposto ma non è JSON valido
        json = { ok: false, error: `HTTP ${res.status} — ${testo.substring(0, 300)}` };
      }
      // Se HTTP error senza campo error nel JSON, aggiungiamo lo status
      if (!res.ok && !json.error) {
        json.error = `HTTP ${res.status}`;
      }
      console.log("avviaSyncBandi risposta:", json);
      return json;
    } catch (e) {
      console.error("avviaSyncBandi errore:", e.message);
      return { ok: false, error: e.message };
    }
  },

  // ----------------------------------------------------------
  // CREDITSAFE — verifica P.IVA
  // ----------------------------------------------------------
  async cercaVIES(piva) {
    try {
      const res = await fetch(SUPABASE_URL + "/functions/v1/creditsafe", {
        method:  "POST",
        headers: { "Authorization": "Bearer " + SUPABASE_ANON, "Content-Type": "application/json" },
        body: JSON.stringify({ action: "vies", piva }),
      });
      const testo = await res.text();
      try { return JSON.parse(testo); } catch (_) { return { ok: false, error: testo.substring(0, 200) }; }
    } catch (e) { return { ok: false, error: e.message }; }
  },

  async verificaPIVA(piva) {
    try {
      const res = await fetch(SUPABASE_URL + "/functions/v1/creditsafe", {
        method:  "POST",
        headers: {
          "Authorization": "Bearer " + SUPABASE_ANON,
          "Content-Type":  "application/json",
        },
        body: JSON.stringify({ piva }),
      });
      const testo = await res.text();
      try {
        return JSON.parse(testo);
      } catch (_) {
        return { ok: false, error: `HTTP ${res.status} — ${testo.substring(0, 300)}` };
      }
    } catch (e) {
      return { ok: false, error: e.message };
    }
  },

  // ----------------------------------------------------------
  // IMPOSTAZIONI AZIENDALI (chiave/valore)
  // ----------------------------------------------------------
  async getImpostazioni() {
    const { data, error } = await _sb.from("impostazioni").select("chiave, valore");
    if (error) { console.error("getImpostazioni:", error.message); return {}; }
    return Object.fromEntries((data || []).map(r => [r.chiave, r.valore]));
  },

  async salvaImpostazione(chiave, valore) {
    const { error } = await _sb
      .from("impostazioni")
      .upsert({ chiave, valore, updated_at: new Date().toISOString() }, { onConflict: "chiave" });
    if (error) { console.error("salvaImpostazione:", error.message); return false; }
    return true;
  },
};
