// ============================================================
// supabase.js — Client Supabase e funzioni CRUD
// ============================================================
// 1. Vai su https://supabase.com → il tuo progetto
// 2. Settings → API
// 3. Copia "Project URL" e "anon public key" qui sotto
// ============================================================

const SUPABASE_URL  = "https://segbfdfoqxrnitboeyof.supabase.co";
const SUPABASE_ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlZ2JmZGZvcXhybml0Ym9leW9mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxMzIxNzksImV4cCI6MjA5NzcwODE3OX0.v5ZGCkqTduegxFaa6GOYUIIHrQ5cQe0JFB7PGO93XNo";

// Inizializza client (CDN carica la libreria come window.supabase)
const _sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON);

// ============================================================
// Oggetto SP — tutte le operazioni sul database
// ============================================================
const SP = {

  // ----------------------------------------------------------
  // PRODOTTI
  // ----------------------------------------------------------
  async getProdotti() {
    const { data, error } = await _sb
      .from("prodotti")
      .select("*")
      .order("id");
    if (error) { console.error("getProdotti:", error.message); return []; }
    return data;
  },

  async inserisciProdotto(dati) {
    const { data, error } = await _sb
      .from("prodotti")
      .insert([{
        nome:        dati.nome,
        categoria:   dati.categoria || "software",
        prezzo:      parseFloat(dati.prezzo) || 0,
        descrizione: dati.descrizione || "",
        attivo:      true,
      }])
      .select()
      .single();
    if (error) { console.error("inserisciProdotto:", error.message); return null; }
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
      })
      .eq("id", id)
      .select()
      .single();
    if (error) { console.error("aggiornaProdotto:", error.message); return null; }
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
    const { data, error } = await _sb
      .from("clienti")
      .select("*")
      .order("nome");
    if (error) { console.error("getClienti:", error.message); return []; }
    return data;
  },

  // Ritorna il primo cliente trovato che è un duplicato, o null
  async cercaDuplicatoCliente({ piva, nome, cf, escludiId }) {
    // Carica tutti i clienti e filtra in JS — evita problemi di sintassi PostgREST
    const { data: tutti } = await _sb
      .from("clienti")
      .select("id, nome, piva, codice_fiscale");

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
  async getPreventivi() {
    const { data, error } = await _sb
      .from("preventivi")
      .select("*")
      .order("created_at", { ascending: false });
    if (error) { console.error("getPreventivi:", error.message); return []; }
    // Normalizza: mappa created_at → data per compatibilità con il resto del codice
    return data.map(p => ({ ...p, data: p.created_at }));
  },

  async inserisciPreventivo(dati) {
    // Prima inserisci senza numero per ottenere l'id
    const { data, error } = await _sb
      .from("preventivi")
      .insert([{
        cliente_id:   dati.clienteId   || null,
        cliente_nome: dati.clienteNome || "",
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

  async eliminaPreventivo(id) {
    const { error } = await _sb.from("preventivi").delete().eq("id", id);
    if (error) { console.error("eliminaPreventivo:", error.message); return false; }
    return true;
  },

  // ----------------------------------------------------------
  // CATEGORIE
  // ----------------------------------------------------------
  async getCategorie() {
    const { data, error } = await _sb
      .from("categorie")
      .select("*")
      .order("ordine");
    if (error) { console.error("getCategorie:", error.message); return []; }
    return data;
  },

  async inserisciCategoria(dati) {
    const { data, error } = await _sb
      .from("categorie")
      .insert([{ nome: dati.nome, icona: dati.icona || "📦", ordine: dati.ordine || 0 }])
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
  async getUtenti() {
    const { data, error } = await _sb
      .from("utenti")
      .select("id, username, nome, ruolo, attivo, avatar, menu_utente, created_at")
      .order("nome");
    if (error) { console.error("getUtenti:", error.message); return []; }
    return data;
  },

  async inserisciUtente(dati, passwordHash) {
    const { data, error } = await _sb
      .from("utenti")
      .insert([{
        username:      dati.username.trim().toLowerCase(),
        password_hash: passwordHash,
        nome:          dati.nome        || "",
        ruolo:         dati.ruolo       || "commerciale",
        avatar:        dati.avatar      || null,
        menu_utente:   dati.menu_utente || null,
        attivo:        true,
      }])
      .select("id, username, nome, ruolo, attivo, avatar, menu_utente")
      .single();
    if (error) { console.error("inserisciUtente:", error.message); return null; }
    return data;
  },

  async aggiornaUtente(id, dati) {
    const aggiornamenti = {
      nome:        dati.nome   || "",
      ruolo:       dati.ruolo  || "commerciale",
      attivo:      dati.attivo !== false,
      avatar:      dati.avatar      !== undefined ? (dati.avatar      || null) : undefined,
      menu_utente: dati.menu_utente !== undefined ? (dati.menu_utente || null) : undefined,
    };
    // Rimuovi undefined
    Object.keys(aggiornamenti).forEach(k => aggiornamenti[k] === undefined && delete aggiornamenti[k]);
    // Aggiorna password solo se fornita
    if (dati._nuovaPasswordHash) {
      aggiornamenti.password_hash = dati._nuovaPasswordHash;
    }
    const { data, error } = await _sb
      .from("utenti")
      .update(aggiornamenti)
      .eq("id", id)
      .select("id, username, nome, ruolo, attivo, avatar, menu_utente")
      .single();
    if (error) { console.error("aggiornaUtente:", error.message); return null; }
    return data;
  },

  async eliminaUtente(id) {
    const { error } = await _sb.from("utenti").delete().eq("id", id);
    if (error) { console.error("eliminaUtente:", error.message); return false; }
    return true;
  },

  // ----------------------------------------------------------
  // RUOLI
  // ----------------------------------------------------------
  async getRuoli() {
    const { data, error } = await _sb
      .from("ruoli")
      .select("*")
      .order("nome");
    if (error) { console.error("getRuoli:", error.message); return []; }
    return data;
  },

  async inserisciRuolo(dati) {
    const { data, error } = await _sb
      .from("ruoli")
      .insert([{
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
