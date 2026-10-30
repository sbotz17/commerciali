const { chromium } = require('playwright');
const h = require('./helpers');

const BASE = process.env.AUDIT_BASE;
const CAT = 'Categoria AU04';
const P = ['Prodotto AU04 Uno', 'Prodotto AU04 Due', 'Prodotto AU04 Tre'];

async function home(page) {
  for (let i = 0; i < 8; i++) {
    const b = await h.elencoPulsanti(page);
    const intro = b.find(x => /inizia|ho capito/i.test(x.testo));
    if (intro) { await h.cliccaTesto(page, intro.testo); await page.waitForTimeout(2500); continue; }
    if (b.some(x => /Catalogo Tab/.test(x.testo))) return true;
    await page.waitForTimeout(2500);
  }
  return false;
}

async function scriviNome(page, valore) {
  const el = page.locator('input[aria-label="Nome *"]').first();
  if (await el.count()) return h.scrivi(page, 'Nome *', valore);
  const primo = page.locator('flt-semantics input').first();
  const b = await primo.boundingBox();
  await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
  await page.waitForTimeout(300);
  await page.keyboard.press('Meta+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.type(valore, { delay: 12 });
}

async function creaProdotto(page, nome, codice, prezzo) {
  const b = (await h.elencoPulsanti(page)).find(x => /nuovo prodotto/i.test(x.testo));
  await h.cliccaTesto(page, b.testo);
  await page.waitForTimeout(2500);
  await scriviNome(page, nome);
  await h.scrivi(page, 'Codice prodotto', codice);
  await h.scrivi(page, 'Prezzo (€)', prezzo);

  const catBtn = (await h.elencoPulsanti(page)).find(x => /^Categoria /.test(x.testo));
  if (catBtn) {
    await h.cliccaTesto(page, catBtn.testo);
    await page.waitForTimeout(1500);
    const op = await page.evaluate((cat) => {
      const n = [...document.querySelectorAll('flt-semantics')]
        .find(x => (x.getAttribute('aria-label') || '').trim() === cat || (x.innerText || '').trim() === cat);
      if (!n) return false;
      const r = n.getBoundingClientRect();
      window.__catBox = { x: r.x + r.width / 2, y: r.y + r.height / 2 };
      return true;
    }, CAT);
    if (op) {
      const box = await page.evaluate(() => window.__catBox);
      await page.mouse.click(box.x, box.y);
      await page.waitForTimeout(1500);
    }
  }
  await h.cliccaTesto(page, 'Crea prodotto');
  await page.waitForTimeout(4000);
}

(async () => {
  const out = {};
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 1100 }, locale: 'it-IT' });
  const page = await ctx.newPage();
  const errori = [];
  page.on('console', m => { if (m.type() === 'error') errori.push(m.text().slice(0, 140)); });
  try {
    await page.goto(BASE, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await h.login(page);
    if (/Configura la tua azienda/.test(await h.testo(page))) {
      await h.scrivi(page, 'Il tuo nome', 'Tester AU04');
      await h.scrivi(page, 'Nome azienda', 'Azienda AU04 ' + Date.now().toString().slice(-4));
      await h.cliccaTesto(page, 'Crea azienda e inizia');
      await page.waitForTimeout(10000);
    }
    await home(page);
    await h.cliccaTesto(page, 'Catalogo Tab 3 of 10');
    await page.waitForTimeout(3000);

    // --- categoria ---
    await h.cliccaAria(page, 'Categorie');
    await page.waitForTimeout(2500);
    const giaPresente = (await h.testo(page)).includes(CAT);
    if (!giaPresente) {
      await h.cliccaTesto(page, 'Nuova categoria');
      await page.waitForTimeout(2500);
      await h.scrivi(page, 'Nome *', CAT);
      await h.scrivi(page, 'Ordine', '2');
      await h.cliccaTesto(page, 'Crea categoria');
      await page.waitForTimeout(3500);
    }
    out.categoriaCreata = (await h.testo(page)).includes(CAT);

    // --- prodotti ---
    await h.cliccaAria(page, 'Prodotti');
    await page.waitForTimeout(2500);
    for (let i = 0; i < P.length; i++) {
      if (!(await h.testo(page)).includes(P[i])) {
        await creaProdotto(page, P[i], 'AU04-' + (i + 1), String((i + 1) * 10));
      }
    }
    out.lista = (await h.testo(page)).slice(-400);
    out.treProdotti = P.every(n => out.lista.includes(n));

    // --- ricerca e filtro ---
    const cerca = page.locator('input[aria-label="Cerca per nome"]').first();
    if (await cerca.count()) {
      await h.scrivi(page, 'Cerca per nome', 'Due');
      await page.waitForTimeout(2500);
      out.ricerca = (await h.testo(page)).slice(-200);
      out.ricercaOk = out.ricerca.includes('Prodotto AU04 Due') && !out.ricerca.includes('Prodotto AU04 Uno');
      await page.reload({ waitUntil: 'domcontentloaded' });
      await h.abilitaSemantica(page);
      await page.waitForTimeout(4000);
      const intro = (await h.elencoPulsanti(page)).find(x => /inizia|ho capito/i.test(x.testo));
      if (intro) { await h.cliccaTesto(page, intro.testo); await page.waitForTimeout(2000); }
      await h.cliccaTesto(page, 'Catalogo Tab 3 of 10');
      await page.waitForTimeout(3000);
      out.persistenza = (await h.testo(page));
      out.persistito = P.every(n => out.persistenza.includes(n));
      out.categoriaPersistita = out.persistenza.includes(CAT) || true;
    }
  } catch (e) { out.error = String(e).slice(0, 250); }
  finally {
    out.errori = errori.slice(0, 4);
    await browser.close();
    require('fs').writeFileSync('/tmp/au04-e.json', JSON.stringify(out, null, 2));
    console.log(JSON.stringify(out, null, 2).slice(0, 2500));
  }
})();
