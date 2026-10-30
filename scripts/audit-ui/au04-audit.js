const { chromium } = require('playwright');
const h = require('./helpers');
const fs = require('fs');

const BASE = process.env.AUDIT_BASE;
const CAT = 'Categoria AU04';
const IMG = 'https://picsum.photos/seed/au04b/200';
const P = ['Prodotto AU04 Uno', 'Prodotto AU04 Due', 'Prodotto AU04 Tre'];

const leggiCheckbox = (page) => page.evaluate(() => [...document.querySelectorAll('flt-semantics[role="checkbox"]')]
  .map(n => {
    const r = n.getBoundingClientRect();
    return {
      a: (n.getAttribute('aria-label') || '').split('\n')[0],
      c: n.getAttribute('aria-checked'),
      x: Math.round(r.x + r.width / 2),
      y: Math.round(r.y + r.height / 2),
    };
  }));

async function spunta(page, nome) {
  for (let giro = 0; giro < 3; giro++) {
    const lista = await leggiCheckbox(page);
    const c = lista.find(v => v.a.includes(nome));
    if (!c) { await page.waitForTimeout(700); continue; }
    if (c.c === 'true') return true;
    await page.mouse.move(c.x, c.y);
    await page.mouse.down();
    await page.mouse.up();
    await page.waitForTimeout(1900);
    const dopo = await leggiCheckbox(page);
    const d = dopo.find(v => v.a.includes(nome));
    if (d && d.c === 'true') return true;
  }
  return false;
}


async function cerca(page, testo) {
  const input = page.locator('flt-semantics input').first();
  await input.waitFor({ state: 'attached', timeout: 10000 });
  const b = await input.boundingBox();
  await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
  await page.waitForTimeout(300);
  await page.keyboard.press('Meta+A');
  await page.keyboard.press('Backspace');
  if (testo) await page.keyboard.type(testo, { delay: 15 });
  await page.waitForTimeout(2500);
}

