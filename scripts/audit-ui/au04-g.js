const { chromium } = require('playwright');
const h = require('./helpers');

const BASE = process.env.AUDIT_BASE;

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

async function cliccaCheckbox(page, contiene) {
  const box = await page.evaluate((needle) => {
    const n = [...document.querySelectorAll('flt-semantics[role="checkbox"]')]
      .find(x => (x.getAttribute('aria-label') || '').includes(needle));
    if (!n) return null;
    const r = n.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, contiene);
  if (!box) return false;
  await page.mouse.click(box.x, box.y);
  return true;
}

(async () => {
  const out = {};
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 1200 }, locale: 'it-IT' });
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

    const riga = page.locator('flt-semantics', { hasText: 'Prodotto AU04 Uno' }).last();
    const box = await riga.boundingBox();
    await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
    await page.waitForTimeout(3500);
    out.formAperto = /Salva modifiche/.test(await h.testo(page));

    out.spuntatoDue = await cliccaCheckbox(page, 'Prodotto AU04 Due');
    await page.waitForTimeout(800);
    out.spuntatoTre = await cliccaCheckbox(page, 'Prodotto AU04 Tre');
    await page.waitForTimeout(800);
    out.selezionati = await page.evaluate(() => document.body.innerText.includes('Selezionati: 2'));

    await h.cliccaTesto(page, 'Salva modifiche');
    await page.waitForTimeout(5000);
    out.lista = (await h.testo(page)).slice(-420);
    out.badgePaniere = /Paniere|sotto-prodotti/i.test(out.lista);
    out.contaFigli = /2 figli|Paniere: 2/i.test(out.lista);

    // filtro per categoria
    const filtro = (await h.elencoPulsanti(page)).find(b => /^Categoria /.test(b.testo));
    if (filtro) {
      await h.cliccaTesto(page, filtro.testo);
      await page.waitForTimeout(1500);
      const op = (await h.elencoPulsanti(page)).find(b => b.testo.trim() === 'Categoria AU04') ||
                 (await h.elencoPulsanti(page)).find(b => b.testo.includes('Categoria AU04'));
      if (op) { await h.cliccaTesto(page, op.testo); await page.waitForTimeout(2500); }
    }
    out.filtro = (await h.testo(page)).slice(-260);
    out.filtroOk = out.filtro.includes('Prodotto AU04 Uno') && out.filtro.includes('Prodotto AU04 Tre');
  } catch (e) { out.error = String(e).slice(0, 250); }
  finally {
    out.errori = errori.slice(0, 4);
    await browser.close();
    require('fs').writeFileSync('/tmp/au04-g.json', JSON.stringify(out, null, 2));
    console.log(JSON.stringify(out, null, 2).slice(0, 2500));
  }
})();
