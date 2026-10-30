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
async function apriFiltro(page) {
  const b = (await h.elencoPulsanti(page)).find(x => /^Categoria /.test(x.testo));
  await h.cliccaTesto(page, b.testo);
  await page.waitForTimeout(1800);
}
async function voci(page) {
  return page.evaluate(() => [...document.querySelectorAll('flt-semantics[role="menuitem"], flt-semantics[aria-label]')]
    .map(n => ({ a: n.getAttribute('aria-label') || '', t: (n.innerText || '').trim().slice(0, 40), r: n.getAttribute('role') || '' }))
    .filter(x => x.a || x.t));
}
async function scegli(page, inizio) {
  const box = await page.evaluate((needle) => {
    const n = [...document.querySelectorAll('flt-semantics')]
      .find(x => (x.getAttribute('aria-label') || '').trim().startsWith(needle));
    if (!n) return null;
    const r = n.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, inizio);
  if (!box) return false;
  await page.mouse.click(box.x, box.y);
  await page.waitForTimeout(2800);
  return true;
}
(async () => {
  const out = {};
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 1200 }, locale: 'it-IT' });
  const page = await ctx.newPage();
  try {
    await page.goto(BASE, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await h.login(page);
    await home(page);
    await h.cliccaTesto(page, 'Catalogo Tab 3 of 10');
    await page.waitForTimeout(3000);

    await apriFiltro(page);
    out.vociMenu = await voci(page);
    out.sceltoGenerale = await scegli(page, 'Generale');
    out.dopoGenerale = (await h.testo(page)).slice(-160);
    out.vuotoGenerale = /Nessun prodotto/.test(out.dopoGenerale);

    await apriFiltro(page);
    out.sceltoTutte = await scegli(page, 'Tutte le categorie');
    out.dopoTutte = (await h.testo(page)).slice(-200);
    out.treProdotti = ['Prodotto AU04 Uno', 'Prodotto AU04 Due', 'Prodotto AU04 Tre'].every(n => out.dopoTutte.includes(n));
  } catch (e) { out.error = String(e).slice(0, 220); }
  finally { await browser.close(); console.log(JSON.stringify(out, null, 2).slice(0, 2500)); }
})();
