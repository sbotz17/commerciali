// ============================================================
// sp-firestore.js — Data layer Firestore con la stessa interfaccia SP
// ============================================================
// Le pagine usano SP.* come prima; cambia solo l'implementazione.
// Collezioni "piatte" con azienda_id, così le query restano semplici
// e le Security Rules possono verificare l'appartenenza all'azienda.
// ============================================================

let _aziendaAttiva = null;

const SP = {
  // ---------- helper ----------
  _col(name) { return fbDb.collection(name); },
  _now() { return new Date().toISOString(); },
  _doc(doc) { return doc && doc.exists ? { id: doc.id, ...doc.data() } : null; },
  _snap(q) { return q.docs.map(d => ({ id: d.id, ...d.data() })); },
  _scope(q) { return _aziendaAttiva ? q.where("azienda_id", "==", _aziendaAttiva) : q; },
  _num(id) { return Number(id) || 0; },
  _sortBy(arr, field, dir = "asc") {
    return arr.sort((a, b) => {
      const va = a[field] ?? "", vb = b[field] ?? "";
      if (typeof va === "number" && typeof vb === "number") return dir === "asc" ? va - vb : vb - va;
      return dir === "asc" ? String(va).localeCompare(String(vb), "it") : String(vb).localeCompare(String(va), "it");
    });
  },

  // ---------- azienda attiva ----------
  setAziendaAttiva(id) { _aziendaAttiva = id || null; },
  getAziendaAttiva() { return _aziendaAttiva; },

  // ---------- AZIENDE / MEMBRI ----------
  async getAziendeUtente(utenteId) {
    const mem = await this._col("membri").where("utente_id", "==", utenteId).get();
    const out = [];
    for (const m of mem.docs) {
      const az = await this._col("aziende").doc(m.data().azienda_id).get();
      if (!az.exists) continue;
      const a = az.data();
      out.push({
        id: az.id,
        nome: a.nome || "Azienda",
        logo: a.logo || null,
        ruolo: m.data().ruolo || "commerciale",
        whatsapp_attivo: !!a.whatsapp_attivo,
      });
    }
    return out;
  },

  async getTutteAziende() {
    const [azSnap, memSnap, utSnap, licSnap] = await Promise.all([
      this._col("aziende").get(),
      this._col("membri").get(),
      this._col("utenti").get(),
      this._col("licenze").get(),
    ]);
    const utenti = {};
    utSnap.docs.forEach(d => { utenti[d.id] = d.data(); });
    const perAz = {};
    memSnap.docs.forEach(d => {
      const m = d.data();
      if (!perAz[m.azienda_id]) perAz[m.azienda_id] = [];
      const u = utenti[m.utente_id] || {};
      perAz[m.azienda_id].push({ ruolo: m.ruolo, nome: u.nome || "", email: u.email || "" });
    });
    const licByAz = {};
    licSnap.docs.forEach(d => { licByAz[d.id] = { id: d.id, ...d.data() }; });
    const az = azSnap.docs.map(d => ({ id: d.id, ...d.data() }));
    this._sortBy(az, "created_at", "asc");
    return az.map(a => ({ ...a, membri: perAz[a.id] || [], licenza: licByAz[a.id] || null }));
  },

  async getLicenzaAzienda(aziendaId) {
    if (!aziendaId) return null;
    const d = await this._col("licenze").doc(aziendaId).get();
    return this._doc(d);
  },

  async salvaLicenza(aziendaId, dati) {
    const payload = {
      azienda_id:     aziendaId,
      piano:          dati.piano || "trial",
      stato:          dati.stato || "attiva",
      data_inizio:    dati.data_inizio || this._now().slice(0, 10),
      data_fine:      dati.data_fine || null,
      max_utenti:     (dati.max_utenti === "" || dati.max_utenti == null) ? null : Number(dati.max_utenti),
      max_preventivi: (dati.max_preventivi === "" || dati.max_preventivi == null) ? null : Number(dati.max_preventivi),
      note:           dati.note || null,
      updated_at:     this._now(),
    };
    try {
      await this._col("licenze").doc(aziendaId).set(payload, { merge: true });
      return { id: aziendaId, ...payload };
    } catch (e) {
      console.error("salvaLicenza:", e.message);
      return { __errore: e.message };
    }
  },

  async revocaLicenza(aziendaId) {
    try {
      await this._col("licenze").doc(aziendaId).delete();
      return { ok: true };
    } catch (e) {
      console.error("revocaLicenza:", e.message);
      return { __errore: e.message };
    }
  },

  async rinominaAzienda(aziendaId, nome) {
    try {
      await this._col("aziende").doc(aziendaId).update({ nome: (nome || "").trim() });
      return { id: aziendaId, nome: (nome || "").trim() };
    } catch (e) {
      console.error("rinominaAzienda:", e.message);
      return { __errore: e.message };
    }
  },

  async eliminaAzienda(aziendaId) {
    try {
      await this._col("aziende").doc(aziendaId).delete();
      return { ok: true };
    } catch (e) {
      console.error("eliminaAzienda:", e.message);
      return { __errore: e.message };
    }
  },

  async creaAzienda(dati) {
    const base = (typeof dati === "string") ? { nome: dati } : (dati || {});
    const payload = { nome: (base.nome || "La mia azienda").trim(), created_at: this._now(), created_by: fbAuth.currentUser ? fbAuth.currentUser.uid : null };
    ["partita_iva", "codice_fiscale", "indirizzo", "comune", "provincia", "cap", "telefono", "email", "pec"]
      .forEach(k => { if (base[k]) payload[k] = String(base[k]).trim(); });
    try {
      const ref = await this._col("aziende").add(payload);
      return { id: ref.id, ...payload };
    } catch (e) {
      console.error("creaAzienda:", e.message);
      return { __errore: e.message };
    }
  },

  async aggiungiMembro(aziendaId, utenteId, ruolo = "commerciale") {
    try {
      await this._col("membri").doc(`${aziendaId}_${utenteId}`).set({
        azienda_id: aziendaId, utente_id: utenteId, ruolo, created_at: this._now(),
      }, { merge: true });
      return { ok: true };
    } catch (e) {
      console.error("aggiungiMembro:", e.message);
      return { __errore: e.message };
    }
  },

  async seedAzienda(aziendaId) {
    const batch = fbDb.batch();
    const ruoli = [
      { nome: "Amministratore", chiave: "admin", descrizione: "Accesso completo", sconto_max: 100, sistema: true,
        permessi: { dashboard:"entrambi", listino:"entrambi", gestione_prodotti:"entrambi", preventivi_propri:"entrambi", preventivi_tutti:"entrambi", approva_preventivi:"entrambi", clienti:"entrambi", bandi:"entrambi", gestione_categorie:"entrambi", gestione_utenti:"entrambi", gestione_ruoli:"entrambi", impostazioni:"entrambi" } },
      { nome: "Commerciale", chiave: "commerciale", descrizione: "Accesso operativo", sconto_max: 20, sistema: true,
        permessi: { dashboard:"lettura", listino:"lettura", preventivi_propri:"entrambi", clienti:"entrambi", bandi:"lettura" } },
    ];
    ruoli.forEach(r => batch.set(this._col("ruoli").doc(), { ...r, azienda_id: aziendaId, created_at: this._now() }));
    [
      { nome: "software", icona: "💻", ordine: 1 },
      { nome: "servizi",  icona: "🛠️", ordine: 2 },
      { nome: "hardware", icona: "🖥️", ordine: 3 },
    ].forEach(c => batch.set(this._col("categorie").doc(), { ...c, azienda_id: aziendaId, created_at: this._now() }));

    const oggi = new Date();
    const fine = new Date(oggi.getTime() + 14 * 24 * 60 * 60 * 1000);
    batch.set(this._col("licenze").doc(aziendaId), {
      azienda_id: aziendaId, piano: "trial", stato: "attiva",
      data_inizio: oggi.toISOString().slice(0, 10),
      data_fine: fine.toISOString().slice(0, 10),
      max_utenti: 2, max_preventivi: 20, updated_at: this._now(),
    }, { merge: true });
    try { await batch.commit(); return true; }
    catch (e) { console.error("seedAzienda:", e.message); return false; }
  },

  // ---------- PIANI ----------
  async getPianiConfig() {
    try {
      const snap = await this._col("piani_config").get();
      return snap.docs.map(d => ({ id: d.id, ...d.data() }));
    } catch (e) { console.error("getPianiConfig:", e.message); return undefined; }
  },

  async getPianoConfig(piano) {
    if (!piano) return null;
    try {
      return this._doc(await this._col("piani_config").doc(piano).get());
    } catch (e) { console.error("getPianoConfig:", e.message); return undefined; }
  },

  async salvaPianoConfig(piano, dati) {
    const norm = v => (v === "" || v == null) ? null : Number(v);
    const payload = {
      piano, pagine: dati.pagine || {},
      max_utenti: norm(dati.max_utenti), max_preventivi: norm(dati.max_preventivi),
      updated_at: this._now(),
    };
    try {
      await this._col("piani_config").doc(piano).set(payload, { merge: true });
      return { id: piano, ...payload };
    } catch (e) { console.error("salvaPianoConfig:", e.message); return { __errore: e.message }; }
  },

  // ---------- WHATSAPP ----------
  async getWhatsappConfig() {
    try { return this._doc(await this._col("whatsapp_config").doc("1").get()); }
    catch (e) { console.error("getWhatsappConfig:", e.message); return undefined; }
  },

  async salvaWhatsappConfig(dati) {
    const payload = {
      id: 1, url: dati.url || null, api_key: dati.api_key || null,
      numero: dati.numero || null, stato: dati.stato || null, updated_at: this._now(),
    };
    try {
      await this._col("whatsapp_config").doc("1").set(payload, { merge: true });
      return payload;
    } catch (e) { console.error("salvaWhatsappConfig:", e.message); return { __errore: e.message }; }
  },

  async inviaWhatsapp(numero, messaggio, mediaUrl) {
    const cfg = await this.getWhatsappConfig();
    if (!cfg || cfg.__errore || !cfg.url) return { __errore: "WhatsApp non configurato" };
    const base = String(cfg.url).replace(/\/+$/, "");
    try {
      const res = await fetch(base + "/send", {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-api-key": cfg.api_key || "" },
        body: JSON.stringify({ to: numero, message: messaggio, mediaUrl: mediaUrl || undefined }),
      });
      let j = {};
      try { j = await res.json(); } catch (_) {}
      if (!res.ok || j.error) return { __errore: j.error || ("HTTP " + res.status) };
      return { ok: true, id: j.id };
    } catch (e) { return { __errore: e.message }; }
  },

  async setWhatsappAzienda(aziendaId, attivo) {
    try {
      await this._col("aziende").doc(aziendaId).update({ whatsapp_attivo: !!attivo });
      return { ok: true };
    } catch (e) { console.error("setWhatsappAzienda:", e.message); return { __errore: e.message }; }
  },

  // ---------- PROFILO / CONTEGGI ----------
  async contaPreventivi() {
    try {
      const snap = await this._scope(this._col("preventivi")).get();
      return snap.size;
    } catch (e) { console.error("contaPreventivi:", e.message); return null; }
  },

  async assicuraProfilo(email, nome) {
    const em = (email || "").trim().toLowerCase();
    if (!em) return null;
    try {
      const q = await this._col("utenti").where("email", "==", em).limit(1).get();
      if (!q.empty) return this._doc(q.docs[0]);
      const username = em.split("@")[0] || em;
      const uid = fbAuth.currentUser ? fbAuth.currentUser.uid : null;
      const ref = uid ? this._col("utenti").doc(uid) : this._col("utenti").doc();
      const payload = {
        username, email: em, nome: (nome || username), ruolo: "admin",
        attivo: true, created_at: this._now(),
      };
      await ref.set(payload, { merge: true });
      return { id: ref.id, ...payload };
    } catch (e) {
      console.error("assicuraProfilo:", e.message);
      return { __errore: e.message };
    }
  },

  // ---------- PRODOTTI ----------
  async getProdotti() {
    try {
      const arr = this._snap(await this._scope(this._col("prodotti")).get());
      return arr.sort((a, b) => this._num(a.id) - this._num(b.id) || String(a.id).localeCompare(String(b.id)));
    } catch (e) { console.error("getProdotti:", e.message); return []; }
  },

  async inserisciProdotto(dati) {
    const payload = {
      azienda_id: _aziendaAttiva,
      nome: dati.nome,
      categoria: dati.categoria || "software",
      prezzo: parseFloat(dati.prezzo) || 0,
      descrizione: dati.descrizione || "",
      immagine: dati.immagine || null,
      attivo: true,
      created_at: this._now(),
    };
    try {
      const ref = await this._col("prodotti").add(payload);
      return { id: ref.id, ...payload };
    } catch (e) { console.error("inserisciProdotto:", e.message); return { __errore: e.message }; }
  },

  async aggiornaProdotto(id, dati) {
    const patch = {
      nome: dati.nome, categoria: dati.categoria,
      prezzo: parseFloat(dati.prezzo) || 0,
      descrizione: dati.descrizione || "", immagine: dati.immagine || null,
      updated_at: this._now(),
    };
    try {
      await this._col("prodotti").doc(id).update(patch);
      return { id, ...patch };
    } catch (e) { console.error("aggiornaProdotto:", e.message); return { __errore: e.message }; }
  },

  async eliminaProdotto(id) {
    try { await this._col("prodotti").doc(id).delete(); return true; }
    catch (e) { console.error("eliminaProdotto:", e.message); return false; }
  },

  // ---------- CLIENTI ----------
  async getClienti() {
    try {
      const arr = this._snap(await this._scope(this._col("clienti")).get());
      return this._sortBy(arr, "nome");
    } catch (e) { console.error("getClienti:", e.message); return []; }
  },

  async cercaDuplicatoCliente({ piva, nome, cf, escludiId }) {
    let tutti;
    try { tutti = this._snap(await this._scope(this._col("clienti")).get()); }
    catch (e) { console.error("cercaDuplicatoCliente:", e.message); return null; }
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
    }
    return null;
  },

  _clientePayload(dati) {
    return {
      azienda_id: _aziendaAttiva,
      tipo_cliente: dati.tipo_cliente || "azienda",
      nome: dati.nome,
      referente: dati.referente || "",
      email: dati.email || "",
      telefono: dati.telefono || "",
      piva: dati.piva || "",
      codice_fiscale: dati.codice_fiscale || "",
      indirizzo: dati.indirizzo || "",
      civico: dati.civico || "",
      cap: dati.cap || "",
      citta: dati.citta || "",
      provincia: dati.provincia || "",
      ateco: dati.ateco || "",
      settore: dati.settore || "ristorazione",
      regione: dati.regione || "lombardia",
      note: dati.note || "",
    };
  },

  async inserisciCliente(dati) {
    const payload = this._clientePayload(dati);
    if (payload.piva) {
      const dup = await this.cercaDuplicatoCliente({ piva: payload.piva });
      if (dup) return { __errDuplicato: true };
    }
    payload.created_at = this._now();
    try {
      const ref = await this._col("clienti").add(payload);
      return { id: ref.id, ...payload };
    } catch (e) { console.error("inserisciCliente:", e.message); return null; }
  },

  async aggiornaCliente(id, dati) {
    const patch = this._clientePayload(dati);
    delete patch.azienda_id;
    patch.updated_at = this._now();
    if (patch.piva) {
      const dup = await this.cercaDuplicatoCliente({ piva: patch.piva, escludiId: id });
      if (dup) return { __errDuplicato: true };
    }
    try {
      await this._col("clienti").doc(id).update(patch);
      return { id, ...patch };
    } catch (e) { console.error("aggiornaCliente:", e.message); return null; }
  },

  async eliminaCliente(id) {
    try { await this._col("clienti").doc(id).delete(); return true; }
    catch (e) { console.error("eliminaCliente:", e.message); return false; }
  },

  // ---------- PREVENTIVI ----------
  async _nextNumeroPreventivo() {
    const key = _aziendaAttiva || "globale";
    const ref = this._col("contatori").doc("preventivi_" + key);
    let n = 1;
    await fbDb.runTransaction(async tx => {
      const snap = await tx.get(ref);
      n = (snap.exists ? Number(snap.data().valore) || 0 : 0) + 1;
      tx.set(ref, { azienda_id: _aziendaAttiva || null, valore: n, updated_at: this._now() }, { merge: true });
    });
    return n;
  },

  async getPreventivi(soloUtenteId = null) {
    try {
      let arr = this._snap(await this._scope(this._col("preventivi")).get());
      if (soloUtenteId) arr = arr.filter(p => p.utente_id === soloUtenteId);
      arr.sort((a, b) => String(b.created_at || "").localeCompare(String(a.created_at || "")));
      return arr.map(p => ({ ...p, data: p.created_at }));
    } catch (e) { console.error("getPreventivi:", e.message); return []; }
  },

  async inserisciPreventivo(dati) {
    const numero = `PRV-${String(await this._nextNumeroPreventivo()).padStart(4, "0")}`;
    const payload = {
      azienda_id: _aziendaAttiva,
      cliente_id: dati.clienteId || null,
      cliente_nome: dati.clienteNome || "",
      utente_id: (typeof getUtenteSessione === "function" ? getUtenteSessione()?.id : null) || null,
      righe: dati.righe || [],
      sconto: dati.sconto || 0,
      note: dati.note || "",
      subtotale: dati.subtotale || 0,
      imp_sconto: dati.impSconto || 0,
      imponibile: dati.imponibile || 0,
      iva: dati.iva || 0,
      totale_iva: dati.totaleIva || 0,
      stato: dati.stato || "bozza",
      numero,
      revisione: 0,
      created_at: this._now(),
    };
    try {
      const ref = await this._col("preventivi").add(payload);
      return { id: ref.id, ...payload, data: payload.created_at };
    } catch (e) { console.error("inserisciPreventivo:", e.message); return null; }
  },

  async aggiornaPreventivo(id, dati) {
    const patch = {
      cliente_id: dati.clienteId || null,
      cliente_nome: dati.clienteNome || "",
      righe: dati.righe || [],
      note: dati.note || "",
      subtotale: dati.subtotale || 0,
      imp_sconto: dati.impSconto || 0,
      imponibile: dati.imponibile || 0,
      iva: dati.iva || 0,
      totale_iva: dati.totaleIva || 0,
      stato: dati.stato || "bozza",
      updated_at: this._now(),
    };
    try {
      await this._col("preventivi").doc(id).update(patch);
      return { id, ...patch };
    } catch (e) { console.error("aggiornaPreventivo:", e.message); return null; }
  },

  async aggiornaStato(id, stato) {
    try { await this._col("preventivi").doc(id).update({ stato, updated_at: this._now() }); return true; }
    catch (e) { console.error("aggiornaStato:", e.message); return false; }
  },

  async creaRevisione(vecchio) {
    try {
      await this._col("preventivi").doc(vecchio.id).update({ stato: "revisionato", updated_at: this._now() });
      const baseNum = (vecchio.numero || "").replace(/-R\d+$/, "");
      const nuovaRev = (vecchio.revisione || 0) + 1;
      const nuovoNumero = baseNum ? `${baseNum}-R${nuovaRev}` : null;
      const payload = {
        azienda_id: _aziendaAttiva || vecchio.azienda_id || null,
        cliente_id: vecchio.cliente_id || null,
        cliente_nome: vecchio.cliente_nome || "",
        utente_id: (typeof getUtenteSessione === "function" ? getUtenteSessione()?.id : null) || vecchio.utente_id || null,
        righe: vecchio.righe || [],
        sconto: vecchio.sconto || 0,
        note: vecchio.note || "",
        subtotale: vecchio.subtotale || 0,
        imp_sconto: vecchio.imp_sconto || 0,
        imponibile: vecchio.imponibile || 0,
        iva: vecchio.iva || 0,
        totale_iva: vecchio.totale_iva || 0,
        stato: "inviato",
        numero: nuovoNumero,
        revisione: nuovaRev,
        created_at: this._now(),
      };
      const ref = await this._col("preventivi").add(payload);
      return { id: ref.id, ...payload, data: payload.created_at };
    } catch (e) { console.error("creaRevisione:", e.message); return { __errore: e.message }; }
  },

  async eliminaPreventivo(id) {
    try { await this._col("preventivi").doc(id).delete(); return true; }
    catch (e) { console.error("eliminaPreventivo:", e.message); return false; }
  },

  // ---------- CATEGORIE ----------
  async getCategorie() {
    try {
      const arr = this._snap(await this._scope(this._col("categorie")).get());
      return arr.sort((a, b) => (a.ordine || 0) - (b.ordine || 0));
    } catch (e) { console.error("getCategorie:", e.message); return []; }
  },

  async inserisciCategoria(dati) {
    const payload = { azienda_id: _aziendaAttiva, nome: dati.nome, icona: dati.icona || "📦", ordine: dati.ordine || 0, created_at: this._now() };
    try { const ref = await this._col("categorie").add(payload); return { id: ref.id, ...payload }; }
    catch (e) { console.error("inserisciCategoria:", e.message); return null; }
  },

  async aggiornaCategoria(id, dati) {
    const patch = { nome: dati.nome, icona: dati.icona || "📦", ordine: dati.ordine || 0, updated_at: this._now() };
    try { await this._col("categorie").doc(id).update(patch); return { id, ...patch }; }
    catch (e) { console.error("aggiornaCategoria:", e.message); return null; }
  },

  async eliminaCategoria(id) {
    try { await this._col("categorie").doc(id).delete(); return true; }
    catch (e) { console.error("eliminaCategoria:", e.message); return false; }
  },

  // ---------- UTENTI / MEMBRI ----------
  async getUtenti() {
    if (!_aziendaAttiva) return [];
    try {
      const mem = await this._col("membri").where("azienda_id", "==", _aziendaAttiva).get();
      const out = [];
      for (const m of mem.docs) {
        const u = await this._col("utenti").doc(m.data().utente_id).get();
        if (u.exists) out.push({ id: u.id, ...u.data(), ruolo: m.data().ruolo });
      }
      return out;
    } catch (e) { console.error("getUtenti:", e.message); return []; }
  },

  async inserisciUtente(dati, _passwordHash) {
    const email = (dati.email || "").trim().toLowerCase() || null;
    try {
      let utente = null;
      if (email) {
        const q = await this._col("utenti").where("email", "==", email).limit(1).get();
        if (!q.empty) utente = this._doc(q.docs[0]);
      }
      if (!utente) {
        const payload = {
          username: (dati.username || "").trim().toLowerCase(),
          email,
          nome: dati.nome || "",
          ruolo: dati.ruolo || "commerciale",
          avatar: dati.avatar || null,
          menu_utente: dati.menu_utente || null,
          attivo: true,
          created_at: this._now(),
        };
        const ref = await this._col("utenti").add(payload);
        utente = { id: ref.id, ...payload };
      }
      await this._col("membri").doc(`${_aziendaAttiva}_${utente.id}`).set({
        azienda_id: _aziendaAttiva, utente_id: utente.id,
        ruolo: dati.ruolo || "commerciale", created_at: this._now(),
      }, { merge: true });
      return { ...utente, ruolo: dati.ruolo || "commerciale" };
    } catch (e) { console.error("inserisciUtente:", e.message); return { __errore: e.message }; }
  },

  async aggiornaUtente(id, dati) {
    const patch = { nome: dati.nome || "", attivo: dati.attivo !== false, updated_at: this._now() };
    if (dati.avatar !== undefined) patch.avatar = dati.avatar || null;
    if (dati.menu_utente !== undefined) patch.menu_utente = dati.menu_utente || null;
    try {
      await this._col("utenti").doc(id).update(patch);
      const ruolo = dati.ruolo || "commerciale";
      if (_aziendaAttiva) {
        await this._col("membri").doc(`${_aziendaAttiva}_${id}`).set({ ruolo, azienda_id: _aziendaAttiva, utente_id: id }, { merge: true });
      }
      return { id, ...patch, ruolo };
    } catch (e) { console.error("aggiornaUtente:", e.message); return null; }
  },

  async eliminaUtente(id) {
    if (!_aziendaAttiva) return false;
    try {
      await this._col("membri").doc(`${_aziendaAttiva}_${id}`).delete();
      return true;
    } catch (e) { console.error("eliminaUtente:", e.message); return false; }
  },

  // ---------- RUOLI ----------
  async getRuoli() {
    try {
      const arr = this._snap(await this._scope(this._col("ruoli")).get());
      return this._sortBy(arr, "nome");
    } catch (e) { console.error("getRuoli:", e.message); return []; }
  },

  async inserisciRuolo(dati) {
    const payload = {
      azienda_id: _aziendaAttiva,
      nome: dati.nome.trim(),
      chiave: (dati.chiave || dati.nome).trim().toLowerCase().replace(/[\s\W]+/g, "_"),
      descrizione: dati.descrizione || "",
      sconto_max: parseInt(dati.sconto_max) || 0,
      permessi: dati.permessi || {},
      sistema: false,
      created_at: this._now(),
    };
    try { const ref = await this._col("ruoli").add(payload); return { id: ref.id, ...payload }; }
    catch (e) { console.error("inserisciRuolo:", e.message); return null; }
  },

  async aggiornaRuolo(id, dati) {
    const patch = {
      nome: dati.nome.trim(), descrizione: dati.descrizione || "",
      sconto_max: parseInt(dati.sconto_max) || 0, permessi: dati.permessi || {},
      updated_at: this._now(),
    };
    try { await this._col("ruoli").doc(id).update(patch); return { id, ...patch }; }
    catch (e) { console.error("aggiornaRuolo:", e.message); return null; }
  },

  async eliminaRuolo(id) {
    try { await this._col("ruoli").doc(id).delete(); return true; }
    catch (e) { console.error("eliminaRuolo:", e.message); return false; }
  },

  // ---------- BANDI ----------
  async getBandi() {
    try {
      const arr = this._snap(await this._col("bandi_incentivi").get())
        .filter(b => b.stato !== "scaduto");
      return arr.sort((a, b) => {
        const da = a.data_chiusura || "9999-12-31";
        const db = b.data_chiusura || "9999-12-31";
        return String(da).localeCompare(String(db));
      });
    } catch (e) { console.error("getBandi:", e.message); throw new Error(e.message); }
  },

  async upsertBandi(records) {
    try {
      const batch = fbDb.batch();
      (records || []).forEach(r => {
        const id = r.id != null ? String(r.id) : this._col("bandi_incentivi").doc().id;
        batch.set(this._col("bandi_incentivi").doc(id), { ...r, id }, { merge: true });
      });
      await batch.commit();
    } catch (e) { console.error("upsertBandi:", e.message); throw new Error(e.message); }
  },

  // ---------- GIRO VISITE ----------
  async getVisite(data, utenteId) {
    try {
      let arr = this._snap(await this._scope(this._col("giro_visite")).get())
        .filter(v => v.data === data);
      if (utenteId) arr = arr.filter(v => v.utente_id === utenteId);
      arr.sort((a, b) => (a.ordine || 0) - (b.ordine || 0) || String(a.ora || "").localeCompare(String(b.ora || "")));
      return arr;
    } catch (e) { console.error("getVisite:", e.message); throw new Error(e.message); }
  },

  async aggiungiVisita(dati) {
    const riga = {
      azienda_id: _aziendaAttiva,
      utente_id: dati.utente_id || null,
      cliente_id: dati.cliente_id || null,
      cliente_nome: dati.cliente_nome || "",
      telefono: dati.telefono || null,
      indirizzo: dati.indirizzo || null,
      data: dati.data,
      ora: dati.ora || null,
      ordine: dati.ordine ?? 0,
      stato: dati.stato || "da_fare",
      note: dati.note || null,
      visita_padre_id: dati.visita_padre_id || null,
      promemoria_min: dati.promemoria_min ?? null,
      promemoria_at: dati.promemoria_at || null,
      promemoria_numero: dati.promemoria_numero || null,
      promemoria_inviato_at: dati.promemoria_inviato_at || null,
      created_at: this._now(),
    };
    try { const ref = await this._col("giro_visite").add(riga); return { id: ref.id, ...riga }; }
    catch (e) { console.error("aggiungiVisita:", e.message); return { __errore: e.message }; }
  },

  async aggiornaVisita(id, patch) {
    const upd = { ...patch, updated_at: this._now() };
    try { await this._col("giro_visite").doc(id).update(upd); return { id, ...upd }; }
    catch (e) { console.error("aggiornaVisita:", e.message); return { __errore: e.message }; }
  },

  async eliminaVisita(id) {
    try { await this._col("giro_visite").doc(id).delete(); return true; }
    catch (e) { console.error("eliminaVisita:", e.message); return false; }
  },

  async riordinaVisite(ordini) {
    try {
      const batch = fbDb.batch();
      (ordini || []).forEach(o => batch.update(this._col("giro_visite").doc(o.id), { ordine: o.ordine }));
      await batch.commit();
      return true;
    } catch (e) { console.error("riordinaVisite:", e.message); return false; }
  },

  async getVisiteCliente(clienteId) {
    try {
      const arr = this._snap(await this._scope(this._col("giro_visite")).get())
        .filter(v => v.cliente_id === clienteId);
      return arr.sort((a, b) => String(b.data || "").localeCompare(String(a.data || "")) || String(b.ora || "").localeCompare(String(a.ora || "")));
    } catch (e) { console.error("getVisiteCliente:", e.message); return []; }
  },

  async getVisitePeriodo(dal, al, utenteId) {
    try {
      let arr = this._snap(await this._scope(this._col("giro_visite")).get())
        .filter(v => v.data >= dal && v.data <= al);
      if (utenteId) arr = arr.filter(v => v.utente_id === utenteId);
      return arr.sort((a, b) => String(a.data).localeCompare(String(b.data)));
    } catch (e) { console.error("getVisitePeriodo:", e.message); throw new Error(e.message); }
  },

  // ---------- FONTI BANDI / LOG ----------
  async getFontiBandi() {
    try {
      const arr = this._snap(await this._col("bandi_fonti").get());
      return this._sortBy(arr, "nome");
    } catch (e) { console.error("getFontiBandi:", e.message); return []; }
  },

  async salvaFonteBandi(dati) {
    const id = dati.id || (dati.nome || "").toLowerCase().replace(/\W+/g, "_");
    const payload = {
      id, nome: dati.nome, url: dati.url || "", tipo: dati.tipo || "rss",
      attiva: dati.attiva !== false, note: dati.note || "", updated_at: this._now(),
    };
    try {
      await this._col("bandi_fonti").doc(id).set(payload, { merge: true });
      return payload;
    } catch (e) { console.error("salvaFonteBandi:", e.message); return null; }
  },

  async toggleFonteBandi(id, attiva) {
    try { await this._col("bandi_fonti").doc(id).update({ attiva }); return true; }
    catch (e) { console.error("toggleFonteBandi:", e.message); return false; }
  },

  async eliminaFonteBandi(id) {
    try { await this._col("bandi_fonti").doc(id).delete(); return true; }
    catch (e) { console.error("eliminaFonteBandi:", e.message); return false; }
  },

  async scriviLogManuale(importati, totale) {
    try {
      await this._col("bandi_sync_log").add({
        fonte_id: "incentivi_gov", stato: "ok", importati, totale_fonte: totale,
        errore: null, avviato_il: this._now(), completato_il: this._now(),
      });
      await this._col("bandi_fonti").doc("incentivi_gov").set({
        sync_stato: "ok", ultimo_sync: this._now(), sync_importati: importati,
        sync_errore: null, updated_at: this._now(),
      }, { merge: true });
    } catch (e) { console.warn("scriviLogManuale:", e.message); }
  },

  async getSyncLog(fonteId = null, limit = 20) {
    try {
      const arr = this._snap(await this._col("bandi_sync_log").orderBy("avviato_il", "desc").limit(limit).get());
      const fonti = {};
      const fSnap = await this._col("bandi_fonti").get();
      fSnap.docs.forEach(d => { fonti[d.id] = d.data().nome; });
      return arr
        .filter(r => !fonteId || r.fonte_id === fonteId)
        .map(r => ({ ...r, bandi_fonti: { nome: fonti[r.fonte_id] || r.fonte_id } }));
    } catch (e) { console.error("getSyncLog:", e.message); return []; }
  },

  // ---------- FUNZIONI CLOUD ----------
  async avviaSyncBandi(fonteId = null) {
    try {
      const res = await fetch(CLOUD_FUNCTIONS_BASE + "/syncBandi", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ fonte: fonteId || null }),
      });
      const testo = await res.text();
      try { return JSON.parse(testo); }
      catch (_) { return { ok: false, error: `HTTP ${res.status} — ${testo.substring(0, 300)}` }; }
    } catch (e) { return { ok: false, error: e.message }; }
  },

  async cercaVIES(piva) {
    try {
      const res = await fetch(CLOUD_FUNCTIONS_BASE + "/creditsafe", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "vies", piva }),
      });
      const testo = await res.text();
      try { return JSON.parse(testo); } catch (_) { return { ok: false, error: testo.substring(0, 200) }; }
    } catch (e) { return { ok: false, error: e.message }; }
  },

  async verificaPIVA(piva) {
    try {
      const res = await fetch(CLOUD_FUNCTIONS_BASE + "/creditsafe", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ piva }),
      });
      const testo = await res.text();
      try { return JSON.parse(testo); }
      catch (_) { return { ok: false, error: `HTTP ${res.status} — ${testo.substring(0, 300)}` }; }
    } catch (e) { return { ok: false, error: e.message }; }
  },

  // ---------- IMPOSTAZIONI ----------
  async getImpostazioni() {
    try {
      const snap = await this._scope(this._col("impostazioni")).get();
      return Object.fromEntries(snap.docs.map(d => [d.data().chiave, d.data().valore]));
    } catch (e) { console.error("getImpostazioni:", e.message); return {}; }
  },

  async salvaImpostazione(chiave, valore) {
    const key = `${_aziendaAttiva || "globale"}_${chiave}`;
    try {
      await this._col("impostazioni").doc(key).set({
        azienda_id: _aziendaAttiva || null, chiave, valore, updated_at: this._now(),
      }, { merge: true });
      return true;
    } catch (e) { console.error("salvaImpostazione:", e.message); return false; }
  },
};
