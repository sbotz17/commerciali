const { chromium } = require('playwright');
const h = require('./helpers');
const fs = require('fs');

const BASE = process.env.AUDIT_BASE;
const CAT = 'Categoria AU04';
const IMG = 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/280px-PNG_transparency_demonstration_1.png';
const CAT_VUOTA = 'Categoria Vuota AU04';
const P = ['Prodotto AU04 Uno', 'Prodotto AU04 Due', 'Prodotto AU04 Tre'];
const out = { commit: process.env.AUDIT_COMMIT, base: BASE, immagini: [], fasi: {} };

const checkboxes = (page) => page.evaluate(() => [...document.querySelectorAll('flt-semantics[role="checkbox"]')]
  .map(n => {
    const r = n.getBoundingClientRect();
    return { a: (n.getAttribute('aria-label') || '').split('\n')[0], c: n.getAttribute('aria-checked'), x: Math.round(r.x + r.width / 2), y: Math.round(r.y + r.height / 2) };
  }));

async function conPagina(browser, fn) {
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 1300 }, locale: 'it-IT' });
  const page = await ctx.newPage();
  page.on('console', m => { if (m.type() === 'error') out.fasi.console = [...(out.fasi.console || []), m.text().slice(0, 120)]; });
  page.on('response', r => { if (r.url().includes('wikimedia.org')) out.immagini.push(r.status()); });
  try {
    await page.goto(BASE, { waitUntil: 'networkidle', timeout: 90000 });
    await page.waitForSelector('flt-semantics-host', { state: 'attached', timeout: 45000 });
    const haPlaceholder = await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 6000 }).then(() => true).catch(() => false);
    if (haPlaceholder) {
      await page.waitForTimeout(1000);
      await page.evaluate(() => {
        const ph = document.querySelector('flt-semantics-placeholder');
        if (ph) ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(t =>
          ph.dispatchEvent(new MouseEvent(t, { bubbles: true, cancelable: true })));
      });
    }
    await page.waitForTimeout(2800);
    if (await page.locator('input[aria-label="Email"]').count()) {
      await h.login(page, process.env.AUDIT_EMAIL, process.env.AUDIT_PASS);
    } else {
      await page.evaluate(() => {
        const ph = document.querySelector('flt-semantics-placeholder');
        if (ph) ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(t =>
          ph.dispatchEvent(new MouseEvent(t, { bubbles: true, cancelable: true })));
      }).catch(() => {});
      await page.waitForTimeout(2500);
    }
    for (let i = 0; i < 10; i++) {
      const t = await h.testo(page);
      if (/Dashboard Scheda/.test(t)) break;
      const b = (await h.elencoPulsanti(page)).find(x => /inizia|ho capito/i.test(x.testo));
      if (b) { await h.cliccaTesto(page, b.testo); await page.waitForTimeout(3500); } else await page.waitForTimeout(2500);
    }
    await h.cliccaTesto(page, 'Catalogo Scheda 3 di 10');
    await page.waitForTimeout(2800);
    return await fn(page);
  } finally {
    await ctx.close();
  }
}

async function creaCategoria(page) {
  await h.cliccaAria(page, 'Categorie');
  await page.waitForTimeout(2000);
  const c = await page.evaluate((cat) => [...document.querySelectorAll('flt-semantics[aria-label]')]
    .some(n => (n.getAttribute('aria-label') || '').startsWith(cat)), CAT);
  if (c) return true;
  await h.cliccaTesto(page, 'Nuova categoria');
  await page.waitForTimeout(2000);
  await h.scrivi(page, 'Nome *', CAT);
  await h.scrivi(page, 'Ordine', '2');
  await h.cliccaTesto(page, 'Crea categoria');
  await page.waitForTimeout(3500);
  return page.evaluate((cat) => [...document.querySelectorAll('flt-semantics[aria-label]')]
    .some(n => (n.getAttribute('aria-label') || '').startsWith(cat)), CAT);
}

