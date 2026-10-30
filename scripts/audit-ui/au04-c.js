const { chromium } = require('playwright');
const h = require('./helpers');

const BASE = process.env.AUDIT_BASE;
const CAT = 'Categoria AU04';
const P1 = 'Prodotto AU04 Uno';
const P2 = 'Prodotto AU04 Due';
const P3 = 'Prodotto AU04 Tre';

async function vaiAllaHome(page) {
  for (let i = 0; i < 8; i++) {
    const b = await h.elencoPulsanti(page);
    if (b.some(x => /Preventivi Tab 4 of 10/.test(x.testo))) return true;
    const intro = b.find(x => /inizia|ho capito/i.test(x.testo));
    if (intro) { await h.cliccaTesto(page, intro.testo); await page.waitForTimeout(2500); continue; }
    await page.waitForTimeout(3000);
  }
  return false;
}

async function scriviCampo(page, label, valore) {
  const el = page.locator(`input[aria-label="${label}"]`).first();
  if (await el.count()) return h.scrivi(page, label, valore);
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
  await scriviCampo(page, 'Nome prodotto', nome);
  await h.scrivi(page, 'Codice prodotto', codice);
  await h.scrivi(page, 'Prezzo (€)', prezzo);
  // categoria: apre il selettore e sceglie Categoria AU04
  const bottoni = await h.elencoPulsanti(page);
  const catBtn = bottoni.find(x => /^Categoria /.test(x.testo));
  if (catBtn) {
    await h.cliccaTesto(page, catBtn.testo);
    await page.waitForTimeout(1500);
    const opzione = (await h.elencoPulsanti(page)).find(x => x.testo === CAT) ||
                    (await h.elencoPulsanti(page)).find(x => x.testo.includes(CAT));
    if (opzione) await h.cliccaTesto(page, opzione.testo);
    await page.waitForTimeout(1500);
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
    await vaiAllaHome(page);
    await h.cliccaTesto(page, 'Catalogo Tab 3 of 10');
    await page.waitForTimeout(3000);

    // --- scheda Categorie ---
    out.tabCategorie = (await h.elencoPulsanti(page)).map(b => b.testo).filter(t => /Categor/i.test(t));
    const tabCat = (await h.elencoPulsanti(page)).find(b => /^Categorie/.test(b.testo));
    if (tabCat) { await h.cliccaTesto(page, tabCat.testo); await page.waitForTimeout(2500); }
    out.categorieSchermata = (await h.testo(page)).slice(-250);
    out.bottoniCategorie = (await h.elencoPulsanti(page)).map(b => b.testo).slice(-8);

    const nuovaCat = (await h.elencoPulsanti(page)).find(b => /nuova categoria/i.test(b.testo));
    out.trovataNuovaCategoria = !!nuovaCat;
    if (nuovaCat) {
      await h.cliccaTesto(page, nuovaCat.testo);
      await page.waitForTimeout(2000);
      const primo = page.locator('input[aria-label="Nome categoria"]').first();
      if (await primo.count()) await h.scrivi(page, 'Nome categoria', CAT);
      else await scriviCampo(page, 'Nome', CAT);
      await h.cliccaTesto(page, 'Salva');
      await page.waitForTimeout(3500);
      out.categoriaCreata = (await h.testo(page)).includes(CAT);
    }

    // --- prodotti ---
    const tabProd = (await h.elencoPulsanti(page)).find(b => /^Prodotti/.test(b.testo));
    if (tabProd) { await h.cliccaTesto(page, tabProd.testo); await page.waitForTimeout(2500); }
    await creaProdotto(page, P1, 'AU04-1', '10');
    await creaProdotto(page, P2, 'AU04-2', '20');
    await creaProdotto(page, P3, 'AU04-3', '30');
    out.lista = (await h.testo(page)).slice(-400);
    out.treProdotti = [P1, P2, P3].every(n => out.lista.includes(n));
  } catch (e) { out.error = String(e).slice(0, 220); }
  finally {
    out.errori = errori.slice(0, 4);
    await browser.close();
    require('fs').writeFileSync('/tmp/au04-c.json', JSON.stringify(out, null, 2));
    console.log(JSON.stringify(out, null, 2).slice(0, 3000));
  }
})();