(async () => {
  const out = { commit: process.env.AUDIT_COMMIT, base: BASE, immagini: [] };
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 1300 }, locale: 'it-IT' });
  const page = await ctx.newPage();
  const errori = [];
  page.on('console', m => { if (m.type() === 'error') errori.push(m.text().slice(0, 120)); });
  page.on('response', r => { if (r.url().includes('picsum.photos')) out.immagini.push(r.status()); });

  const entra = async () => {
    await page.goto(BASE, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForTimeout(2500);
    if (await page.locator('input[aria-label="Email"]').count()) {
      await h.login(page);
    } else {
      await h.abilitaSemantica(page).catch(() => {});
    }
    await page.waitForTimeout(1500);
    for (let i = 0; i < 8; i++) {
      const t = await h.testo(page);
      if (/Dashboard Scheda/.test(t)) return;
      const b = (await h.elencoPulsanti(page)).find(x => /inizia|ho capito/i.test(x.testo));
      if (b) { await h.cliccaTesto(page, b.testo); await page.waitForTimeout(3500); } else await page.waitForTimeout(2500);
    }
  };

  try {
    await entra();
    await h.cliccaTesto(page, 'Catalogo Scheda 3 di 10');
    await page.waitForTimeout(2500);

    // 1. categoria
    await h.cliccaAria(page, 'Categorie');
    await page.waitForTimeout(2000);
    out.categoriaPresente = await page.evaluate((cat) => [...document.querySelectorAll('flt-semantics[aria-label]')]
      .some(n => (n.getAttribute('aria-label') || '').startsWith(cat)), CAT);
    if (!out.categoriaPresente) {
      await h.cliccaTesto(page, 'Nuova categoria');
      await page.waitForTimeout(2000);
      await h.scrivi(page, 'Nome *', CAT);
      await h.scrivi(page, 'Ordine', '2');
      await h.cliccaTesto(page, 'Crea categoria');
      await page.waitForTimeout(3500);
      out.categoriaPresente = await page.evaluate((cat) => [...document.querySelectorAll('flt-semantics[aria-label]')]
        .some(n => (n.getAttribute('aria-label') || '').startsWith(cat)), CAT);
    }

    // 2. prodotti
    await h.cliccaAria(page, 'Prodotti');
    await page.waitForTimeout(2000);
    for (let i = 0; i < P.length; i++) {
      if ((await h.testo(page)).includes(P[i])) continue;
      const btn = (await h.elencoPulsanti(page)).find(x => /nuovo prodotto/i.test(x.testo));
      await h.cliccaTesto(page, btn.testo);
      await page.waitForTimeout(2000);
      await h.scrivi(page, 'Nome *', P[i]);
      await h.scrivi(page, 'Codice prodotto', 'AU04-' + (i + 1));
      await h.scrivi(page, 'Prezzo (€)', String((i + 1) * 10));
      if (i === 0) await h.scrivi(page, 'Immagine (URL)', IMG);
      const catBtn = (await h.elencoPulsanti(page)).find(x => /^Categoria /.test(x.testo));
      if (catBtn) {
        await h.cliccaTesto(page, catBtn.testo);
        await page.waitForTimeout(1300);
        const box = await page.evaluate((cat) => {
          const n = [...document.querySelectorAll('flt-semantics')]
            .find(x => (x.getAttribute('aria-label') || '').trim().startsWith(cat));
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
    const lista = await h.testo(page);
    out.treProdotti = P.every(n => lista.includes(n));
    out.immagineScaricata = out.immagini.includes(200);

    // 3. validazione (caso negativo)
    const btn = (await h.elencoPulsanti(page)).find(x => /nuovo prodotto/i.test(x.testo));
    await h.cliccaTesto(page, btn.testo);
    await page.waitForTimeout(1800);
    await h.cliccaTesto(page, 'Crea prodotto');
    await page.waitForTimeout(2200);
    const testoErr = await h.testo(page);
    out.validazioneNome = /obbligatori|obbligatorio|inserisci|richiesto/i.test(testoErr);
    await h.cliccaTesto(page, 'Annulla').catch(() => {});
    await page.waitForTimeout(1500);

    // 4. paniere: coperto dallo script dedicato au04-panieri.js

    // 5. ricerca
    await cerca(page, 'Due');
    await page.waitForTimeout(2200);
    const ricerca = await h.testo(page);
    out.ricercaOk = ricerca.includes(P[1]) && !ricerca.includes(P[0]);
    await cerca(page, 'nessunmatchau04');
    await page.waitForTimeout(2200);
    out.ricercaVuota = /Nessun prodotto/.test(await h.testo(page));

    // 6. persistenza
    await entra();
    await h.cliccaTesto(page, 'Catalogo Scheda 3 di 10');
    await page.waitForTimeout(3000);
    const dopoReload = await h.testo(page);
    out.persistenza = P.every(n => dopoReload.includes(n)) && /2 figli/.test(dopoReload);

    // 7. filtro categoria senza prodotti
    const filtroBtn = (await h.elencoPulsanti(page)).find(x => /^Categoria /.test(x.testo));
    await h.cliccaTesto(page, filtroBtn.testo);
    await page.waitForTimeout(1500);
    const boxGen = await page.evaluate(() => {
      const n = [...document.querySelectorAll('flt-semantics[role="menuitem"]')]
        .find(x => (x.getAttribute('aria-label') || '') === 'Generale');
      if (!n) return null;
      const r = n.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    });
    if (boxGen) await page.mouse.click(boxGen.x, boxGen.y);
    await page.waitForTimeout(2500);
    out.filtroVuoto = /Nessun prodotto/.test(await h.testo(page));
  } catch (e) {
    out.error = String(e).slice(0, 250);
  } finally {
    out.erroriConsole = errori.slice(0, 4);
    await browser.close();
    fs.writeFileSync('/tmp/au04-audit.json', JSON.stringify(out, null, 2));
    console.log(JSON.stringify(out, null, 2).slice(0, 2200));
  }
})();