async function creaProdotto(page, nome, codice, prezzo, conImmagine) {
  if ((await h.testo(page)).includes(nome)) return;
  const btn = (await h.elencoPulsanti(page)).find(x => /nuovo prodotto/i.test(x.testo));
  await h.cliccaTesto(page, btn.testo);
  await page.waitForTimeout(2000);
  await h.scrivi(page, 'Nome *', nome);
  await h.scrivi(page, 'Codice prodotto', codice);
  await h.scrivi(page, 'Prezzo (€)', prezzo);
  if (conImmagine) await h.scrivi(page, 'Immagine (URL)', IMG);
  const catBtn = (await h.elencoPulsanti(page)).find(x => /^Categoria /.test(x.testo));
  if (catBtn) {
    await h.cliccaTesto(page, catBtn.testo);
    await page.waitForTimeout(1300);
    const box = await page.evaluate((cat) => {
      const n = [...document.querySelectorAll('flt-semantics')].find(x => (x.getAttribute('aria-label') || '').trim().startsWith(cat));
      if (!n) return null;
      const r = n.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    }, CAT);
    if (box) await page.mouse.click(box.x, box.y);
    await page.waitForTimeout(1300);
  }
  await h.cliccaTesto(page, 'Crea prodotto');
  await page.waitForTimeout(3800);
}

async function seleziona(page, nome) {
  const campo = page.locator('input[aria-label^="Paniere (sotto-prodotti)"]').first();
  if (await campo.count()) {
    const b = await campo.boundingBox();
    await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
    await page.waitForTimeout(300);
    await page.keyboard.press('Meta+A');
    await page.keyboard.press('Backspace');
    await page.keyboard.type(nome, { delay: 15 });
    await page.waitForTimeout(1500);
  }
  const c = (await checkboxes(page)).find(v => v.a.includes(nome));
  if (!c) return false;
  if (c.c === 'true') return true;
  await page.mouse.move(c.x, c.y);
  await page.mouse.down();
  await page.mouse.up();
  await page.waitForTimeout(1800);
  return ((await checkboxes(page)).find(v => v.a.includes(nome)) || {}).c === 'true';
}

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--no-sandbox'] });
  try {
    // FASE 1: categoria, prodotti, immagine, validazione
    out.fasi.setup = await conPagina(browser, async (page) => {
      const r = {};
      r.categoria = await creaCategoria(page);
      // seconda categoria, senza prodotti: serve al filtro "nessun prodotto"
      const haCategorie = await page.evaluate((cat) => [...document.querySelectorAll('flt-semantics[aria-label]')]
        .some(n => (n.getAttribute('aria-label') || '').startsWith(cat)), CAT_VUOTA);
      if (!haCategorie) {
        await h.cliccaTesto(page, 'Nuova categoria');
        await page.waitForTimeout(2000);
        await h.scrivi(page, 'Nome *', CAT_VUOTA);
        await h.scrivi(page, 'Ordine', '3');
        await h.cliccaTesto(page, 'Crea categoria');
        await page.waitForTimeout(3000);
      }
      r.categoriaVuota = await page.evaluate((cat) => [...document.querySelectorAll('flt-semantics[aria-label]')]
        .some(n => (n.getAttribute('aria-label') || '').startsWith(cat)), CAT_VUOTA);
      await h.cliccaAria(page, 'Prodotti');
      await page.waitForTimeout(2000);
      await creaProdotto(page, P[0], 'AU04-1', '10', true);
      await creaProdotto(page, P[1], 'AU04-2', '20', false);
      await creaProdotto(page, P[2], 'AU04-3', '30', false);
      const lista = await h.testo(page);
      r.prodotti = P.every(n => lista.includes(n));
      const btn = (await h.elencoPulsanti(page)).find(x => /nuovo prodotto/i.test(x.testo));
      await h.cliccaTesto(page, btn.testo);
      await page.waitForTimeout(1800);
      await h.cliccaTesto(page, 'Crea prodotto');
      await page.waitForTimeout(2200);
      r.validazione = /obbligatori|obbligatorio|inserisci|richiesto/i.test(await h.testo(page));
      await h.cliccaTesto(page, 'Annulla').catch(() => {});
      return r;
    });

    // FASE 2: paniere
    out.fasi.paniere = await conPagina(browser, async (page) => {
      const r = {};
      const riga = page.locator('flt-semantics', { hasText: P[0] }).last();
      const b = await riga.boundingBox();
      await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
      await page.waitForTimeout(3000);
      r.due = await seleziona(page, P[1]);
      r.tre = await seleziona(page, P[2]);
      await h.cliccaTesto(page, 'Salva modifiche');
      for (let i = 0; i < 10; i++) { await page.waitForTimeout(1200); if (/Nuovo prodotto/.test(await h.testo(page))) break; }
      const lista = await h.testo(page);
      r.lista = /Nuovo prodotto/.test(lista);
      r.badge = /2 figli/.test(lista);
      return r;
    });

    // FASE 3: ricerca (risultato e vuoto)
    out.fasi.ricerca = await conPagina(browser, async (page) => {
      const r = {};
      await h.scrivi(page, 'Cerca per nome', 'Due');
      await page.waitForTimeout(2400);
      const t1 = await h.testo(page);
      r.conRisultato = t1.includes(P[1]) && !t1.includes(P[0]);
      await page.reload({ waitUntil: 'domcontentloaded' });
      await h.abilitaSemantica(page);
      await page.waitForTimeout(4500);
      const intro = (await h.elencoPulsanti(page)).find(x => /inizia|ho capito/i.test(x.testo));
      if (intro) { await h.cliccaTesto(page, intro.testo); await page.waitForTimeout(2000); }
      await h.cliccaTesto(page, 'Catalogo Scheda 3 di 10');
      await page.waitForTimeout(2600);
      const input = page.locator('flt-semantics input').first();
      const b = await input.boundingBox();
      await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
      await page.keyboard.type('nessunmatchau04', { delay: 15 });
      await page.waitForTimeout(2500);
      r.vuota = /Nessun prodotto/.test(await h.testo(page));
      return r;
    });

    // FASE 4: filtro categoria senza prodotti
    out.fasi.filtro = await conPagina(browser, async (page) => {
      const r = {};
      const filtroBtn = (await h.elencoPulsanti(page)).find(x => /^Categoria /.test(x.testo));
      await h.cliccaTesto(page, filtroBtn.testo);
      await page.waitForTimeout(1500);
      r.voci = await page.evaluate(() => [...document.querySelectorAll('flt-semantics[role="menuitem"]')].map(n => n.getAttribute('aria-label')));
      const box = await page.evaluate(() => {
        const n = [...document.querySelectorAll('flt-semantics[role="menuitem"]')].find(x => (x.getAttribute('aria-label') || '') === 'Categoria Vuota AU04');
        if (!n) return null;
        const b = n.getBoundingClientRect();
        return { x: b.x + b.width / 2, y: b.y + b.height / 2 };
      });
      if (box) await page.mouse.click(box.x, box.y);
      await page.waitForTimeout(2500);
      r.vuoto = /Nessun prodotto/.test(await h.testo(page));
      return r;
    });

    // FASE 5: persistenza
    out.fasi.persistenza = await conPagina(browser, async (page) => {
      const t = await h.testo(page);
      return { prodotti: P.every(n => t.includes(n)), badge: /2 figli/.test(t) };
    });

    // FASE 6: eliminazione
    out.fasi.eliminazione = await conPagina(browser, async (page) => {
      const r = {};
      const az = page.locator('flt-semantics[role="button"]', { hasText: 'Azioni prodotto' }).last();
      const b = await az.boundingBox();
      await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2);
      await page.mouse.down(); await page.mouse.up();
      await page.waitForTimeout(1800);
      const elim = await page.evaluate(() => {
        const n = [...document.querySelectorAll('flt-semantics[role="menuitem"]')].find(x => (x.getAttribute('aria-label') || '') === 'Elimina');
        if (!n) return null;
        const b = n.getBoundingClientRect();
        return { x: b.x + b.width / 2, y: b.y + b.height / 2 };
      });
      if (!elim) return { trovato: false };
      await page.mouse.click(elim.x, elim.y);
      await page.waitForTimeout(2000);
      const dialogo = await h.testo(page);
      const m = dialogo.match(/Il prodotto "([^"]+)"/);
      r.prodotto = m ? m[1] : null;
      const conf = (await h.elencoPulsanti(page)).find(x => /^Elimina$/.test(x.testo.trim()));
      if (conf) { await h.cliccaTesto(page, conf.testo); await page.waitForTimeout(3500); }
      const lista = await h.testo(page);
      r.sparito = r.prodotto ? !lista.includes(r.prodotto) : false;
      r.rimasti = (lista.match(/Prodotto AU04/g) || []).length;
      return r;
    });
  } catch (e) {
    out.error = String(e).slice(0, 250);
  } finally {
    await browser.close();
    fs.writeFileSync('/tmp/au04-prova.json', JSON.stringify(out, null, 2));
    console.log(JSON.stringify(out, null, 2).slice(0, 2600));
  }
})();
